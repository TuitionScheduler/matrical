import asyncio
import json
import sys
import time
from src.scrapers.web_scraper import scrape_department
from src.scrapers.ssh_scraper import scrape_rumad_for_availability

import concurrent.futures
from sqlalchemy import create_engine, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from src.database import Course, Section, Meeting, Base
from src.parsers.schedule_parser import parse_schedule
from src.constants import db_to_rumad_terms


def runner(department, db_term, year, professor_ids):
    MAX_ERRORS = 1
    errors = 0
    while errors < MAX_ERRORS:
        try:
            data = scrape_department(department, db_term, year, professor_ids)
            if data is not None:
                write_courses_to_database(data)
                print(f"Successfully scraped and wrote {department} to database")
            else:
                print(f"No data returned for {department}")
            break
        except Exception as e:
            print(f"Error processing {department}: {str(e)}")
            errors += 1
            if errors < MAX_ERRORS:
                print(
                    f"Retrying {department} (attempt {errors + 1} of {MAX_ERRORS})..."
                )
            else:
                print(f"Failed to process {department} after {MAX_ERRORS} attempts")


def write_courses_to_database(data):
    engine = create_engine("sqlite:///courses.db", echo=False)
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    with Session() as session:
        for course_code, course_data in data["courses"].items():
            term = course_data["term"]
            year = course_data["year"]
            try:
                with session.no_autoflush:
                    course = (
                        session.query(Course)
                        .filter_by(course_code=course_code, year=year, term=term)
                        .first()
                    )
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
                                session.delete(meeting)
                            session.delete(section)
                        session.flush()

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
                                [prof["name"] for prof in section_data["professors"]]
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

                    session.merge(course)
            except IntegrityError as e:
                print(f"IntegrityError for course {course_code}: {str(e)}")
                session.rollback()
            except Exception as e:
                print(f"Error processing course {course_code}: {str(e)}")
                session.rollback()
            else:
                session.commit()


def write_section_availability_to_database(data):
    engine = create_engine("sqlite:///courses.db", echo=False)
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    with Session() as session:
        if "year" not in data or "term" not in data:
            print(
                "Failed to write section availability to DB, missing term and/or year"
            )
            return None
        for course_code, sections in data["courses"].items():
            no_lab_course_code = course_code.rstrip("L")
            for section_dict in sections:
                section = (
                    session.query(Section)
                    .join(Course)
                    .filter(
                        Course.course_code == no_lab_course_code,
                        Course.term == data["term"],
                        Course.year == data["year"],
                        Section.section_code == section_dict["section_code"],
                    )
                    .first()
                )
                if section is not None:
                    update_section_query = (
                        update(Section)
                        .where(Section.sid == section.sid)
                        .values(
                            capacity=section_dict["capacity"],
                            taken=section_dict["utilized"],
                        )
                    )
                    session.execute(update_section_query)
        session.commit()


async def scrape_to_sql(db_term: str, year: int):
    with open("input_files/professor_ids.txt") as file:
        professor_ids = json.load(file)
    with open("input_files/departments.txt") as file:
        departments = sorted(department.strip() for department in file)

    start_time = time.time()
    # Scrape web site for courses and sections
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        futures = [
            executor.submit(runner, department, db_term, year, professor_ids)
            for department in departments
        ]
        concurrent.futures.wait(futures)
    web_scrape_time = time.time()
    # Scrape RUMAD for section availability
    section_availability = await scrape_rumad_for_availability(
        db_to_rumad_terms[db_term]
    )
    write_section_availability_to_database(section_availability)
    rumad_scrape_time = time.time()
    print(f"Finished scraping and writing to database.")
    print(
        f"""
          Time Breakdown:
          Course Offering Scraping: {round(web_scrape_time - start_time,1)} seconds
          Section Availability Scraping: {round(rumad_scrape_time - start_time,1)} seconds
          """
    )


if __name__ == "__main__":
    term, year = sys.argv[1], int(sys.argv[2])
    asyncio.run(scrape_to_sql(term, year))
