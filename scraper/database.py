from sqlalchemy import Boolean, ForeignKey, create_engine, Column, Integer, String, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class Course(Base):
    __tablename__ = "courses"
    course_code = Column(String(10), primary_key=True, unique=True)
    course_name = Column(String)
    year = Column(Integer)
    term = Column(Integer)  # First Semester is 2, Second Semester is 3
    credits = Column(Integer)
    department = Column(String)
    prerequisites = Column(String)
    corequisites = Column(String)

    # Define a one-to-many relationship between Course and Section
    sections = relationship("Section", back_populates="course")


class Section(Base):
    __tablename__ = "sections"
    id = Column(Integer, primary_key=True, autoincrement=True)
    section_code = Column(String(5))
    meetings = Column(String)  # comma separated
    modality = Column(String)
    capacity = Column(Integer)
    taken = Column(Integer)
    reserved = Column(Boolean)
    professors = Column(Integer)  # comma separated
    term = Column(Integer)
    year = Column(Integer)
    misc = Column(String)  # comma separated

    # Define a many-to-one relationship between Section and Course
    course_code = Column(Integer, ForeignKey("courses.course_code"))
    course = relationship("Course", back_populates="sections")

    # Define a one-to-many relationship between Section and Schedule
    schedules = relationship("Schedule", back_populates="section")


class Schedule(Base):
    __tablename__ = "schedules"
    id = Column(Integer, primary_key=True, autoincrement=True)
    building = Column(String)
    room = Column(String)
    days = Column(String)
    start_time = Column(String)
    end_time = Column(String)

    # Define a many-to-one relationship between Schedule and Section
    section_id = Column(Integer, ForeignKey("sections.id"))
    section = relationship("Section", back_populates="schedules")


engine = create_engine("sqlite:///courses.db", echo=True)
Base.metadata.create_all(engine)
