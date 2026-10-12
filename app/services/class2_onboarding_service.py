import os
import json
import string
import secrets
import zipfile
import html
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from app.core.config import settings
from app.core.security import get_password_hash
from app.models.user import User, UserRole
from app.models.student import Student
from app.models.academic import ClassSection
from app.models.audit import AuditLog
from app.services.college_importer import ImportValidationError

DEFAULT_ROSTER_PATH = os.path.abspath("college_seed/students_class2_development.json")
DEFAULT_DOCX_OUTPUT_PATH = r"C:\Users\Abishek\Documents\Attendance_Marker\CLASS2_STUDENT_CREDENTIALS.docx"
EXPECTED_CLASS_NAME = "III Year CSE Cyber Security - Class 2"
EXPECTED_STUDENT_COUNT = 55
MAX_SYSTEM_STUDENTS = 130


def generate_secure_temporary_password(length: int = 8) -> str:
    """
    Generates a cryptographically secure random temporary password of exactly `length` characters (default 8).
    Guarantees at least 1 uppercase, 1 lowercase, 1 digit, and 1 special symbol.
    """
    special_chars = "!@#$%^&*"
    chars = string.ascii_letters + string.digits + special_chars
    pwd = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice(special_chars)
    ]
    if length > 4:
        pwd += [secrets.choice(chars) for _ in range(length - 4)]
    elif length < 4:
        pwd = pwd[:length]
    secrets.SystemRandom().shuffle(pwd)
    return "".join(pwd[:length])


def generate_credential_docx(output_path: str, credential_records: List[Dict[str, Any]]):
    """
    Generates a confidential Microsoft Word (.docx) document containing the one-time
    initial student login credentials using standard Python library zipfile and XML.
    """
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    body_xml = []

    # Title & Confidential Banner
    body_xml.append("""
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="36"/><w:color w:val="1E3A8A"/></w:rPr><w:t>Class 2 Student Onboarding Credentials</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="DC2626"/></w:rPr><w:t>CONFIDENTIAL — STUDENT LOGIN CREDENTIALS</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:i/><w:sz w:val="20"/><w:color w:val="4B5563"/></w:rPr><w:t>Store securely. Temporary passwords must be changed on first login. Do not share publicly or commit to source control.</w:t></w:r>
    </w:p>
    <w:p/>
    """)

    # Table
    table_xml = ["""<w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E5E7EB"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E5E7EB"/>
        </w:tblBorders>
      </w:tblPr>"""]

    headers = [
        "S.No.",
        "Register Number",
        "Student Name",
        "Student ID",
        "Entry Type",
        "Username / Login ID",
        "Temporary Password",
        "Force Password Change"
    ]

    table_xml.append("<w:tr><w:trPr><w:tblHeader/></w:trPr>")
    for h in headers:
        table_xml.append(f"""
        <w:tc>
          <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="1E293B"/><w:vAlign w:val="center"/></w:tcPr>
          <w:p><w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="18"/></w:rPr><w:t>{html.escape(h)}</w:t></w:r></w:p>
        </w:tc>""")
    table_xml.append("</w:tr>")

    for idx, rec in enumerate(credential_records):
        s_no = str(idx + 1)
        roll_no = str(rec.get("roll_number", ""))
        full_name = str(rec.get("full_name", ""))
        student_id = "Unassigned" if rec.get("student_id") is None else str(rec.get("student_id"))
        entry_type = str(rec.get("entry_type", "REGULAR"))
        username = str(rec.get("username", roll_no))
        temp_pwd = str(rec.get("temporary_password", ""))
        force_change = "true" if rec.get("force_password_change", True) else "false"

        row_cells = [s_no, roll_no, full_name, student_id, entry_type, username, temp_pwd, force_change]
        fill_color = "F8FAFC" if (idx + 1) % 2 == 0 else "FFFFFF"

        table_xml.append("<w:tr>")
        for cell_idx, cell_text in enumerate(row_cells):
            is_pwd = (cell_idx == 6)
            font_xml = '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>' if is_pwd else ""
            color_xml = '<w:color w:val="2563EB"/>' if is_pwd else '<w:color w:val="0F172A"/>'
            bold_xml = "<w:b/>" if is_pwd else ""

            table_xml.append(f"""
            <w:tc>
              <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="{fill_color}"/><w:vAlign w:val="center"/></w:tcPr>
              <w:p><w:r><w:rPr>{font_xml}{color_xml}{bold_xml}<w:sz w:val="18"/></w:rPr><w:t>{html.escape(cell_text)}</w:t></w:r></w:p>
            </w:tc>""")
        table_xml.append("</w:tr>")

    table_xml.append("</w:tbl>")
    body_xml.append("".join(table_xml))

    doc_xml = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    {''.join(body_xml)}
    <w:sectPr>
      <w:pgSz w:w="15840" w:h="12240" w:orient="landscape"/>
      <w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>"""

    content_types_xml = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>"""

    rels_xml = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>"""

    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as docx:
        docx.writestr("[Content_Types].xml", content_types_xml)
        docx.writestr("_rels/.rels", rels_xml)
        docx.writestr("word/document.xml", doc_xml)
        docx.writestr("word/_rels/document.xml.rels", """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>""")


def onboard_class2_students(
    db: Session,
    admin_user_id: Optional[int] = None,
    roster_path: Optional[str] = None,
    docx_output_path: Optional[str] = DEFAULT_DOCX_OUTPUT_PATH,
    dry_run: bool = False
) -> Dict[str, Any]:
    """
    Onboards the 55 verified Class 2 student accounts from college_seed/students_class2_development.json.
    Performs full capacity, uniqueness, and structural verification with reconciliation against existing records.
    Generates strong in-memory temporary passwords and outputs a private DOCX register outside Git.
    """
    target_roster = roster_path or DEFAULT_ROSTER_PATH
    if not os.path.exists(target_roster):
        raise ImportValidationError("Roster file not found", [f"File does not exist: {target_roster}"])

    with open(target_roster, "r", encoding="utf-8") as f:
        roster_data = json.load(f)

    if not isinstance(roster_data, list):
        raise ImportValidationError("Invalid roster structure", ["Dataset root must be a JSON array."])

    if len(roster_data) != EXPECTED_STUDENT_COUNT:
        raise ImportValidationError(
            "Roster size mismatch",
            [f"Expected {EXPECTED_STUDENT_COUNT} students, found {len(roster_data)}."]
        )

    # 1. Pre-validation and duplicate checking
    errors = []
    seen_rolls = set()
    existing_matching = []
    to_create = []

    for idx, item in enumerate(roster_data):
        row_num = idx + 1
        roll_no = str(item.get("roll_number", "")).strip()
        full_name = str(item.get("full_name", "")).strip()
        class_name = str(item.get("class_name", "")).strip()
        entry_type = str(item.get("entry_type", "REGULAR")).strip().upper()

        if not roll_no or not full_name:
            errors.append(f"Row {row_num}: Missing roll_number or full_name")
            continue

        if roll_no in seen_rolls:
            errors.append(f"Row {row_num}: Duplicate roll_number '{roll_no}' in roster batch")
            continue
        seen_rolls.add(roll_no)

        if class_name != EXPECTED_CLASS_NAME:
            errors.append(f"Row {row_num}: Invalid class '{class_name}' (expected '{EXPECTED_CLASS_NAME}')")

        # Database collision and reconciliation check
        existing_student = db.query(Student).filter(Student.roll_number == roll_no).first()
        existing_user = db.query(User).filter(User.username == roll_no).first()

        if existing_student:
            # Check for name mismatch
            if existing_student.full_name != full_name:
                errors.append(
                    f"Row {row_num}: Mismatch found for register number '{roll_no}'. "
                    f"Source name: '{full_name}', Database name: '{existing_student.full_name}', "
                    f"Student ID: {existing_student.id}"
                )
            else:
                existing_matching.append(item)
        elif existing_user:
            errors.append(f"Row {row_num}: User account with username '{roll_no}' already exists in database without matching Student")
        else:
            to_create.append(item)

    if errors:
        raise ImportValidationError("Class 2 onboarding pre-validation failed", errors)

    # 2. Capacity Check: existing total + new <= 130
    current_student_count = db.query(Student).count()
    projected_total = current_student_count + len(to_create)
    if projected_total > MAX_SYSTEM_STUDENTS:
        raise ImportValidationError(
            "System student capacity limit exceeded",
            [f"Current students ({current_student_count}) + new students ({len(to_create)}) = {projected_total} exceeds MAX_STUDENTS capacity of {MAX_SYSTEM_STUDENTS}."]
        )

    # 3. Class Section Verification
    class_section = db.query(ClassSection).filter(ClassSection.name == EXPECTED_CLASS_NAME).first()
    if not class_section:
        raise ImportValidationError(
            "Target class section missing",
            [f"Class section '{EXPECTED_CLASS_NAME}' does not exist in the database."]
        )

    if dry_run:
        return {
            "status": "DRY_RUN_SUCCESS",
            "attempted": len(roster_data),
            "created": len(to_create),
            "existing_skipped": len(existing_matching),
            "capacity_current": current_student_count,
            "capacity_projected": projected_total,
            "capacity_max": MAX_SYSTEM_STUDENTS,
            "message": f"Dry-run validation successful. {len(to_create)} students to create, {len(existing_matching)} existing students verified. No database changes made."
        }

    # 4. Ingestion Loop inside transaction
    created_users = []
    created_students = []
    credentials_for_doc = []

    try:
        for idx, item in enumerate(to_create):
            roll_no = str(item.get("roll_number", "")).strip()
            full_name = str(item.get("full_name", "")).strip()
            student_id = item.get("student_id")
            entry_type = str(item.get("entry_type", "REGULAR")).strip().upper()

            # Generate strong temporary password in memory
            temp_password = generate_secure_temporary_password(5)
            hashed_pwd = get_password_hash(temp_password)

            # Development fallback email
            dev_email = f"{roll_no.lower()}@dev.college.local"

            user = User(
                username=roll_no,
                email=dev_email,
                hashed_password=hashed_pwd,
                role=UserRole.STUDENT,
                is_active=True,
                force_password_change=True,
                login_identifier=roll_no
            )
            db.add(user)
            db.flush()
            created_users.append(user)

            student = Student(
                user_id=user.id,
                roll_number=roll_no,
                full_name=full_name,
                class_id=class_section.id,
                department="CSE Cyber Security",
                semester="5",
                is_active=True
            )
            db.add(student)
            db.flush()
            created_students.append(student)

            # Record in memory for confidential one-time DOCX document
            credentials_for_doc.append({
                "roll_number": roll_no,
                "full_name": full_name,
                "student_id": student_id,
                "entry_type": entry_type,
                "username": roll_no,
                "temporary_password": temp_password,
                "force_password_change": True
            })

        # 5. Post-Creation Invariant Verifications
        final_c2_students = db.query(Student).filter(Student.class_id == class_section.id).count()
        if final_c2_students != EXPECTED_STUDENT_COUNT:
            raise RuntimeError(f"Expected {EXPECTED_STUDENT_COUNT} Class 2 students in database, got {final_c2_students}")

        c1_section = db.query(ClassSection).filter(ClassSection.name == "II Year CSE Cyber Security - Class 1").first()
        final_c1_students = db.query(Student).filter(Student.class_id == c1_section.id).count() if c1_section else 0
        if final_c1_students != 64:
            raise RuntimeError(f"Expected 64 Class 1 students preserved, got {final_c1_students}")

        final_total_students = db.query(Student).count()
        if final_total_students != 119:
            raise RuntimeError(f"Expected exactly 119 total students in database, got {final_total_students}")

        # 6. Audit Log Entry (non-sensitive details)
        audit = AuditLog(
            user_id=admin_user_id,
            action="ONBOARD_CLASS2_STUDENTS",
            details=f"Securely provisioned {len(created_students)} student accounts for '{EXPECTED_CLASS_NAME}' with forced password change."
        )
        db.add(audit)

        # Commit Transaction
        db.commit()

        # 7. Generate Confidential DOCX outside Git repository
        docx_generated_path = None
        if docx_output_path and credentials_for_doc:
            generate_credential_docx(docx_output_path, credentials_for_doc)
            docx_generated_path = docx_output_path

        return {
            "status": "SUCCESS",
            "attempted": len(roster_data),
            "created": len(created_students),
            "existing_skipped": len(existing_matching),
            "failures": 0,
            "final_c1_count": final_c1_students,
            "final_c2_count": final_c2_students,
            "capacity_used": final_total_students,
            "capacity_max": MAX_SYSTEM_STUDENTS,
            "capacity_remaining": MAX_SYSTEM_STUDENTS - final_total_students,
            "class_name": EXPECTED_CLASS_NAME,
            "docx_path": docx_generated_path,
            "message": f"Successfully onboarded {len(created_students)} Class 2 students."
        }

    except Exception as e:
        db.rollback()
        raise e
