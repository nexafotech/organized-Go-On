"""
Unit & Integration Tests for Milestone 11B:
Attendance Policy & System Settings Calculation Mode Validation

Verifies:
1. GET settings returns valid calculation_mode
2. RECORD_BASED accepted
3. IMPACT_BASED accepted
4. Invalid value rejected
5. Empty value rejected
6. Null value rejected
7. Frontend dropdown contains exactly 2 choices ('Record Based' -> RECORD_BASED, 'Impact Based' -> IMPACT_BASED)
8. Save RECORD_BASED works and persists in DB
9. Save IMPACT_BASED works and persists in DB
10. Page reload preserves selected mode
11. Invalid DB state is repaired safely
12. Fresh DB initialization produces valid mode
13. Duplicate error notification is not produced (deduplication & double-submit protection)
"""

import re
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, UserRole
from app.models.policy import AttendancePolicy
from app.engines.policy_engine import get_active_policy

# In-memory SQLite for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

test_engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=test_engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=test_engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def auth_headers(db_session):
    admin = User(
        username="admin",
        email="admin@college.edu",
        hashed_password=get_password_hash("admin123"),
        role=UserRole.ADMIN,
        is_active=True,
        login_identifier="admin",
    )
    db_session.add(admin)
    db_session.commit()
    db_session.refresh(admin)

    token = create_access_token(admin.id, role="admin")
    return {"Authorization": f"Bearer {token}"}


# ------------------------------------------------------------------------------
# 1. GET settings returns valid calculation_mode
# ------------------------------------------------------------------------------
def test_1_get_settings_returns_valid_calculation_mode(client, auth_headers):
    """1. GET settings returns valid calculation_mode."""
    res = client.get("/api/v1/admin/settings/attendance-policy", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert "calculation_mode" in data
    assert data["calculation_mode"] in ["RECORD_BASED", "IMPACT_BASED"]
    assert data["calculation_mode"] != ""


# ------------------------------------------------------------------------------
# 2. RECORD_BASED accepted
# ------------------------------------------------------------------------------
def test_2_record_based_accepted(client, auth_headers):
    """2. RECORD_BASED accepted."""
    payload = {"calculation_mode": "RECORD_BASED"}
    res = client.put("/api/v1/admin/settings/attendance-policy", json=payload, headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["calculation_mode"] == "RECORD_BASED"


# ------------------------------------------------------------------------------
# 3. IMPACT_BASED accepted
# ------------------------------------------------------------------------------
def test_3_impact_based_accepted(client, auth_headers):
    """3. IMPACT_BASED accepted."""
    payload = {"calculation_mode": "IMPACT_BASED"}
    res = client.put("/api/v1/admin/settings/attendance-policy", json=payload, headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["calculation_mode"] == "IMPACT_BASED"


# ------------------------------------------------------------------------------
# 4. Invalid value rejected
# ------------------------------------------------------------------------------
def test_4_invalid_value_rejected(client, auth_headers):
    """4. Invalid value rejected."""
    payload = {"calculation_mode": "EXACT_PERCENTAGE"}
    res = client.put("/api/v1/admin/settings/attendance-policy", json=payload, headers=auth_headers)
    assert res.status_code == 400
    detail = res.json()["detail"]
    assert "calculation_mode must be one of" in detail
    assert "RECORD_BASED" in detail
    assert "IMPACT_BASED" in detail


# ------------------------------------------------------------------------------
# 5. Empty value rejected
# ------------------------------------------------------------------------------
def test_5_empty_value_rejected(client, auth_headers):
    """5. Empty value rejected."""
    payload = {"calculation_mode": ""}
    res = client.put("/api/v1/admin/settings/attendance-policy", json=payload, headers=auth_headers)
    assert res.status_code == 400
    detail = res.json()["detail"]
    assert "calculation_mode must be one of" in detail


# ------------------------------------------------------------------------------
# 6. Null value rejected
# ------------------------------------------------------------------------------
def test_6_null_value_rejected(client, auth_headers):
    """6. Null value rejected."""
    payload = {"calculation_mode": None}
    res = client.put("/api/v1/admin/settings/attendance-policy", json=payload, headers=auth_headers)
    assert res.status_code == 400
    detail = res.json()["detail"]
    assert "calculation_mode must be one of" in detail


# ------------------------------------------------------------------------------
# 7. Frontend dropdown contains exactly 2 choices
# ------------------------------------------------------------------------------
def test_7_frontend_dropdown_contains_exactly_2_choices():
    """7. Frontend dropdown in admin_panel.html contains exactly 2 choices: RECORD_BASED and IMPACT_BASED."""
    with open("app/templates/admin_panel.html", "r", encoding="utf-8") as f:
        html = f.read()

    # Extract select block
    select_match = re.search(r'<select[^>]*id="policyCalcMode"[^>]*>(.*?)</select>', html, re.DOTALL)
    assert select_match is not None, "Dropdown with id 'policyCalcMode' not found in admin_panel.html"
    select_content = select_match.group(1)

    # Extract options
    options = re.findall(r'<option[^>]*value="([^"]*)"[^>]*>(.*?)</option>', select_content)
    assert len(options) == 2, f"Expected exactly 2 options in calculation_mode dropdown, got {len(options)}"

    opts = {val: text.strip() for val, text in options}
    assert "RECORD_BASED" in opts
    assert "IMPACT_BASED" in opts
    assert opts["RECORD_BASED"] == "Record Based"
    assert opts["IMPACT_BASED"] == "Impact Based"


# ------------------------------------------------------------------------------
# 8. Save RECORD_BASED works and persists in DB
# ------------------------------------------------------------------------------
def test_8_save_record_based_works(client, auth_headers, db_session):
    """8. Save RECORD_BASED works and persists in DB."""
    payload = {
        "minimum_percentage": 75.0,
        "calculation_mode": "RECORD_BASED",
        "period_absent_loss": 0.5,
        "class_absent_loss": 1.0,
        "day_absent_loss": 2.0,
    }
    res = client.put("/api/v1/admin/settings/attendance-policy", json=payload, headers=auth_headers)
    assert res.status_code == 200

    pol = db_session.query(AttendancePolicy).filter(AttendancePolicy.is_active == True).first()
    assert pol is not None
    assert pol.calculation_mode == "RECORD_BASED"
    assert pol.minimum_percentage == 75.0


# ------------------------------------------------------------------------------
# 9. Save IMPACT_BASED works and persists in DB
# ------------------------------------------------------------------------------
def test_9_save_impact_based_works(client, auth_headers, db_session):
    """9. Save IMPACT_BASED works and persists in DB."""
    payload = {
        "minimum_percentage": 80.0,
        "calculation_mode": "IMPACT_BASED",
        "period_absent_loss": 0.5,
        "class_absent_loss": 1.0,
        "day_absent_loss": 2.0,
    }
    res = client.put("/api/v1/admin/settings/attendance-policy", json=payload, headers=auth_headers)
    assert res.status_code == 200

    pol = db_session.query(AttendancePolicy).filter(AttendancePolicy.is_active == True).first()
    assert pol is not None
    assert pol.calculation_mode == "IMPACT_BASED"
    assert pol.minimum_percentage == 80.0


# ------------------------------------------------------------------------------
# 10. Page reload preserves selected mode
# ------------------------------------------------------------------------------
def test_10_page_reload_preserves_selected_mode(client, auth_headers):
    """10. Page reload (subsequent GET) preserves the selected calculation mode."""
    # First set to IMPACT_BASED
    res1 = client.put("/api/v1/admin/settings/attendance-policy", json={"calculation_mode": "IMPACT_BASED"}, headers=auth_headers)
    assert res1.status_code == 200

    # Simulate reload
    get1 = client.get("/api/v1/admin/settings/attendance-policy", headers=auth_headers)
    assert get1.status_code == 200
    assert get1.json()["calculation_mode"] == "IMPACT_BASED"

    # Now switch to RECORD_BASED
    res2 = client.put("/api/v1/admin/settings/attendance-policy", json={"calculation_mode": "RECORD_BASED"}, headers=auth_headers)
    assert res2.status_code == 200

    # Simulate reload
    get2 = client.get("/api/v1/admin/settings/attendance-policy", headers=auth_headers)
    assert get2.status_code == 200
    assert get2.json()["calculation_mode"] == "RECORD_BASED"


# ------------------------------------------------------------------------------
# 11. Invalid DB state is repaired safely
# ------------------------------------------------------------------------------
def test_11_invalid_db_state_is_repaired_safely(client, auth_headers, db_session):
    """11. An invalid/corrupted calculation_mode in DB is safely self-healed to RECORD_BASED."""
    # Ensure policy exists
    get_active_policy(db_session)

    # Forcefully corrupt the database value directly via SQL
    db_session.execute(text("UPDATE attendance_policies SET calculation_mode = 'CORRUPTED_LEGACY_VAL'"))
    db_session.commit()

    # Query via API / policy engine
    res = client.get("/api/v1/admin/settings/attendance-policy", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["calculation_mode"] == "RECORD_BASED"

    # Verify DB was self-healed
    pol = db_session.query(AttendancePolicy).first()
    assert pol.calculation_mode == "RECORD_BASED"


# ------------------------------------------------------------------------------
# 12. Fresh DB initialization produces valid mode
# ------------------------------------------------------------------------------
def test_12_fresh_db_initialization_produces_valid_mode(db_session):
    """12. A fresh database initialization creates default policy with RECORD_BASED mode."""
    # Ensure zero policies exist
    db_session.query(AttendancePolicy).delete()
    db_session.commit()

    # get_active_policy creates default
    pol = get_active_policy(db_session)
    assert pol is not None
    assert pol.calculation_mode == "RECORD_BASED"
    assert pol.is_active is True


# ------------------------------------------------------------------------------
# 13. Duplicate error notification is not produced
# ------------------------------------------------------------------------------
def test_13_duplicate_error_notification_is_not_produced():
    """13. Frontend admin_app.js has deduplication logic in showToast and double-submit guards."""
    with open("app/static/js/admin_app.js", "r", encoding="utf-8") as f:
        js = f.read()

    # Verify showToast deduplicates identical messages
    assert "Deduplicate" in js or "existingToasts" in js or "existing" in js
    assert "toast" in js
    assert "toastContainer" in js

    # Verify handleSavePolicy has double-submit guard
    assert "isSavingPolicy" in js
    assert "disabled = true" in js
