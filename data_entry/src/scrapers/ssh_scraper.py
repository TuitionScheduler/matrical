from typing import Tuple
from paramiko import AutoAddPolicy, BadAuthenticationType, SSHClient, Channel, SSHConfig
from paramiko.auth_strategy import Password, AuthStrategy
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
MAX_TASK_COUNT = 25
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


def log_department_page(dept: str, raw_content: str) -> None:
    with open(f"output_files/{dept}.ansi", "a") as f:
        f.write(raw_content)
        f.write("\n")


def commit_department(scraped_courses: dict, term: str, year: int, Session):
    db_term = putty_to_db_terms[term]
    with Session() as session:
        for course_code, sections in scraped_courses.items():
            no_lab_course_code = course_code.rstrip("L")
            for section_dict in sections:
                section = (
                    session.query(Section)
                    .join(Course)
                    .filter(
                        Course.course_code == no_lab_course_code,
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


class PuttyAuth(AuthStrategy):
    def get_sources(self):
        yield Password("estudiante", lambda: "")


async def worker(queue: asyncio.Queue, Session, term: str):
    ssh = SSHClient()
    ssh.set_missing_host_key_policy(AutoAddPolicy())

    ssh.connect(
        "rumad.uprm.edu",
        username="estudiante",
        password="",
        auth_strategy=PuttyAuth(ssh_config=SSHConfig()),
    )

    chan = ssh.invoke_shell()
    print(f"Opened channel {hex(id(chan))}")
    await setup(chan, term)

    year = None
    while True:
        try:
            department = await queue.get()
            if department is None:  # Sentinel value to indicate end of queue
                break

            print(f"Channel {hex(id(chan))} scraping {department}")

            await send_input(chan, [(f"{department}\n", 5)])
            raw_department_result = await read_channel(chan)

            if "< Oprima Enter o [PF4(9)=Fin] >" not in raw_department_result:
                print(f"No courses in {department}")
                continue

            courses = {}
            while "< Oprima Enter o [PF4(9)=Fin] >" in raw_department_result:
                parsed_page = parse_department_page(raw_department_result)
                course = parsed_page.get("course_code", None)
                if year is None and "year" in parsed_page:
                    year = parsed_page["year"]
                if course is None or len(parsed_page["sections"]) == 0:
                    await send_input(chan, [("\n", 0.5)])
                    raw_department_result = await read_channel(chan)
                    continue
                if course not in courses:
                    courses[course] = []
                courses[course].extend(parsed_page["sections"].values())
                await send_input(chan, [("\n", 0.5)])
                raw_department_result = await read_channel(chan)
            if year is None:
                _, year = get_term_year(term)
            print(f"Finished scraping {len(courses)} courses from {department}")
            commit_department(courses, term, year, Session)

        except socket.error:
            print(f"Socket disconnected while scraping {department}; reconnecting")
            ssh.connect(
                "rumad.uprm.edu",
                username="estudiante",
                password="",
                auth_strategy=PuttyAuth(ssh_config=SSHConfig()),
            )
            await asyncio.sleep(0)
            chan = ssh.invoke_shell()
            await setup(chan, term)
            await queue.put(department)  # Put the department back in the queue
        except Exception as e:
            print(f"Exception {e} occurred while scraping {department}")
            failures.add(department)
            await send_input(chan, [("9\n", -1), (term_input, -1)])

    chan.close()
    ssh.close()


async def main():
    global failures
    term = sys.argv[1] if len(sys.argv) > 1 else Term.FIRST_SEMESTER.value

    with open("input_files/departments.txt") as file:
        departments = [line.strip() for line in file]

    start_time = time()
    retries = 0
    engine = create_engine("sqlite:///courses.db", echo=False)
    Session = sessionmaker(bind=engine)

    while retries < MAX_RETRIES:
        queue = asyncio.Queue()
        for department in departments:
            await queue.put(department)

        tasks = []
        task_count = min(len(departments), MAX_TASK_COUNT)
        for _ in range(task_count):
            task = asyncio.create_task(worker(queue, Session, term))
            tasks.append(task)

        # Add sentinel values to signal workers to stop
        for _ in range(task_count):
            await queue.put(None)

        await asyncio.gather(*tasks)

        if len(failures) == 0:
            break

        departments = list(failures)
        failures = set()
        print("Scraping previously failed courses")
        retries += 1

    print("Time elapsed: " + str(time() - start_time))


if __name__ == "__main__":
    asyncio.run(main())
