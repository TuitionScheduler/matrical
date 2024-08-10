import pytest
from src.parsers.requisite_parser import (
    parse_prerequisites,
)


def test_credits_to_graduation_requirement():
    result = parse_prerequisites("MENOS DE 30 CRS PARA GRADUACION")
    assert result == {"type": "CREDITS_TO_GRADUATION_REQUIREMENT", "value": 30}


def test_english_level_requirement():
    result = parse_prerequisites("NIVEL_AVAN_INGL >= #4")
    assert result == {
        "type": "ENGLISH_LEVEL_REQUIREMENT",
        "comparator": ">=",
        "level": 4,
    }


def test_year_requirement():
    result = parse_prerequisites("3RO")
    assert result == {"type": "YEAR_REQUIREMENT", "value": 3}


def test_course():
    result = parse_prerequisites("CIIC3011")
    assert result == {"type": "COURSE", "value": "CIIC3011"}


def test_director_approval():
    result = parse_prerequisites("DIR")
    assert result == {"type": "DIRECTOR_APPROVAL", "value": "DIR"}


def test_graduation_status_requirement():
    result = parse_prerequisites("SUBGRADUADO")
    assert result == {"type": "GRADUATION_STATUS_REQUIREMENT", "value": "Undergraduate"}


def test_unknown():
    result = parse_prerequisites("EXAM")
    assert result == {"type": "UNKNOWN", "value": "EXAM"}


def test_credits_with_pattern_requirement():
    result = parse_prerequisites("CIIC* {3}")
    assert result == {
        "type": "CREDITS_WITH_PATTERN_REQUIREMENT",
        "patterns": ["CIIC*"],
        "credits": 3,
    }


def test_courses_with_pattern_requirement():
    result = parse_prerequisites("CIIC* 2")
    assert result == {
        "type": "COURSES_WITH_PATTERN_REQUIREMENT",
        "patterns": ["CIIC*"],
        "courses": 2,
    }
