import logging
from typing import Tuple
from paramiko import AutoAddPolicy, SSHClient, Channel, SSHConfig
from paramiko.auth_strategy import Password, AuthStrategy
import re
from datetime import datetime
import asyncio
import socket
from src.models.enums import Term
from src.parsers.ansi_parser import parse_department_page
from src.constants import TERMS
from pathlib import Path

from src.scrapers.log_utils import get_scraper_run_id

MAX_RETRIES = 1


def get_term_year(term: str | None = None) -> Tuple[str, int]:
    now = datetime.now()
    current_term = TERMS[now.month - 1]
    if term is None:
        term = current_term.value
    year = now.year
    if current_term == Term.SECOND_SEMESTER and Term(term) == Term.SECOND_SEMESTER:
        year -= 1
    return (term, year)


async def send_input(chan: Channel, inputs: list[Tuple[str, float]]) -> bool:
    res = 0
    for x in inputs:
        res = chan.send(x[0].encode("ansi"))
        if x[1] >= 0:
            await asyncio.sleep(x[1])
    return res != 0


async def read_channel(chan: Channel) -> str:
    result = []
    await asyncio.sleep(0.05)
    while chan.recv_ready():
        result.append(chan.recv(1000))
        await asyncio.sleep(0.03)
    return "".join(map(lambda b: b.decode("ansi"), result))


async def setup(chan: Channel, term: str):
    global term_input
    logging.info(f"SSH Task: Setting up channel {hex(id(chan))} for term {term}")
    await send_input(chan, [("5", 1), ("6", 1)])
    terms_page = await read_channel(chan)
    terms = re.findall(r"\d\=[0-9A-Za-z]+", terms_page)
    terms = {term.split("=")[1]: term.split("=")[0] for term in terms}
    term_input = terms[term]
    logging.debug(f"SSH Task: Selected term input: {term_input} for term {term}")
    await send_input(chan, [(term_input, -1)])
    logging.info(
        f"SSH Task: Channel {hex(id(chan))} successfully set up for term {term}"
    )


def log_department_page(channel_id: str, dept: str, raw_content: str) -> None:
    file_path = Path(f"output_files/{get_scraper_run_id()}/{channel_id}/{dept}.ansi")
    logging.debug(
        f"SSH Task: Logging department page for {dept} to {file_path.as_posix()}"
    )
    file_path.parent.mkdir(parents=True, exist_ok=True)
    with file_path.open("a") as f:
        f.write(raw_content)
        f.write("\n")
    logging.debug(f"SSH Task: Successfully logged department page for {dept}")


class PuttyAuth(AuthStrategy):
    def get_sources(self):
        yield Password("estudiante", lambda: "")


async def initialize_ssh_channels(clients: list[SSHClient]) -> list[Channel]:
    channels = []
    for i, ssh in enumerate(clients):
        logging.info(f"SSH Task: Initializing SSH client {i+1}/{len(clients)}")
        try:
            ssh.set_missing_host_key_policy(AutoAddPolicy())
            ssh.connect(
                "rumad.uprm.edu",
                username="estudiante",
                password="",
                auth_strategy=PuttyAuth(ssh_config=SSHConfig()),
            )
            channel = ssh.invoke_shell()
            channel_id = hex(id(channel))
            logging.info(f"SSH Task: Successfully opened channel {channel_id}")
            channels.append(channel)
            await asyncio.sleep(
                0.0001
            )  # give some time to process other tasks in the io queue
        except Exception as e:
            logging.error(f"SSH Task: Failed to initialize SSH client {i+1}: {str(e)}")
            raise
    logging.info(f"SSH Task: Successfully initialized {len(channels)} SSH channels")
    return channels


async def scrape_department_availability(channel, department_data: dict):
    department = department_data["department"]
    channel_id = hex(id(channel))
    scraped_year = None

    logging.info(f"SSH Task: Channel {channel_id} started scraping {department}")
    await send_input(channel, [(f"{department}\n", 5)])
    raw_department_result = await read_channel(channel)

    if "< Oprima Enter o [PF4(9)=Fin] >" not in raw_department_result:
        logging.warning(
            f"SSH Task: No section availability data found for {department} on channel {channel_id}"
        )
        log_department_page(channel_id, department, raw_department_result)
        return department_data

    courses = {}
    page_count = 0
    while "< Oprima Enter o [PF4(9)=Fin] >" in raw_department_result:
        page_count += 1
        logging.debug(
            f"SSH Task: Processing page {page_count} for department {department} on channel {channel_id}"
        )
        parsed_page = parse_department_page(raw_department_result)
        course = parsed_page.get("courseCode", None)
        if scraped_year is None and "year" in parsed_page:
            scraped_year = parsed_page["year"]
            logging.debug(
                f"SSH Task: Detected year {scraped_year} for department {department}"
            )

        if course is None or len(parsed_page["sections"]) == 0:
            logging.debug(
                f"SSH Task: No valid course or sections found on page {page_count} for {department}"
            )
            await send_input(channel, [("\n", 0.5)])
            raw_department_result = await read_channel(channel)
            continue

        if course not in courses:
            courses[course] = []
            logging.debug(
                f"SSH Task: Found new course {course} for department {department}"
            )

        sections_count = len(parsed_page["sections"])
        courses[course].extend(parsed_page["sections"].values())
        logging.debug(
            f"SSH Task: Added {sections_count} sections for course {course} (department {department})"
        )

        await send_input(channel, [("\n", 1)])
        raw_department_result = await read_channel(channel)

    if scraped_year is None or scraped_year != department_data["year"]:
        logging.warning(
            f"SSH Task: Scraped year {scraped_year} does not match expected year {department_data['year']} for {department}"
        )
        return department_data

    updated_sections_count = 0
    for course_data in department_data["courses"].values():
        course_code = course_data["courseCode"]
        for existingSection in course_data["sections"]:
            for scrapedSection in courses.get(course_code, []):
                if existingSection["sectionCode"] == scrapedSection["sectionCode"]:
                    existingSection["capacity"] = scrapedSection["capacity"]
                    existingSection["usage"] = scrapedSection["usage"]
                    updated_sections_count += 1

    logging.info(
        f"SSH Task: Finished scraping {department} on channel {channel_id}: processed {page_count} pages, "
        f"found {len(courses)} courses, updated {updated_sections_count} sections"
    )
    return department_data


async def ssh_scraper_task(
    rumad_term: str,
    ssh_queue: asyncio.Queue,
    db_queue: asyncio.Queue,
    channel: Channel,
):
    task_id = hex(id(channel))[-6:]  # Use last 6 chars of channel id as task identifier
    logging.info(f"SSH Task: Starting scraper task {task_id} for term {rumad_term}")

    try:
        await setup(channel, rumad_term)
        departments_processed = 0

        while True:
            try:
                department_data = await ssh_queue.get()
                department = department_data["department"]
                departments_processed += 1

                logging.info(
                    f"SSH Task: Task {task_id} processing department {department} (#{departments_processed})"
                )

                retry_count = 0
                while retry_count < MAX_RETRIES:
                    try:
                        updated_data = await scrape_department_availability(
                            channel, department_data
                        )
                        await db_queue.put(updated_data)
                        logging.debug(
                            f"SSH Task: Successfully queued data for {department} to database"
                        )
                        break
                    except socket.error as e:
                        retry_count += 1
                        logging.error(
                            f"SSH Task: Socket error while scraping {department} on task {task_id} "
                            f"(attempt {retry_count}/{MAX_RETRIES}): {str(e)}"
                        )
                        if retry_count >= MAX_RETRIES:
                            logging.critical(
                                f"SSH Task: Max retries exceeded for {department}, reconnecting channel"
                            )
                            channel = (await initialize_ssh_channels([SSHClient()]))[0]
                            await setup(channel, rumad_term)
                            # Put back in queue for another attempt after reconnection
                            await ssh_queue.put(department_data)
                            ssh_queue.task_done()
                            continue
                        await asyncio.sleep(retry_count * 2)  # Exponential backoff

                ssh_queue.task_done()
                logging.info(
                    f"SSH Task: Task {task_id} completed processing department {department}"
                )

            except Exception as e:
                logging.exception(
                    f"SSH Task: Unexpected error in task {task_id}: {str(e)}"
                )
                # Make sure to mark task as done even if it fails
                ssh_queue.task_done()
    except Exception as e:
        logging.exception(f"SSH Task: Fatal error in scraper task {task_id}: {str(e)}")
        raise
