from pypdf import PdfReader
import re

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from src.database import Base, Program


def program_name_sanitizer(progName: str):
    # strip prefix and suffix space and unwanted chars
    progName = progName.strip(" `´")
    # remove phrase in parenthesis
    parenStart = progName.find("(")
    parenEnd = progName.rfind(")")
    if parenStart != -1 and parenEnd != -1:
        progName = progName[:parenStart] + progName[parenEnd + 1 :]

    # remove excess spaces between words
    return re.sub(r"\s{2,}", " ", progName)


reader = PdfReader("input_files/IMIS-RUM-2024.pdf")
pages = reader.pages
dataPattern = r"([0-9]{4,})[\s\t]*(\w(?:\s+\w)*)[\s\t]*([0-9]+)"
engine = create_engine("sqlite:///courses.db", echo=True)
Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)
session = Session()
session.begin()
for page in pages:
    lines = page.extract_text().splitlines()
    for line in lines:
        match = re.search(r"([0-9]{4})\s*([^0-9]+(?:\s+[^0-9]+)*)\s*([0-9]+)", line)
        if match:
            programCode = match.group(1)
            programName = program_name_sanitizer(match.group(2))
            requiredIgs = int(match.group(3))
            program = (
                session.query(Program).where(Program.prog_code == programCode).first()
            )
            if program:
                program.prog_name = programName  # type: ignore
                program.required_igs = requiredIgs  # type: ignore
            else:
                session.add(
                    Program(
                        prog_code=programCode,
                        prog_name=programName,
                        required_igs=requiredIgs,
                    )
                )
session.commit()
session.close()
