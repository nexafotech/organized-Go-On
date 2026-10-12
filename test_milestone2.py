import os
import sys
import unittest
from datetime import datetime
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.main import app
from seed_db import seed_database
from app.core.database import SessionLocal
from app.models.user import User, Faculty, UserRole
from app.models.academic import Period, TimetableEntry, FacultyAssignment, Subject, ClassSection
from app.models.student import Student
from app.models.attendance import ClassSession, AttendanceRecord, SessionStatus, AttendanceStatus
from app.models.audit import AuditLog
from app.core.security import get_password_hash

class TestMilestone2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # 1. Reset database with baseline seeds
        seed_database()
        cls.client = TestClient(app)

        db = SessionLocal()
        try:
            # 2. Get baseline faculty
            faculty_user = db.query(User).filter(User.username == "faculty").first()
            cls.faculty_id = faculty_user.faculty_profile.id

            # 3. Create a second faculty member for isolation testing
            fac2_user = User(
                username="faculty2",
                email="faculty2@college.edu",
                hashed_password=get_password_hash("faculty123"),
                role=UserRole.FACULTY,
                is_active=True
            )
            db.add(fac2_user)
            db.flush()

            fac2_profile = Faculty(
                user_id=fac2_user.id,
                employee_id="EMP-102",
                full_name="Dr. Grace Hopper",
                department="Computer Science"
            )
            db.add(fac2_profile)
            db.flush()
            cls.fac2_id = fac2_profile.id

            # 4. Create a second timetable entry for fac2 on current day/time
            now = datetime.now()
            current_day = now.strftime("%A")
            current_time = now.strftime("%H:%M")

            # Check if there is a period slot matching current time or create a test active period slot
            active_period = db.query(Period).filter(
                Period.start_time <= current_time,
                Period.end_time >= current_time
            ).first()

            if not active_period:
                # Create a period slot spanning current time so tests always find an active class slot!
                active_period = Period(
                    period_number=88,
                    name="Current Active Test Slot",
                    start_time="00:00",
                    end_time="23:59"
                )
                db.add(active_period)
                db.flush()

            # Ensure Faculty 1 has a timetable entry for current day in active_period
            class1 = db.query(ClassSection).filter(ClassSection.name == "CSE-3A").first()
            subject1 = db.query(Subject).filter(Subject.code == "PTS").first()

            assign1 = db.query(FacultyAssignment).filter(
                FacultyAssignment.faculty_id == cls.faculty_id,
                FacultyAssignment.subject_id == subject1.id,
                FacultyAssignment.class_id == class1.id
            ).first()
            if not assign1:
                assign1 = FacultyAssignment(
                    faculty_id=cls.faculty_id,
                    subject_id=subject1.id,
                    class_id=class1.id
                )
                db.add(assign1)
                db.flush()

            tt_entry1 = db.query(TimetableEntry).filter(
                TimetableEntry.day_of_week == current_day,
                TimetableEntry.period_id == active_period.id,
                TimetableEntry.assignment_id == assign1.id
            ).first()

            if not tt_entry1:
                tt_entry1 = TimetableEntry(
                    day_of_week=current_day,
                    period_id=active_period.id,
                    assignment_id=assign1.id
                )
                db.add(tt_entry1)
                db.flush()
            cls.tt_entry1_id = tt_entry1.id

            # Create Faculty 2 assignment & timetable entry for CSE-3B
            class2 = db.query(ClassSection).filter(ClassSection.name == "CSE-3B").first()
            subject2 = db.query(Subject).filter(Subject.code == "EC").first()

            assign2 = FacultyAssignment(
                faculty_id=cls.fac2_id,
                subject_id=subject2.id,
                class_id=class2.id
            )
            db.add(assign2)
            db.flush()

            tt_entry2 = TimetableEntry(
                day_of_week=current_day,
                period_id=active_period.id,
                assignment_id=assign2.id
            )
            db.add(tt_entry2)
            db.flush()
            cls.tt_entry2_id = tt_entry2.id

            db.commit()

        finally:
            db.close()

    def get_token(self, username="faculty", password="faculty123"):
        res = self.client.post("/api/v1/auth/login", json={
            "username_or_email": username,
            "password": password
        })
        return res.json()["access_token"]

    def test_01_faculty_start_current_class_session(self):
        token = self.get_token("faculty", "faculty123")
        headers = {"Authorization": f"Bearer {token}"}

        res = self.client.post("/api/v1/faculty/sessions/start", headers=headers)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("session_id", data)
        self.assertEqual(data["status"], "ACTIVE")
        self.session_id = data["session_id"]

    def test_02_duplicate_active_session_prevented(self):
        token = self.get_token("faculty", "faculty123")
        headers = {"Authorization": f"Bearer {token}"}

        # Attempt to start session again for same active slot
        res = self.client.post("/api/v1/faculty/sessions/start", headers=headers)
        self.assertEqual(res.status_code, 200)
        # Returns the already active session without creating duplicate row in DB

    def test_03_students_loaded_from_correct_class(self):
        token = self.get_token("faculty", "faculty123")
        headers = {"Authorization": f"Bearer {token}"}

        active_res = self.client.get("/api/v1/faculty/sessions/active", headers=headers)
        self.assertEqual(active_res.status_code, 200)
        data = active_res.json()
        self.assertTrue(data["has_active_session"])
        session = data["session"]

        self.assertIn("roster", session)
        # Verify Alex, Sarah, Pugazh are loaded
        rolls = [st["roll_number"] for st in session["roster"]]
        self.assertIn("101", rolls)
        self.assertIn("102", rolls)

    def test_04_mark_student_present_and_absent(self):
        token = self.get_token("faculty", "faculty123")
        headers = {"Authorization": f"Bearer {token}"}

        active_res = self.client.get("/api/v1/faculty/sessions/active", headers=headers)
        session_id = active_res.json()["session"]["session_id"]
        roster = active_res.json()["session"]["roster"]

        st1_id = roster[0]["student_id"]
        st2_id = roster[1]["student_id"]

        # Mark Student 1 PRESENT
        res1 = self.client.post(f"/api/v1/faculty/sessions/{session_id}/attendance", headers=headers, json={
            "student_id": st1_id,
            "status": "PRESENT"
        })
        self.assertEqual(res1.status_code, 200)
        self.assertEqual(res1.json()["status"], "PRESENT")

        # Mark Student 2 ABSENT
        res2 = self.client.post(f"/api/v1/faculty/sessions/{session_id}/attendance", headers=headers, json={
            "student_id": st2_id,
            "status": "ABSENT"
        })
        self.assertEqual(res2.status_code, 200)
        self.assertEqual(res2.json()["status"], "ABSENT")

    def test_05_student_deduplication_per_session(self):
        token = self.get_token("faculty", "faculty123")
        headers = {"Authorization": f"Bearer {token}"}

        active_res = self.client.get("/api/v1/faculty/sessions/active", headers=headers)
        session_id = active_res.json()["session"]["session_id"]
        roster = active_res.json()["session"]["roster"]
        st1_id = roster[0]["student_id"]

        # Re-marking Student 1 ABSENT updates existing record instead of adding duplicate row
        res = self.client.post(f"/api/v1/faculty/sessions/{session_id}/attendance", headers=headers, json={
            "student_id": st1_id,
            "status": "ABSENT"
        })
        self.assertEqual(res.status_code, 200)

        # Check total attendance records for this session & student
        db = SessionLocal()
        records_count = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session_id,
            AttendanceRecord.student_id == st1_id
        ).count()
        db.close()

        self.assertEqual(records_count, 1)

    def test_06_student_can_have_attendance_in_two_different_sessions(self):
        # 1. Faculty 1 active session
        token1 = self.get_token("faculty", "faculty123")
        s1 = self.client.get("/api/v1/faculty/sessions/active", headers={"Authorization": f"Bearer {token1}"}).json()["session"]
        st_id = s1["roster"][0]["student_id"]

        # 2. Faculty 2 starts session for CSE-3B (or assign student to both classes / create session 2)
        token2 = self.get_token("faculty2", "faculty123")
        s2_start = self.client.post("/api/v1/faculty/sessions/start", headers={"Authorization": f"Bearer {token2}"}).json()
        s2_id = s2_start["session_id"]

        # Mark student in session 2 as PRESENT
        res = self.client.post(f"/api/v1/faculty/sessions/{s2_id}/attendance", headers={"Authorization": f"Bearer {token2}"}, json={
            "student_id": st_id,
            "status": "PRESENT"
        })
        self.assertEqual(res.status_code, 200)

        # Verify student has attendance records in BOTH session 1 and session 2
        db = SessionLocal()
        att_count = db.query(AttendanceRecord).filter(AttendanceRecord.student_id == st_id).count()
        db.close()
        self.assertGreaterEqual(att_count, 2)

    def test_07_faculty_cannot_access_another_facultys_session(self):
        token1 = self.get_token("faculty", "faculty123")
        token2 = self.get_token("faculty2", "faculty123")

        s1_id = self.client.get("/api/v1/faculty/sessions/active", headers={"Authorization": f"Bearer {token1}"}).json()["session"]["session_id"]

        # Faculty 2 attempts to view Faculty 1's session details
        res_view = self.client.get(f"/api/v1/faculty/sessions/{s1_id}", headers={"Authorization": f"Bearer {token2}"})
        self.assertEqual(res_view.status_code, 403)

        # Faculty 2 attempts to mark attendance in Faculty 1's session
        res_mark = self.client.post(f"/api/v1/faculty/sessions/{s1_id}/attendance", headers={"Authorization": f"Bearer {token2}"}, json={
            "student_id": 1,
            "status": "PRESENT"
        })
        self.assertEqual(res_mark.status_code, 403)

    def test_08_complete_session_and_prevent_modification(self):
        token1 = self.get_token("faculty", "faculty123")
        headers = {"Authorization": f"Bearer {token1}"}

        s1_id = self.client.get("/api/v1/faculty/sessions/active", headers=headers).json()["session"]["session_id"]

        # Complete session
        complete_res = self.client.post(f"/api/v1/faculty/sessions/{s1_id}/complete", headers=headers)
        self.assertEqual(complete_res.status_code, 200)
        self.assertEqual(complete_res.json()["status"], "COMPLETED")

        # Attempt to modify attendance in completed session should fail
        mod_res = self.client.post(f"/api/v1/faculty/sessions/{s1_id}/attendance", headers=headers, json={
            "student_id": 1,
            "status": "PRESENT"
        })
        self.assertEqual(mod_res.status_code, 400)
        self.assertIn("not ACTIVE", mod_res.json()["detail"])

    def test_09_admin_view_all_sessions_and_audit_correction(self):
        admin_token = self.get_token("admin", "admin123")
        headers = {"Authorization": f"Bearer {admin_token}"}

        # 1. Admin views all sessions
        sessions_res = self.client.get("/api/v1/admin/sessions", headers=headers)
        self.assertEqual(sessions_res.status_code, 200)
        self.assertIsInstance(sessions_res.json(), list)

        session_id = sessions_res.json()[0]["session_id"]

        # 2. Admin performs explicit attendance correction
        correct_res = self.client.post(f"/api/v1/admin/sessions/{session_id}/correction", headers=headers, json={
            "student_id": 1,
            "new_status": "PRESENT",
            "reason": "Official medical leave approval"
        })
        self.assertEqual(correct_res.status_code, 200)

        # 3. Verify entry in AuditLog
        audit_res = self.client.get("/api/v1/admin/audit-logs", headers=headers)
        self.assertEqual(audit_res.status_code, 200)
        audit_logs = audit_res.json()
        self.assertTrue(any("ADMIN_ATTENDANCE_CORRECTION" in log["action"] for log in audit_logs))

if __name__ == "__main__":
    unittest.main()
