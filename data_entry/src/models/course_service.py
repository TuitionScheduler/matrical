from src.database import Course, engine
from sqlalchemy.orm import sessionmaker


class CourseService:
    def __init__(self):
        Session = sessionmaker(engine)
        self.session = Session()

    def getCourse(self, code, term, year) -> Course | None:
        self.session.begin()
        course = (
            self.session.query(Course)
            .filter_by(course_code=code, year=year, term=term)
            .first()
        )
        return course
