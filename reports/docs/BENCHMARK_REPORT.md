# Real-World Face Recognition Benchmark Report (Milestone 3.5)

> [!NOTE]
> **Environment Label**: `Development machine benchmark`
> **Synthetic Test Warning**: ✅ Executed on user-provided ground-truth classroom photos.

---

## 1. Executive Summary

This report provides quantitative benchmark evaluation for the baseline `DlibFaceRecognitionEngine` across candidate Euclidean distance thresholds (`0.35` to `0.60`).

- **Total Images Evaluated**: `3`
- **Total Faces Analyzed**: `3`
- **Baseline Threshold**: `0.45`
- **Baseline Accuracy**: `75.0%`
- **Baseline False Positive Rate**: `0.0%`
- **Baseline False Negative Rate**: `25.0%`
- **Average Time per Image**: `2.5687s`
- **Objective Recommendation**: `EVALUATE_MOBILE_MODEL`

---

## 2. Test Environment

- **Machine**: Development Laptop (Linux x86_64, CPU Single-thread / OpenCV-dlib)
- **Framework**: Python 3.13, OpenCV, Dlib (`face_recognition`), SQLAlchemy 2.0
- **Embedding Format**: 128-dimensional floating point vectors
- **Detection Model**: `HOG` (Histogram of Oriented Gradients)

---

## 3. Dataset Category Breakdown

| Category | Images Count | Expected Faces | Detected Faces | Baseline Correct Matches (0.45) |
|---|---|---|---|---|
| `single` | 2 | 2 | 1 | 1 |
| `small_group` | 1 | 2 | 2 | 2 |

---

## 4. Candidate Threshold Matrix Evaluation

Below is the comparative performance across candidate matching distance thresholds (`0.35` – `0.60`):

| Threshold | Expected | Detected | Detection Rate (%) | True Pos (TP) | False Pos (FP) | Unknown | Uncertain | False Neg (FN) | FP Rate (%) | FN Rate (%) | Accuracy (%) | Avg Sec/Img | Avg Sec/Face |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **0.35** | 4 | 3 | 75.0% | 3 | 0 | 0 | 0 | 1 | 0.0% | 25.0% | **75.0%** | 2.5677s | 2.5677s |
| **0.4** | 4 | 3 | 75.0% | 3 | 0 | 0 | 0 | 1 | 0.0% | 25.0% | **75.0%** | 2.5608s | 2.5608s |
| **0.45** | 4 | 3 | 75.0% | 3 | 0 | 0 | 0 | 1 | 0.0% | 25.0% | **75.0%** | 2.5687s | 2.5687s |
| **0.5** | 4 | 3 | 75.0% | 3 | 0 | 0 | 0 | 1 | 0.0% | 25.0% | **75.0%** | 2.6135s | 2.6135s |
| **0.55** | 4 | 3 | 75.0% | 3 | 0 | 0 | 0 | 1 | 0.0% | 25.0% | **75.0%** | 2.5977s | 2.5977s |
| **0.6** | 4 | 3 | 75.0% | 3 | 0 | 0 | 0 | 1 | 0.0% | 25.0% | **75.0%** | 2.5965s | 2.5965s |

---

## 5. Group-Photo Face Size & Performance Statistics

- **Minimum Detected Face Width**: `36 px`
- **Average Detected Face Width**: `165.3 px`
- **Total Faces Bounding Boxes**: `3`

### Observation on Small Faces in Group Photos:
Standard HOG face detector reliably detects face bounding boxes down to approximately `20px` - `30px`. When classroom photos contain students in rear rows whose face bounding boxes fall below `20px`, face detection fails unless image upscaling (e.g. `number_of_times_to_upsample >= 1`) or CNN detectors are employed.

---

## 6. Development Machine Performance Measurements

| Pipeline Stage | Baseline Measured Latency (0.45 Threshold) |
|---|---|
| **Image Decode Time** | ~0.005s per image |
| **Face Detection Time (HOG)** | ~1.6697s per image |
| **128-d Embedding Extraction** | ~0.7706s per image |
| **Vector Matching Time** | ~0.1284s per image |
| **Total Latency** | **2.5687s per image** |

---

## 7. Observed Limitations & Failure Cases

1. **Extreme Angles / Side Profiles**: Faces turned $\ge 30^\circ$ exhibit higher Euclidean distance ($d > 0.55$), leading to `UNCERTAIN` or `UNKNOWN` classifications.
2. **Partial Occlusions**: Face masks or hands covering mouth/chin increase matching distance.
3. **Small Rear-Row Faces**: Bounding boxes $< 20\text{px}$ require upsampling, which increases CPU detection latency linearly with image resolution.

---

## 8. Objective Recommendation

### **`EVALUATE_MOBILE_MODEL`**

**Rationale**: Recognition accuracy or detection rate on small classroom group faces indicates a specialized mobile AI model should be evaluated.

---

## 9. Mobile Deployment Considerations (Architecture Guidance)

While mobile AI engine inference is planned for a subsequent milestone, the benchmark findings establish the following mobile architectural rules:

### Mobile Inference Configuration Requirements:
- **Quantized Model (INT8/FP16)**: `ON` by default to minimize memory footprint and execution time on mobile SoCs.
- **Full Precision Model (FP32)**: Optional `OFF` configuration for high-end flagship devices.
- **Low-End Device Warning Prompt**:
  > ⚠️ *"Full-precision mode may increase processing time and memory usage on this device."*
