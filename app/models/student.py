from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from app.core.database import Base

class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    roll_number = Column(String(50), unique=True, index=True, nullable=False)
    full_name = Column(String(100), nullable=False)
    email = Column(String(100), nullable=True)
    phone = Column(String(20), nullable=True)
    class_id = Column(Integer, ForeignKey("class_sections.id", ondelete="SET NULL"), nullable=True)
    is_active = Column(Boolean, default=True)
    # M4: Academic profile fields
    semester = Column(String(20), nullable=True)     # e.g., "3", "Semester 3"
    department = Column(String(100), nullable=True)  # e.g., "Computer Science & Engineering"
    # M4: Auth linkage — nullable so existing students without accounts still work
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, unique=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    class_section = relationship("ClassSection", back_populates="students")
    attendance_records = relationship("AttendanceRecord", back_populates="student", cascade="all, delete-orphan")
    face_embeddings = relationship("FaceEmbedding", back_populates="student", cascade="all, delete-orphan")
    # M4: Auth relationship
    user = relationship("User", back_populates="student_profile", foreign_keys=[user_id])
