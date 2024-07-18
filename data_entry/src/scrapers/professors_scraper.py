import requests
from bs4 import BeautifulSoup
import re
import concurrent.futures
import time
import json
from src.scrapers.scraper_utils import apply_regex

professors = {}


def parse_slug(slug):
    match = re.match(r"^([a-z]+(?:-[a-z]+)*)(?:-(\d+))?$", slug)
    if match:
        groups = match.groups()
        main_part = apply_regex(
            groups[0].replace("-del-", "-"), r"\-[a-z]\-", lambda _: "-"
        )
        additional_part = int(groups[1]) if groups[1] else None
        return main_part, additional_part
    return None, None


def runner(department_link: str):
    global professors
    response = requests.get(f"https://notaso.com{department_link}")
    soup = BeautifulSoup(response.content, "html.parser")
    for p in soup.find_all("p", class_="pull-left"):
        name = p.b.get_text()
        search_response = requests.get(
            f"https://notaso.com/api/v2/professors/?search={name}"
        ).json()
        for result in search_response["results"]:
            id, number = parse_slug(result["slug"])
            if professors.get(id, False):
                if professors[id]["number"] is not None:
                    if number is None or professors[id]["number"] > number:
                        professors[id] = {
                            "number": number,
                            "score": result["score"],
                            "url": f"https://notaso.com/professors/{result['slug']}/",
                        }
            else:
                professors[id] = {
                    "number": number,
                    "score": result["score"],
                    "url": f"https://notaso.com/professors/{result['slug']}/",
                }

        print(f"Scraped {name}")


url = "https://notaso.com/universities/urpm/"
response = requests.get(url)
soup = BeautifulSoup(response.content, "html.parser")
department_links = [
    a["href"]
    for a in soup.find_all("a", href=re.compile("/universities/urpm/"))
    if a["href"] != "/universities/urpm/"
]

start_time = time.time()
with concurrent.futures.ThreadPoolExecutor(
    max_workers=len(department_links) // 2
) as executor:
    for department in department_links:
        executor.submit(runner, department)

# professors.update(a["href"][len("/professors/"):-1] for a in soup.find_all("a", href=re.compile("/professors/")))

with open("input_files/professor_ids.txt", "w") as file:
    json.dump(professors, file, indent=2)

print(f"Scraped in {str(time.time() - start_time)} seconds")
