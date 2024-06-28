from scraper import scrape_department
from constants import season_map, spanish_season_map
import concurrent.futures
import sys
import time
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import datetime
from stats import DeptStats
import json
from notification import send_notification
import os

cred = credentials.Certificate("credentials.json")
app = firebase_admin.initialize_app(cred)
db = firestore.client()
doc_ref = db.collection("DepartmentCourses")

registration_token = os.getenv("FIREBASE_NOTIFICATION_REG_KEY")

dept_stats: list[DeptStats] = []
scraped_depts = []


def calculate_doc_size(data):
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
        return sum([calculate_doc_size(item) for item in data])


def calculate_doc_name_size(path):
    size = 0
    for collection in path.split("/"):
        size += len(collection) + 1
    return size + 16


def runner(department, term, year, professor_ids):
    global dept_stats, doc_ref
    while True:
        try:
            data = scrape_department(department, term, year, professor_ids)
        except Exception as e:
            print(e)
            print(f"Failed to scrape {department}; trying again")
        else:
            if data is not None:
                doc_ref.document(
                    f"{data['department']}:{data['term'].replace(' ','')}:{data['year']}"
                ).set(data)
                scraped_depts.append(department)
                # print(data)
                dept_stats.append(
                    DeptStats(
                        department,
                        calculate_doc_name_size(
                            f"DepartmentCourses/{department}:{data['term']}:{year}"
                        )
                        + calculate_doc_size(data),
                        len(data["courses"].keys()),
                        sum(
                            len(course["sections"])
                            for course in data["courses"].values()
                        ),
                    )
                )
                print(f"Successfully scraped {department}")
            else:
                print(f"No sections found for {department}")
            break


if __name__ == "__main__":
    term, year = sys.argv[1], sys.argv[2]
    with open("professor_ids.txt") as file:
        professor_ids = json.load(file)
    with open("departments.txt") as file:
        departments = sorted(department.strip() for department in file)
    start_time = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        for department in departments:
            executor.submit(runner, department, term, year, professor_ids)

    departmentCoursesEntryInfo: dict = (
        db.collection("DataEntryInformation")
        .document("DepartmentCourses")
        .get()
        .to_dict()
    )

    termYearScrapeInfo = (
        {}
        if departmentCoursesEntryInfo is None
        else departmentCoursesEntryInfo.get("termYearScrapeInfo", {})
    )

    oldDepts = termYearScrapeInfo.get(f"{season_map[term]}:{year}", {}).get(
        "departments", []
    )
    # print(oldDepts)
    # print(scraped_depts)
    newDepts = sorted(list(set(scraped_depts).difference(set(oldDepts))))
    # print(newDepts)
    termYearScrapeInfo.update(
        {
            f"{season_map[term]}:{year}": {
                "lastUpdated": datetime.datetime.now(),
                "departments": scraped_depts,
            }
        }
    )
    db.collection("DataEntryInformation").document("DepartmentCourses").set(
        {"termYearScrapeInfo": termYearScrapeInfo}
    )

    def generate_body(depts: list) -> str:
        if len(depts) == 0:
            return ""
        if len(depts) == 1:
            return f"El departamento {depts[0]} fue añadido."
        deptsString = f"{', '.join(depts[:-1])} y {depts[-1]}"
        return f"Los departamentos {deptsString} fueron añadidos."

    if len(newDepts) > 0 and registration_token is not None:
        send_notification(
            f"Departamentos nuevos para el {spanish_season_map[term]} de {year}",
            generate_body(newDepts),
            registration_token,
        )

    print(f"Finished scraping in {str(time.time() - start_time)} seconds")

    with open("dept_stats.csv", "w") as file:
        file.write("Department,Bytes,CourseCount,SectionCount\n")
        for dept in dept_stats:
            file.write(
                f"{dept.dept},{dept.bytes},{dept.course_count},{dept.section_count}\n"
            )
