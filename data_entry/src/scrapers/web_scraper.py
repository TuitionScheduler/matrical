import asyncio
import logging
import aiohttp
from aiolimiter import AsyncLimiter
from bs4 import BeautifulSoup, Tag
import re
from src.scrapers.scraper_utils import apply_regex
from src.constants import db_term_to_number


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


def get_professor_review(professor_ids: list[str], professors_ids_map: dict[str, dict]):
    for professor_id in professor_ids:
        if professors_ids_map.get(professor_id, False):
            return professors_ids_map[professor_id]
    return None


async def scrape_department(
    session: aiohttp.ClientSession,
    department: str,
    db_term: str,
    year: int,
    professor_ids_map: dict[str, dict],
    rate_limit: AsyncLimiter,
) -> dict | None:
    numerical_term = db_term_to_number.get(db_term)
    if not numerical_term:
        logging.error(
            f"Web Scraper: Invalid db_term '{db_term}' not found in db_term_to_number"
        )
        return None

    url = f"https://www.uprm.edu/registrar/sections/index.php?v1={department.lower()}&v2=&term={numerical_term}-{str(year)}&a=s&cmd1=Search"
    logging.info(f"Web Scraper: Fetching URL: {url}")

    try:
        async with rate_limit:
            response = await session.get(url)
            if response.status != 200:
                logging.error(
                    f"Web Scraper: HTTP error for {department}: Status Code: {response.status}, URL: {url}"
                )
                return None

            content = await response.text()
            content_length = len(content)
            logging.debug(
                f"Web Scraper: Received {content_length} bytes for {department}"
            )

            if content_length < 500:  # Suspiciously small response
                logging.warning(
                    f"Web Scraper: Suspiciously small response ({content_length} bytes) for {department}"
                )
                logging.debug(f"Web Scraper: Response content: {content[:200]}...")
    except aiohttp.ClientError as e:
        logging.error(f"Web Scraper: Network error for {department}: {str(e)}")
        return None
    except asyncio.TimeoutError:
        logging.error(f"Web Scraper: Request timed out for {department}")
        return None
    except Exception as e:
        logging.error(f"Web Scraper: Unexpected error fetching {department}: {str(e)}")
        return None

    soup = BeautifulSoup(content, "html.parser")

    # Check for WebService Error
    error_h2 = soup.find("h2", string="WebService Error")
    if error_h2 is not None:
        error_message = error_h2.find_next("pre")
        error_text = error_message.text if error_message else "Unknown WebService Error"
        logging.warning(f"Web Scraper: WebService Error for {department}: {error_text}")
        return None

    # Check for table
    table = soup.find("table", class_="section_results")
    if table is None:
        logging.warning(f"Web Scraper: No section_results table found for {department}")
        # Log some context from the page to help diagnose
        page_title = soup.title.text if soup.title else "No title"
        first_heading = soup.find("h1")
        heading_text = first_heading.text if first_heading else "No heading"
        logging.debug(
            f"Web Scraper: Page context - Title: '{page_title}', First heading: '{heading_text}'"
        )
        return None

    if not isinstance(table, Tag):
        logging.warning(f"Web Scraper: Table is not a Tag for {department}")
        return None

    rows = table.find_all("tr")
    if len(rows) <= 1:
        logging.warning(
            f"Web Scraper: Table has no data rows (only {len(rows)} rows) for {department}"
        )
        return None

    courses: dict[str, dict] = {}
    department_obj = {
        "department": department,
        "term": db_term,
        "year": int(year),
        "courses": courses,
    }

    processed_rows = 0

    try:
        for i in range(1, len(rows), 2):  # Skip the header row
            if i + 1 >= len(rows):
                logging.warning(
                    f"Web Scraper: Odd number of rows for {department}, can't process last row"
                )
                break

            try:
                top_cols = rows[i].find_all("td")
                bottom_cols = rows[i + 1].find_all("td")

                if len(top_cols) < 6:
                    logging.warning(
                        f"Web Scraper: Incomplete top row data (only {len(top_cols)} columns) for {department} at row {i}"
                    )
                    continue

                if len(bottom_cols) < 2:
                    logging.warning(
                        f"Web Scraper: Incomplete bottom row data (only {len(bottom_cols)} columns) for {department} at row {i+1}"
                    )
                    continue

                section_code_text = top_cols[1].get_text(separator="\n")
                if "\n" not in section_code_text:
                    logging.warning(
                        f"Web Scraper: Unexpected format in section_code cell for {department} at row {i}: '{section_code_text}'"
                    )
                    continue

                course_name, section_code = tuple(section_code_text.split("\n"))

                if "-" not in section_code:
                    logging.warning(
                        f"Web Scraper: Invalid section code format for {department} at row {i}: '{section_code}'"
                    )
                    continue

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
                        get_professor_ids(*split_professor(name)),  # type: ignore
                        professor_ids_map,
                    )
                    professors.append(
                        {
                            "name": name if name != "" else "Profesor Desconocido",
                            "url": review["url"] if review else "",
                        }
                    )

                requisites_text = bottom_cols[1].get_text()
                if "Enrollment Requisites:" not in requisites_text:
                    logging.warning(
                        f"Web Scraper: Unexpected requisites format for {department} at row {i+1}: '{requisites_text}'"
                    )
                    requisites, corequisites = "", ""
                else:
                    requisites_content = requisites_text[
                        len("Enrollment Requisites:") :
                    ].strip()
                    if ", Co-Requisites:" in requisites_content:
                        requisites, corequisites = tuple(
                            x.strip()
                            for x in requisites_content.split(", Co-Requisites:", 1)
                        )
                    else:
                        requisites, corequisites = requisites_content, ""

                if not courses.get(course_code, False):
                    try:
                        credits_int = int(credits)
                    except ValueError:
                        logging.warning(
                            f"Web Scraper: Invalid credits value '{credits}' for {department}, course {course_code}"
                        )
                        credits_int = 0

                    courses[course_code] = {
                        "courseCode": course_code,
                        "term": db_term,
                        "year": int(year),
                        "courseName": course_name,
                        "department": department,
                        "credits": credits_int,
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
                processed_rows += 1

            except Exception as e:
                logging.error(
                    f"Web Scraper: Error processing row {i} for {department}: {str(e)}"
                )
                continue
    except Exception as e:
        logging.error(
            f"Web Scraper: Error while processing {department} data: {str(e)}"
        )

    # Final validation
    if not courses:
        logging.warning(
            f"Web Scraper: No courses were extracted for {department} despite finding a table"
        )
        return None

    logging.info(
        f"Web Scraper: Successfully processed {processed_rows} section rows for {department}, found {len(courses)} courses"
    )

    return department_obj


async def web_scraper_task(
    web_queue: asyncio.Queue,
    ssh_queue: asyncio.Queue,
    db_term: str,
    year: int,
    professor_ids: dict,
    rate_limit: AsyncLimiter,
):
    async with aiohttp.ClientSession() as session:
        while True:
            department = await web_queue.get()
            try:
                logging.info(
                    f"Web Scraper: Starting to scrape {department} for {db_term} {year}"
                )

                data = await scrape_department(
                    session, department, db_term, year, professor_ids, rate_limit
                )

                if data:
                    course_count = len(data["courses"])
                    section_count = sum(
                        len(c["sections"]) for c in data["courses"].values()
                    )
                    await ssh_queue.put(data)
                    logging.info(
                        f"Web Scraper: Successfully scraped {department}: {course_count} courses with {section_count} sections total"
                    )
                else:
                    logging.warning(
                        f"Web Scraper: No course data found for {department}"
                    )
            except Exception as e:
                logging.error(
                    f"Web Scraper: Unhandled exception while scraping {department}: {str(e)}"
                )
                import traceback

                logging.error(
                    f"Web Scraper: Traceback for {department}: {traceback.format_exc()}"
                )
            finally:
                web_queue.task_done()
