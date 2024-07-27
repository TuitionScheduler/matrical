from src.database import Course, engine
from sqlalchemy.orm import sessionmaker


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

    def getAllCourses(self, term, year) -> list[Course]:
        self.session.begin()
        courses = self.session.query(Course).filter_by(year=year, term=term).all()
        self.session.close()
        return courses
