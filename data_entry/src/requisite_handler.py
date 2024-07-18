from functools import reduce
from src.models.course import DesiredCourse
from src.models.course_requisite_result import RequisitesAnalysisResult
from src.models.course_service import CourseService
from src.models.student import StudentRecord
from src.parsers.requisite_parser import parse_prerequisites, parse_corequisites


class RecommendationSystem:
    def __init__(self, courseService: CourseService):
        self.cs = courseService

    def checkCourseRequisites(
        self, student: StudentRecord, course: DesiredCourse
    ) -> RequisitesAnalysisResult:
        fetchedCourse = self.cs.getCourse(course.courseCode, course.term, course.year)
        if not fetchedCourse:
            return RequisitesAnalysisResult(
                False, True, []
            )  # TODO: figure out what I want to do with the returned missing reqs
        parsedPrerequisites = parse_prerequisites(fetchedCourse.prerequisites)
        parsedCorequisites = parse_corequisites(fetchedCourse.corequisites)

        return RequisitesAnalysisResult(True, False, [])

    def requisiteChecker(
        self, student: StudentRecord, course: DesiredCourse, requisites: dict
    ):
        if len(requisites) > 1:
            return False, ["Couldn't parse requirements"]
        # handle individual requirements
        match requisites["type"]:
            case "CREDITS_TO_GRADUATION_REQUIREMENT":
                return (
                    requisites["value"] > 160 - student.completedCredits
                ), []  # TODO: tie this to creds of degree instead of hardcode
            case "ENGLISH_LEVEL_REQUIREMENT":
                match requisites["comparator"]:
                    case ">":
                        return student.english_level > requisites["value"], []
                    case "<":
                        return student.english_level < requisites["value"], []
                    case ">=":
                        return student.english_level >= requisites["value"], []
                    case "<=":
                        return student.english_level <= requisites["value"], []
                    case "==":
                        return student.english_level == requisites["value"], []
            case "YEAR_REQUIREMENT":
                return student.yearsEnrolled(course.year) >= requisites["value"], []
            case "COURSE":
                return student.tookCourse(requisites["value"]), []
            case "DIRECTOR_APPROVAL":
                return False, ["Requires Director Approbal"]
            case "UNKNOWN":
                return False, ["Couldn't parse requirements"]
            case "DEPARTMENT_REQUIREMENT":
                return (
                    requisites["value"]
                    in [department for department, year in student.enrolledDegrees],
                    [],
                )
            case "GRADUATION_STATUS_REQUIREMENT":
                return True, []  # TODO lol
            case "DEPARTMENT_CREDITS_REQUIREMENT":
                # TODO implement
                return True, []
                # return student.departmentCredits()
            # recursively handle compound requirements
            case "OR":
                res = reduce(
                    lambda prev, curr: (
                        prev[0] or curr[0],  # type: ignore
                        [] if prev[0] or curr[0] else prev[1] + curr[1],  # type: ignore
                    ),
                    map(
                        lambda req: self.requisiteChecker(student, course, req),
                        requisites["conditions"],
                    ),
                    (False, []),
                )
                return res
            case "AND":
                res = reduce(
                    lambda prev, curr: (
                        prev[0] and curr[0],  # type: ignore
                        [] if prev[0] and curr[0] else prev[1] + curr[1],  # type: ignore
                    ),
                    map(
                        lambda req: self.requisiteChecker(student, course, req),
                        requisites["conditions"],
                    ),
                    (True, []),
                )
                return res
            case "FOR":
                return (True, [])  # TODO Lol
