from sqlalchemy import Column, Integer, String, Time, ForeignKey, UniqueConstraint, DateTime, Table
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from app.core.database import Base

class ClassSection(Base):
    __tablename__ = "class_sections"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, index=True, nullable=False)  # e.g., "CSE-3A"
    grade_level = Column(String(50), nullable=True)                      # e.g., "Year 3"
    academic_year = Column(String(20), nullable=True)                    # e.g., "2025-2026"
    class_advisor_id = Column(Integer, ForeignKey("faculty.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    students = relationship("Student", back_populates="class_section", cascade="all, delete-orphan")
    assignments = relationship("FacultyAssignment", back_populates="class_section", cascade="all, delete-orphan")
    class_advisor = relationship("Faculty", foreign_keys=[class_advisor_id], backref="advised_classes")

class Subject(Base):
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(20), unique=True, index=True, nullable=False)  # e.g., "CET-II"
    name = Column(String(100), nullable=False)                           # e.g., "Computer Networks"
    description = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    assignments = relationship("FacultyAssignment", back_populates="subject", cascade="all, delete-orphan")

class Period(Base):
    __tablename__ = "periods"

    id = Column(Integer, primary_key=True, index=True)
    period_number = Column(Integer, unique=True, nullable=False)       # 1..N
    name = Column(String(50), nullable=False)                          # e.g., "Period 1"
    start_time = Column(String(5), nullable=False)                     # "09:10" (HH:MM 24hr format)
    end_time = Column(String(5), nullable=False)                       # "10:00"
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    timetable_entries = relationship("TimetableEntry", back_populates="period", cascade="all, delete-orphan")

assignment_authorized_faculty = Table(
    "assignment_authorized_faculty",
    Base.metadata,
    Column("assignment_id", Integer, ForeignKey("faculty_assignments.id", ondelete="CASCADE"), primary_key=True),
    Column("faculty_id", Integer, ForeignKey("faculty.id", ondelete="CASCADE"), primary_key=True),
)

class FacultyAssignment(Base):
    __tablename__ = "faculty_assignments"
    __table_args__ = (
        UniqueConstraint("faculty_id", "subject_id", "class_id", name="uq_faculty_subject_class"),
    )

    id = Column(Integer, primary_key=True, index=True)
    faculty_id = Column(Integer, ForeignKey("faculty.id", ondelete="CASCADE"), nullable=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    class_id = Column(Integer, ForeignKey("class_sections.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    faculty = relationship("Faculty", back_populates="assignments")
    subject = relationship("Subject", back_populates="assignments")
    class_section = relationship("ClassSection", back_populates="assignments")
    timetable_entries = relationship("TimetableEntry", back_populates="assignment", cascade="all, delete-orphan")
    authorized_faculty = relationship(
        "Faculty",
        secondary=assignment_authorized_faculty,
        backref="authorized_assignments"
    )

    def is_faculty_authorized(self, target_faculty_id: int) -> bool:
        if self.faculty_id == target_faculty_id:
            return True
        if self.authorized_faculty:
            return any(f.id == target_faculty_id for f in self.authorized_faculty)
        return False

    @property
    def all_authorized_faculty(self):
        res = []
        if self.faculty:
            res.append(self.faculty)
        if self.authorized_faculty:
            for f in self.authorized_faculty:
                if f not in res:
                    res.append(f)
        return res

    @property
    def display_faculty_name(self) -> str:
        all_facs = self.all_authorized_faculty
        if not all_facs:
            return "Faculty assignment pending"
        return ", ".join(f.full_name for f in all_facs)

class TimetableEntry(Base):
    __tablename__ = "timetable_entries"
    __table_args__ = (
        UniqueConstraint("day_of_week", "period_id", "assignment_id", name="uq_day_period_assignment"),
    )

    id = Column(Integer, primary_key=True, index=True)
    day_of_week = Column(String(20), nullable=False)  # Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday
    period_id = Column(Integer, ForeignKey("periods.id", ondelete="CASCADE"), nullable=False)
    assignment_id = Column(Integer, ForeignKey("faculty_assignments.id", ondelete="CASCADE"), nullable=False)
    room = Column(String(50), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    period = relationship("Period", back_populates="timetable_entries")
    assignment = relationship("FacultyAssignment", back_populates="timetable_entries")
    class_sessions = relationship("ClassSession", back_populates="timetable_entry")
