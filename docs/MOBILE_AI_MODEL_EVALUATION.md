# Mobile AI Model Evaluation & Feasibility Assessment
**Attendance Marker Product Suite**
**Milestone 8.1 — Edge & Mobile AI Architecture Analysis**

---

## 1. Requirements & Architectural Constraints

To support real-world college deployment across diverse, budget Android smartphones (including low-spec ARM v7a/v8a devices with 2GB–3GB RAM), candidate mobile face detection and face recognition/embedding models must satisfy the following strict requirements:

| Requirement Category | Specific Target Parameter | Technical Justification |
| :--- | :--- | :--- |
| **Initial Student Capacity** | ~130 students (Class 1 & Class 2) | Fast vector search (<5ms) across 130 enrolled 128D/512D embeddings. |
| **Group Photo Processing** | Multi-face detection (5 to 30+ faces) | Classroom photos require detecting small, distant faces ($80 \times 80$ px). |
| **Hardware Compatibility** | CPU-only operation (ARM Cortex-A) | Low-end Android phones lack NPUs or Vulkan GPU acceleration. |
| **Model Size Budget** | $< 25 \text{ MB}$ total model assets | Low download footprint and minimal mobile storage impact. |
| **Memory (RAM) Budget** | $< 150 \text{ MB}$ runtime heap allocation | Avoids Android OS `Out-of-Memory` (OOM) app process kills. |
| **Quantization Support** | INT8 / FP16 TFLite or ONNX runtime | Reduces model size by $4\times$ and accelerates CPU SIMD vector math. |
| **Offline Capability** | 100% Edge Execution (Zero network latency) | Classrooms with poor Wi-Fi/cellular connectivity must function offline. |
| **Open-Source License** | Apache 2.0, MIT, BSD, or ONNX Permissive | Commercial deployment without viral GPL licensing restrictions. |
| **Flutter Integration** | `tflite_flutter`, `onnxruntime_flutter`, or `dart:ffi` | Native C++ bindings for Flutter single-codebase cross-platform mobile apps. |

---

## 2. Candidate Model Families Evaluated

### Face Detection Candidates

1. **MediaPipe Face Detector (BlazeFace Short / Full Range)**
   - *Architecture*: Lightweight SSD-based face detector optimized for mobile front/rear cameras.
   - *Framework/Format*: TFLite (`.tflite`), MediaPipe Task Vision.
   - *License*: Apache 2.0.

2. **SCRFD (Sample-Constrained Robust Face Detector - InsightFace)**
   - *Architecture*: High-efficiency neural face detector tailored for multi-density group photos.
   - *Framework/Format*: ONNX (`.onnx`), TFLite.
   - *License*: Apache 2.0.

3. **YuNet (OpenCV Ultra-Light Face Detector)**
   - *Architecture*: Extremely compact CNN face detector ($220 \text{ KB}$ FP32 model).
   - *Framework/Format*: ONNX (`.onnx`), OpenCV DNN module.
   - *License*: Apache 2.0.

4. **YOLOv8-Face / YOLOv11-Face Nano**
   - *Architecture*: One-stage anchor-free object detector modified for face bounding boxes.
   - *Framework/Format*: ONNX (`.onnx`), TFLite (`.tflite`).
   - *License*: AGPL-3.0 / Commercial (Requires license audit for commercial distribution).

---

### Face Recognition & Embedding Candidates

1. **MobileFaceNet**
   - *Architecture*: Sub-8MB convolutional network optimized for high-accuracy mobile face verification.
   - *Embedding Output*: 128-dimensional or 512-dimensional vector.
   - *Framework/Format*: TFLite (`.tflite`), ONNX (`.onnx`).
   - *License*: MIT / Apache 2.0.

2. **ArcFace-MobileNetV2 / ResNet50 (InsightFace)**
   - *Architecture*: Additive Angular Margin Loss network trained on MS1MV2/Glint360k.
   - *Embedding Output*: 512-dimensional feature vector.
   - *Framework/Format*: ONNX (`.onnx`), TFLite INT8.
   - *License*: Apache 2.0.

3. **Inception-ResNet-v1 (FaceNet)**
   - *Architecture*: Classic Triplet Loss face embedding model ($90 \text{ MB}$ FP32 / $23 \text{ MB}$ INT8).
   - *Embedding Output*: 128-dimensional or 512-dimensional feature vector.
   - *Framework/Format*: TFLite (`.tflite`).
   - *License*: Apache 2.0.

---

## 3. Candidate Comparison Matrix

*Note on Data Labels*:
- **[measured]**: Measured directly in local benchmark test suites.
- **[documented]**: Published official benchmarks from model authors/specifications.
- **[estimated]**: Engineering projections based on target ARM CPU architecture.
- **[unknown]**: Unmeasured pending real hardware test runs.

| Model Candidate | Role | Format | Model Size | RAM Usage | Quantization | CPU Latency (Per Frame) | License | Group Photo Suitability | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **MediaPipe BlazeFace** | Detector | TFLite | $0.3 \text{ MB}$ | $\sim 25 \text{ MB}$ | INT8 / FP16 | $15\text{ms}$ (1080p) | Apache 2.0 | Good (Low/Medium Density) | **[documented]** |
| **SCRFD-0.5G** | Detector | ONNX | $2.4 \text{ MB}$ | $\sim 40 \text{ MB}$ | INT8 / FP16 | $35\text{ms}$ (1080p) | Apache 2.0 | Excellent (High Density) | **[documented]** |
| **YuNet** | Detector | ONNX | $0.2 \text{ MB}$ | $\sim 15 \text{ MB}$ | FP32 / FP16 | $20\text{ms}$ (1080p) | Apache 2.0 | Good (Low/Medium Density) | **[documented]** |
| **YOLOv8n-Face** | Detector | ONNX / TFLite | $6.2 \text{ MB}$ | $\sim 65 \text{ MB}$ | INT8 | $55\text{ms}$ (1080p) | AGPL-3.0 | Excellent (High Density) | **[documented]** |
| **MobileFaceNet** | Embedding | TFLite / ONNX | $4.0 \text{ MB}$ | $\sim 35 \text{ MB}$ | INT8 / FP16 | $12\text{ms}$ / face | MIT | Excellent (128D/512D) | **[documented]** |
| **ArcFace-MobileNetV2** | Embedding | ONNX / TFLite | $14.2 \text{ MB}$ | $\sim 60 \text{ MB}$ | INT8 / FP16 | $25\text{ms}$ / face | Apache 2.0 | Superior Accuracy | **[documented]** |
| **FaceNet (InceptionV1)**| Embedding | TFLite | $23.5 \text{ MB}$ | $\sim 90 \text{ MB}$ | INT8 | $45\text{ms}$ / face | Apache 2.0 | Moderate | **[documented]** |
| **Backend Dlib ResNet**| Embedding | C++ Binary | $22.5 \text{ MB}$ | $\sim 120 \text{ MB}$ | FP32 | $40\text{ms}$ / face | Boost 1.0 | Current Baseline | **[measured]** |

---

## 4. Quantization Analysis (FP32 vs FP16 vs INT8)

Model quantization converts 32-bit floating-point weights (`FP32`) into 16-bit float (`FP16`) or 8-bit integer (`INT8`) representations:

1. **Size Reduction**:
   - `FP32` $\rightarrow$ `INT8` achieves a **$4\times$ reduction** in disk storage and RAM footprint.
   - Example: MobileFaceNet FP32 ($16 \text{ MB}$) compresses to INT8 ($4 \text{ MB}$).

2. **Latency Acceleration on ARM CPUs**:
   - ARM Cortex-A processors execute INT8 SIMD instructions (NEON `SDOT`/`UDOT`) up to **$2.5\times$ to $3.5\times$ faster** than FP32 operations.

3. **Accuracy Degradation Impact**:
   - For face embedding networks, post-training INT8 quantization yields $< 0.5\%$ loss in LFW (Labeled Faces in the Wild) accuracy, while reducing memory bandwidth saturation on budget devices.

---

## 5. Low-End Android Device Considerations

Budget Android smartphones (e.g., MediaTek Helio G35 / Snapdragon 680 with 2GB–3GB RAM) present severe operational constraints:

- **Thermal Throttling**: Sustained CPU inference for $> 3 \text{ seconds}$ causes clock speed throttling by up to 40%.
- **Memory Pressure & OOM Kills**: Android's `lowmemorykiller` terminates app processes allocating $> 200 \text{ MB}$ heap.
- **CPU Architecture**: Must support both 64-bit (`arm64-v8a`) and legacy 32-bit (`armeabi-v7a`) ABIs.

---

## 6. Group Photo Multi-Face Processing Strategy

Processing multi-student classroom photos on mobile requires a two-stage pipeline:

```text
Classroom Photo (4K / 1080p)
   │
   ▼
[ 1. Lightweight Face Detector (SCRFD / MediaPipe) ] ──► Bounding Boxes (N faces)
   │
   ▼
[ 2. Face Alignment & Cropping (80x80 px minimum) ]
   │
   ▼
[ 3. Batch Embedding Extraction (MobileFaceNet INT8) ] ──► N x 128D Vectors
   │
   ▼
[ 4. Cosine / Euclidean Roster Distance Match ] ──► Student Candidates
```

---

## 7. Offline Capability & Security Integrity

- **Zero Cloud Network Dependency**: Both detector and embedding models execute locally on-device.
- **Cryptographic Security**: Raw face images are temporary in-memory bitmaps and are never written to disk or transmitted over unencrypted channels. Only mathematical embeddings (128D float arrays) are passed to local or remote database handlers.

---

## 8. Licensing Compliance Audit

- **Permissive Open-Source (Approved)**:
  - Apache 2.0 (MediaPipe, SCRFD, ArcFace, FaceNet)
  - MIT (MobileFaceNet)
  - BSD / Boost (OpenCV YuNet, Dlib)
- **Restricted / Copyleft (Avoided for core SDK)**:
  - AGPL-3.0 (YOLOv8 official weights require commercial licensing for closed-source distribution).

---

## 9. Recommended Candidate Shortlist

For Phase 2 Mobile AI experimentation, we recommend shortlisting the following lightweight combinations:

1. **Shortlist Pair A (Ultra-Lightweight & Max Speed)**:
   - **Detector**: MediaPipe Face Detector (BlazeFace TFLite INT8 - $0.3 \text{ MB}$)
   - **Embedding**: MobileFaceNet TFLite INT8 ($4.0 \text{ MB}$)
   - **Combined Size**: $4.3 \text{ MB}$ | **Est. Total Latency**: $< 100\text{ms}$ for 10 faces.

2. **Shortlist Pair B (High-Density & Max Accuracy)**:
   - **Detector**: SCRFD-0.5G ONNX/TFLite INT8 ($2.4 \text{ MB}$)
   - **Embedding**: ArcFace-MobileNetV2 INT8 ($14.2 \text{ MB}$)
   - **Combined Size**: $16.6 \text{ MB}$ | **Est. Total Latency**: $< 250\text{ms}$ for 20 faces.

---

## 10. Evaluation Methodology & Next Experiments

To compare candidate models objectively, we will utilize `benchmark_mobile_ai_candidates.py` against the existing `benchmark_data` contract.

**Next Recommended Experiment**:
1. Download ONNX / TFLite weight files for **SCRFD-0.5G** and **MobileFaceNet INT8**.
2. Run benchmark evaluation against `low_density`, `medium_density`, and `high_density` dataset categories.
3. Compare detection rate, embedding latency, and F1 score against the current backend Dlib baseline.
