import logging
import firebase_admin.firestore_async
import sys
import time
import json
import os
import asyncio
import firebase_admin.firestore_async as firestore_async
from firebase_admin import credentials
from google.cloud.firestore_v1 import AsyncClient

import datetime
from src.models.stats import DeptStats
from aiolimiter import AsyncLimiter
from paramiko import SSHClient
from src.scrapers.log_utils import ScraperTarget, configure_logging
from src.scrapers.ssh_scraper import (
    initialize_ssh_channels,
    ssh_scraper_task,
)
from src.constants import db_to_rumad_terms
from src.scrapers.web_scraper import web_scraper_task


def calculate_doc_size(data: dict | str | bool | list | None) -> int:
    if isinstance(data, dict):
        size = 0
        for key, value in data.items():
            key_size = len(key) + 1
            value_size = calculate_doc_size(value)
            key_pair_size = key_size + value_size
            size += key_pair_size
        return size
    elif isinstance(data, str):
        return len(data) + 1
    elif any([isinstance(data, bool), data is None]):
        return 1
    elif isinstance(data, (datetime.datetime, float, int)):
        return 8
    elif isinstance(data, list):
        return sum([calculate_doc_size(item) for item in data], start=0)
    else:
        logging.warning(
            f"Tried to calculate document size for unknown data type: {type(data)}"
        )
        return 0


def calculate_doc_name_size(path):
    size = 0
    for collection in path.split("/"):
        size += len(collection) + 1
    return size + 16


async def write_to_firebase_task(
    db_queue: asyncio.Queue,
    client: AsyncClient,
    scraped_depts: list[str],
    dept_stats: list[DeptStats],
):
    collection_ref = client.collection("DepartmentCourses")
    while True:
        data = await db_queue.get()
        department = data["department"]
        term = data["term"]
        year = data["year"]
        await collection_ref.document(
            f"{department}:{term.replace(' ','')}:{year}"
        ).set(data)
        scraped_depts.append(department)
        dept_stats.append(
            DeptStats(
                department,
                calculate_doc_name_size(
                    f"DepartmentCourses/{department}:{data['term']}:{year}"
                )
                + calculate_doc_size(data),  # type: ignore
                len(data["courses"].keys()),
                sum(len(course["sections"]) for course in data["courses"].values()),
            )
        )
        logging.info(f"Saved {department} to Firebase")
        db_queue.task_done()


async def pass_through_queue_task(
    source_queue: asyncio.Queue, destination_queue: asyncio.Queue
):
    while True:
        data = await source_queue.get()
        source_queue.task_done()
        await destination_queue.put(data)


async def scrape_to_firebase(db_term, year, ssh_tasks):
    # Set up logging
    configure_logging(ScraperTarget.Firebase)
    # Setup Firebase access
    cred = credentials.Certificate("credentials.json")
    app = firebase_admin.initialize_app(cred)
    client = firestore_async.client(app)
    start_time = time.time()

    dept_stats: list[DeptStats] = []
    scraped_depts = []

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
                web_queue=web_queue,
                ssh_queue=ssh_queue,
                db_term=db_term,
                year=year,
                professor_ids=professor_ids,
                rate_limit=web_request_limiter,
            )
        )
        for _ in range(4)
    ]

    # Create and queue up tasks to scrape section availability from UPRM enrollment server
    channels = await initialize_ssh_channels(clients=clients)
    if db_term not in db_to_rumad_terms:
        ssh_scraper_tasks = [
            asyncio.create_task(
                pass_through_queue_task(
                    source_queue=ssh_queue, destination_queue=db_queue
                )
            )
        ]
    else:
        ssh_scraper_tasks = [
            asyncio.create_task(
                ssh_scraper_task(
                    rumad_term=db_to_rumad_terms[db_term],
                    ssh_queue=ssh_queue,
                    db_queue=db_queue,
                    channel=channel,
                )
            )
            for channel in channels
        ]

    # Create and queue up database task to store scraped departments
    db_task = asyncio.create_task(
        write_to_firebase_task(db_queue, client, scraped_depts, dept_stats)
    )

    if not os.path.isdir("output_files"):
        os.makedirs("output_files")
    with open("output_files/dept_stats.csv", "w") as file:
        file.write("Department,Bytes,CourseCount,SectionCount\n")
        for dept in dept_stats:
            file.write(
                f"{dept.dept},{dept.bytes},{dept.course_count},{dept.section_count}\n"
            )
    await web_queue.join()
    web_scrape_time = time.time()
    await ssh_queue.join()
    ssh_scrape_time = time.time()
    await db_queue.join()
    db_save_time = time.time()

    departmentCoursesEntryInfoDocRef = client.collection(
        "DataEntryInformation"
    ).document("DepartmentCourses")

    await departmentCoursesEntryInfoDocRef.set(
        document_data={
            f"termYearScrapeInfo": {
                f"{db_term}:{year}": {
                    "departments": scraped_depts,
                    "lastUpdated": datetime.datetime.now(),
                }
            }
        },
        merge=True,
    )

    # termYearScrapeInfo[f"{db_term}:{year}"] = {
    #     "lastUpdated": datetime.datetime.now(),
    #     "departments": scraped_depts,
    # }

    # await client.collection("DataEntryInformation").document("DepartmentCourses").set(
    #     {"termYearScrapeInfo": termYearScrapeInfo}
    # )

    logging.info(
        f"""
Time Breakdown:
Course Offering Web Scraping: {round(web_scrape_time-start_time, 2)} seconds
Section Availability SSH Scraping: {round(ssh_scrape_time-web_scrape_time, 2)} seconds
Database Storing: {round(db_save_time-ssh_scrape_time, 2)} seconds
Total Time: {round(db_save_time-start_time, 2)} seconds
          """
    )

    # clean up tasks and resources
    client.close()
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
    ssh_tasks = int(sys.argv[3])

    with asyncio.Runner() as runner:
        runner.run(scrape_to_firebase(db_term=db_term, year=year, ssh_tasks=ssh_tasks))
    exit()
