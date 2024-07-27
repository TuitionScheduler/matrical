from src.models.course import DesiredCourse
from src.models.student import StudentRecord, CourseRecord
from src.models.course_service import CourseService
from src.parsers.requisite_parser import parse_prerequisites
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


def lemahn():
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
    print(*list(parsedPrereqs), sep="\n")


if __name__ == "__main__":
    lemahn()
