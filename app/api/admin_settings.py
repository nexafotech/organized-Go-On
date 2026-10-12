"""
M4: Admin Settings API

Covers:
  - GET/PUT /admin/settings/auth        — Authentication configuration
  - GET/PUT /admin/settings/attendance-policy — Attendance policy engine config
  - GET/PUT /admin/settings/ai           — AI/recognition settings
  - GET     /admin/audit                — Paginated audit log viewer
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from app.core.database import get_db
from app.models.policy import AttendancePolicy, SystemSetting
from app.models.audit import AuditLog
from app.models.user import User
from app.schemas.policy import (
    AttendancePolicyOut, AttendancePolicyUpdate,
    AuthSettingsOut, AuthSettingsUpdate,
    AISettingsOut, AISettingsUpdate,
    SystemSettingOut, SystemSettingUpdate,
    AuditLogOut,
)
from app.api.deps import require_admin
from app.engines.policy_engine import get_active_policy
from app.core.datetime_utils import normalize_utc_datetime

router = APIRouter(
    prefix="/admin/settings",
    tags=["Admin Settings"],
    dependencies=[Depends(require_admin)]
)

audit_router = APIRouter(
    prefix="/admin/audit",
    tags=["Admin Audit"],
    dependencies=[Depends(require_admin)]
)


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

DEFAULT_AUTH_SETTINGS = {
    "auth.faculty_login_method": ("USERNAME", "Login identifier for faculty: USERNAME | FACULTY_ID | EMAIL"),
    "auth.student_login_method": ("REGISTER_NUMBER", "Login identifier for students: REGISTER_NUMBER | USERNAME | EMAIL"),
    "auth.min_password_length": ("8", "Minimum password length"),
    "auth.require_uppercase": ("true", "Require at least one uppercase letter"),
    "auth.require_digit": ("true", "Require at least one digit"),
    "auth.require_special": ("false", "Require at least one special character"),
    "auth.max_failed_attempts": ("5", "Max failed login attempts before lockout (0 = disabled)"),
    "auth.lock_duration_minutes": ("30", "Account lock duration in minutes"),
    "auth.session_days": ("7", "Session/token lifetime in days"),
    "auth.force_change_on_reset": ("true", "Force password change after admin reset"),
    "auth.password_expiry_days": ("0", "Password expiry in days (0 = never expires)"),
}

DEFAULT_AI_SETTINGS = {
    "ai.quantized_model": ("true", "Use quantized/mobile model (ON=quantized, OFF=full-precision)"),
    "ai.recognition_threshold": ("0.45", "Distance threshold for confident face match"),
    "ai.uncertain_threshold": ("0.60", "Distance threshold for uncertain face match"),
    "ai.min_face_size_px": ("50", "Minimum face bounding box size in pixels"),
    "ai.image_quality_threshold": ("0.5", "Minimum image quality score (0.0-1.0)"),
    "ai.performance_mode": ("BALANCED", "AI performance mode: BALANCED | ACCURACY | SPEED"),
}


def _get_or_create_setting(db: Session, key: str, default_value: str, description: str = "") -> SystemSetting:
    setting = db.query(SystemSetting).filter(SystemSetting.key == key).first()
    if not setting:
        setting = SystemSetting(key=key, value=default_value, description=description)
        db.add(setting)
        db.commit()
        db.refresh(setting)
    return setting


def _get_val(db: Session, key: str, default: str) -> str:
    s = db.query(SystemSetting).filter(SystemSetting.key == key).first()
    return s.value if s else default


def _set_val(db: Session, key: str, value: str, description: str = ""):
    setting = db.query(SystemSetting).filter(SystemSetting.key == key).first()
    if setting:
        setting.value = value
        setting.updated_at = datetime.now(timezone.utc)
    else:
        setting = SystemSetting(key=key, value=value, description=description)
        db.add(setting)
    db.commit()


def _ensure_defaults(db: Session, defaults: dict):
    """Ensure all default settings exist in the database."""
    for key, (default_val, description) in defaults.items():
        _get_or_create_setting(db, key, default_val, description)


# ─────────────────────────────────────────────────────────────────────────────
# Auth Settings
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/auth", response_model=AuthSettingsOut)
def get_auth_settings(db: Session = Depends(get_db)):
    """Get all authentication configuration settings."""
    _ensure_defaults(db, DEFAULT_AUTH_SETTINGS)
    return AuthSettingsOut(
        faculty_login_method=_get_val(db, "auth.faculty_login_method", "USERNAME"),
        student_login_method=_get_val(db, "auth.student_login_method", "REGISTER_NUMBER"),
        min_password_length=int(_get_val(db, "auth.min_password_length", "8")),
        require_uppercase=_get_val(db, "auth.require_uppercase", "true") == "true",
        require_digit=_get_val(db, "auth.require_digit", "true") == "true",
        require_special=_get_val(db, "auth.require_special", "false") == "true",
        max_failed_attempts=int(_get_val(db, "auth.max_failed_attempts", "5")),
        lock_duration_minutes=int(_get_val(db, "auth.lock_duration_minutes", "30")),
        session_days=int(_get_val(db, "auth.session_days", "7")),
        force_change_on_reset=_get_val(db, "auth.force_change_on_reset", "true") == "true",
        password_expiry_days=int(_get_val(db, "auth.password_expiry_days", "0")),
    )


@router.put("/auth", response_model=AuthSettingsOut)
def update_auth_settings(
    data: AuthSettingsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """Update authentication configuration settings."""
    updates = {}
    if data.faculty_login_method is not None:
        valid = ["USERNAME", "FACULTY_ID", "EMAIL"]
        if data.faculty_login_method not in valid:
            raise HTTPException(400, detail=f"faculty_login_method must be one of {valid}")
        updates["auth.faculty_login_method"] = data.faculty_login_method
    if data.student_login_method is not None:
        valid = ["REGISTER_NUMBER", "USERNAME", "EMAIL"]
        if data.student_login_method not in valid:
            raise HTTPException(400, detail=f"student_login_method must be one of {valid}")
        updates["auth.student_login_method"] = data.student_login_method
    if data.min_password_length is not None:
        updates["auth.min_password_length"] = str(data.min_password_length)
    if data.require_uppercase is not None:
        updates["auth.require_uppercase"] = "true" if data.require_uppercase else "false"
    if data.require_digit is not None:
        updates["auth.require_digit"] = "true" if data.require_digit else "false"
    if data.require_special is not None:
        updates["auth.require_special"] = "true" if data.require_special else "false"
    if data.max_failed_attempts is not None:
        updates["auth.max_failed_attempts"] = str(data.max_failed_attempts)
    if data.lock_duration_minutes is not None:
        updates["auth.lock_duration_minutes"] = str(data.lock_duration_minutes)
    if data.session_days is not None:
        updates["auth.session_days"] = str(data.session_days)
    if data.force_change_on_reset is not None:
        updates["auth.force_change_on_reset"] = "true" if data.force_change_on_reset else "false"
    if data.password_expiry_days is not None:
        updates["auth.password_expiry_days"] = str(data.password_expiry_days)

    for key, value in updates.items():
        _set_val(db, key, value)

    # Audit log
    log = AuditLog(
        user_id=current_user.id,
        action="UPDATE_AUTH_SETTINGS",
        details=f"Updated: {list(updates.keys())}",
    )
    db.add(log)
    db.commit()

    return get_auth_settings(db)


# ─────────────────────────────────────────────────────────────────────────────
# Attendance Policy
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/attendance-policy", response_model=AttendancePolicyOut)
def get_attendance_policy(db: Session = Depends(get_db)):
    """Get the active attendance policy configuration."""
    policy = get_active_policy(db)
    return policy


@router.put("/attendance-policy", response_model=AttendancePolicyOut)
def update_attendance_policy(
    data: AttendancePolicyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """Update the active attendance policy configuration."""
    policy = get_active_policy(db)

    valid_units = ["PERIOD", "HOUR"]
    valid_unmarked = ["PRESENT", "ABSENT", "NOT_ENTERED", "EXCLUDED"]
    valid_od_modes = ["COUNT_AS_PRESENT", "EXCLUDE_FROM_DENOMINATOR", "COUNT_SEPARATELY"]
    valid_leave = ["ABSENT", "EXCLUDED"]

    valid_calc_modes = ["RECORD_BASED", "IMPACT_BASED"]

    if data.calculation_unit is not None:
        if data.calculation_unit not in valid_units:
            raise HTTPException(400, detail=f"calculation_unit must be one of {valid_units}")
        policy.calculation_unit = data.calculation_unit
    if data.minimum_percentage is not None:
        policy.minimum_percentage = data.minimum_percentage
    if data.warning_threshold is not None:
        policy.warning_threshold = data.warning_threshold
    if data.critical_threshold is not None:
        policy.critical_threshold = data.critical_threshold
    if data.unmarked_behavior is not None:
        if data.unmarked_behavior not in valid_unmarked:
            raise HTTPException(400, detail=f"unmarked_behavior must be one of {valid_unmarked}")
        policy.unmarked_behavior = data.unmarked_behavior
    if data.exclude_no_class is not None:
        policy.exclude_no_class = data.exclude_no_class
    if data.exclude_suspended is not None:
        policy.exclude_suspended = data.exclude_suspended
    if data.exclude_timetable_not_set is not None:
        policy.exclude_timetable_not_set = data.exclude_timetable_not_set
    if data.od_enabled is not None:
        policy.od_enabled = data.od_enabled
    if data.od_faculty_can_mark is not None:
        policy.od_faculty_can_mark = data.od_faculty_can_mark
    if data.od_require_reason is not None:
        policy.od_require_reason = data.od_require_reason
    if data.od_require_approval is not None:
        policy.od_require_approval = data.od_require_approval
    if data.od_allow_retroactive is not None:
        policy.od_allow_retroactive = data.od_allow_retroactive
    if data.od_allow_multiple_periods is not None:
        policy.od_allow_multiple_periods = data.od_allow_multiple_periods
    if data.od_calculation_mode is not None:
        if data.od_calculation_mode not in valid_od_modes:
            raise HTTPException(400, detail=f"od_calculation_mode must be one of {valid_od_modes}")
        policy.od_calculation_mode = data.od_calculation_mode
    if data.leave_calculation_mode is not None:
        if data.leave_calculation_mode not in valid_leave:
            raise HTTPException(400, detail=f"leave_calculation_mode must be one of {valid_leave}")
        policy.leave_calculation_mode = data.leave_calculation_mode
    if "calculation_mode" in data.model_fields_set:
        if data.calculation_mode not in valid_calc_modes:
            raise HTTPException(400, detail=f"calculation_mode must be one of {valid_calc_modes}")
        policy.calculation_mode = data.calculation_mode

    # Validation helper for impact fields
    import math
    def _val_impact(name: str, val: Optional[float]):
        if val is not None:
            if math.isnan(val) or math.isinf(val):
                raise HTTPException(400, detail=f"{name} must be a valid finite number")
            if val < 0.0:
                raise HTTPException(400, detail=f"{name} cannot be negative")
            if val > 100.0:
                raise HTTPException(400, detail=f"{name} exceeds maximum allowable magnitude (100%)")
            return val
        return None

    if data.period_present_gain is not None:
        policy.period_present_gain = _val_impact("period_present_gain", data.period_present_gain)
    if data.period_absent_loss is not None:
        policy.period_absent_loss = _val_impact("period_absent_loss", data.period_absent_loss)
    if data.class_present_gain is not None:
        policy.class_present_gain = _val_impact("class_present_gain", data.class_present_gain)
    if data.class_absent_loss is not None:
        policy.class_absent_loss = _val_impact("class_absent_loss", data.class_absent_loss)
    if data.day_present_gain is not None:
        policy.day_present_gain = _val_impact("day_present_gain", data.day_present_gain)
    if data.day_absent_loss is not None:
        policy.day_absent_loss = _val_impact("day_absent_loss", data.day_absent_loss)

    if data.description is not None:
        policy.description = data.description

    db.commit()
    db.refresh(policy)

    # Audit log
    log = AuditLog(
        user_id=current_user.id,
        action="UPDATE_ATTENDANCE_POLICY",
        details=f"Policy ID {policy.id} updated",
    )
    db.add(log)
    db.commit()

    return policy


# ─────────────────────────────────────────────────────────────────────────────
# AI / Recognition Settings
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/ai", response_model=AISettingsOut)
def get_ai_settings(db: Session = Depends(get_db)):
    """
    Get AI/recognition configuration settings.
    quantized_model defaults to ON (True) — selects quantized vs full-precision model.
    """
    _ensure_defaults(db, DEFAULT_AI_SETTINGS)
    return AISettingsOut(
        quantized_model=_get_val(db, "ai.quantized_model", "true") == "true",
        recognition_threshold=float(_get_val(db, "ai.recognition_threshold", "0.45")),
        uncertain_threshold=float(_get_val(db, "ai.uncertain_threshold", "0.60")),
        min_face_size_px=int(_get_val(db, "ai.min_face_size_px", "50")),
        image_quality_threshold=float(_get_val(db, "ai.image_quality_threshold", "0.5")),
        performance_mode=_get_val(db, "ai.performance_mode", "BALANCED"),
    )


@router.put("/ai", response_model=AISettingsOut)
def update_ai_settings(
    data: AISettingsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """
    Update AI/recognition settings.
    quantized_model=false selects full-precision mode (higher memory/time cost).
    """
    if data.quantized_model is not None:
        _set_val(db, "ai.quantized_model", "true" if data.quantized_model else "false")
    if data.recognition_threshold is not None:
        _set_val(db, "ai.recognition_threshold", str(data.recognition_threshold))
    if data.uncertain_threshold is not None:
        _set_val(db, "ai.uncertain_threshold", str(data.uncertain_threshold))
    if data.min_face_size_px is not None:
        _set_val(db, "ai.min_face_size_px", str(data.min_face_size_px))
    if data.image_quality_threshold is not None:
        _set_val(db, "ai.image_quality_threshold", str(data.image_quality_threshold))
    if data.performance_mode is not None:
        valid = ["BALANCED", "ACCURACY", "SPEED"]
        if data.performance_mode not in valid:
            raise HTTPException(400, detail=f"performance_mode must be one of {valid}")
        _set_val(db, "ai.performance_mode", data.performance_mode)

    log = AuditLog(
        user_id=current_user.id,
        action="UPDATE_AI_SETTINGS",
        details="AI settings updated",
    )
    db.add(log)
    db.commit()

    return get_ai_settings(db)


# ─────────────────────────────────────────────────────────────────────────────
# Audit Log Viewer
# ─────────────────────────────────────────────────────────────────────────────

@audit_router.get("", response_model=List[AuditLogOut])
def get_audit_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    action: Optional[str] = Query(None, description="Filter by action type"),
    db: Session = Depends(get_db)
):
    """Paginated audit log viewer for admins."""
    query = db.query(AuditLog)
    if action:
        query = query.filter(AuditLog.action == action.upper())
    logs = query.order_by(AuditLog.timestamp.desc()).offset(skip).limit(limit).all()

    result = []
    for log in logs:
        actor = log.user.username if log.user else "system"
        result.append(AuditLogOut(
            id=log.id,
            actor=actor,
            action=log.action,
            target=None,
            details=log.details,
            ip_address=log.ip_address,
            timestamp=normalize_utc_datetime(log.timestamp).isoformat() if log.timestamp else None,
        ))
    return result
