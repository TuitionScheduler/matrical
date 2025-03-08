import json
import logging
import datetime
import sys
import time
import argparse
import asyncio
from aiolimiter import AsyncLimiter
from paramiko import SSHClient
from sqlalchemy import delete
from src.parsers.schedule_parser import parse_schedule
from src.scrapers.log_utils import ScraperTarget, configure_logging
from src.scrapers.ssh_scraper import (
    initialize_ssh_channels,
    ssh_scraper_task,
)
from src.database import Course, Section, Meeting, Base
from src.constants import db_to_rumad_terms, ideal_ssh_tasks
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import (
    create_async_engine,
    AsyncSession,
    AsyncEngine,
    async_sessionmaker,
)
from sqlalchemy.orm import selectinload
from src.scrapers.web_scraper import web_scraper_task


async def write_to_database_task(
    db_queue: asyncio.Queue,
    async_engine: AsyncEngine,
):
    AsyncSessionLocal = async_sessionmaker(
        async_engine, class_=AsyncSession, expire_on_commit=False
    )
    # define these vars so they aren't unbound later on
    course = None
    course_code = None

    while True:
        data = await db_queue.get()
        department = data["department"]
        logging.info(f"DB Task: Adding {department} to SQL DB")
        term = data["term"]
        year = data["year"]
        async with AsyncSessionLocal() as session:
            with session.no_autoflush:
                try:
                    # Go through all the courses, delete existing db records, then batch add all the new records
                    courses = []
                    for course_code, course_data in data["courses"].items():
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

                        # delete the existing version of the course and add the new one to the db
                        course_delete_query = delete(Course).where(
                            Course.course_code == course_code
                            and Course.term == term
                            and Course.year == year
                        )
                        await session.execute(course_delete_query)
                        courses.append(course)
                    try:
                        logging.info(
                            f"DB Task: Adding {len(courses)} courses to SQL DB"
                        )
                        session.add_all(courses)
                        await asyncio.wait_for(session.commit(), timeout=30)
                        logging.info(f"DB Task: Saved {department} to SQL DB")
                    except asyncio.TimeoutError:
                        logging.warning(f"DB Task: Commit timeout for {department}.")
                except IntegrityError as e:
                    logging.exception(f"DB Task: IntegrityError for {course}: {str(e)}")
                    await session.rollback()
                except Exception as e:
                    logging.exception(
                        f"DB Task: Error saving course {course_code} to DB: {str(e)}"
                    )
                    await session.rollback()
                finally:
                    db_queue.task_done()


async def pass_through_queue_task(
    source_queue: asyncio.Queue, destination_queue: asyncio.Queue
):
    while True:
        data = await source_queue.get()
        source_queue.task_done()
        await destination_queue.put(data)


async def scrape_to_sql(db_term, year, ssh_tasks, disable_ssh=False):
    # if invalid db_term, disable ssh
    if db_term not in db_to_rumad_terms:
        logging.warning(
            f"Term {db_term} not found in db_to_rumad_terms. SSH scraping will be skipped."
        )
        disable_ssh = True
    # Set up logging
    configure_logging(ScraperTarget.SQLite)
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
    clients = [SSHClient() for _ in range(ssh_tasks)] if not disable_ssh else []
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
    if disable_ssh:
        logging.info("SSH scraping disabled. Only using web data.")
        ssh_scraper_tasks = [
            asyncio.create_task(
                pass_through_queue_task(
                    source_queue=ssh_queue, destination_queue=db_queue
                )
            )
        ]
        channels = []
    else:
        channels = await initialize_ssh_channels(clients=clients)
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
        write_to_database_task(db_queue=db_queue, async_engine=engine)
    )

    await web_queue.join()
    logging.info("All web scraper tasks have completed.")
    web_scrape_time = time.time()
    await ssh_queue.join()
    logging.info("All ssh scraper tasks have completed.")
    ssh_scrape_time = time.time()
    await db_queue.join()
    logging.info("All db tasks have completed.")
    db_save_time = time.time()

    logging.info(
        f"""
Time Breakdown:
Course Offering Web Scraping: {round(web_scrape_time-start_time, 2)} seconds
{"Section Availability SSH Scraping" if not disable_ssh else "SSH Scraping (disabled)"}: {round(ssh_scrape_time-web_scrape_time, 2)} seconds
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


def get_available_terms():
    """Return a list of available terms from the db_to_rumad_terms dictionary."""
    return list(db_to_rumad_terms.keys())


def interactive_mode():
    """Run the scraper in interactive mode, prompting for parameters."""
    print("\n🔍 UPRM Course Scraper 🔍\n")

    available_terms = get_available_terms()
    print("Available terms:")
    for i, term in enumerate(available_terms, 1):
        print(f"  {i}. {term}")

    while True:
        try:
            term_choice = int(input("\nSelect term (number): "))
            if 1 <= term_choice <= len(available_terms):
                db_term = available_terms[term_choice - 1]
                break
            else:
                print(f"Please enter a number between 1 and {len(available_terms)}")
        except ValueError:
            print("Please enter a valid number")

    # Get year
    current_year = datetime.datetime.now().year
    year = int(input(f"\nEnter year [{current_year}]: ") or current_year)

    # Get SSH tasks
    while True:
        try:
            ssh_tasks = int(input("\nEnter number of SSH tasks [4]: ") or "4")
            if 1 <= ssh_tasks <= 30:  # Reasonable range check
                break
            else:
                print("Please enter a number between 1 and 30")
        except ValueError:
            print("Please enter a valid number")

    disable_ssh = input("\nDisable SSH scraping? (y/N) [N]: ").lower() in ("y", "yes")

    ssh_status = "disabled" if disable_ssh else f"enabled with {ssh_tasks} tasks"
    print(
        f"\nStarting scraper with term={db_term}, year={year}, SSH scraping: {ssh_status}"
    )
    print("Working...\n")

    # Run the scraper with the provided parameters
    asyncio.run(
        scrape_to_sql(
            db_term=db_term, year=year, ssh_tasks=ssh_tasks, disable_ssh=disable_ssh
        )
    )


def main():
    parser = argparse.ArgumentParser(
        description="UPRM Course Scraper - Collects and stores course information from UPRM systems",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser.add_argument(
        "-t",
        "--term",
        choices=get_available_terms(),
        help=f"Academic term to scrape (e.g., {', '.join(get_available_terms())})",
    )

    current_year = datetime.datetime.now().year
    parser.add_argument(
        "-y",
        "--year",
        type=int,
        default=current_year,
        help=f"Academic year to scrape (e.g., {current_year})",
    )

    parser.add_argument(
        "-s",
        "--ssh-tasks",
        type=int,
        default=0,
        help="Number of SSH connections to use for concurrent scraping",
    )

    parser.add_argument(
        "--no-ssh",
        action="store_true",
        help="Disable SSH scraping (only get data from web sources)",
    )

    parser.add_argument(
        "--list-terms", action="store_true", help="List all available terms and exit"
    )

    parser.add_argument(
        "-i",
        "--interactive",
        action="store_true",
        help="Run in interactive mode (ignores other arguments)",
    )

    args = parser.parse_args()

    # List terms if requested
    if args.list_terms:
        print("Available terms:")
        for i, term in enumerate(get_available_terms()):
            print(f"{i+1}. {term}")
        return

    # Check if interactive mode is requested or no args provided
    if args.interactive or (not args.term and len(sys.argv) == 1):
        interactive_mode()
        return

    if not args.term:
        parser.error("the following arguments are required: -t/--term")

    ssh_tasks = args.ssh_tasks
    if not ssh_tasks:
        ssh_tasks = ideal_ssh_tasks[args.term]

    ssh_status = "disabled" if args.no_ssh else f"enabled with {args.ssh_tasks} tasks"
    print(
        f"Starting scraper with term={args.term}, year={args.year}, SSH scraping: {ssh_status}"
    )
    asyncio.run(
        scrape_to_sql(
            db_term=args.term,
            year=args.year,
            ssh_tasks=ssh_tasks,
            disable_ssh=args.no_ssh,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nOperation cancelled by user. Exiting...")
        sys.exit(0)
