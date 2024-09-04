import re
from typing import Tuple

format_text_pattern = re.compile(r"\[(\d+)m")
clear_display_pattern = re.compile(r"\[J")
clear_line_pattern = re.compile(r"\[K")
unknown_sequence_pattern = re.compile(r"\[(\d+)?[A-Z]")
term_year_pattern = re.compile(
    r"\[3;41H(\d[a-z]{2}\s*[A-Za-z]{3})\s+([0-9]{4})-[0-9]{4}\[3;59H"
)
course_code_pattern = re.compile(
    r"\[([0-9]+);13H([A-Z]{4}\s*[0-9]{4}L?)\s*\[[0-9]+;23H"
)

section_code_pattern = re.compile(
    r"\[([0-9]+);1H\s*([0-9]{1,3}[A-Z#]{,1})\s*\[[0-9]+;5H"
)
capacity_pattern = re.compile(r"\[([0-9]+);63H\s*(\d+)\s*\[[0-9]+;67H")
utilized_pattern = re.compile(r"\[([0-9]+);69H\s*(\d+)\s*\[[0-9]+;74H")
remaining_pattern = re.compile(r"\[([0-9]+);75H\s*(\d+-?)\s*\[[0-9]+;80H")

# TODO: complete this pattern
" [12;43H[12;47H 1[12;49H[12;50Hseccion[12;63H  45[12;67H[12;69H  24 [12;74H[12;75H  21 [12;80H[22;1H [22;48H< Oprima Enter o [PF4(9)=Fin] >[22;79H[22;79H"
metrics_pattern = re.compile(
    r"\[[0-9]+;22H\* Totales:\[[0-9]+;33H([A-Z]{4})\[[0-9]+;37H\[[0-9]+;38H([0-9]{4})\[[0-9]+;42H\[[0-9]+;42H"
)


def parse_department_page(raw_content: str) -> dict:
    # preprocess the department page by removing non-cursor escape codes
    content_with_no_text_formatting = re.sub(format_text_pattern, "", raw_content)
    content_with_no_line_clears = re.sub(
        clear_line_pattern, "", content_with_no_text_formatting
    )
    simplified_content = re.sub(clear_display_pattern, "", content_with_no_line_clears)
    # search for all the data
    term_year_match = re.search(term_year_pattern, simplified_content)
    course_code_match = re.search(course_code_pattern, simplified_content)

    section_code_matches = re.findall(section_code_pattern, simplified_content)
    capacity_matches = re.findall(capacity_pattern, simplified_content)
    utilized_matches = re.findall(utilized_pattern, simplified_content)
    remaining_matches = re.findall(remaining_pattern, simplified_content)

    extracted_data: dict = {"sections": {}}
    if course_code_match:
        row, course_code = course_code_match.groups()
        extracted_data["courseCode"] = course_code.replace(" ", "")
    # parse sections and other data:
    sections_capacities_utilized_remaining = zip(
        section_code_matches, capacity_matches, utilized_matches, remaining_matches
    )
    for s_match, c_match, u_match, r_match in sections_capacities_utilized_remaining:
        srow, section_code = s_match
        crow, capacity = c_match
        urow, utilized = u_match
        rrow, remaining = r_match
        if srow != crow != urow != rrow:
            print(f"index mismatch between parsed fields: {srow}-{crow}-{urow}-{rrow}")

        extracted_data["sections"][srow] = {
            "sectionCode": section_code,
            "capacity": int(capacity),
            "usage": int(utilized),
            "remaining": (
                int(remaining) if remaining[-1] != "-" else -1 * int(remaining[:-1])
            ),
        }

    if term_year_match:
        term, year = term_year_match.groups()
        extracted_data["term"] = term.replace(" ", "")
        extracted_data["year"] = int(year)
    return extracted_data


r"""
Below is some unused scraping code that took enough time to write that I'd rather not just delete it all
course_name_pattern = re.compile(r"\[5;35H(\w+(?:\s+\w+)?)\s*\[5;61H")
move_cursor_pattern = re.compile(r"\[(\d+);(\d+)[Hf]")
room_pattern = re.compile(r"\[([0-9]+);7H(\w{1,3}\s*\w{,4})\[[0-9]+;13H")
days_pattern = re.compile(r"(?:\[([0-9]+);[0-9]+H([LMWJV])\[[0-9]+;[0-9]+H)+")
time_pattern = re.compile(
    r"\[([0-9]+);21H\s*([0-9]{1,2}(?:pm)?\s*-\s*[0-9]{2}(?:pm)?)\s*\[[0-9]+;35H"
)
credits_pattern = re.compile(r"\[([0-9]+);38H\s*(\d+)\s*\[[0-9]+;39H")
professor_pattern = re.compile(r"\[([0-9]+);42H\s*(\w+\s*)+\s*\[[0-9]+;62H")
course_name_match = re.search(course_name_pattern, simplified_content)

room_matches = re.findall(room_pattern, simplified_content)
days_matches = re.findall(days_pattern, simplified_content)
time_matches = re.findall(time_pattern, simplified_content)
credits_matches = re.findall(credits_pattern, simplified_content)
professor_matches = re.findall(professor_pattern, simplified_content)

for room_match in room_matches:
    row, room = room_match
    if row in extracted_data["sections"]:
        extracted_data["sections"][row]["room"] = [room]
    else:
        closest_row = reduce(
            lambda closest, curr: (
                closest if (curr > row and curr < closest) else curr
            ),
            extracted_data["sections"].keys(),
        )
        extracted_data["sections"][closest_row]["room"].append(room)
for days_match in days_matches:
    row, days = days_match
    if row in extracted_data["sections"]:
        extracted_data["sections"][row]["days"] = [days]
    else:
        closest_row = reduce(
            lambda closest, curr: (
                closest if (curr > row and curr < closest) else curr
            ),
            extracted_data["sections"].keys(),
        )
        extracted_data["sections"][closest_row]["days"].append(days)
for time_match in time_matches:
    row, time = time_match
    if row in extracted_data["sections"]:
        extracted_data["sections"][row]["time"] = [time]
    else:
        closest_row = reduce(
            lambda closest, curr: (
                closest if (curr > row and curr < closest) else curr
            ),
            extracted_data["sections"].keys(),
        )
        extracted_data["sections"][closest_row]["time"].append(time)

for credits_match in credits_matches:
    row, credits = credits_match
    extracted_data["sections"][row]["credits"] = credits

for professor_match in professor_matches:
    row, professor = professor_match
    extracted_data["sections"][row]["professor"] = professor

for capacity_match in capacity_matches:
    row, capacity = capacity_match
    extracted_data["sections"][row]["capacity"] = capacity

for utilized_match in utilized_matches:
    row, utilized = utilized_match
    extracted_data["sections"][row]["utilized"] = utilized

for remaining_match in remaining_matches:
    row, remaining = remaining_match
    extracted_data["sections"][row]["remaining"] = remaining
"""
