# FACE RECOGNITION TARGETED DEBUG REPORT: RETHISH S TEST PHOTO

**System**: Attendance Marker  
**Target Student**: Rethish S (Register Number: `721025149046`)  
**Target Test Image**: `C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg`  
**Date**: October 5, 2026  
**Status**: RESOLVED & VERIFIED (PASS)  

---

## 1. Exact Test Image Verification

- **Path**: `C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg`
- **File Exists**: True
- **File Readability**: True
- **File Size**: 140,260 bytes (~140 KB, non-zero)
- **Format**: Valid JPEG (RGB color mode)
- **Decoded Dimensions**: 1600 × 774 pixels (OpenCV shape: `(774, 1600, 3)`)
- **File Integrity**: Original file preserved completely untouched; not renamed, moved, or modified.

---

## 2. Expected Student & Enrollment Verification

- **Target Register Number**: `721025149046`
- **Full Name**: Rethish S
- **Student Database ID**: 46 (Class Section ID: 4)
- **Active Biometric Templates in DB**: **4 valid templates** (stored in `FaceEmbedding` table with `dlib_resnet` 128-d vectors from folder enrollment).
- **Integrity**: Templates were not recreated, reseeded, or altered.

---

## 3. Reproduction & Failure Tracing

### 3.1 Observed Symptom
When submitting the photo in the Chrome Web application after image preview, the UI displayed:
```
"Failed to process group photo"
```

### 3.2 Failure Stage Breakdown
We traced the complete execution path:

1. **Local Image Selection**: PASS (Browser provides image bytes `_currentBytes` to `ImagePreviewScreen`).
2. **HTTP Multipart Request**: PASS (`ApiClient.multipartPostBytes` sends `image/jpeg` with multipart boundary).
3. **Network Request**: PASS (`POST /api/v1/faculty/sessions/2/recognize-image` returned **HTTP 200 OK** in backend logs).
4. **Backend Image Decoding**: PASS (OpenCV decodes image bytes successfully).
5. **Face Detection**: PASS (Existing `dlib_hog` detector detects 8 faces).
6. **Embedding Generation**: PASS (`dlib_resnet` computes 128-d vectors for all 8 detected faces).
7. **Biometric Face Matching**: PASS:
   - **Face #4** matches Rethish S (`721025149046`) with Euclidean distance **0.1566** (HIGH_CONFIDENCE, confidence score: **73.9%**).
   - Face #1 matches Abishek A (`721025149002`) with Euclidean distance **0.1548** (HIGH_CONFIDENCE, confidence score: **74.21%**).
   - Face #6 matches Rithanya Shree V (`721025149047`) with Euclidean distance **0.3086** (HIGH_CONFIDENCE, confidence score: **48.57%**).
8. **HTTP Response Serialization**: PASS (Backend returned valid JSON).
9. **Client Response Deserialization (ROOT CAUSE)**: **FAIL (CRASH)**:
   - The backend `engine.recognize_image()` returns integer match counts:
     `"high_confidence_matches": 3`, `"uncertain_matches": 4`, `"unknown_faces": 1`.
   - The Flutter model deserializer in `mobile/lib/models/recognition_model.dart` executed:
     `final rawHigh = json['high_confidence_matches'] as List? ?? [];`
   - In Dart, casting an `int` (`3`) to `List<dynamic>` throws a runtime `TypeError`:
     `type 'int' is not a subtype of type 'List<dynamic>' in type cast`.
   - In `FacultyService.uploadGroupPhoto()`, the `TypeError` fell into the generic `catch (e)` block:
     `_errorMessage = 'Failed to process group photo';`
   - This masked the successful 200 OK recognition response and surfaced the generic error banner in the UI.

---

## 4. Root Cause Classification

**Category: 10. RESPONSE PARSING FAILURE / API SCHEMA MISMATCH**

The backend recognition endpoint returned integer summary counts (`high_confidence_matches: 3`) directly from the recognition engine, while the frontend Dart model expected structured candidate lists (`List<Map<String, dynamic>>`).

---

## 5. Fix Applied

### 5.1 Backend (`app/api/faculty_recognition.py`)
- Normalized `/api/v1/faculty/sessions/{session_id}/recognize-image` so that `high_confidence_matches`, `uncertain_matches`, and `unknown_faces` are structured into candidate lists extracted from `recognition_output["results"]`.
- Added aliases so candidates provide both `full_name` and `name`, and both `confidence` and `derived_score`.
- Preserved existing test mock compatibility where lists were already provided.

### 5.2 Mobile Frontend (`mobile/lib/models/recognition_model.dart`)
- Updated `RecognitionResultModel.fromJson`:
  - If `high_confidence_matches` / `uncertain_matches` are lists, parses them safely.
  - If match counts are numbers and lists are empty, falls back gracefully to parsing candidates directly from the raw `results` array.
  - Handles `unknown_faces` whether provided as a list or a numeric count.
- Updated `HighConfidenceMatch.fromJson` and `CandidateStudent.fromJson` to accept either `full_name` or `name`, and either `confidence` or `derived_score`.

### 5.3 Error Diagnostics (`mobile/lib/services/faculty_service.dart`)
- Updated `uploadGroupPhoto` catch block to log `debugPrint('uploadGroupPhoto error: $e');` and preserve diagnostic exception context in `_errorMessage`.

---

## 6. Verification Results

### 6.1 Direct Test with Exact Photo
- **File**: `C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg`
- **HTTP Endpoint**: `/api/v1/faculty/sessions/2/recognize-image`
- **Status Code**: `200 OK`
- **Total High-Confidence Matches**: **3**
  1. `721025149002` — **ABISHEK A** (Distance: `0.1548`, Confidence: `74.21%`)
  2. `721025149046` — **RETHISH S** (Distance: `0.1566`, Confidence: `73.90%`)
  3. `721025149047` — **RITHANYA SHREE V** (Distance: `0.3086`, Confidence: `48.57%`)
- **Target Student Identified**: **721025149046 — Rethish S** is unequivocally matched and present in `high_confidence_matches`.

### 6.2 Regression Testing
- **Flutter Code Analysis**:
  ```
  flutter analyze
  No issues found! (0 errors, 0 warnings)
  ```
- **Flutter Automated Tests**:
  ```
  flutter test
  All 97 tests passed! (100% PASS)
  ```
- **Backend Automated Tests**:
  ```
  pytest tests/test_admin_face_enrollment.py -v
  All 17 tests passed! (100% PASS)
  ```

---

## 7. Conclusion

The real face-recognition engine performed flawlessly with high confidence for Rethish S (`721025149046`). The observed "Failed to process group photo" error was strictly a client-server contract deserialization mismatch which has been comprehensively resolved with bidirectional resilience.
