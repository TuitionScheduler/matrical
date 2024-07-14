import json
import sys
import time
from scraper import scrape_department
import concurrent.futures
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from database import Course, Section, Schedule, Base
from parsers.schedule_parser import parse_schedule
from constants import term_to_number


def runner(department, term, year, professor_ids, session):
    MAX_ERRORS = 1
    errors = 0
    while errors < MAX_ERRORS:
        try:
            data = scrape_department(department, term, year, professor_ids)
            if data is not None:
                write_to_database(data, session)
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


def write_to_database(data, session):

    for course_code, course_data in data["courses"].items():
        term = term_to_number[course_data["term"]]
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
                    course.year = year
                    course.term = term
                    course.credits = course_data["credits"]
                    course.department = course_data["department"]
                    course.prerequisites = course_data["prerequisites"]
                    course.corequisites = course_data["corequisites"]

                for section_data in course_data["sections"]:
                    section = Section(
                        section_code=section_data["sectionCode"],
                        meetings=",".join(section_data["meetings"]),
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

                    for meeting in section_data["meetings"]:
                        meetingDict = parse_schedule(meeting)
                        if meetingDict is not None:
                            schedule = Schedule(
                                building=meetingDict["building"],
                                room=meetingDict["room"],
                                days=meetingDict["days"],
                                start_time=meetingDict["start_time"],
                                end_time=meetingDict["end_time"],
                            )
                            section.schedules.append(schedule)

                session.merge(course)
        except IntegrityError as e:
            print(f"IntegrityError for course {course_code}: {str(e)}")
        except Exception as e:
            print(f"Error processing course {course_code}: {str(e)}")


if __name__ == "__main__":
    term, year = sys.argv[1], sys.argv[2]
    with open("professor_ids.txt") as file:
        professor_ids = json.load(file)
    with open("departments.txt") as file:
        departments = sorted(department.strip() for department in file)

    engine = create_engine("sqlite:///courses.db", echo=True)
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    session.begin()
    start_time = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        futures = [
            executor.submit(runner, department, term, year, professor_ids, session)
            for department in departments
        ]
        concurrent.futures.wait(futures)
    session.commit()
    session.close()
    print(
        f"Finished scraping and writing to database in {str(time.time() - start_time)} seconds"
    )
