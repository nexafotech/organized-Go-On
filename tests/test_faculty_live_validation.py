import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_validate_faculty_valid_username():
    """Verify faculty username is recognized as valid FACULTY."""
    res = client.post(
        "/api/v1/auth/validate-identifier",
        json={"identifier": "fac01", "role": "FACULTY"}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["valid"] is True
    assert data["role"] == "FACULTY"
    assert data["message"] == "Faculty account recognized"
    # Ensure no sensitive fields exposed
    assert "hashed_password" not in data
    assert "id" not in data
    assert "session_token" not in data

def test_validate_faculty_valid_employee_id():
    """Verify faculty employee ID (e.g. FAC01) is recognized as valid FACULTY."""
    res = client.post(
        "/api/v1/auth/validate-identifier",
        json={"identifier": "FAC01", "role": "FACULTY"}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["valid"] is True
    assert data["role"] == "FACULTY"
    assert data["message"] == "Faculty account recognized"

def test_validate_faculty_valid_email():
    """Verify faculty email is recognized as valid FACULTY."""
    res = client.post(
        "/api/v1/auth/validate-identifier",
        json={"identifier": "fac01@college.edu", "role": "FACULTY"}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["valid"] is True
    assert data["role"] == "FACULTY"

def test_validate_faculty_case_insensitivity():
    """Verify identifier check is case-insensitive (e.g. FaC01, fac01, FAC01)."""
    for id_val in ["FaC01", "fac01", "FAC01"]:
        res = client.post(
            "/api/v1/auth/validate-identifier",
            json={"identifier": id_val, "role": "FACULTY"}
        )
        assert res.status_code == 200
        assert res.json()["valid"] is True

def test_validate_faculty_rejects_student_roll_number():
    """Role-aware check: Student roll numbers MUST NOT be accepted as faculty."""
    for student_id in ["721025149001", "721025149061", "721024149001"]:
        res = client.post(
            "/api/v1/auth/validate-identifier",
            json={"identifier": student_id, "role": "FACULTY"}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["valid"] is False
        assert data["role"] == "FACULTY"
        assert data["message"] == "Invalid faculty username"

def test_validate_faculty_rejects_admin():
    """Role-aware check: Admin username MUST NOT be accepted as faculty."""
    res = client.post(
        "/api/v1/auth/validate-identifier",
        json={"identifier": "admin", "role": "FACULTY"}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["valid"] is False
    assert data["role"] == "FACULTY"

def test_validate_faculty_rejects_nonexistent():
    """Verify nonexistent accounts return valid: False."""
    res = client.post(
        "/api/v1/auth/validate-identifier",
        json={"identifier": "nonexistent_faculty_xyz", "role": "FACULTY"}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["valid"] is False
    assert data["role"] == "FACULTY"

def test_validate_empty_identifier():
    """Verify empty identifier returns valid: False."""
    res = client.post(
        "/api/v1/auth/validate-identifier",
        json={"identifier": "   ", "role": "FACULTY"}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["valid"] is False
