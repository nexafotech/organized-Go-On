"""
Safe Read-Only Audit of Authentication & Password Flow.
No credentials or hashes are printed.
"""
import os
import sys

sys.path.insert(0, os.path.abspath("."))

from app.core.database import SessionLocal
from app.models.user import User, UserRole, Faculty
from app.models.student import Student
from app.models.policy import SystemSetting
from app.core.security import verify_password, get_password_hash
from app.api.admin import _generate_temporary_password

def audit():
    db = SessionLocal()
    print("=" * 60)
    print("1. AUTH SETTINGS IN DATABASE")
    print("=" * 60)
    settings = db.query(SystemSetting).filter(SystemSetting.key.like("auth.%")).all()
    for s in settings:
        print(f"  {s.key} = {s.value}")

    print("\n" + "=" * 60)
    print("2. USER & IDENTIFIER COLUMN POPULATION")
    print("=" * 60)
    total_users = db.query(User).count()
    users_with_login_id = db.query(User).filter(User.login_identifier != None).count()
    users_without_login_id = db.query(User).filter(User.login_identifier == None).count()
    print(f"Total Users: {total_users}")
    print(f"Users WITH login_identifier: {users_with_login_id}")
    print(f"Users WITHOUT login_identifier: {users_without_login_id}")

    # Check student users specifically
    student_users = db.query(User).filter(User.role == UserRole.STUDENT).all()
    st_missing_login_id = [u for u in student_users if not u.login_identifier]
    print(f"Student Users Total: {len(student_users)}")
    print(f"Student Users missing login_identifier: {len(st_missing_login_id)}")
    
    # Sample check of 5 students
    for u in student_users[:5]:
        st = db.query(Student).filter(Student.user_id == u.id).first()
        roll = st.roll_number if st else "NO_PROFILE"
        print(f"  User ID {u.id}: username='{u.username}', login_id='{u.login_identifier}', roll='{roll}', email='{u.email}'")

    # Check faculty users specifically
    faculty_users = db.query(User).filter(User.role == UserRole.FACULTY).all()
    fac_missing_login_id = [u for u in faculty_users if not u.login_identifier]
    print(f"\nFaculty Users Total: {len(faculty_users)}")
    print(f"Faculty Users missing login_identifier: {len(fac_missing_login_id)}")
    for u in faculty_users:
        fac = db.query(Faculty).filter(Faculty.user_id == u.id).first()
        emp_id = fac.employee_id if fac else "NO_PROFILE"
        print(f"  User ID {u.id}: username='{u.username}', login_id='{u.login_identifier}', emp_id='{emp_id}', email='{u.email}'")

    print("\n" + "=" * 60)
    print("3. TEMPORARY PASSWORD GENERATOR PROPERTIES")
    print("=" * 60)
    for _ in range(5):
        pw = _generate_temporary_password(5)
        print(f"  Sample temp pw: length={len(pw)}, has_upper={any(c.isupper() for c in pw)}, has_lower={any(c.islower() for c in pw)}, has_digit={any(c.isdigit() for c in pw)}, has_symbol={any(c in '!@#$%^&*' for c in pw)}")

    print("\n" + "=" * 60)
    print("4. HASHING & VERIFICATION COMPATIBILITY TEST")
    print("=" * 60)
    test_pw = "Sample#Pass123"
    h1 = get_password_hash(test_pw)
    v1 = verify_password(test_pw, h1)
    v2 = verify_password("WrongPassword", h1)
    v3 = verify_password(test_pw + " ", h1)
    print(f"  Self-hash match: {v1}")
    print(f"  Wrong password match: {v2}")
    print(f"  Trailing space match: {v3}")

    print("\n" + "=" * 60)
    print("5. FAILED LOGIN ATTEMPTS & LOCKOUTS IN DATABASE")
    print("=" * 60)
    problem_users = db.query(User).filter((User.failed_login_attempts > 0) | (User.locked_until != None)).all()
    print(f"Users with failed attempts > 0 or locked: {len(problem_users)}")
    for u in problem_users:
        print(f"  User ID {u.id} ({u.username}, role={u.role}): failed_attempts={u.failed_login_attempts}, locked_until={u.locked_until}, force_password_change={u.force_password_change}")

    print("\n" + "=" * 60)
    print("6. FORCE_PASSWORD_CHANGE ACCOUNTS IN DATABASE")
    print("=" * 60)
    fpc_users = db.query(User).filter(User.force_password_change == True).all()
    print(f"Users with force_password_change == True: {len(fpc_users)}")
    for u in fpc_users:
        print(f"  User ID {u.id} ({u.username}, role={u.role}): force_password_change={u.force_password_change}")

    db.close()

if __name__ == "__main__":
    audit()
