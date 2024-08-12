from src.models.course import DesiredCourse
from src.models.student import StudentRecord, CourseRecord
from src.models.course_service import CourseService
from src.parsers.requisite_parser import parse_prerequisites, lexer_tester
from src.requisite_handler import RecommendationSystem


# Simple script to test course recommendation system
def main():
    course_service = CourseService()
    recommendation_system = RecommendationSystem(course_service)
    student = StudentRecord(
        name="John Doe",
        enrolledDegrees=[("CIIC", 2022)],
        enrolledCourses=["MATE3031"],
        completed_courses=[
            CourseRecord("CIIC3011", "001", "Fall", 2022, "A", 3),
            CourseRecord("CIIC4010", "002", "Spring", 2023, "B", 3),
            CourseRecord("CIIC3075", "010", "Spring", 2023, "A", 3),
        ],
        graduation_status="SUBGRADUADO",
        english_level=2,
    )

    # Create the desired course
    desired_course = DesiredCourse(courseCode="CINE3005", term="Fall", year=2024)

    # Check if the student can take the course
    requisite_analysis_result = recommendation_system.checkCourseRequisites(
        student, desired_course
    )

    print(requisite_analysis_result)


def find_unknowns():
    # finds all courses we currently can't parse the requirements of
    cs = CourseService()

    interestedCourseObjects = cs.getLatestCourses()
    parsedPrereqs = map(
        lambda c: parse_prerequisites(c.prerequisites) if c else {},
        interestedCourseObjects,
    )
    [print(pReq, end="\n\n") for pReq in parsedPrereqs if pReq.get("type") == "UNKNOWN"]


def test_patterns_cases():  # Some courses whose prerequisites involve patterns ie. CIIC****{12}
    cs = CourseService()
    interestedCourses = [
        {"course_code": "ADMI6006"},
        {"course_code": "AGRO4038"},
        {"course_code": "CINE3005"},
        {"course_code": "CINE3025"},
        {"course_code": "CINE4001"},
        {"course_code": "CINE4002"},
        {"course_code": "CINE4005"},
        {"course_code": "CINE4016"},
        {"course_code": "CINE4017"},
        {"course_code": "INGL4095"},
        {"course_code": "ININ4995"},
        {"course_code": "QUIM8008"},
    ]
    interestedCourseObjects = map(
        lambda c: cs.getCourse(c["course_code"], None, None), interestedCourses
    )
    parsedPrereqs = map(
        lambda c: parse_prerequisites(c.prerequisites) if c else {},
        interestedCourseObjects,
    )
    print(*list(parsedPrereqs), sep="\n\n")


def try_parse():  # Some historically tricky cases
    print(lexer_tester("MENOS DE 30 CRS PARA GRADUACION"))
    print(lexer_tester("QUIM4998{3}"))
    print(lexer_tester("(1204 Y (3RO O 4TO))"))
    print(
        lexer_tester("BIOL4015 O BIOL3052 O (BIOL3062 Y BIO3064)")
    )  # Note how BIOL is missing an L here
    print(lexer_tester("(MUSI3171 Y MUSI3231) O EXAM"))
    print(lexer_tester("EXA O EXA DIAG MATE"))  # No idea what EXA DIAG MATE is
    print(lexer_tester("EXA"))
    print(lexer_tester("DIR Y (4TO O 5TO)"))
    print(lexer_tester("0503 Y !0503M Y ****{48}"))
    print(
        lexer_tester(
            "INGL3231 Y [INGL3236 O INGL3238 O INGL3268 O INGL4107 O INGL4108]{6}"
        )
    )
    print(lexer_tester("NIVEL_AVAN_INGL > #3"))
    print(lexer_tester("(FISI3172 O FISI3162) Y (MATE3063 O MATE3185) Y !0502 Y !0507"))
    print(lexer_tester("GRADUADO Y DIR"))


if __name__ == "__main__":
    find_unknowns()
