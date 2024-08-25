from sqlalchemy import (
    Boolean,
    ForeignKey,
    create_engine,
    Column,
    Integer,
    String,
    Index,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class Program(Base):
    __tablename__ = "programs"
    prog_code = Column(String(5), primary_key=True, nullable=False)
    prog_name = Column(String, nullable=False)
    required_igs = Column(Integer, nullable=False)


class Course(Base):
    __tablename__ = "courses"
    id = Column(Integer, primary_key=True, autoincrement=True)
    course_code = Column(String(10), nullable=False)
    course_name = Column(String)
    year = Column(Integer, nullable=False)
    term = Column(String, nullable=False)
    credits = Column(Integer)
    department = Column(String)
    prerequisites = Column(String)
    corequisites = Column(String)

    # Define a one-to-many relationship between Course and Section
    sections = relationship("Section", back_populates="course")

    # Create indexes for term and year
    __table_args__ = (
        Index("idx_term", term),
        Index("idx_year", year),
        UniqueConstraint("course_code", "term", "year", name="uq_course_term_year"),
    )


class Section(Base):
    __tablename__ = "sections"
    id = Column(Integer, primary_key=True, autoincrement=True)
    section_code = Column(String(5), nullable=False)
    meetings = Column(String)  # comma separated
    modality = Column(String)
    capacity = Column(Integer, default=0)
    taken = Column(Integer, default=0)
    reserved = Column(Boolean)
    professors = Column(String)  # comma separated
    misc = Column(String)  # comma separated

    # Define a many-to-one relationship between Section and Course
    course_id = Column(Integer, ForeignKey("courses.id"), nullable=False)
    course = relationship("Course", back_populates="sections")

    # Define a one-to-many relationship between Section and Schedule
    schedules = relationship("Schedule", back_populates="section")
    grade_distributions = relationship("GradeDistribution", back_populates="section")
    __table_args__ = (
        UniqueConstraint("section_code", "course_id", name="unique_sections"),
    )


class Schedule(Base):
    __tablename__ = "schedules"
    id = Column(Integer, primary_key=True, autoincrement=True)
    building = Column(String)
    room = Column(String)
    days = Column(String)
    start_time = Column(String)
    end_time = Column(String)

    # Define a many-to-one relationship between Schedule and Section
    section_id = Column(Integer, ForeignKey("sections.id"), nullable=False)
    section = relationship("Section", back_populates="schedules")


class GradeDistribution(Base):
    __tablename__ = "grade_distributions"
    tid = Column(
        Integer, primary_key=True, autoincrement=True
    )  # tid->table id to not overlap with Incomplete D
    section_id = Column(Integer, ForeignKey("sections.id"), nullable=False)
    A = Column(Integer, default=0, nullable=False)
    B = Column(Integer, default=0, nullable=False)
    C = Column(Integer, default=0, nullable=False)
    D = Column(Integer, default=0, nullable=False)
    F = Column(Integer, default=0, nullable=False)
    I = Column(Integer, default=0, nullable=False)
    IA = Column(Integer, default=0, nullable=False)
    IB = Column(Integer, default=0, nullable=False)
    IC = Column(Integer, default=0, nullable=False)
    ID = Column(Integer, default=0, nullable=False)
    IF = Column(Integer, default=0, nullable=False)
    NS = Column(Integer, default=0, nullable=False)
    P = Column(Integer, default=0, nullable=False)
    S = Column(Integer, default=0, nullable=False)
    W = Column(Integer, default=0, nullable=False)

    section = relationship("Section", back_populates="grade_distributions")


engine = create_engine("sqlite:///courses.db", echo=True)
Base.metadata.create_all(engine)
