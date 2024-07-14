import re
import ply.yacc as yacc
import ply.lex as lex
import logging

tokens = (
    "CREDITS_TO_GRADUATION_REQUIREMENT",
    "ENGLISH_LEVEL_REQUIREMENT",
    "CREDIT_REQUIREMENT",
    "YEAR_REQUIREMENT",
    "COURSE",
    "DIRECTOR_APPROVAL",
    "UNKNOWN",
    "DEPARTMENT_REQUIREMENT",
    "GRADUATION_STATUS_REQUIREMENT",
    "OR",
    "AND",
    "LPAREN",
    "RPAREN",
    "FOR",
    "WHITESPACE",
)


# TODO: Parse this better
def t_DEPARTMENT_CREDITS_REQUIREMENT(t):
    r"(\{[0-9]+\}\s*([\*A-Z]{4}([\*0-9]{4})?|\[([\*A-Z]{4}([\*0-9]{4})?,\s*)+[\*A-Z]{4}([\*0-9]{4})?\]))\
    |(([\*A-Z]{4}([\*0-9]{4})?|\[([\*A-Z]{4}([\*0-9]{4})?,\s*)+[\*A-Z]{4}([\*0-9]{4})?\])\s*\{[0-9]+\})"
    t.value = {"type": "DEPARTMENT_CREDITS_REQUIREMENT", "value": t.value}
    return t


def t_YEAR_REQUIREMENT(t):
    r"1ER|2DO|3RO|4TO|5TO|6TO|7MO|8VO|9NO"
    match = re.match(r"(\d+)", t.value)
    if match:
        t.value = {"type": "YEAR_REQUIREMENT", "value": int(match.group(1))}
    return t


def t_COURSE(t):
    r"[A-Z]{4}\s*\d{4}"
    t.value = {"type": "COURSE", "value": t.value}
    return t


def t_DIRECTOR_APPROVAL(t):
    r"DIR(?=\s|$|\))"
    t.value = {"type": "DIRECTOR_APPROVAL", "value": t.value}
    return t


def t_DEPARTMENT_REQUIREMENT(t):
    r"(?!PARA)[A-Z]{4}(?=\s|$|\))"
    t.value = {"type": "DEPARTMENT_REQUIREMENT", "value": t.value}
    return t


def t_GRADUATION_STATUS_REQUIREMENT(t):
    r"SUBGRADUADO|GRADUADO"
    t.value = {"type": "GRADUATION_STATUS_REQUIREMENT", "value": t.value}
    return t


def t_CREDITS_TO_GRADUATION_REQUIREMENT(t):
    r"MENOS\sDE\s\d+\sCRS?\sPARA\sGRADUACION"
    credits = re.match(r"\d+", t.value)
    t.value = {
        "type": "CREDITS_TO_GRADUATION_REQUIREMENT",
        "value": int(
            credits.group()
        ),  # Read as: "You can graduate if you have fewer than these creds left"
    }
    return t


def t_ENGLISH_LEVEL_REQUIREMENT(t):
    r"NIVEL_AVAN_INGL\s(=|<|>|<=|>=)\s\#(\d+)"
    comparator = re.findall(r"\s(=|<|>|<=|>=)\s", t.value)[0]
    level = re.findall(r"\d+", t.value)[0]
    t.value = {
        "type": "CREDITS_TO_GRADUATION_REQUIREMENT",
        "comparator": comparator,
        "level": int(level),  # Read as: your level must be [comparator] [level]
    }
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


t_OR = r"O|o|U|u"
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


def p_term(p):
    """prerequisite : CREDITS_TO_GRADUATION_REQUIREMENT
    | YEAR_REQUIREMENT
    | DEPARTMENT_CREDITS_REQUIREMENT
    | COURSE
    | DIRECTOR_APPROVAL
    | DEPARTMENT_REQUIREMENT
    | GRADUATION_STATUS_REQUIREMENT
    | ENGLISH_LEVEL_REQUIREMENT
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


def parse_prerequisites(input_string):
    try:
        result = parser.parse(input_string, lexer=lexer)
        return result
    except Exception as e:
        logger.error(f"Errored out whilst parsing {input_string}: {e}")
        return {"type": "UNKNOWN", "value": input_string}


def parse_corequisites(input_string):
    return parse_prerequisites(input_string)
