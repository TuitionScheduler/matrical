from functools import reduce
from typing import Tuple
from src.models.course import DesiredCourse
from src.models.course_requisite_result import RequisitesAnalysisResult
from src.models.course_service import CourseService
from src.models.student import StudentRecord
from src.parsers.requisite_parser import parse_prerequisites, parse_corequisites


class RecommendationSystem:
    def __init__(self, courseService: CourseService):
        self.cs = courseService

    def checkCourseRequisites(
        self, student: StudentRecord, course: DesiredCourse, hasDirectorApproval=False
    ) -> RequisitesAnalysisResult:
        fetchedCourse = self.cs.getCourse(course.courseCode, course.term, course.year)
        if not fetchedCourse:
            return RequisitesAnalysisResult(False, "", "")
        parsedPrerequisites = parse_prerequisites(fetchedCourse.prerequisites)
        parsedCorequisites = parse_corequisites(fetchedCourse.corequisites)
        tookPrerequisites, missingPrerequisites = self.requisiteChecker(
            student=student,
            course=course,
            requisites=parsedPrerequisites,
            hasDirectorApproval=hasDirectorApproval,
            checkingCorequisites=False,
        )
        tookCorequisites, missingCorequisites = self.requisiteChecker(
            student=student,
            course=course,
            requisites=parsedCorequisites,
            hasDirectorApproval=hasDirectorApproval,
            checkingCorequisites=True,
        )
        canTakeCourse = tookPrerequisites and tookCorequisites
        return RequisitesAnalysisResult(
            canTakeCourse, missingPrerequisites, missingCorequisites
        )

    def requisiteChecker(
        self,
        student: StudentRecord,
        course: DesiredCourse,
        requisites: dict,
        hasDirectorApproval: bool = False,
        checkingCorequisites: bool = False,  # This is to allow checking a student's currently enrolled courses
    ) -> Tuple[bool, str]:
        if len(requisites) < 1:
            return (True, "")
        # handle individual requirements
        match requisites["type"]:
            case "CREDITS_TO_GRADUATION_REQUIREMENT":
                return (
                    requisites["value"] > (160 - student.completedCredits)
                ), ""  # TODO: tie this to creds of degree instead of hardcode
            case "ENGLISH_LEVEL_REQUIREMENT":
                match requisites["comparator"]:
                    case ">":
                        meetsRequiredEnglish = (
                            student.english_level > requisites["value"]
                        )
                        return meetsRequiredEnglish, (
                            ""
                            if meetsRequiredEnglish
                            else "English level lower than required level"
                        )
                    case "<":
                        meetsRequiredEnglish = (
                            student.english_level < requisites["value"]
                        )
                        return meetsRequiredEnglish, (
                            ""
                            if meetsRequiredEnglish
                            else "English level higher than required level"
                        )
                    case ">=":
                        meetsRequiredEnglish = (
                            student.english_level >= requisites["value"]
                        )
                        return meetsRequiredEnglish, (
                            ""
                            if meetsRequiredEnglish
                            else "English level lower than required level"
                        )
                    case "<=":
                        meetsRequiredEnglish = (
                            student.english_level <= requisites["value"]
                        )
                        return meetsRequiredEnglish, (
                            ""
                            if meetsRequiredEnglish
                            else "English level higher than required level"
                        )
                    case "==":
                        meetsRequiredEnglish = (
                            student.english_level == requisites["value"]
                        )
                        return meetsRequiredEnglish, (
                            ""
                            if meetsRequiredEnglish
                            else "English level not equal to required level"
                        )
                return (
                    False,
                    "Couldn't parse comparator for English level requirment",
                )
            case "YEAR_REQUIREMENT":
                return (
                    student.yearsEnrolled(course.year) >= requisites["value"],
                    f"Must have been enrolled at least {requisites['value']} years",
                )
            case "COURSE":
                requiredCourse = requisites["value"]
                tookCourse = student.tookCourse(requiredCourse)
                takingCourse = requiredCourse in student.enrolledCourses
                if tookCourse:
                    return True, ""
                if checkingCorequisites:
                    if takingCourse:
                        return True, ""
                    else:
                        return False, f"Must be enrolled in {requiredCourse}"
                return False, f"Missing {requiredCourse}"
            case "EXAM_REQUIREMENT":
                return (False, "")  # TODO: implement
            case "DIRECTOR_APPROVAL":
                return hasDirectorApproval, (
                    "" if hasDirectorApproval else "Requires Director Approval"
                )
            case "UNKNOWN":
                return False, "Couldn't parse requirements"
            case "DEPARTMENT_REQUIREMENT":
                requiredDept = requisites["value"]
                isInDept = requiredDept in [
                    department for department, year in student.enrolledDegrees
                ]
                return (isInDept, "" if isInDept else f"Not in {requiredDept}")
            case "PROGRAM_REQUIREMENT":
                # TODO: make this actually work by mapping departments to programs or viceversa
                requiredProgram = requisites["value"]
                isInDept = requiredProgram in [
                    department for department, year in student.enrolledDegrees
                ]
                return (isInDept, "" if isInDept else f"Not in {requiredProgram}")
            case "GRADUATION_STATUS_REQUIREMENT":
                correctStatus = requisites["value"] == student.graduation_status
                return correctStatus, (
                    "" if correctStatus else f"Must be {requisites['value']}"
                )
            case "CREDITS_WITH_PATTERN_REQUIREMENT":
                patterns = requisites["patterns"]
                requiredCredits = requisites["credits"]
                takenCredits = 0
                for takenCourse in student.completed_courses:
                    foundMatch = False
                    for pattern in patterns:
                        matches = True
                        for cChar, pChar in zip(takenCourse.courseCode, pattern):
                            if pChar != "*" and pChar != cChar:
                                matches = False
                                break
                        if matches:
                            foundMatch = True
                            break
                    if foundMatch:
                        takenCredits += takenCourse.credits
                if takenCredits >= requiredCredits:
                    return True, ""
                else:
                    return (
                        False,
                        f"Needs {requiredCredits} credits matching {patterns}, but only has {takenCredits}",
                    )
            case "COURSES_WITH_PATTERN_REQUIREMENT":
                patterns = requisites["patterns"]
                requiredNumberOfCourses = requisites["courses"]
                qualifiedCourses = 0
                for takenCourse in student.completed_courses:
                    foundMatch = False
                    for pattern in patterns:
                        matches = True
                        for cChar, pChar in zip(takenCourse.courseCode, pattern):
                            if pChar != "*" and pChar != cChar:
                                matches = False
                                break
                        if matches:
                            foundMatch = True
                            break
                    if foundMatch:
                        qualifiedCourses += 1
                if qualifiedCourses >= requiredNumberOfCourses:
                    return True, ""
                else:
                    return (
                        False,
                        f"Needs {requiredNumberOfCourses} courses matching {patterns}, but only has {qualifiedCourses}",
                    )
                # return student.departmentCredits()

            # recursively handle compound requirements
            case "OR":
                res = reduce(
                    lambda prev, curr: (
                        prev[0] or curr[0],
                        [] if prev[0] or curr[0] else prev[1] + [curr[1]],
                    ),
                    map(
                        lambda req: self.requisiteChecker(
                            student, course, req, hasDirectorApproval
                        ),
                        requisites["conditions"],
                    ),
                    (False, []),
                )
                success = res[0]
                missing = (
                    f"({' or '.join(res[1])})" if len(res[1]) > 1 else "".join(res[1])
                )
                return success, missing
            case "AND":
                res = reduce(
                    lambda prev, curr: (
                        prev[0] and curr[0],
                        [] if prev[0] and curr[0] else prev[1] + [curr[1]],
                    ),
                    map(
                        lambda req: self.requisiteChecker(
                            student, course, req, hasDirectorApproval
                        ),
                        requisites["conditions"],
                    ),
                    (True, []),
                )
                success = res[0]
                missing = (
                    f"({' and '.join(res[1])})" if len(res[1]) > 1 else "".join(res[1])
                )
                return success, missing
            case "FOR":
                # This case is rather strange as the only instance recorded is with the FISI course FISI4105
                # For now, we only handle the corequisite case and assume that the first condition is the course we expect to be enrolled in
                if not checkingCorequisites:
                    return (True, "")
                requisite = requisites["conditions"][0]
                if requisite["type"] != "COURSE":
                    return (False, "Couldn't parse FOR requirement")
                requiredCourse = requisite["value"]
                hasCourse = (
                    student.tookCourse(requiredCourse)
                    or requiredCourse in student.enrolledCourses
                )
                return hasCourse, (
                    "" if hasCourse else f"Must be enrolled in {requiredCourse}"
                )

        return (False, "Couldn't parse requirement type")
