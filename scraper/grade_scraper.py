import sys
import pandas as pd
from sqlalchemy import create_engine, join
from sqlalchemy.orm import sessionmaker
from sqlalchemy.sql import select
from database import Course, Section, GradeDistribution, Base
import argparse


def import_data(excel_file, academic_year):
    # Create engine and session
    engine = create_engine("sqlite:///courses.db", echo=True)
    Session = sessionmaker(bind=engine)
    session = Session()

    sheets = ["SEM-1", "SEM-2"]

    for sheet in sheets:
        df = pd.read_excel(excel_file, sheet_name=sheet).fillna(0)
        # Map term to integer
        term_map = {"SEM-1": 2, "SEM-2": 3}
        term = term_map[sheet]
        course_key = "COURSE" if academic_year < 2023 else "Curso"
        section_key = "SECTION" if academic_year < 2023 else "Seccion"

        for _, row in df.iterrows():
            # Get or create Course
            course_code = row[course_key].replace(" ", "")
            course = (
                session.query(Course)
                .filter_by(
                    course_code=course_code,
                    year=academic_year,
                    term=term,
                )
                .first()
            )

            if not course:
                print(f"Warning: Course not found {course_code} ")
                continue

            # Query to get the section ID
            j = join(Section, Course, Section.course_id == Course.id)
            stmt = (
                select(Section.id)
                .select_from(j)
                .where(
                    (Course.course_code == course_code)
                    & (Section.section_code == row[section_key])
                    & (Course.year == academic_year)
                    & (Course.term == term)
                )
            )
            section_id = session.execute(stmt).scalar_one_or_none()

            if section_id is None:
                print(
                    f"Warning: Section not found for course {course_code}, section {row[section_key]}"
                )
                continue

            # Create or update GradeDistribution
            grade_distribution = (
                session.query(GradeDistribution)
                .filter_by(section_id=section_id)
                .first()
            )
            if not grade_distribution:
                grade_distribution = GradeDistribution(section_id=section_id)
                session.add(grade_distribution)

            # Update grade distribution
            for grade in [
                "A",
                "B",
                "C",
                "D",
                "F",
                "I",  # incompletes
                "IA",
                "IB",
                "IC",
                "ID",
                "IF",
                "NS",
                "P",  # Pass
                "S",
                "W",  # Dropped
            ]:
                setattr(grade_distribution, grade, row.get(grade, 0))

        # Commit changes for each sheet
        session.commit()

    # Close the session
    session.close()

    print("Data import completed successfully.")


def main():
    parser = argparse.ArgumentParser(
        description="Import grade distribution data from Excel file."
    )
    parser.add_argument("-f", "--excel_file", help="Path to the Excel file")
    parser.add_argument(
        "-y", "--academic_year", type=int, help="Academic year (e.g., 2023)"
    )

    args = parser.parse_args()

    import_data(args.excel_file, args.academic_year)


if __name__ == "__main__":
    main()
