from dataclasses import dataclass


@dataclass(slots=True)
class DesiredCourse:
    courseCode: str
    term: str
    year: int
