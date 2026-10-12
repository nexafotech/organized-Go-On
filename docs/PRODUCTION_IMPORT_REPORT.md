# PRODUCTION DATA IMPORT REPORT
**Execution Timestamp**: `2026-09-26 05:13:54 UTC`  
**Execution Mode**: `DRY-RUN (Simulated)`  
**Final Status**: **`BLOCKED_GATED`**

---
## 1. Pre-Ingestion Validation Gating Summary

- **Validation PASS Count**: `16`
- **Validation WARN Count**: `34`
- **Validation FAIL Count**: `0`
- **Validation MISSING Count**: `0`

### Blocking Gating Violations Detected
> [!CAUTION]
> The import workflow was blocked because the dataset failed production completeness or security invariants:

- **BLOCKED**: Placeholder identity detected in faculty_production_template.json -> Row 1.identity: Placeholder faculty identity detected: 'FACULTY_PLACEHOLDER_001' / 'Faculty Member Placeholder 001'.
- **BLOCKED**: Placeholder identity detected in faculty_production_template.json -> Row 2.identity: Placeholder faculty identity detected: 'FACULTY_PLACEHOLDER_002' / 'Faculty Member Placeholder 002'.
- **BLOCKED**: Placeholder identity detected in students_production_template.json -> Row 1.identity: Placeholder student identity detected: '2026_CYBER_C1_001' / 'STUDENT_PLACEHOLDER_C1_001'.
- **BLOCKED**: Placeholder identity detected in students_production_template.json -> Row 2.identity: Placeholder student identity detected: '2026_CYBER_C2_001' / 'STUDENT_PLACEHOLDER_C2_001'.
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 1.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'FDS' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 2.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'DMC' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 3.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'FDS LAB' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 4.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'DPCO' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 5.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'OOPS' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 6.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'DS' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 7.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'ACE-I' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 8.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'UHV' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 9.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'IKS' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 10.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'DS LAB' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 11.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'IIC' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 12.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'JAVA LAB' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 13.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'TWM' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 14.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'LIB' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 15.faculty_username: Faculty assignment for 'II Year CSE Cyber Security - Class 1' - 'ASSOC' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 16.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'AIML' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 17.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'LP' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 18.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'SDBMS' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 19.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'ESSS' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 20.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'SDBMS LAB' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 21.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'CC' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 22.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'E&I' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 23.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'CC-I' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 24.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'LIB' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 25.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'IIC' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 26.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'LINUX LAB' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 27.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'TWM' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 28.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'ESSS LAB' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 29.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'CF' is unassigned/placeholder ('None').
- **BLOCKED**: Placeholder identity detected in faculty_assignments.json -> Row 30.faculty_username: Faculty assignment for 'III Year CSE Cyber Security - Class 2' - 'CF LAB' is unassigned/placeholder ('None').
- **BLOCKED**: Required production file 'faculty.json' is missing from 'C:\Users\Abishek\Desktop\am-oss\college_seed'
- **BLOCKED**: Required production file 'students.json' is missing from 'C:\Users\Abishek\Desktop\am-oss\college_seed'

---
## 2. Ingestion Statistics by Category

| Category | Imported Records | Skipped (Existing) | Import Status |
| :--- | :---: | :---: | :--- |
| *None* | `0` | `0` | Blocked before execution |

---
## 3. Database Invariants & Relational Verification

*Verification skipped due to pre-ingestion gating blocks.*

---
## 4. Security & Zero-Credential Enforcement

- [x] **No Plaintext Passwords Committed**: Plaintext passwords are not stored in database records or logged.
- [x] **No JWTs or Secrets Exposed**: Zero tokens logged in reports or terminal output.
- [x] **Demo Fixtures Gated**: Development demo credentials strictly rejected from production import.
- [x] **Zero Biometrics**: Verified zero biometric vectors or photos in student datasets.
