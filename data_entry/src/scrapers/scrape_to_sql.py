import json
import os
import socket
from sqlite3 import IntegrityError
import sys
import time
import aiohttp
import re
import asyncio
from aiolimiter import AsyncLimiter
from paramiko import Channel, SSHClient
from sqlalchemy import select
from src.parsers.schedule_parser import parse_schedule
from src.scrapers.ssh_scraper import (
    initialize_ssh_channels,
    ssh_scraper_task,
)
from src.database import Course, Section, Meeting, Base
from src.parsers.schedule_parser import parse_schedule
from src.constants import db_to_rumad_terms
from src.database import Base, Course, Section, Meeting

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from sqlalchemy.ext.asyncio import (
    create_async_engine,
    AsyncSession,
    AsyncEngine,
    async_sessionmaker,
)
from sqlalchemy.orm import selectinload

from src.scrapers.web_scraper import web_scraper_task


async def write_to_database_task(db_queue: asyncio.Queue, async_engine: AsyncEngine):
    AsyncSessionLocal = async_sessionmaker(
        async_engine, class_=AsyncSession, expire_on_commit=False
    )
    while True:
        data = await db_queue.get()
        department = data["department"]
        term = data["term"]
        year = data["year"]
        async with AsyncSessionLocal() as session:
            with session.no_autoflush:
                try:
                    for course_code, course_data in data["courses"].items():

                        # Use selectinload to eagerly load sections and meetings
                        course_query = (
                            select(Course)
                            .options(
                                selectinload(Course.sections).selectinload(
                                    Section.meetings
                                )
                            )
                            .filter_by(course_code=course_code, year=year, term=term)
                        )
                        result = await session.execute(course_query)
                        course = result.scalar_one_or_none()

                        if not course:
                            course = Course(
                                course_code=course_code,
                                course_name=course_data["courseName"],
                                year=year,
                                term=term,
                                credits=course_data["credits"],
                                department=course_data["department"],
                                prerequisites=course_data["prerequisites"],
                                corequisites=course_data["corequisites"],
                            )
                            session.add(course)
                        else:
                            # Update existing course data
                            course.course_name = course_data["courseName"]
                            course.credits = course_data["credits"]
                            course.department = course_data["department"]
                            course.prerequisites = course_data["prerequisites"]
                            course.corequisites = course_data["corequisites"]

                        # Remove existing sections and their meetings
                        if course.sections:
                            for section in course.sections:
                                for meeting in section.meetings:
                                    await session.delete(meeting)
                                await session.delete(section)
                            await session.flush()
                        # Add new sections and meetings
                        for section_data in course_data["sections"]:
                            section = Section(
                                section_code=section_data["sectionCode"],
                                meetings_text=",".join(section_data["meetings"]),
                                modality=section_data["modality"],
                                capacity=section_data["capacity"],
                                taken=section_data["usage"],
                                reserved=section_data["reserved"],
                                professors=",".join(
                                    [
                                        prof["name"]
                                        for prof in section_data["professors"]
                                    ]
                                ),
                                misc=section_data["misc"],
                            )
                            course.sections.append(section)
                            for meeting_text in section_data["meetings"]:
                                meetingDict = parse_schedule(meeting_text)
                                if meetingDict is None:
                                    continue
                                meeting = Meeting(
                                    building=meetingDict["building"],
                                    room=meetingDict["room"],
                                    days=meetingDict["days"],
                                    start_time=meetingDict["start_time"],
                                    end_time=meetingDict["end_time"],
                                )
                                section.meetings.append(meeting)
                    await session.merge(course)
                except IntegrityError as e:
                    print(f"IntegrityError for course {course_code}: {str(e)}")
                    await session.rollback()
                except Exception as e:
                    print(f"Error saving course {course_code} to DB: {str(e)}")
                    await session.rollback()
                else:
                    await session.commit()
                    print(f"Saved {department} to SQL DB")
        db_queue.task_done()


async def pass_through_queue_task(
    source_queue: asyncio.Queue, destination_queue: asyncio.Queue
):
    while True:
        data = await source_queue.get()
        source_queue.task_done()
        await destination_queue.put(data)


async def scrape_to_sql(db_term, year, ssh_tasks):

    start_time = time.time()
    engine = create_async_engine("sqlite+aiosqlite:///courses.db", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    with open("input_files/professor_ids.txt") as file:
        professor_ids = json.load(file)
    with open("input_files/departments.txt") as file:
        departments = [department.strip() for department in file]
    # Departments will travel like so: File -> Web Queue -> SSH Queue -> DB Queue
    # ssh queue and db queue have dictionary representations of all the courses in a department
    web_queue: asyncio.Queue[str] = asyncio.Queue()
    ssh_queue: asyncio.Queue[dict] = asyncio.Queue()
    db_queue: asyncio.Queue[dict] = asyncio.Queue()
    clients = [SSHClient() for _ in range(ssh_tasks)]
    web_request_limiter = AsyncLimiter(4, 1)
    # populate Web Queue
    for department in departments:
        web_queue.put_nowait(department)

    # Create and queue up tasks to scrape course data from UPRM course offering website
    web_scraper_tasks = [
        asyncio.create_task(
            web_scraper_task(
                web_queue,
                ssh_queue,
                db_term,
                year,
                professor_ids,
                rate_limit=web_request_limiter,
            )
        )
        for _ in range(4)
    ]

    # Create and queue up tasks to scrape section availability from UPRM enrollment server
    channels = await initialize_ssh_channels(clients)
    if db_term not in db_to_rumad_terms:
        ssh_scraper_tasks = [
            asyncio.create_task(pass_through_queue_task(ssh_queue, db_queue))
        ]
    else:
        ssh_scraper_tasks = [
            asyncio.create_task(
                ssh_scraper_task(
                    db_to_rumad_terms[db_term], ssh_queue, db_queue, channel
                )
            )
            for channel in channels
        ]

    # Create and queue up database task to store scraped departments
    db_task = asyncio.create_task(write_to_database_task(db_queue, engine))

    await web_queue.join()
    web_scrape_time = time.time()
    await ssh_queue.join()
    ssh_scrape_time = time.time()
    await db_queue.join()
    db_save_time = time.time()
    print(
        f"""
Time Breakdown:
Course Offering Web Scraping: {round(web_scrape_time-start_time, 2)} seconds
Section Availability SSH Scraping: {round(ssh_scrape_time-web_scrape_time, 2)} seconds
Database Storing: {round(db_save_time-ssh_scrape_time, 2)} seconds
Total Time: {round(db_save_time-start_time, 2)} seconds
          """
    )

    # clean up tasks and resources
    for chan in channels:
        chan.close()
    for ssh in clients:
        ssh.close()
    db_task.cancel()
    for task in web_scraper_tasks:
        task.cancel()
    for task in ssh_scraper_tasks:
        task.cancel()


if __name__ == "__main__":
    db_term = sys.argv[1]
    year = int(sys.argv[2])
    # web_tasks = int(sys.argv[3])
    ssh_tasks = int(sys.argv[3])
    asyncio.run(scrape_to_sql(db_term=db_term, year=year, ssh_tasks=ssh_tasks))
