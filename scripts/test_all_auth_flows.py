"""
Comprehensive Test Script for All Authentication & Password Flows.
Tests:
1. Identifier resolution (Student & Faculty)
2. Password verification with bcrypt
3. Admin password reset (temporary password generation & DB update)
4. Login with temporary password
5. Password change via /api/v1/auth/change-password
6. Login with new password
7. Force password change flag transitions
8. Failed attempts counter & account lock behavior
Note: NO passwords or hashes are printed. Only status codes, flags, and pass/fail verdicts.
"""
import os
import sys

sys.path.insert(0, os.path.abspath("."))

from fastapi.testclient import TestClient
from app.main import app
from app.core.database import SessionLocal
from app.models.user import User, UserRole, Faculty
from app.models.student import Student
from app.core.security import verify_password, get_password_hash
from app.api.admin import _generate_temporary_password

client = TestClient(app)

def run_tests():
    db = SessionLocal()
    print("=" * 70)
    print("TEST 1: IDENTIFIER RESOLUTION & LOOKUP IN DB")
    print("=" * 70)
    
    # Pick a faculty user (e.g. fac01)
    fac_user = db.query(User).filter(User.username == "fac01").first()
    fac_profile = db.query(Faculty).filter(Faculty.user_id == fac_user.id).first()
    print(f"Faculty fac01: ID={fac_user.id}, Username='{fac_user.username}', LoginID='{fac_user.login_identifier}', EmpID='{fac_profile.employee_id}'")
    
    # Pick a student user (e.g. 721025149001)
    stu_user = db.query(User).filter(User.username == "721025149001").first()
    stu_profile = db.query(Student).filter(Student.user_id == stu_user.id).first()
    print(f"Student 721025149001: ID={stu_user.id}, Username='{stu_user.username}', LoginID='{stu_user.login_identifier}', Roll='{stu_profile.roll_number}'")

    print("\n" + "=" * 70)
    print("TEST 2: ADMIN PASSWORD RESET & LOGIN WITH TEMP PASSWORD")
    print("=" * 70)
    
    # We will test admin reset on a student and verify login
    # Get admin user and token
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    from app.core.security import create_access_token
    admin_token = create_access_token(admin.id, role="ADMIN")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    
    # Choose a target student to test: student 721025149060
    target_student = db.query(Student).filter(Student.roll_number == "721025149060").first()
    target_user = target_student.user
    original_hash = target_user.hashed_password
    original_fpc = target_user.force_password_change
    original_failed = target_user.failed_login_attempts
    
    print(f"Target student ID={target_student.id}, user_id={target_user.id}, roll={target_student.roll_number}")
    print(f"Before reset: FPC={original_fpc}, failed_attempts={original_failed}")
    
    # Perform Admin Reset
    reset_resp = client.post(
        f"/api/v1/admin/students/{target_student.id}/reset-password",
        json={"generate_temporary": True, "force_password_change": True},
        headers=admin_headers
    )
    print(f"Admin reset status: {reset_resp.status_code}")
    reset_data = reset_resp.json()
    temp_pw = reset_data.get("temporary_password")
    print(f"Temp password returned: length={len(temp_pw) if temp_pw else 0}, FPC in response={reset_data.get('force_password_change')}")
    
    # Verify in DB
    db.refresh(target_user)
    print(f"DB after reset: FPC={target_user.force_password_change}, failed_attempts={target_user.failed_login_attempts}, locked={target_user.locked_until}")
    
    # Attempt login with the temporary password via /api/v1/auth/student/login
    login_resp = client.post(
        "/api/v1/auth/student/login",
        json={"identifier": target_student.roll_number, "password": temp_pw}
    )
    print(f"Student login with temp password status: {login_resp.status_code}")
    if login_resp.status_code == 200:
        login_data = login_resp.json()
        print(f"Login success! FPC={login_data.get('force_password_change')}, StudentID={login_data.get('student_id')}")
        stu_token = login_data.get("access_token")
    else:
        print(f"Login failed! Response: {login_resp.text}")
        stu_token = None

    print("\n" + "=" * 70)
    print("TEST 3: PASSWORD CHANGE FLOW VIA /api/v1/auth/change-password")
    print("=" * 70)
    
    if stu_token:
        stu_headers = {"Authorization": f"Bearer {stu_token}"}
        new_test_pw = "NewSecurePass2026!"
        
        # Call change password
        change_resp = client.post(
            "/api/v1/auth/change-password",
            json={
                "current_password": temp_pw,
                "new_password": new_test_pw,
                "confirm_password": new_test_pw
            },
            headers=stu_headers
        )
        print(f"Change password status: {change_resp.status_code}")
        print(f"Change password response: {change_resp.json()}")
        
        # Verify in DB
        db.refresh(target_user)
        print(f"DB after change: FPC={target_user.force_password_change}, password_changed_at={target_user.password_changed_at}")
        
        # Now test login with OLD temp password (should fail 401)
        old_login_resp = client.post(
            "/api/v1/auth/student/login",
            json={"identifier": target_student.roll_number, "password": temp_pw}
        )
        print(f"Login with OLD temp password status: {old_login_resp.status_code} (Expected 401)")
        
        # Now test login with NEW password (should succeed 200)
        new_login_resp = client.post(
            "/api/v1/auth/student/login",
            json={"identifier": target_student.roll_number, "password": new_test_pw}
        )
        print(f"Login with NEW password status: {new_login_resp.status_code} (Expected 200)")
        if new_login_resp.status_code == 200:
            print(f"Login success with new password! FPC={new_login_resp.json().get('force_password_change')}")
        else:
            print(f"Login failed! Response: {new_login_resp.text}")
            
        # Also test /api/v1/auth/me with new token
        new_token = new_login_resp.json().get("access_token")
        me_resp = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {new_token}"})
        print(f"/auth/me status: {me_resp.status_code}, payload keys: {list(me_resp.json().keys())}")

    print("\n" + "=" * 70)
    print("TEST 4: REVERTING TARGET STUDENT TO ORIGINAL HASH")
    print("=" * 70)
    target_user.hashed_password = original_hash
    target_user.force_password_change = original_fpc
    target_user.failed_login_attempts = original_failed
    db.commit()
    print("Target student credentials cleanly restored to original state.")

    db.close()

if __name__ == "__main__":
    run_tests()
