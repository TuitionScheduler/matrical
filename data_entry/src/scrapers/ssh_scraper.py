from typing import Tuple
from paramiko import AutoAddPolicy, SSHClient, Channel, SSHConfig
from paramiko.auth_strategy import Password, AuthStrategy
import re
import sys
from datetime import datetime
from time import time
import asyncio
import socket
from src.models.enums import Term
from src.parsers.ansi_parser import parse_department_page
from src.constants import rumad_to_db_terms, TERMS

MAX_RETRIES = 3
MAX_TASK_COUNT = 25
TIMEOUT_TIME = 60


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
    await send_input(chan, [("5", 1), ("6", 1)])
    terms_page = await read_channel(chan)
    terms = re.findall(r"\d\=[0-9A-Za-z]+", terms_page)
    terms = {term.split("=")[1]: term.split("=")[0] for term in terms}
    term_input = terms[term]
    await send_input(chan, [(term_input, -1)])


def log_department_page(dept: str, raw_content: str) -> None:
    with open(f"output_files/{dept}.ansi", "a") as f:
        f.write(raw_content)
        f.write("\n")


class PuttyAuth(AuthStrategy):
    def get_sources(self):
        yield Password("estudiante", lambda: "")


async def initialize_ssh_channels(clients: list[SSHClient]):
    channels = []
    for ssh in clients:
        ssh.set_missing_host_key_policy(AutoAddPolicy())
        ssh.connect(
            "rumad.uprm.edu",
            username="estudiante",
            password="",
            auth_strategy=PuttyAuth(ssh_config=SSHConfig()),
        )
        channel = ssh.invoke_shell()
        print(f"Opened channel {hex(id(channel))}")
        channels.append(channel)
    return channels


async def scrape_department_availability(channel, department_data: dict):
    department = department_data["department"]
    scraped_year = None
    print(f"Channel {hex(id(channel))} scraping {department}")
    await send_input(channel, [(f"{department}\n", 5)])
    raw_department_result = await read_channel(channel)

    if "< Oprima Enter o [PF4(9)=Fin] >" not in raw_department_result:
        print(f"No section availability data found for {department}")
        return department_data

    courses = {}
    while "< Oprima Enter o [PF4(9)=Fin] >" in raw_department_result:
        parsed_page = parse_department_page(raw_department_result)
        course = parsed_page.get("courseCode", None)
        if scraped_year is None and "year" in parsed_page:
            scraped_year = parsed_page["year"]
        if course is None or len(parsed_page["sections"]) == 0:
            await send_input(channel, [("\n", 0.5)])
            raw_department_result = await read_channel(channel)
            continue
        if course not in courses:
            courses[course] = []
        courses[course].extend(parsed_page["sections"].values())
        await send_input(channel, [("\n", 1)])
        raw_department_result = await read_channel(channel)

    if scraped_year is None or scraped_year != department_data["year"]:
        return department_data

    for course_data in department_data["courses"].values():
        for existingSection in course_data["sections"]:
            for scrapedSection in courses.get(course_data["courseCode"], []):
                if existingSection["sectionCode"] == scrapedSection["sectionCode"]:
                    existingSection["capacity"] = scrapedSection["capacity"]
                    existingSection["usage"] = scrapedSection["usage"]

    print(
        f"Finished scraping section availability for {len(courses)} courses \
from {department}"
    )
    return department_data


if __name__ == "__main__":
    _, term, department, *_ = sys.argv
    ssh = SSHClient()
    ssh.connect(
        "rumad.uprm.edu",
        username="estudiante",
        password="",
        auth_strategy=PuttyAuth(ssh_config=SSHConfig()),
    )
    channel = ssh.invoke_shell()
    # print(asyncio.run(scrape_rumad_for_availability(term)))
