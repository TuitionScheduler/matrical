from enum import StrEnum


class RequisiteType(StrEnum):
    CREDITS_TO_GRADUATION = "CREDITS_TO_GRADUATION_REQUIREMENT"
    ENGLISH_LEVEL = "ENGLISH_LEVEL_REQUIREMENT"
    YEAR = "YEAR_REQUIREMENT"
    COURSE = "COURSE"
    DIRECTOR_APPROVAL = "DIRECTOR_APPROVAL"
    UNKNOWN = "UNKNOWN"
    DEPARTMENT = "DEPARTMENT_REQUIREMENT"
    GRADUATION_STATUS = "GRADUATION_STATUS_REQUIREMENT"
    DEPARTMENT_CREDITS = "DEPARTMENT_CREDITS_REQUIREMENT"


class GroupType(StrEnum):
    AND = "AND"
    OR = "OR"
