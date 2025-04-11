from src.models.enums import Term


number_to_db_term = {
    "1": "FirstSummer",
    "2": "Fall",
    "3": "Spring",
    "4": "SecondSummer",
    "5": "ExtendedSummer",
}
db_term_to_number = {value: key for key, value in number_to_db_term.items()}

spanish_term_to_map = {
    "1": "primer verano",
    "2": "primer semestre",
    "3": "segundo semestre",
    "4": "segundo verano",
    "5": "verano extendido",
}

TERMS = (
    [Term.SECOND_SEMESTER] * 5
    + [Term.FIRST_SUMMER]
    + [Term.SECOND_SUMMER]
    + [Term.FIRST_SEMESTER] * 5
)
rumad_to_db_terms = {
    Term.FIRST_SEMESTER.value: "Fall",
    Term.SECOND_SEMESTER.value: "Spring",
    Term.FIRST_SUMMER.value: "FirstSummer",
    Term.SECOND_SUMMER.value: "SecondSummer",
    Term.EXTENDED_SUMMER.value: "ExtendedSummer",
}

db_to_rumad_terms = {value: key for (key, value) in rumad_to_db_terms.items()}

# Empirically determined based on how many courses there tend to be per department
ideal_ssh_tasks = {
    "Fall": 24,
    "Spring": 24,
    "FirstSummer": 10,
    "SecondSummer": 5,
    "ExtendedSummer": 5,
}
