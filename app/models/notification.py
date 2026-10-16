import enum
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Index
from sqlalchemy.orm import relationship
from app.core.database import Base


class NotificationType(str, enum.Enum):
    NEXT_CLASS_STUDENT = "NEXT_CLASS_STUDENT"
    NEXT_CLASS_FACULTY = "NEXT_CLASS_FACULTY"
    ATTENDANCE = "ATTENDANCE"
    ACCOUNT = "ACCOUNT"
    ADMIN = "ADMIN"
    GENERAL = "GENERAL"


class NotificationChannel(str, enum.Enum):
    GO_ON_NEXT_CLASS = "GO_ON_NEXT_CLASS"
    GO_ON_ATTENDANCE = "GO_ON_ATTENDANCE"
    GO_ON_ACCOUNT = "GO_ON_ACCOUNT"
    GO_ON_ADMIN = "GO_ON_ADMIN"
    GO_ON_GENERAL = "GO_ON_GENERAL"


class NotificationDeliveryStatus(str, enum.Enum):
    SENT = "SENT"
    STORED = "STORED"
    SIMULATED = "SIMULATED"
    PROVIDER_ACCEPTED = "PROVIDER_ACCEPTED"
    FAILED = "FAILED"
    SKIPPED = "SKIPPED"
    # Truthful statuses (honest audit reporting)
    FCM_ACCEPTED = "FCM_ACCEPTED"
    NO_TOKEN = "NO_TOKEN"
    RECORDED = "RECORDED"
    DELIVERY_CONFIRMED = "DELIVERY_CONFIRMED"
    PARTIAL_FAILURE = "PARTIAL_FAILURE"


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token = Column(String(512), nullable=False, index=True)
    platform = Column(String(20), default="android", nullable=False)  # android, ios, web
    device_name = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user = relationship("User", backref="device_tokens")

    __table_args__ = (
        Index("ix_device_token_user_active", "user_id", "is_active"),
    )


class NotificationLog(Base):
    __tablename__ = "notification_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    notification_type = Column(String(50), nullable=False)
    channel_id = Column(String(50), nullable=False, default=NotificationChannel.GO_ON_GENERAL.value)
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=False)
    data_payload = Column(Text, nullable=True)  # JSON string
    reference_date = Column(String(10), nullable=True)  # YYYY-MM-DD (Asia/Kolkata)
    period_id = Column(Integer, nullable=True)
    timetable_entry_id = Column(Integer, nullable=True)
    status = Column(String(20), default=NotificationDeliveryStatus.SENT.value, nullable=False)
    error_message = Column(Text, nullable=True)
    is_read = Column(Boolean, default=False, nullable=False, index=True)
    read_at = Column(DateTime, nullable=True)
    is_pinned = Column(Boolean, default=False, nullable=False, index=True)
    pinned_at = Column(DateTime, nullable=True)
    is_deleted = Column(Boolean, default=False, nullable=False, index=True)
    deleted_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)

    user = relationship("User", backref="notification_logs")

    __table_args__ = (
        Index("ix_notif_log_idempotency", "user_id", "notification_type", "reference_date", "timetable_entry_id"),
        Index("ix_notif_log_user_read", "user_id", "is_read"),
        Index("ix_notif_log_user_deleted", "user_id", "is_deleted"),
        Index("ix_notif_log_user_pinned", "user_id", "is_pinned"),
    )


class ScheduledNotification(Base):
    __tablename__ = "scheduled_notifications"

    id = Column(Integer, primary_key=True, index=True)
    admin_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    audience = Column(String(20), nullable=False)  # STUDENT, FACULTY, ALL
    target_type = Column(String(20), nullable=False)  # ALL, CLASS, USER
    target_id = Column(String(100), nullable=True)
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=False)
    channel = Column(String(50), nullable=False, default=NotificationChannel.GO_ON_ADMIN.value)
    priority = Column(String(20), nullable=False, default="NORMAL")
    route = Column(String(100), nullable=True)
    scheduled_at = Column(DateTime, nullable=False, index=True)
    status = Column(String(20), default="PENDING", nullable=False)  # PENDING, SENT, CANCELLED, FAILED
    recipients_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    admin = relationship("User", backref="scheduled_notifications")
