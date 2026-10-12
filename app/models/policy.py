"""
M4: Attendance Policy Engine Model and System Settings Key-Value Store.

AttendancePolicy: Stores all configurable policy fields that control how
attendance is calculated, displayed, and enforced.

SystemSetting: Generic key-value store for admin-configurable settings
(auth settings, AI settings, display settings, etc.).
"""

from sqlalchemy import Column, Integer, String, Boolean, Float, Text, DateTime
from datetime import datetime, timezone
from app.core.database import Base


class AttendancePolicy(Base):
    """
    Configurable attendance policy. Only one active record is used at a time.
    Future: support versioning / per-class overrides.
    """
    __tablename__ = "attendance_policies"

    id = Column(Integer, primary_key=True, index=True)

    # --- Calculation Unit ---
    calculation_unit = Column(String(20), default="PERIOD", nullable=False)
    # Options: PERIOD, HOUR

    # --- Thresholds ---
    minimum_percentage = Column(Float, default=75.0, nullable=False)    # e.g. 75.0
    warning_threshold = Column(Float, default=75.0, nullable=False)     # e.g. 75.0
    critical_threshold = Column(Float, default=65.0, nullable=False)    # e.g. 65.0

    # --- Unmarked Behavior ---
    # What to do when faculty hasn't marked a student yet for a completed session
    # Options: PRESENT, ABSENT, NOT_ENTERED, EXCLUDED
    unmarked_behavior = Column(String(20), default="NOT_ENTERED", nullable=False)

    # --- Special Session Behaviors ---
    # Whether NO_CLASS periods are excluded from denominator
    exclude_no_class = Column(Boolean, default=True, nullable=False)
    # Whether SUSPENDED periods are excluded from denominator
    exclude_suspended = Column(Boolean, default=True, nullable=False)
    # Whether timetable-not-set periods are excluded
    exclude_timetable_not_set = Column(Boolean, default=True, nullable=False)

    # --- OD Policy ---
    od_enabled = Column(Boolean, default=True, nullable=False)
    od_faculty_can_mark = Column(Boolean, default=True, nullable=False)
    od_require_reason = Column(Boolean, default=False, nullable=False)
    od_require_approval = Column(Boolean, default=False, nullable=False)
    od_allow_retroactive = Column(Boolean, default=False, nullable=False)
    od_allow_multiple_periods = Column(Boolean, default=True, nullable=False)
    # OD calculation: COUNT_AS_PRESENT, EXCLUDE_FROM_DENOMINATOR, COUNT_SEPARATELY
    od_calculation_mode = Column(String(30), default="COUNT_AS_PRESENT", nullable=False)

    # --- Leave Behavior ---
    leave_calculation_mode = Column(String(30), default="ABSENT", nullable=False)
    # Options: ABSENT, EXCLUDED

    # --- Calculation Mode ---
    calculation_mode = Column(String(30), default="RECORD_BASED", nullable=False)
    # Options: RECORD_BASED, IMPACT_BASED

    # --- Attendance Impact Configuration ---
    period_present_gain = Column(Float, default=0.25, nullable=False)
    period_absent_loss = Column(Float, default=0.25, nullable=False)

    class_present_gain = Column(Float, default=1.00, nullable=False)
    class_absent_loss = Column(Float, default=1.00, nullable=False)

    day_present_gain = Column(Float, default=1.00, nullable=False)
    day_absent_loss = Column(Float, default=1.00, nullable=False)

    # --- Metadata ---
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc))


class SystemSetting(Base):
    """
    Generic key-value store for admin-configurable system settings.
    Key examples:
        auth.faculty_login_method   = "FACULTY_ID"  | "USERNAME" | "EMAIL"
        auth.student_login_method   = "REGISTER_NUMBER" | "USERNAME" | "EMAIL"
        auth.min_password_length    = "8"
        auth.require_uppercase      = "true"
        auth.require_digit          = "true"
        auth.require_special        = "false"
        auth.max_failed_attempts    = "5"
        auth.lock_duration_minutes  = "30"
        auth.session_days           = "7"
        auth.force_change_on_reset  = "true"
        auth.password_expiry_days   = "0"  (0 = disabled)
        ai.quantized_model          = "true"
        ai.recognition_threshold    = "0.45"
        ai.uncertain_threshold      = "0.60"
        ai.min_face_size_px         = "50"
        ai.image_quality_threshold  = "0.5"
        ai.performance_mode         = "BALANCED"  | "ACCURACY" | "SPEED"
    """
    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(100), unique=True, index=True, nullable=False)
    value = Column(Text, nullable=False)
    description = Column(String(500), nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc))
