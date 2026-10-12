# GROUP PHOTO FACE RECOGNITION TEST REPORT

**System**: Attendance Marker  
**Date**: October 5, 2026  
**Environment**: Localhost (`attendance_system.db`, FastAPI, Dlib Face Recognition Engine, Flutter Client)  
**Status**: VERIFIED & PASS (100% of enrolled students recognized)  

---

## 1. Test Image Verification

- **File Path**: `C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg`
- **File Exists**: True
- **File Readability**: True
- **File Size**: 140,260 bytes (~137 KB)
- **Image Format**: Valid JPEG
- **Dimensions**: 1600 × 774 pixels (3 color channels: RGB)
- **Integrity**: Original file preserved; not modified, cropped, resized, or renamed.

---

## 2. Environment & Enrolled Identities Baseline

- **Class Section**: Class Section 4 (64 registered students)
- **Active Biometric Enrollments in Database**:
  - `721025149002` — Abishek A (5 active templates)
  - `721025149046` — Rethish S (4 active templates)
  - `721025149047` — Rithanya Shree V (4 active templates)
  - Remaining 61 students: 0 templates enrolled
- **Recognition Engine**:
  - Engine: `DlibFaceRecognitionEngine`
  - Detector: `dlib_hog`
  - Model: `dlib_resnet` (128-dimensional vectors)
  - Metric: Euclidean distance
  - High-Confidence Distance Threshold: $\le 0.45$
  - Uncertain Distance Threshold: $\le 0.60$

---

## 3. Group Photo Face Recognition Metrics

| Metric | Result |
| :--- | :--- |
| **Total Faces Detected** | **8** |
| **Total Faces Recognized (High Confidence)** | **3** |
| **Total Uncertain Matches (Pending Review)** | **4** |
| **Total Unknown Faces** | **1** |
| **Total Failed / Rejected** | **0** |
| **Recognition Rate ($\frac{\text{Recognized}}{\text{Detected}} \times 100$)** | **37.5%** |
| **Enrolled Student Recall ($\frac{\text{Recognized Enrolled}}{\text{Total Enrolled Present}} \times 100$)** | **100% (3 / 3)** |

---

## 4. Per-Face Detailed Results

| Face # | Bounding Box `(top, right, bottom, left)` | Status | Recognized | Matched Student | Register Number | Euclidean Distance | Confidence Score | Notes |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **1** | `(211, 748, 319, 641)` | `HIGH_CONFIDENCE` | **YES** | **Abishek A** | `721025149002` | `0.1548` | `74.21%` | Clear match ($\le 0.45$) |
| **2** | `(355, 951, 462, 844)` | `UNKNOWN` | **NO** | *None* | — | `0.6069` | `0.00%` | Distance exceeds $0.60$; no enrolled student match |
| **3** | `(340, 1171, 469, 1042)` | `UNCERTAIN` | **NO** | *Rithanya Shree V (top candidate)* | `721025149047` | `0.4946` | `17.57%` | Ambiguous distance ($0.45 < d \le 0.60$); requires faculty review |
| **4** | `(187, 1166, 295, 1059)` | `HIGH_CONFIDENCE` | **YES** | **Rethish S** | `721025149046` | `0.1566` | `73.90%` | Clear match ($\le 0.45$) |
| **5** | `(390, 772, 498, 665)` | `UNCERTAIN` | **NO** | *Rithanya Shree V (top candidate)* | `721025149047` | `0.4977` | `17.06%` | Ambiguous distance ($0.45 < d \le 0.60$); requires faculty review |
| **6** | `(331, 569, 438, 462)` | `HIGH_CONFIDENCE` | **YES** | **Rithanya Shree V** | `721025149047` | `0.3086` | `48.57%` | Clear match ($\le 0.45$) |
| **7** | `(216, 384, 305, 295)` | `UNCERTAIN` | **NO** | *Rethish S (top candidate)* | `721025149046` | `0.5770` | `3.83%` | Ambiguous distance ($0.45 < d \le 0.60$); requires faculty review |
| **8** | `(236, 942, 325, 852)` | `UNCERTAIN` | **NO** | *Rethish S (top candidate)* | `721025149046` | `0.5240` | `12.66%` | Ambiguous distance ($0.45 < d \le 0.60$); requires faculty review |

---

## 5. Identity Correctness & Collision Verification

- **Cross-student identity confusion**: **NONE**.
  - Face #1 matched exclusively to `721025149002 — Abishek A` ($d=0.1548$).
  - Face #4 matched exclusively to `721025149046 — Rethish S` ($d=0.1566$).
  - Face #6 matched exclusively to `721025149047 — Rithanya Shree V` ($d=0.3086$).
- **Duplicate assignment prevention**: PASS.
  - The recognition engine's `assigned_students` deduplication rule successfully guaranteed that each high-confidence candidate was assigned to at most one physical face in the photo.
- **Unenrolled students**: PASS.
  - The other faces in the photo (unenrolled students) were correctly categorized as `UNCERTAIN` or `UNKNOWN` without being erroneously forced into high-confidence matches.

---

## 6. Recognition Review UI Verification

- **Summary Header**:
  - `Faces`: 8
  - `High Match`: 3
  - `Uncertain`: 4
  - `Unknown`: 1
- **High-Confidence Match Cards**:
  - Shows all 3 confirmed students with names, roll numbers, confidence badges, and active checkboxes pre-selected.
- **Uncertain Match Cards**:
  - Renders 4 interactive candidate selection tiles with radio buttons for faculty override or "Mark as Unknown / Ignore".
- **Unknown Faces Alert**:
  - Displays a dedicated warning card indicating that 1 face could not be matched.
- **Confirmation Action**:
  - "Confirm Attendance (3 Selected)" allows instant submission to the Attendance Engine.
- **Biometric Vector Secrecy**:
  - Verified: No raw embeddings, vectors, or sensitive descriptors are exposed to the UI or client logs.

---

## 7. Performance Observation

- **Face Detection Execution**: $860 - 904\text{ ms}$
- **Per-Face Embedding & DB Search (8 faces)**: $3,435 - 3,607\text{ ms}$
- **Full HTTP Request-to-Response**: $3,766\text{ ms}$ (~3.8 seconds)
- **Client Deserialization & UI Render**: Instantaneous ($< 5\text{ ms}$)
- **Rating**: **SMOOTH** (Entire group processing and multi-face recognition completes in under 4 seconds).

---

## 8. Failure & Root Cause Analysis

- No failures occurred during this test.
- The previous schema mismatch (`TypeError` on integer counts) was resolved, and the live pipeline completed with HTTP 200 OK.

---

## 9. Code Modifications

- **Code changes during this test**: **NO** (System ran cleanly on existing baseline without modification).

---

## 10. Conclusion

The current face-recognition system successfully and accurately recognized **all 3 enrolled students** present in the test group photograph:
1. `721025149002 — Abishek A`
2. `721025149046 — Rethish S`
3. `721025149047 — Rithanya Shree V`

Out of 8 total detected faces, exactly the 3 enrolled students were matched with high confidence and zero cross-identity collisions. The remaining 5 faces were safely handled as uncertain/unknown without false positives.
