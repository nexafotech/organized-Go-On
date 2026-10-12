"""
Failsafe verification script: Runs single account test before full rotation.
"""
import os
import sys
import json
import secrets
import string
import urllib.request
import urllib.error

sys.path.insert(0, os.path.abspath("."))

from app.core.database import SessionLocal
from app.models.user import User, UserRole
from app.models.student import Student
from app.core.security import get_password_hash

BASE_URL = "http://127.0.0.1:8000"

def generate_strong_password(length: int = 14) -> str:
    safe_symbols = "!@#$%^&*"
    chars = string.ascii_letters + string.digits + safe_symbols
    pwd = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice(safe_symbols),
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice(safe_symbols),
    ]
    pwd += [secrets.choice(chars) for _ in range(length - len(pwd))]
    secrets.SystemRandom().shuffle(pwd)
    return "".join(pwd)

def http_post(endpoint: str, payload: dict, token: str = None):
    url = f"{BASE_URL}{endpoint}"
    data_bytes = json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data_bytes, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode("utf-8")
            return resp.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            parsed = json.loads(body)
        except Exception:
            parsed = {"detail": body}
        return e.code, parsed

def http_get(endpoint: str, token: str = None):
    url = f"{BASE_URL}{endpoint}"
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode("utf-8")
            return resp.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            parsed = json.loads(body)
        except Exception:
            parsed = {"detail": body}
        return e.code, parsed

def run_failsafe():
    db = SessionLocal()
    st = db.query(Student).filter(Student.roll_number == "721025149060").first()
    u = st.user
    orig_hash = u.hashed_password
    orig_fpc = u.force_password_change

    print("[FAILSAFE] Testing single account rotation flow...")
    test_pw = generate_strong_password(14)
    assert len(test_pw) == 14
    assert any(c.isupper() for c in test_pw)
    assert any(c.islower() for c in test_pw)
    assert any(c.isdigit() for c in test_pw)
    assert any(c in "!@#$%^&*" for c in test_pw)

    # Reset
    u.hashed_password = get_password_hash(test_pw)
    u.force_password_change = True
    u.failed_login_attempts = 0
    u.locked_until = None
    u.session_token = None
    db.commit()

    # Login
    status, login_res = http_post(
        "/api/v1/auth/student/login",
        {"identifier": st.roll_number, "password": test_pw}
    )
    assert status == 200, f"Login failed: {status} {login_res}"
    assert login_res.get("force_password_change") is True
    tok = login_res.get("access_token")

    # Profile
    status, me_res = http_get("/api/v1/auth/me", token=tok)
    assert status == 200
    assert me_res.get("force_password_change") is True

    # Change password
    new_pw = generate_strong_password(14)
    status, ch_res = http_post(
        "/api/v1/auth/change-password",
        {"current_password": test_pw, "new_password": new_pw, "confirm_password": new_pw},
        token=tok
    )
    assert status == 200
    assert ch_res.get("force_password_change") is False

    # Old pw fails
    status, old_res = http_post(
        "/api/v1/auth/student/login",
        {"identifier": st.roll_number, "password": test_pw}
    )
    assert status == 401

    # New pw succeeds
    status, new_res = http_post(
        "/api/v1/auth/student/login",
        {"identifier": st.roll_number, "password": new_pw}
    )
    assert status == 200

    # Revert
    u.hashed_password = orig_hash
    u.force_password_change = orig_fpc
    u.failed_login_attempts = 0
    u.locked_until = None
    u.session_token = None
    db.commit()
    db.close()

    print("[FAILSAFE] Single account rotation flow PASSED completely.")

if __name__ == "__main__":
    run_failsafe()
