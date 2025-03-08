import re
import logging

logger = logging.getLogger(__name__)


def convert_to_24_hour(time: str):
    hours, minutes, meridian = re.split(r"[:\s]", time)
    hours = int(hours)
    if meridian.lower() == "pm" and hours < 12:
        hours += 12
    time_24_hour = f"{hours:02}:{minutes}"
    return time_24_hour


time_regex = r"\d{1,2}:\d{2}\s*[apAP][mM]\s*-\s*\d{1,2}:\d{2}\s*[apAP][mM]"
days_regex = r"[LMWJVSD]{1,7}"
room_code_regex = r"[A-Z0-9]{1,5}\s[A-Z0-9]{1,5}"
whitespace = r"[\xa0\s\t]*"
schedule_regex = (
    rf"({time_regex}){whitespace}({days_regex}){whitespace}({room_code_regex})?"
)


def parse_schedule(input_string: str) -> dict[str, str] | None:
    match = re.search(schedule_regex, input_string)
    if match:
        times = match.group(1).split("-")
        days = match.group(2)
        room_code = match.group(3) if match.lastindex > 2 else " "  # type: ignore
        building, room = room_code.split(" ")

        return {
            "start_time": convert_to_24_hour(times[0].strip()),
            "end_time": convert_to_24_hour(times[1].strip()),
            "days": days,
            "building": building,
            "room": room,
        }
    else:
        logger.error(f"Failed to parse {input_string}")
        return None
