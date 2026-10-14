from sqlalchemy import create_engine, event
from sqlalchemy.orm import declarative_base, sessionmaker
from app.core.config import settings

connect_args = {"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {}

engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
    echo=False
)

# Enable SQLite foreign key constraints
if "sqlite" in settings.DATABASE_URL:
    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def init_db(bind_engine=engine):
    """
    Initializes the database schema and performs lightweight migrations
    for SQLite/Postgres to ensure schema consistency.
    """
    from sqlalchemy import text, inspect
    import app.models  # Ensure all model tables are attached to Base.metadata
    Base.metadata.create_all(bind=bind_engine)
    
    # Check for missing columns in existing SQLite tables
    try:
        inspector = inspect(bind_engine)
        tables = inspector.get_table_names()
        if "timetable_entries" in tables:
            columns = [c["name"] for c in inspector.get_columns("timetable_entries")]
            if "room" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE timetable_entries ADD COLUMN room VARCHAR(50)"))
                    conn.commit()
        if "users" in tables:
            columns = [c["name"] for c in inspector.get_columns("users")]
            if "password_changed_at" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN password_changed_at DATETIME"))
                    conn.commit()
            if "password_change_window_id" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN password_change_window_id INTEGER"))
                    conn.commit()
        if "attendance_policies" in tables:
            with bind_engine.connect() as conn:
                conn.execute(text("UPDATE attendance_policies SET calculation_mode = 'RECORD_BASED' WHERE calculation_mode IS NULL OR calculation_mode NOT IN ('RECORD_BASED', 'IMPACT_BASED')"))
                conn.commit()
        if "class_sections" in tables:
            columns = [c["name"] for c in inspector.get_columns("class_sections")]
            if "class_advisor_id" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE class_sections ADD COLUMN class_advisor_id INTEGER REFERENCES faculty(id)"))
                    conn.commit()
        if "attendance_records" in tables:
            columns = [c["name"] for c in inspector.get_columns("attendance_records")]
            if "updated_at" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE attendance_records ADD COLUMN updated_at DATETIME"))
                    conn.commit()
        if "periods" in tables:
            with bind_engine.connect() as conn:
                conn.execute(text("UPDATE periods SET start_time = '12:00', end_time = '12:50' WHERE period_number = 4 AND (start_time != '12:00' OR end_time != '12:50')"))
                conn.commit()
        if "notification_logs" in tables:
            columns = [c["name"] for c in inspector.get_columns("notification_logs")]
            if "is_read" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE notification_logs ADD COLUMN is_read BOOLEAN DEFAULT 0 NOT NULL"))
                    conn.commit()
            if "read_at" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE notification_logs ADD COLUMN read_at DATETIME"))
                    conn.commit()
            if "is_pinned" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE notification_logs ADD COLUMN is_pinned BOOLEAN DEFAULT 0 NOT NULL"))
                    conn.commit()
            if "pinned_at" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE notification_logs ADD COLUMN pinned_at DATETIME"))
                    conn.commit()
            if "is_deleted" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE notification_logs ADD COLUMN is_deleted BOOLEAN DEFAULT 0 NOT NULL"))
                    conn.commit()
            if "deleted_at" not in columns:
                with bind_engine.connect() as conn:
                    conn.execute(text("ALTER TABLE notification_logs ADD COLUMN deleted_at DATETIME"))
                    conn.commit()
    except Exception as e:
        print(f"[DB] Schema migration check notice: {e}")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

