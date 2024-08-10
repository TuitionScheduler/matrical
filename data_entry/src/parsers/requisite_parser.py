import re
import ply.yacc as yacc
import ply.lex as lex
import logging

tokens = (
    "CREDITS_TO_GRADUATION_REQUIREMENT",
    "ENGLISH_LEVEL_REQUIREMENT",
    "PATTERN_GROUP",
    "CREDITS_GROUP",
    "COURSES_AMOUNT_REQUIRED",
    "YEAR_REQUIREMENT",
    "COURSE",
    "DIRECTOR_APPROVAL",
    "UNKNOWN",
    # "DEPARTMENT_REQUIREMENT", #Removing this requirement and will replace with program code inspection
    "GRADUATION_STATUS_REQUIREMENT",
    "OR",
    "AND",
    "LPAREN",
    "RPAREN",
    "FOR",
    "WHITESPACE",
)


def t_CREDITS_TO_GRADUATION_REQUIREMENT(t):
    r"MENOS\s+DE\s+\d+\s+CRS\s+PARA\s+GRADUACION"
    credits = re.search(r"\d+", t.value)
    t.value = {
        "type": "CREDITS_TO_GRADUATION_REQUIREMENT",
        "value": int(
            credits.group()  # type: ignore
        ),  # Read as: "You can graduate if you have fewer than these creds left"
    }
    return t


def t_ENGLISH_LEVEL_REQUIREMENT(t):
    r"NIVEL_AVAN_INGL\s(=|<|>|<=|>=)\s\#(\d+)"
    comparator = re.findall(r"\s(=|<|>|<=|>=)\s", t.value)[0]
    level = re.findall(r"\d+", t.value)[0]
    t.value = {
        "type": "ENGLISH_LEVEL_REQUIREMENT",
        "comparator": comparator,
        "level": int(level),  # Read as: your level must be [comparator] [level]
    }
    return t


def t_GRADUATION_STATUS_REQUIREMENT(t):
    r"SUBGRADUADO|GRADUADO"
    translated_status = {
        "SUBGRADUADO": "Undergraduate",
        "GRADUADO": "Graduate",
    }
    t.value = {
        "type": "GRADUATION_STATUS_REQUIREMENT",
        "value": translated_status[t.value],
    }
    return t


def t_YEAR_REQUIREMENT(t):
    r"1ER|2DO|3RO|4TO|5TO|6TO|7MO|8VO|9NO"
    match = re.match(r"(\d+)", t.value)
    if match:
        t.value = {"type": "YEAR_REQUIREMENT", "value": int(match.group(1))}
    return t


# This requirement is currently broken and should be replaced with a program code (ie 0503) requirement
# def t_DEPARTMENT_REQUIREMENT(t):
#     r"(?!PARA)[A-Z]{4}(?=\s|$|\))"
#     t.value = {"type": "DEPARTMENT_REQUIREMENT", "value": t.value}
#     return t


def t_COURSE(t):
    r"[A-Z]{4}\s*\d{4}"
    t.value = {"type": "COURSE", "value": t.value}
    return t


# THIS MUST BE BELOW COURSE OR IT WILL TAKE PRECEDENCE AND BREAK COURSE RECOGNITION
def t_PATTERN_GROUP(t):
    r"(?:\[([A-Z0-9*]{4,9}(?:,\s*[A-Z0-9*]{4,9})*)\]|([A-Z0-9*]{4,9}))"
    # Really, patterns should only be of length 4 and 8, but the university mispelled it once
    # in CINE2025 with the pattern ****3****, so we'll just pretend it is allowed
    # Not breaking behavior as the pattern is zip()'d vs the course code and thus 9th character of the pattern would
    # never be compared with the course code (which always has a length of 8)
    if t.value.startswith("["):
        # It's an array pattern
        patterns = t.value[1:-1].replace(" ", "").split(",")
    else:
        # It's a single pattern
        patterns = [t.value]
    t.value = patterns
    return t


def t_DIRECTOR_APPROVAL(t):
    r"DIR(?=\s|$|\))"
    t.value = {"type": "DIRECTOR_APPROVAL", "value": t.value}
    return t


def t_CREDITS_GROUP(t):
    r"\{([0-9]+)\}"
    t.value = int(t.value[1:-1])  # Remove braces and convert to int
    return t


def t_COURSES_AMOUNT_REQUIRED(t):
    r"\s*(\d+)\s*"
    t.value = int(t.value.strip(" "))
    return t


# This rule is for requirements whose conditions are not well understood.
def t_UNKNOWN(t):
    r"[0-9]{4}|EXAM(?=\s|$|\))"
    t.value = {"type": "UNKNOWN", "value": t.value}
    return t


def t_WHITESPACE(t):
    r"[ \s\t]+"  # Matches spaces and tabs
    pass


def t_error(t):
    logger.info(f"Illegal character '{t.value[0]}'")
    t.lexer.skip(1)


t_OR = r"O|o|U|u"  # Maybe add Y/O for that one weird course?
t_AND = r"Y|y|E|e"
t_LPAREN = r"\("
t_RPAREN = r"\)"
t_FOR = r"PARA"

# Define the precedence of operators
precedence = (
    ("left", "FOR"),
    ("left", "OR"),
    ("left", "AND"),
)


# Parser
def p_prerequisite_base_rule(p):
    """prerequisite : empty"""
    p[0] = {}


def p_and_group(p):
    """prerequisite : prerequisite AND prerequisite"""
    if p[1]["type"] == "AND" or p[3]["type"] == "AND":
        and_term = 1 if p[1]["type"] == "AND" else 3
        other_term = 3 if p[1]["type"] == "AND" else 1
        if p[other_term]["type"] == "AND":
            p[and_term]["conditions"].extend(p[other_term]["conditions"])
        else:
            p[and_term]["conditions"].append(p[other_term])
        p[0] = p[and_term]
    else:
        p[0] = {"type": "AND", "conditions": [p[1], p[3]]}


def p_or_group(p):
    """prerequisite : prerequisite OR prerequisite"""
    if p[1]["type"] == "OR" or p[3]["type"] == "OR":
        or_term = 1 if p[1]["type"] == "OR" else 3
        other_term = 3 if p[1]["type"] == "OR" else 1
        if p[other_term]["type"] == "OR":
            p[or_term]["conditions"].extend(p[other_term]["conditions"])
        else:
            p[or_term]["conditions"].append(p[other_term])
        p[0] = p[or_term]
    else:
        p[0] = {"type": "OR", "conditions": [p[1], p[3]]}


def p_for_group(p):
    """prerequisite : prerequisite FOR prerequisite"""
    p[0] = {"type": "FOR", "conditions": [p[1], p[3]]}


def p_grouped_term(p):
    """prerequisite : LPAREN prerequisite RPAREN"""
    p[0] = p[2]


def p_credits_with_pattern_requirement(p):
    """credits_with_pattern_requirement : PATTERN_GROUP CREDITS_GROUP"""
    p[0] = {
        "type": "CREDITS_WITH_PATTERN_REQUIREMENT",
        "patterns": p[1],
        "credits": p[2],
    }


def p_courses_with_pattern_requirement(p):
    """courses_with_pattern_requirement : PATTERN_GROUP COURSES_AMOUNT_REQUIRED"""
    p[0] = {
        "type": "COURSES_WITH_PATTERN_REQUIREMENT",
        "patterns": p[1],
        "courses": p[2],
    }


def p_term(p):
    """prerequisite : CREDITS_TO_GRADUATION_REQUIREMENT
    | YEAR_REQUIREMENT
    | COURSE
    | DIRECTOR_APPROVAL
    | GRADUATION_STATUS_REQUIREMENT
    | ENGLISH_LEVEL_REQUIREMENT
    | credits_with_pattern_requirement
    | courses_with_pattern_requirement
    | UNKNOWN"""
    p[0] = p[1]


def p_empty(p):
    """empty :"""
    pass  # This production represents an empty string, so no action is taken


def p_error(p):
    error_message = f"Syntax error at token {p.value}"
    raise Exception(error_message)


lexer = lex.lex()
lexer.outputdir = "requisite_parser_output"
parser = yacc.yacc()
parser.outputdir = "requisite_parser_output"
logger = logging.getLogger(__name__)


def lexer_tester(input_string):
    lexer.input(input_string)
    tok = lexer.token()
    while tok is not None:
        print(tok)
        tok = lexer.token()


def parse_prerequisites(input_string):
    try:
        result = parser.parse(input_string, lexer=lexer)
        return result
    except Exception as e:
        logger.error(f"Errored out whilst parsing {input_string}: {e}")
        return {"type": "UNKNOWN", "value": input_string}


def parse_corequisites(input_string):
    return parse_prerequisites(input_string)
