from dataclasses import dataclass
from typing import Dict, List, Set, Tuple


@dataclass(slots=True)
class CourseRecord:
    courseCode: str
    sectionCode: str
    term: str
    year: int
    letterGrade: str
    credits: int


@dataclass(slots=True)
class StudentRecord:
    name: str  # full name of student
    enrolledCourses: List[str]
    enrolledDegrees: List[
        Tuple[str, int]
    ]  # 4 letter code and the year enrolled ie (INSO,2019)
    completed_courses: List[CourseRecord]
    graduation_status: str  # Undergraduate or Graduate
    english_level: int  # ranges between 1-3 depending on taking the PNA and scoring well on the College Board

    @property
    def completedCredits(self) -> int:
        return sum([c.credits for c in self.completed_courses])

    def yearsEnrolled(self, currentYear: int) -> int:
        return (
            currentYear
            - min((year for d, year in self.enrolledDegrees), key=currentYear)  # type: ignore
            + 1
        )

    def departmentCredits(self, department: str) -> int:
        return sum(
            [
                c.credits
                for c in self.completed_courses
                if c.courseCode.startswith(department)
            ]
        )

    def tookCourse(self, course: str) -> bool:
        return course in map(lambda c: c.courseCode, self.completed_courses)
