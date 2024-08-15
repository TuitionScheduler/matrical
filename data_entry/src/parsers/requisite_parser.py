import re
import ply.yacc as yacc
import ply.lex as lex
import logging

tokens = (
    "CREDITS_TO_GRADUATION_REQUIREMENT",
    "GRADUATION_STATUS_REQUIREMENT",
    "ENGLISH_LEVEL_REQUIREMENT",
    "CREDITS_WITH_PATTERN_REQUIREMENT",
    "COURSES_WITH_PATTERN_REQUIREMENT",
    "YEAR_REQUIREMENT",
    "COURSE",
    "EXAM_REQUIREMENT",
    "UNKNOWN",
    "DEPARTMENT_REQUIREMENT",
    "PROGRAM_REQUIREMENT",
    "DIRECTOR_APPROVAL",
    "ANDOR",
    "OR",
    "AND",
    "LPAREN",
    "RPAREN",
    "LBRACKET",
    "RBRACKET",
    "CREDITS_GROUP",
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
    r"NIVEL_AVAN_INGL\s*(=|<|>|<=|>=)\s*\#(\d+)"
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


def t_CREDITS_WITH_PATTERN_REQUIREMENT(t):
    r"(?:\[([A-Z*]{4}[0-9*]{0,5}(?:,\s*[A-Z*]{4}[0-9*]{0,5})*)\]|([A-Z*]{4}[0-9*]{0,5}))\s*\{([0-9]+)\}"
    # Really, patterns should only be of length 4 and 8, but the university mispelled it once
    # in CINE2025 with the pattern ****3****, so we'll just pretend it is allowed
    # Not breaking behavior as the pattern is zip()'d vs the course code and thus 9th character of the pattern would
    # never be compared with the course code (which always has a length of 8)
    credits = int(re.search(r"\{\d+\}", t.value).group()[1:-1])  # type: ignore
    if t.value.startswith("["):
        # It's an array pattern
        rBracketPos = t.value.rindex("]")
        patterns = t.value[1:rBracketPos].replace(" ", "").split(",")
    else:
        # It's a single pattern
        lCurlyPos = t.value.index("{")
        patterns = [t.value[:lCurlyPos].replace(" ", "")]
    t.value = {
        "type": "CREDITS_WITH_PATTERN_REQUIREMENT",
        "patterns": patterns,
        "credits": credits,
    }
    return t


# Note: currently only handles array patterns
def t_COURSES_WITH_PATTERN_REQUIREMENT(t):
    r"(?:\[([A-Z*]{4}[0-9*]{0,5}(?:,\s*[A-Z*]{4}[0-9*]{0,5})*)\])\s*(\d+)"
    # Really, patterns should only be of length 4 and 8, but the university mispelled it once
    # in CINE2025 with the pattern ****3****, so we'll just pretend it is allowed
    # Not breaking behavior as the pattern is zip()'d vs the course code and thus 9th character of the pattern would
    # never be compared with the course code (which always has a length of 8)
    rBracketPos = t.value.rindex("]")
    patterns = t.value[1:rBracketPos].replace(" ", "").split(",")
    credits = int(t.value[rBracketPos + 1 :].replace(" ", ""))
    t.value = {
        "type": "COURSES_WITH_PATTERN_REQUIREMENT",
        "patterns": patterns,
        "credits": credits,
    }
    return t


def t_COURSE(t):
    r"[A-Z]{4}\s*\d{4}"
    t.value = {"type": "COURSE", "value": t.value}
    return t


def t_DIRECTOR_APPROVAL(t):
    r"DIR(?=\s|$|\))"
    t.value = {"type": "DIRECTOR_APPROVAL", "value": t.value}
    return t


# This rule is for requirements whose conditions are not well understood.
def t_UNKNOWN(t):
    r"(BIO3064)"
    t.value = {"type": "UNKNOWN", "value": t.value}
    return t


def t_EXAM_REQUIREMENT(t):
    r"(EXA\s*DIAG\s*MATE)|((EXAM|EXA)(?=\s|$|\)))"
    t.value = {"type": "EXAM_REQUIREMENT", "value": t.value}
    return t


def t_DEPARTMENT_REQUIREMENT(t):
    r"[A-Z]{4}"
    t.value = {"type": "DEPARTMENT_REQUIREMENT", "value": t.value}
    return t


def t_PROGRAM_REQUIREMENT(t):
    r"(!)?[0-9]{4}(M)?"
    t.value = {"type": "PROGRAM_REQUIREMENT", "value": t.value}
    return t


def t_CREDITS_GROUP(t):
    r"\{([0-9]+)\}"
    t.value = int(t.value[1:-1])  # Remove braces and convert to int
    return t


def t_WHITESPACE(t):
    r"[ \s\t]+"  # Matches spaces and tabs
    pass


def t_error(t):
    logger.info(f"Illegal character '{t.value[0]}'")
    t.lexer.skip(1)


t_ANDOR = r"(Y/O)"
t_AND = r"[YyEe](?!/)|(O Y)"
t_OR = r"[OoUu](?!(\sY))"
t_LPAREN = r"\("
t_RPAREN = r"\)"
t_LBRACKET = r"\["
t_RBRACKET = r"\]"
t_FOR = r"PARA"

# Define the precedence of operators
precedence = (
    ("left", "FOR"),
    ("left", "OR"),
    ("left", "ANDOR"),
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


def p_credits_with_pattern_requirement_or(p):
    """credits_with_pattern_requirement : LBRACKET prerequisite RBRACKET CREDITS_GROUP"""
    if p[2].get("type") != "OR":
        patterns = []
    else:
        requisites = p[2].get("conditions")
        patterns = [
            requisite["value"]
            for requisite in requisites
            if requisite["type"] == "COURSE"
        ]
    p[0] = {
        "type": "CREDITS_WITH_PATTERN_REQUIREMENT",
        "patterns": patterns,
        "credits": p[4],
    }


def p_andor_group(p):
    """andor_group : andor_group ANDOR COURSE
    | COURSE ANDOR COURSE
    """
    if p[1]["type"] == "COURSE":
        p[0] = {"type": "ANDOR", "value": [p[1], p[3]]}
    elif p[1]["type"] == "ANDOR":
        p[1]["value"].extend(p[3])
        p[0] = p[1]


def p_credits_with_pattern_requirement_andor(p):
    """credits_with_pattern_requirement : CREDITS_GROUP LPAREN andor_group RPAREN
    | CREDITS_GROUP LPAREN COURSE RPAREN
    """
    if p[3].get("type") == "ANDOR":
        patterns = p[3]["value"]
    else:
        patterns = [p[3]["value"]]
    p[0] = {
        "type": "CREDITS_WITH_PATTERN_REQUIREMENT",
        "patterns": patterns,
        "credits": p[1],
    }


def p_credits_with_pattern_requirement_inverted(p):
    """credits_with_pattern_requirement : CREDITS_GROUP DEPARTMENT_REQUIREMENT"""

    patterns = [p[2]["value"]]
    p[0] = {
        "type": "CREDITS_WITH_PATTERN_REQUIREMENT",
        "patterns": patterns,
        "credits": p[1],
    }


def p_credits_with_pattern_requirement(p):
    """credits_with_pattern_requirement : CREDITS_WITH_PATTERN_REQUIREMENT"""
    p[0] = p[1]


def p_term(p):
    """prerequisite : CREDITS_TO_GRADUATION_REQUIREMENT
    | YEAR_REQUIREMENT
    | COURSE
    | DIRECTOR_APPROVAL
    | GRADUATION_STATUS_REQUIREMENT
    | ENGLISH_LEVEL_REQUIREMENT
    | credits_with_pattern_requirement
    | COURSES_WITH_PATTERN_REQUIREMENT
    | PROGRAM_REQUIREMENT
    | DEPARTMENT_REQUIREMENT
    | EXAM_REQUIREMENT
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
