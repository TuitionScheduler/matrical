from sqlalchemy import create_engine, desc, func, select
from sqlalchemy.orm import sessionmaker
from src.database import Course


engine = create_engine("sqlite:///courses.db")
Session = sessionmaker(bind=engine)
dept_courses = {}
with open("input_files/departments.txt", "r") as f:
    departments = [line.strip() for line in f]
    for dept in departments:
        dept_courses[dept] = 0
with Session() as session:
    # Get the latest two years
    latest_two_years = (
        session.query(Course.year).distinct().order_by(desc(Course.year)).limit(2).all()
    )

    # Extract the years into a list
    latest_two_years = [year[0] for year in latest_two_years]

    # Query to count courses per department for the latest two years
    course_count_per_department = (
        session.query(Course.department, func.count(Course.id).label("course_count"))
        .filter(Course.year.in_(latest_two_years))
        .group_by(Course.department)
        .all()
    )
    for department, course_count in course_count_per_department:
        dept_courses[department] = course_count

with open("input_files/departments.txt", "w+") as f:
    for dept in sorted(
        dept_courses.keys(), key=lambda k: dept_courses[k], reverse=True
    ):
        f.write(dept)
        f.write("\n")