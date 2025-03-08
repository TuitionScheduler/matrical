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
from sqlalchemy.orm import relationship, declarative_base

Base = declarative_base()


class Program(Base):
    __tablename__ = "programs"
    prog_code = Column(String(5), primary_key=True, nullable=False)
    prog_name = Column(String, nullable=False)
    required_igs = Column(Integer, nullable=False)


class Course(Base):
    __tablename__ = "courses"
    cid = Column(Integer, primary_key=True, autoincrement=True)
    course_code = Column(String(10), nullable=False)
    course_name = Column(String)
    year = Column(Integer, nullable=False)
    term = Column(String, nullable=False)
    credits = Column(Integer)
    department = Column(String)
    prerequisites = Column(String)
    corequisites = Column(String)

    # Define a one-to-many relationship between Course and Section
    sections = relationship(
        "Section", back_populates="course", cascade="all, delete, delete-orphan"
    )

    __table_args__ = (
        Index("idx_term", term),
        Index("idx_year", year),
        UniqueConstraint("course_code", "term", "year", name="uq_course_term_year"),
    )


class Section(Base):
    __tablename__ = "sections"
    sid = Column(Integer, primary_key=True, autoincrement=True)
    section_code = Column(String(5), nullable=False)
    meetings_text = Column(String)  # comma separated
    modality = Column(String)
    capacity = Column(Integer, default=0)
    taken = Column(Integer, default=0)
    reserved = Column(Boolean)
    professors = Column(String)  # comma separated
    misc = Column(String)  # comma separated

    # Define a many-to-one relationship between Section and Course
    cid = Column(Integer, ForeignKey("courses.cid"), nullable=False)
    course = relationship("Course", back_populates="sections")

    # Define a one-to-many relationship between Section and Meeting
    meetings = relationship(
        "Meeting", back_populates="section", cascade="all, delete, delete-orphan"
    )

    # Define a one-to-many relationship between Section and GradeDistribution
    grade_distributions = relationship("GradeDistribution", back_populates="section")

    __table_args__ = (UniqueConstraint("section_code", "cid", name="unique_sections"),)


class Meeting(Base):
    __tablename__ = "meetings"
    mid = Column(Integer, primary_key=True, autoincrement=True)
    building = Column(String)
    room = Column(String)
    days = Column(String)
    start_time = Column(String)
    end_time = Column(String)

    # Define a many-to-one relationship between Meeting and Section
    sid = Column(Integer, ForeignKey("sections.sid"), nullable=False)
    section = relationship("Section", back_populates="meetings")


class GradeDistribution(Base):
    __tablename__ = "grade_distributions"
    tid = Column(
        Integer, primary_key=True, autoincrement=True
    )  # tid->table id to not overlap with Incomplete D
    sid = Column(Integer, ForeignKey("sections.sid"), nullable=False)
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
