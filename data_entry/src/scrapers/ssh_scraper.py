from typing import Tuple
from paramiko import AutoAddPolicy, BadAuthenticationType, SSHClient, Channel
from paramiko.auth_strategy import Password
import re
import sys
from sqlalchemy import and_, create_engine, select, update
from sqlalchemy.orm import sessionmaker
from src.database import Course, Section, Schedule
from datetime import datetime
from time import time
import asyncio
import socket
from src.models.enums import Term
from src.parsers.ansi_parser import parse_department_page

MAX_RETRIES = 3
TASK_COUNT = 15
TIMEOUT_TIME = 60
TERMS = (
    [Term.SECOND_SEMESTER] * 5
    + [Term.FIRST_SUMMER]
    + [Term.SECOND_SUMMER]
    + [Term.FIRST_SEMESTER] * 5
)
putty_to_db_terms = {
    Term.FIRST_SEMESTER.value: "Fall",
    Term.SECOND_SEMESTER.value: "Spring",
    Term.FIRST_SUMMER.value: "FirstSummer",
    Term.SECOND_SUMMER.value: "SecondSummer",
}

failures = set()
term_input = ""


def get_term_year(term: str | None = None) -> Tuple[str, int]:
    now = datetime.now()
    current_term = TERMS[now.month - 1]
    if term is None:
        term = current_term.value
    year = now.year
    if current_term == Term.SECOND_SEMESTER and Term(term) == Term.SECOND_SEMESTER:
        year -= 1
    return (term, year)


async def send_input(chan: Channel, inputs: list[Tuple[str, int]]) -> bool:
    res = 0
    for x in inputs:
        res = chan.send(x[0])
        if x[1] >= 0:
            await asyncio.sleep(x[1])
    return res != 0


async def read_channel(chan: Channel) -> str:
    result = []
    await asyncio.sleep(0.05)
    while chan.recv_ready():
        result.append(chan.recv(1000))
        await asyncio.sleep(0.01)
    return "".join(map(lambda b: b.decode("ansi"), result))


async def setup(chan: Channel, term: str):
    global term_input
    await send_input(chan, [("5", 1), ("6", 1)])
    terms_page = await read_channel(chan)
    terms = re.findall(r"\d\=[0-9A-Za-z]+", terms_page)
    terms = {term.split("=")[1]: term.split("=")[0] for term in terms}
    term_input = terms[term]
    await send_input(chan, [(term_input, -1)])


def log_department_page(dept: str, raw_content: str) -> dict:
    with open(f"output_files/{dept}.ansi", "a") as f:
        f.write(raw_content)
        f.write("\n")


def commit_department(scraped_courses: dict, term: str, year: int, Session):
    db_term = putty_to_db_terms[term]
    with Session() as session:
        for course_code, sections in scraped_courses.items():
            for section_dict in sections:
                section = (
                    session.query(Section)
                    .join(Course)
                    .filter(
                        Course.course_code == course_code,
                        Course.term == db_term,
                        Course.year == year,
                        Section.section_code == section_dict["section_code"],
                    )
                    .first()
                )
                if section is not None:
                    update_section_query = (
                        update(Section)
                        .where(Section.id == section.id)
                        .values(
                            capacity=section_dict["capacity"],
                            taken=section_dict["utilized"],
                        )
                    )
                    session.execute(update_section_query)
        session.commit()


async def find_departments(departments: list[str], Session, term: str):
    if len(departments) == 0:
        return

    ssh = SSHClient()
    ssh.set_missing_host_key_policy(AutoAddPolicy())

    ssh.connect(
        "rumad.uprm.edu",
        username="estudiante",
        password="",
        auth_strategy=Password("estudiante", lambda: ""),
    )

    chan = ssh.invoke_shell()
    print(f"Opened channel {hex(id(chan))}")
    await setup(chan, term)
    print(f"Channel {hex(id(chan))} scraping {departments}")
    year = None
    for department in departments:
        try:
            await send_input(
                chan,
                [
                    (f"{department}\n", 5),
                ],
            )

            raw_department_result = await read_channel(chan)
            if "< Oprima Enter o [PF4(9)=Fin] >" not in raw_department_result:
                print(f"No courses in {department}")
                continue

            courses = {}
            # process first page
            while "< Oprima Enter o [PF4(9)=Fin] >" in raw_department_result:
                parsed_page = parse_department_page(raw_department_result)
                course = parsed_page.get("course_code", None)
                if year is None and "year" in parsed_page:
                    year = parsed_page["year"]
                if course is None:
                    log_department_page(department, raw_department_result)
                    # read next page
                    await send_input(chan, [("\n", 0.5)])
                    raw_department_result = await read_channel(chan)
                    continue
                if course not in parsed_page:
                    courses[course] = []
                for section in parsed_page["sections"].values():
                    courses[course].append(section)
                # navigate to next page
                # read next page
                await send_input(chan, [("\n", 0.5)])
                raw_department_result = await read_channel(chan)
            print(f"Finished scraping {len(courses)} courses from {department}")
            # commit scraped courses to the database
            commit_department(courses, term, year, Session)
        except socket.error:
            print(f"Socket disconnected while scraping {department}; reconnecting")
            ssh.connect(
                "rumad.uprm.edu",
                username="estudiante",
                password="",
                auth_strategy=Password("estudiante", lambda: ""),
            )
            await asyncio.sleep(0)
            chan = ssh.invoke_shell()
            await setup(chan, term)
        # except Exception as e:
        #     print(f"Exception {e} occurred while scraping {department}")
        #     failures.add(department)
        #     await send_input(chan, [("9\n", -1), (term_input, -1)])

    chan.close()
    ssh.close()


def split_list_into_sublists(
    input_list: list[str], num_sublists: int
) -> list[list[str]]:
    if not input_list:
        return [[]] * num_sublists

    avg_length = len(input_list) // num_sublists
    remainder = len(input_list) % num_sublists

    sublists = []
    current_index = 0

    for _ in range(num_sublists):
        sublist_length = avg_length + 1 if remainder > 0 else avg_length
        sublists.append(input_list[current_index : current_index + sublist_length])
        current_index += sublist_length
        remainder -= 1

    return sublists


async def main():
    global failures
    term = sys.argv[1] if len(sys.argv) > 1 else Term.FIRST_SEMESTER.value

    with open("input_files/departments.txt") as file:
        departments = split_list_into_sublists(
            [line.strip() for line in file], TASK_COUNT
        )

    start_time = time()
    retries = 0
    engine = create_engine("sqlite:///courses.db", echo=False)
    Session = sessionmaker(bind=engine)
    while retries < MAX_RETRIES:
        tasks = []
        for department_group in departments:
            tasks.append(find_departments(department_group, Session, term))

        await asyncio.gather(*tasks)

        if len(failures) == 0:
            break
        departments = split_list_into_sublists(list(failures), TASK_COUNT)
        failures = set()
        print("Scraping previously failed courses")
        retries += 1
    print("Time elapsed: " + str(time() - start_time))


if __name__ == "__main__":
    asyncio.run(main())
