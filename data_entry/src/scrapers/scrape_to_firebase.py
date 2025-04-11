import logging
import firebase_admin
import firebase_admin.firestore_async as firestore_async
import sys
import time
import json
import os
import asyncio
import argparse
import datetime
from aiolimiter import AsyncLimiter
from paramiko import SSHClient
from firebase_admin import credentials, initialize_app
from google.cloud.firestore_v1 import AsyncClient

from src.models.stats import DeptStats
from src.scrapers.log_utils import ScraperTarget, configure_logging
from src.scrapers.ssh_scraper import (
    initialize_ssh_channels,
    ssh_scraper_task,
)
from src.constants import db_to_rumad_terms, ideal_ssh_tasks
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


async def scrape_to_firebase(db_term, year, ssh_tasks, disable_ssh=False):
    # if invalid db_term, disable ssh
    if db_term not in db_to_rumad_terms:
        logging.warning(
            f"Term {db_term} not found in db_to_rumad_terms. SSH scraping will be skipped."
        )
        disable_ssh = True

    # Set up logging
    configure_logging(ScraperTarget.Firebase)

    # Setup Firebase access
    cred = credentials.Certificate(json.loads(os.environ["CREDENTIALS_JSON"]))
    app = initialize_app(cred)
    client = firestore_async.client(app)
    logging.info(f"Starting scraping of {db_term} {year}-{year+1}")
    start_time = time.time()

    dept_stats: list[DeptStats] = []
    scraped_depts = []

    with open("input_files/professor_ids.txt") as file:
        professor_ids = json.load(file)
    with open("input_files/departments.txt") as file:
        departments = sorted([department.strip() for department in file])

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
        write_to_firebase_task(
            db_queue=db_queue,
            client=client,
            scraped_depts=scraped_depts,
            dept_stats=dept_stats,
        )
    )

    if not os.path.isdir("output_files"):
        os.makedirs("output_files")

    await web_queue.join()
    web_scrape_time = time.time()
    await ssh_queue.join()
    ssh_scrape_time = time.time()
    await db_queue.join()
    db_save_time = time.time()

    # Write stats to file
    with open("output_files/dept_stats.csv", "w") as file:
        file.write("Department,Bytes,CourseCount,SectionCount\n")
        for dept in dept_stats:
            file.write(
                f"{dept.dept},{dept.bytes},{dept.course_count},{dept.section_count}\n"
            )

    # Update Firebase metadata
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


def get_available_terms():
    """Return a list of available terms from the db_to_rumad_terms dictionary."""
    return list(db_to_rumad_terms.keys())


def interactive_mode():
    """Run the scraper in interactive mode, prompting for parameters."""
    print("\n🔍 UPRM Course Scraper - Firebase Edition 🔍\n")

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
        scrape_to_firebase(
            db_term=db_term, year=year, ssh_tasks=ssh_tasks, disable_ssh=disable_ssh
        )
    )


def main():
    parser = argparse.ArgumentParser(
        description="UPRM Course Scraper for Firebase - Collects and stores course information from UPRM systems",
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
        scrape_to_firebase(
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
