import requests
from bs4 import BeautifulSoup
import re
from scraper_utils import apply_regex
from constants import number_to_term


def get_modality(section_code):
    if len(section_code) > 3:
        return section_code[3:]
    return ""


def split_professor(
    professor: str,
) -> tuple[str | None, str | None, str | None]:
    match = re.match(r"(\w+)(?: (\w)\.?)? (\w+)(?: ((\w+\s*)+))?", professor)
    if match:
        return (
            match.group(1),
            match.group(3),
            match.group(4) or None,
        )
    return None, None, None


def get_professor_ids(name: str, lastname: str, second_lastname: str) -> list[str]:
    result = []
    if not name or not lastname:
        return result
    name, lastname = name.lower(), lastname.lower()
    # if initial and second_lastname:
    #     result.append(
    #         f"{name}-{initial.lower()}-{lastname}-{second_lastname.replace(' ', '-').lower()}"
    #     )
    if second_lastname:
        result.append(f"{name}-{lastname}-{second_lastname.replace(' ', '-').lower()}")
    # if initial:
    #     result.append(f"{name}-{initial.lower()}-{lastname}")
    result.append(f"{name}-{lastname}")
    return result


def get_professor_review(professor_ids: list[str], professors_ids_map: dict[str]):
    for professor_id in professor_ids:
        if professors_ids_map.get(professor_id, False):
            return professors_ids_map[professor_id]
    return None


def scrape_department(
    department: str, term: str, year: int, professor_ids_map: dict[str]
) -> dict:
    url = f"https://www.uprm.edu/registrar/sections/index.php?v1={department.lower()}&v2=&term={term}-{str(year)}&a=s&cmd1=Search"
    response = requests.get(url)

    if response.status_code == 200:
        soup = BeautifulSoup(response.content, "html.parser")

        if soup.find("h2", text="WebService Error") is not None:
            raise Exception("Failed to scrape department")

        table = soup.find("table", class_="section_results")

        if table is None:
            return None

        courses: dict[str, dict] = {}
        department_obj = {
            "department": department,
            "term": number_to_term[term],
            "year": int(year),
            "courses": courses,
        }
        rows = table.find_all("tr")
        for i in range(1, len(rows), 2):  # Skip the header row
            top_cols = rows[i].find_all("td")
            bottom_cols = rows[i + 1].find_all("td")

            course_name, section_code = tuple(
                top_cols[1].get_text(separator="\n").split("\n")
            )
            course_code, section = tuple(section_code.split("-"))
            credits = top_cols[2].get_text()
            division = top_cols[3].get_text()
            meetings = [
                text.replace("\u00a0", "")
                for text in top_cols[4].get_text(separator="\n").split("\n")
                if text != ""
            ]
            professor_names = [
                apply_regex(
                    apply_regex(professor, r"[Dd][Ee][Ll]", lambda _: ""),
                    r"\s+",
                    lambda _: " ",
                )
                for professor in top_cols[5].get_text(separator="\n").split("\n")
            ]
            professors = []
            for name in professor_names:
                review = get_professor_review(
                    get_professor_ids(*split_professor(name)),
                    professor_ids_map,
                )
                professors.append(
                    {
                        "name": name if name != "" else "Profesor Desconocido",
                        "url": review["url"] if review else "",
                    }
                )
            requisites, corequisites = tuple(
                x.strip()
                for x in bottom_cols[1]
                .get_text()[len("Enrollment Requisites:") :]
                .split(", Co-Requisites:", 1)
            )

            if not courses.get(course_code, False):
                courses[course_code] = {
                    "courseCode": course_code,
                    "term": number_to_term[term],
                    "year": int(year),
                    "courseName": course_name,
                    "department": department,
                    "credits": int(credits),
                    "prerequisites": requisites,
                    "corequisites": corequisites,
                    "hasIntegratedLab": False,
                    "division": division,
                    "sections": [],
                }

            section = {
                "sectionCode": section,
                "meetings": meetings,
                "modality": get_modality(section),
                "capacity": 0,
                "usage": 0,
                "reserved": False,
                "professors": professors,
                "misc": "",
            }

            if section["modality"] == "L":
                courses[course_code]["hasIntegratedLab"] = True

            courses[course_code]["sections"].append(section)

        return department_obj
    else:
        raise Exception(f"Failed to retrieve data. Status Code: {response.status_code}")
