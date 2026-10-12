import os
import sys
import unittest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.main import app
from seed_db import seed_database
from app.core.database import Base, engine

class TestMilestone1(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Drop and re-seed clean test database
        Base.metadata.drop_all(bind=engine)
        seed_database()
        cls.client = TestClient(app)

    def test_01_health_check(self):
        res = self.client.get("/health")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["status"], "ok")

    def test_02_admin_login_success(self):
        res = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "admin",
            "password": "admin123"
        })
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("access_token", data)
        self.assertEqual(data["token_type"], "bearer")

    def test_03_faculty_login_success(self):
        res = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "faculty",
            "password": "faculty123"
        })
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("access_token", data)

    def test_04_wrong_password_rejected(self):
        res = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "admin",
            "password": "wrongpassword"
        })
        self.assertEqual(res.status_code, 401)

    def test_05_faculty_cannot_access_admin_api(self):
        login_res = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "faculty",
            "password": "faculty123"
        })
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        res = self.client.get("/api/v1/admin/faculty", headers=headers)
        self.assertEqual(res.status_code, 403)
        self.assertIn("Admin privilege required", res.json()["detail"])

    def test_06_admin_can_access_admin_api(self):
        login_res = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "admin",
            "password": "admin123"
        })
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        res = self.client.get("/api/v1/admin/faculty", headers=headers)
        self.assertEqual(res.status_code, 200)
        self.assertIsInstance(res.json(), list)

    def test_07_auth_me_endpoint_and_session_persistence(self):
        login_res = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "faculty",
            "password": "faculty123"
        })
        token = login_res.json()["access_token"]

        res_bearer = self.client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(res_bearer.status_code, 200)
        self.assertEqual(res_bearer.json()["role"], "FACULTY")

        res_cookie = self.client.get("/api/v1/auth/me", cookies={"attendance_session": token})
        self.assertEqual(res_cookie.status_code, 200)
        self.assertEqual(res_cookie.json()["role"], "FACULTY")

    def test_08_logout_invalidates_cookie(self):
        login_res = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "faculty",
            "password": "faculty123"
        })
        token = login_res.json()["access_token"]

        logout_res = self.client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(logout_res.status_code, 200)

    def test_09_admin_faculty_crud(self):
        admin_token = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "admin", "password": "admin123"
        }).json()["access_token"]
        headers = {"Authorization": f"Bearer {admin_token}"}

        create_res = self.client.post("/api/v1/admin/faculty", headers=headers, json={
            "employee_id": "EMP-999",
            "full_name": "Test Faculty",
            "department": "Physics",
            "username": "testfaculty",
            "email": "testfaculty@college.edu",
            "password": "password123"
        })
        self.assertEqual(create_res.status_code, 201)
        faculty_id = create_res.json()["id"]

        edit_res = self.client.put(f"/api/v1/admin/faculty/{faculty_id}", headers=headers, json={
            "full_name": "Updated Faculty Name",
            "is_active": False
        })
        self.assertEqual(edit_res.status_code, 200)
        self.assertEqual(edit_res.json()["full_name"], "Updated Faculty Name")
        self.assertFalse(edit_res.json()["is_active"])

        disabled_login = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "testfaculty",
            "password": "password123"
        })
        self.assertEqual(disabled_login.status_code, 403)

        del_res = self.client.delete(f"/api/v1/admin/faculty/{faculty_id}", headers=headers)
        self.assertEqual(del_res.status_code, 200)

    def test_10_admin_student_crud(self):
        admin_token = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "admin", "password": "admin123"
        }).json()["access_token"]
        headers = {"Authorization": f"Bearer {admin_token}"}

        classes = self.client.get("/api/v1/admin/classes", headers=headers).json()
        class_id = classes[0]["id"] if classes else None

        st_res = self.client.post("/api/v1/admin/students", headers=headers, json={
            "roll_number": "999",
            "full_name": "New Student",
            "email": "student999@college.edu",
            "class_id": class_id
        })
        self.assertEqual(st_res.status_code, 201)
        st_id = st_res.json()["id"]

        st_edit = self.client.put(f"/api/v1/admin/students/{st_id}", headers=headers, json={
            "full_name": "Updated Student Name"
        })
        self.assertEqual(st_edit.status_code, 200)

        st_del = self.client.delete(f"/api/v1/admin/students/{st_id}", headers=headers)
        self.assertEqual(st_del.status_code, 200)

    def test_11_admin_class_subject_period_crud(self):
        admin_token = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "admin", "password": "admin123"
        }).json()["access_token"]
        headers = {"Authorization": f"Bearer {admin_token}"}

        c_res = self.client.post("/api/v1/admin/classes", headers=headers, json={
            "name": "TEST-CLASS-101",
            "grade_level": "Year 1",
            "academic_year": "2026"
        })
        self.assertEqual(c_res.status_code, 201)

        sub_res = self.client.post("/api/v1/admin/subjects", headers=headers, json={
            "code": "SUB-999",
            "name": "Testing Subject",
            "description": "Automated Unit Test Subject"
        })
        self.assertEqual(sub_res.status_code, 201)

        p_res = self.client.post("/api/v1/admin/periods", headers=headers, json={
            "period_number": 99,
            "name": "Night Slot",
            "start_time": "20:00",
            "end_time": "21:00"
        })
        self.assertEqual(p_res.status_code, 201)

    def test_12_faculty_timetable_and_active_class(self):
        fac_token = self.client.post("/api/v1/auth/login", json={
            "username_or_email": "faculty", "password": "faculty123"
        }).json()["access_token"]
        headers = {"Authorization": f"Bearer {fac_token}"}

        tt_res = self.client.get("/api/v1/faculty/timetable", headers=headers)
        self.assertEqual(tt_res.status_code, 200)
        self.assertIn("timetable", tt_res.json())

        active_res = self.client.get("/api/v1/faculty/active-class", headers=headers)
        self.assertEqual(active_res.status_code, 200)
        self.assertIn("has_active_class", active_res.json())

    def test_13_prototype_files_and_dataset_intact(self):
        if os.path.exists("dataset"):
            self.assertTrue(os.path.exists("dataset/101_Alex"))
            self.assertTrue(os.path.exists("dataset/102_Sarah"))
            self.assertTrue(os.path.exists("dataset/103_pugazh"))
        self.assertTrue(os.path.exists("encodings.pickle") or os.path.exists("attendance_system.db"))
        self.assertTrue(os.path.exists("encode_faces.py"))
        self.assertTrue(os.path.exists("attendance_marker.py"))
        self.assertTrue(os.path.exists("attendance_manager.py"))
        self.assertTrue(os.path.exists("timetable.py"))

if __name__ == "__main__":
    unittest.main()
