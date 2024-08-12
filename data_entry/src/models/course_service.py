from src.database import Course, engine
from sqlalchemy.orm import sessionmaker, aliased
from sqlalchemy import func, distinct


class CourseService:
    def __init__(self):
        Session = sessionmaker(engine)
        self.session = Session()

    def getCourse(self, code: str, term: str | None, year: int | None) -> Course | None:
        self.session.begin()
        if term is None and year is None:
            self.session.query(Course).filter_by(course_code=code)
            course = self.session.query(Course).filter_by(course_code=code).first()
        elif term is None:
            course = (
                self.session.query(Course)
                .filter_by(course_code=code, year=year)
                .first()
            )
        elif year is None:
            course = (
                self.session.query(Course)
                .filter_by(course_code=code, term=term)
                .order_by(Course.year.desc())
                .first()
            )
        else:
            course = (
                self.session.query(Course)
                .filter_by(course_code=code, term=term, year=year)
                .first()
            )
        self.session.close()
        return course

    def getAllCourses(self, term: str, year: int) -> list[Course]:
        self.session.begin()
        courses = self.session.query(Course).filter_by(year=year, term=term).all()
        self.session.close()
        return courses

    def getLatestCourses(self) -> list[Course]:
        # Subquery to get the max year for each course_code
        subquery = (
            self.session.query(
                Course.course_code, func.max(Course.year).label("max_year")
            )
            .group_by(Course.course_code)
            .subquery()
        )

        latest_courses = (
            self.session.query(Course)
            .join(
                subquery,
                (Course.course_code == subquery.c.course_code)
                & (Course.year == subquery.c.max_year),
            )
            .distinct(Course.course_code)
            .all()
        )
        return latest_courses
