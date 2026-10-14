import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import get_db, SessionLocal
from app.core.config import settings, Settings
from app.core.security import get_password_hash, create_access_token
from app.models.user import User, UserRole

client = TestClient(app)

@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def test_logout_invalidates_session_token(db_session: Session):
    """
    Verifies that calling /auth/logout marks user.session_token as REVOKED
    and that subsequent calls with the previously valid token return 401 Unauthorized.
    """
    # 1. Create a test faculty user
    username = f"audit_fac_{datetime.now(timezone.utc).timestamp()}"
    raw_password = "SecurePassword123!"
    hashed = get_password_hash(raw_password)
    user = User(
        username=username,
        email=f"{username}@example.com",
        hashed_password=hashed,
        role=UserRole.FACULTY,
        is_active=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    # 2. Log in
    login_resp = client.post("/api/v1/auth/login", json={
        "username_or_email": username,
        "password": raw_password
    })
    assert login_resp.status_code == 200, login_resp.text
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 3. Verify token works
    me_resp = client.get("/api/v1/auth/me", headers=headers)
    assert me_resp.status_code == 200
    assert me_resp.json()["username"] == username

    # 4. Perform logout
    logout_resp = client.post("/api/v1/auth/logout", headers=headers)
    assert logout_resp.status_code == 200
    assert logout_resp.json()["message"] == "Successfully logged out"

    # 5. Verify database state
    db_session.refresh(user)
    assert user.session_token == "REVOKED"

    # 6. Verify subsequent request with same token is REJECTED
    subsequent_resp = client.get("/api/v1/auth/me", headers=headers)
    assert subsequent_resp.status_code == 401
    assert "revoked" in subsequent_resp.json()["detail"].lower()


def test_password_change_invalidates_pre_existing_tokens(db_session: Session):
    """
    Verifies that administrative password reset or password change invalidates pre-existing
    session tokens issued prior to password_changed_at.
    """
    username = f"audit_pwd_{datetime.now(timezone.utc).timestamp()}"
    raw_password = "OldPassword123!"
    hashed = get_password_hash(raw_password)
    user = User(
        username=username,
        email=f"{username}@example.com",
        hashed_password=hashed,
        role=UserRole.FACULTY,
        is_active=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    # 1. Log in to get active session
    login_resp = client.post("/api/v1/auth/login", json={
        "username_or_email": username,
        "password": raw_password
    })
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Simulate administrative password reset
    db_session.refresh(user)
    user.hashed_password = get_password_hash("AdminResetNewPassword789!")
    user.session_token = None
    user.password_changed_at = datetime.now(timezone.utc)
    db_session.commit()

    # 3. Pre-existing token must now be rejected
    rejected_resp = client.get("/api/v1/auth/me", headers=headers)
    assert rejected_resp.status_code == 401
    assert "password was changed" in rejected_resp.json()["detail"].lower()


def test_cors_rejects_untrusted_origins():
    """
    Verifies that CORSMiddleware does not reflect arbitrary untrusted origins when credentials are used,
    while permitting explicitly allowed origins like localhost:3000.
    """
    # 1. Untrusted origin
    untrusted_resp = client.options("/api/v1/auth/me", headers={
        "Origin": "https://malicious-attacker.evil",
        "Access-Control-Request-Method": "GET"
    })
    # Untrusted origin should NOT have Access-Control-Allow-Origin: https://malicious-attacker.evil
    assert untrusted_resp.headers.get("access-control-allow-origin") != "https://malicious-attacker.evil"

    # 2. Trusted origin
    trusted_resp = client.options("/api/v1/auth/me", headers={
        "Origin": "http://localhost:3000",
        "Access-Control-Request-Method": "GET"
    })
    assert trusted_resp.headers.get("access-control-allow-origin") == "http://localhost:3000"
    assert trusted_resp.headers.get("access-control-allow-credentials") == "true"


def test_production_secret_key_safeguard():
    """
    Verifies that settings.validate_production_configuration() halts with a RuntimeError
    if ENVIRONMENT is production and the default dev secret key is detected.
    """
    test_settings = Settings()
    test_settings.ENVIRONMENT = "production"
    test_settings.SECRET_KEY = test_settings._DEFAULT_DEV_SECRET

    with pytest.raises(RuntimeError) as exc_info:
        test_settings.validate_production_configuration()

    assert "FATAL CONFIGURATION ERROR" in str(exc_info.value)
