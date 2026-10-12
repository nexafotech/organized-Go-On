from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field, field_validator


class DeviceTokenCreate(BaseModel):
    token: str = Field(..., min_length=10, max_length=512, description="FCM device registration token")
    platform: str = Field(default="android", max_length=20, description="Client platform: android, ios, web")
    device_name: Optional[str] = Field(default=None, max_length=100, description="Device model or name")


class DeviceTokenOut(BaseModel):
    id: int
    user_id: int
    token: str
    platform: str
    device_name: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class NotificationSettingsOut(BaseModel):
    student_next_class_enabled: bool = True
    student_next_class_lead_minutes: int = 10
    faculty_next_class_enabled: bool = True
    faculty_next_class_lead_minutes: int = 15
    attendance_status_enabled: bool = True
    admin_announcements_enabled: bool = True


class NotificationSettingsUpdate(BaseModel):
    student_next_class_enabled: Optional[bool] = None
    student_next_class_lead_minutes: Optional[int] = Field(default=None, ge=1, le=120)
    faculty_next_class_enabled: Optional[bool] = None
    faculty_next_class_lead_minutes: Optional[int] = Field(default=None, ge=1, le=120)
    attendance_status_enabled: Optional[bool] = None
    admin_announcements_enabled: Optional[bool] = None

    @field_validator("student_next_class_lead_minutes", "faculty_next_class_lead_minutes")
    @classmethod
    def validate_lead_minutes(cls, v):
        if v is not None and (v < 1 or v > 120):
            raise ValueError("Lead time must be between 1 and 120 minutes")
        return v


class AdminCustomNotificationCreate(BaseModel):
    audience: str = Field(..., description="Target audience: STUDENT, FACULTY, ALL")
    target_type: str = Field(default="ALL", description="Target scope: ALL, CLASS, USER")
    target_id: Optional[str] = Field(default=None, description="Class ID or User ID/identifier")
    channel: str = Field(default="GO_ON_ADMIN", description="Channel: GO_ON_ADMIN, GO_ON_GENERAL, GO_ON_ATTENDANCE, GO_ON_NEXT_CLASS")
    priority: str = Field(default="NORMAL", description="Priority level: NORMAL, HIGH")
    title: str = Field(..., min_length=1, max_length=200, description="Notification title")
    body: str = Field(..., min_length=1, max_length=1000, description="Notification body")
    route: Optional[str] = Field(default=None, description="Safe deep link internal route")
    scheduled_at: Optional[datetime] = Field(default=None, description="Scheduled delivery timestamp (Asia/Kolkata)")

    @field_validator("audience")
    @classmethod
    def validate_audience(cls, v):
        allowed = {"STUDENT", "FACULTY", "ALL"}
        v_upper = v.strip().upper()
        if v_upper not in allowed:
            raise ValueError(f"Audience must be one of {allowed}")
        return v_upper

    @field_validator("target_type")
    @classmethod
    def validate_target_type(cls, v):
        allowed = {"ALL", "CLASS", "USER"}
        v_upper = v.strip().upper()
        if v_upper not in allowed:
            raise ValueError(f"Target type must be one of {allowed}")
        return v_upper

    @field_validator("priority")
    @classmethod
    def validate_priority(cls, v):
        allowed = {"NORMAL", "HIGH"}
        v_upper = v.strip().upper()
        if v_upper not in allowed:
            raise ValueError(f"Priority must be one of {allowed}")
        return v_upper


class AdminCustomNotificationResponse(BaseModel):
    success: bool
    recipients_count: int
    notification_type: str
    channel: str
    title: str
    body: str
    status: str
    message: str
    scheduled_at: Optional[datetime] = None


class NotificationLogOut(BaseModel):
    id: int
    user_id: int
    notification_type: str
    channel_id: str
    title: str
    body: str
    data_payload: Optional[str] = None
    reference_date: Optional[str] = None
    period_id: Optional[int] = None
    timetable_entry_id: Optional[int] = None
    status: str
    error_message: Optional[str] = None
    is_read: bool = False
    read_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class UnreadCountOut(BaseModel):
    unread_count: int


class NotificationActionResponse(BaseModel):
    success: bool
    id: Optional[int] = None
    count: Optional[int] = None
    message: str


class NextClassReminderCheckResult(BaseModel):
    date: str
    current_time: str
    timezone: str = "Asia/Kolkata"
    student_reminders_sent: int
    faculty_reminders_sent: int
    student_reminders_skipped: int
    faculty_reminders_skipped: int
    details: List[Dict[str, Any]] = []


class ScheduledNotificationOut(BaseModel):
    id: int
    admin_id: Optional[int] = None
    audience: str
    target_type: str
    target_id: Optional[str] = None
    title: str
    body: str
    channel: str
    priority: str
    route: Optional[str] = None
    scheduled_at: datetime
    status: str
    recipients_count: int
    created_at: datetime

    class Config:
        from_attributes = True
