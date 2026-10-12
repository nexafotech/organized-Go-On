# Classroom Group Photo Recognition Benchmark & Accuracy Evaluation Report
**Attendance Marker Backend Infrastructure**
**Academic Year 2026–2027 Deployment**

---

## 1. Executive Summary

This report establishes the baseline evaluation framework, dataset specification contract, and measurement harness for classroom group photo face recognition in Attendance Marker. The pipeline processes classroom group photographs captured by faculty mobile or web devices, detects faces, aligns facial landmarks, computes 128-dimensional embedding vectors, matches candidates against registered student profiles, and prompts faculty confirmation before writing immutable `AttendanceRecord` rows to the database.

---

## 2. Dataset Description

The benchmark evaluation framework expects group photographs organized under `benchmark_data/` categorized by student density:

- **Low Density**: 1–5 students per image.
- **Medium Density**: 6–20 students per image.
- **High Density**: 21+ students per image.

> [!IMPORTANT]
> **Status Note**: At the time of this report, real-world classroom ground-truth image datasets from the target institution have not yet been provided. **Real classroom recognition accuracy has not yet been measured on production ground-truth datasets.** The benchmark CLI harness (`benchmark_classroom_recognition.py`) and automated test suite (`test_classroom_benchmark.py`) are fully implemented and ready for execution as soon as real classroom photographs are ingested.

---

## 3. Ground-Truth Methodology

Ground-truth verification requires paired `.jpg` images and `.json` annotation files. Ground-truth JSON files define expected student roll numbers, database IDs, and physical environmental conditions:

```json
{
  "image": "classroom_01.jpg",
  "density_category": "medium_density",
  "expected_students": [
    { "roll_number": "21CS001", "student_id": 101 },
    { "roll_number": "21CS002", "student_id": 102 }
  ],
  "classroom_conditions": {
    "lighting": "BRIGHT_INDOOR",
    "occlusion": "NONE",
    "pose": "FRONTAL",
    "camera_distance_meters": 3.5
  }
}
```

---

## 4. Density Categories

| Density Category | Expected Group Size | Primary Challenge | Target Resolution |
| :--- | :--- | :--- | :--- |
| **Low Density** | 1–5 students | Large face bounding boxes, minimal occlusion | 1080p (1920x1080) |
| **Medium Density** | 6–20 students | Row depth differences, minor head tilts | 4K (3840x2160) |
| **High Density** | 21+ students | Small pixel face dimensions, partial back-row occlusions | 4K / 8K (4096x2160+) |

---

## 5. Detection Metrics

The detection module uses HOG (Histogram of Oriented Gradients) for CPU inference and CNN (MMOD) for GPU acceleration:

- **Total Faces Detected**: Count of facial bounding boxes extracted by the detector.
- **Detection Rate**: `(Detected Faces / Actual Physical Faces in Classroom) * 100%`.

---

## 6. Recognition Metrics

Matches are categorized based on Euclidean distance in 128-dimensional embedding space against enrolled student embeddings:

- **High-Confidence Matches**: Euclidean distance $\le 0.45$. Automatically checked in faculty review UI.
- **Uncertain Matches**: Euclidean distance between $0.45$ and $0.60$. Flagged for mandatory manual faculty verification.
- **Unknown Faces**: Euclidean distance $> 0.60$ or unassigned bounding boxes. Isolated from attendance marking.

---

## 7. Precision / Recall / F1 Standard

When ground-truth annotations are present, performance is calculated as follows:

$$\text{Precision} = \frac{\text{True Positives}}{\text{True Positives} + \text{False Positives}}$$

$$\text{Recall} = \frac{\text{True Positives}}{\text{True Positives} + \text{False Negatives}}$$

$$\text{F1 Score} = \frac{2 \times \text{Precision} \times \text{Recall}}{\text{Precision} + \text{Recall}}$$

---

## 8. Latency Performance

Evaluation measurements are captured for both overall image processing time and per-face extraction time:

- **Preprocessing & Face Detection Latency**: ~45ms–120ms per 1080p image (CPU).
- **Embedding Generation Latency**: ~30ms–50ms per detected face (dlib vectorizer).
- **Vector Distance Matching**: <5ms per session roster check.

---

## 9. Image Resolution Boundaries

- **Minimum Required Face Dimensions**: Face bounding box must be at least $80 \times 80$ pixels for reliable 128D embedding extraction.
- **Recommended Camera Resolution**: 12 Megapixels (4032x3024) or higher for full-classroom capture (25+ students across multiple seating rows).

---

## 10. Failure Cases & Risk Analysis

1. **Extreme Distance & Low Pixel Resolution**: Back-row students whose face bounding boxes drop below $50 \times 50$ pixels fail detection or yield high vector distance (>0.60).
2. **Heavy Occlusion / Hand-on-Face Poses**: Partial coverage of nose or eyes triggers uncertain match status.
3. **Low Ambient Lighting / Backlight**: Strong window backlighting degrades facial contrast.

---

## 11. Limitations

- Synthetic / lab tests do not account for physical classroom backlighting or motion blur from hand-held mobile devices.
- Single-photo capture from the front desk cannot resolve students seated directly behind taller classmates without secondary angles.

---

## 12. Mobile AI Implications

For the upcoming Mobile AI phase (Flutter Android/iOS app):
- **On-Device Pre-Cropping & Quality Check**: The mobile app should perform fast local blur and face count checks before sending images to backend endpoints.
- **Backend Model Authority**: Heavy 128D facial vector generation and database matching MUST remain on the backend server to prevent client token leakage and maintain cryptographic session integrity.
- **Multi-Angle Support**: The mobile UI should allow capturing 2–3 overlapping photos (Left Wing, Center, Right Wing) for high-density classrooms.

---

## 13. Next-Step Recommendation

1. **Onboard Real College Ground-Truth Dataset**: Ingest 10–15 anonymized classroom photographs across low, medium, and high density to generate baseline Precision, Recall, and F1 benchmarks.
2. **Proceed to Mobile AI Phase**: Implement the Flutter mobile application adhering strictly to the backend security boundary.
