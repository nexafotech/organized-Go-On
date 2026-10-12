# Milestone 14D: Real Classroom Recognition Benchmark Report

**Document ID:** `docs/RECOGNITION_ENGINE_BENCHMARK_14D.md`  
**Date:** September 25, 2026  
**Status:** Complete — Empirical Benchmark Report  
**Authors:** AI Engineering Team  
**Scope:** Comparative benchmark of Candidate `ScrfdArcFaceRecognitionEngine` versus Baseline `DlibFaceRecognitionEngine` on official college classroom photographs.

---

## 1. Dataset Summary

The benchmark dataset comprises all 6 official college classroom photographs located in `college_data/official_photos/`. Source files were evaluated without modification, cropping, or lossy recompression.

| # | Filename | Resolution | Megapixels | File Size (Bytes) | File Size (MB) | Format | Status |
|---|---|---|---|---|---|---|---|
| 1 | `IMG_20260819_143612167.jpg.jpeg` | 3072 × 4096 | 12.58 MP | 2,584,492 | 2.46 MB | JPEG | `[MEASURED]` |
| 2 | `IMG_20260819_143705541.jpg.jpeg` | 3072 × 4096 | 12.58 MP | 2,682,076 | 2.56 MB | JPEG | `[MEASURED]` |
| 3 | `IMG_20260819_143731882.jpg.jpeg` | 3072 × 4096 | 12.58 MP | 2,573,536 | 2.45 MB | JPEG | `[MEASURED]` |
| 4 | `IMG_20260819_143741100.jpg.jpeg` | 3072 × 4096 | 12.58 MP | 1,877,464 | 1.79 MB | JPEG | `[MEASURED]` |
| 5 | `IMG_20260819_143843786.jpg.jpeg` | 3072 × 4096 | 12.58 MP | 2,469,636 | 2.36 MB | JPEG | `[MEASURED]` |
| 6 | `IMG_20260819_144007736.jpg.jpeg` | 4096 × 3072 | 12.58 MP | 3,243,158 | 3.09 MB | JPEG | `[MEASURED]` |
| **Total** | **6 Photographs** | — | **75.48 MP** | **15,430,362** | **14.71 MB** | — | `[MEASURED]` |

---

## 2. Test Environment

Benchmark evaluations were executed in the development environment under standard non-preemptible process priorities.

| Specification | Configuration | Tag |
|---|---|---|
| Operating System | Windows 11 AMD64 (Version 10.0.26100) | `[MEASURED]` |
| Host CPU | x86_64 Architecture with AVX2 instruction support | `[MEASURED]` |
| Dedicated GPU | NVIDIA GeForce RTX 4050 Laptop GPU (6141 MiB VRAM) | `[MEASURED]` |
| GPU Driver Version | NVIDIA 572.40 | `[MEASURED]` |
| Python Environment | Python 3.13.15 (64-bit) in `.venv` | `[MEASURED]` |
| ONNX Runtime Version | 1.30.0 (`onnxruntime` CPU engine) | `[MEASURED]` |
| Execution Provider | `CPUExecutionProvider` | `[MEASURED]` |
| GPU Provider Status | Unavailable in ONNX Runtime; PyTorch detects CUDA, but prebuilt `onnxruntime-gpu` wheels for Python 3.13 lack user-mode cuDNN runtime DLLs. Evaluated entirely on CPU. | `[MEASURED]` |

---

## 3. Baseline Dlib Configuration

The baseline production face recognition engine implements dlib's classic HOG-SVM detector and deep ResNet metric learning network.

| Component / Parameter | Specification | Tag |
|---|---|---|
| Engine Identifier | `dlib` (`DlibFaceRecognitionEngine`) | `[MEASURED]` |
| Face Detector | `dlib.get_frontal_face_detector()` (Classic HOG + Linear SVM) | `[MEASURED]` |
| Facial Landmark Model | `shape_predictor_68_face_landmarks.dat` (68 landmarks) | `[MEASURED]` |
| Recognition Model | `dlib_face_recognition_resnet_model_v1.dat` | `[MEASURED]` |
| Input Dimensions | Native unscaled image (up to 4096 × 3072) | `[MEASURED]` |
| Embedding Vector Dimensions | 128 float values | `[MEASURED]` |
| Distance Metric | Euclidean Distance ($L_2$) | `[MEASURED]` |
| Production Match Threshold | `MATCH_THRESHOLD = 0.45` | `[MEASURED]` |
| Production Uncertain Threshold | `MAX_DISTANCE = 0.60` | `[MEASURED]` |
| Normalization | Euclidean vector | `[MEASURED]` |

---

## 4. Candidate SCRFD + ArcFace Configuration

The candidate engine decouples detection and recognition into specialized ONNX deep neural networks.

| Component / Parameter | Specification | Tag |
|---|---|---|
| Engine Identifier | `scrfd_arcface` (`ScrfdArcFaceRecognitionEngine`) | `[MEASURED]` |
| Face Detector Model | `det_10g.onnx` (SCRFD-10G with 5-point landmark heads) | `[MEASURED]` |
| SHA-256 Hash (`det_10g.onnx`) | `5838f7fe05d15a510531c3b12386fd107a60ae52655fa4fcc345a3038b31a89c` | `[MEASURED]` |
| Detection Input Processing | Letterbox aspect-ratio preserving resize (stride 32 padding) | `[MEASURED]` |
| Detection Confidence Threshold | `0.50` | `[MEASURED]` |
| NMS IoU Threshold | `0.40` | `[MEASURED]` |
| Landmark Format | 5 Facial Keypoints (Left Eye, Right Eye, Nose, Left Mouth, Right Mouth) | `[MEASURED]` |
| Landmark Alignment Method | Partial Affine Similarity Transform (`cv2.estimateAffinePartial2D`) | `[MEASURED]` |
| Alignment Target Template | Standard ArcFace 112 × 112 coordinate matrix | `[MEASURED]` |
| Face Recognition Model | `w600k_r50.onnx` (ArcFace ResNet-50 backbone, WebFace600K) | `[MEASURED]` |
| SHA-256 Hash (`w600k_r50.onnx`) | `4c06341c33c2a66652a611ae10e0db12e06972e013a3db9c6a65db2642fe544b` | `[MEASURED]` |
| Recognition Input Dimensions | 112 × 112 × 3 (RGB normalized) | `[MEASURED]` |
| Embedding Vector Dimensions | 512 float values | `[MEASURED]` |
| Normalization | $L_2$ Unit Normalization ($\|v\|_2 = 1.0$) | `[MEASURED]` |
| Distance Metric | Cosine Similarity | `[MEASURED]` |
| Candidate Match Threshold | `high_confidence = 0.50` (Evaluation only) | `[MEASURED]` |
| Candidate Uncertain Threshold | `uncertain = 0.35` (Evaluation only) | `[MEASURED]` |

---

## 5. Face Detection Benchmark Results

Both engines were evaluated across all 6 classroom photographs. Faces were categorized into density tiers: Single Person (1 face) and Medium Density (6–15 faces).

| Photograph | Dlib Detected | SCRFD Detected | SCRFD Conf. Range | Smallest Face (SCRFD) | Largest Face (SCRFD) | Density Tier | Status |
|---|---|---|---|---|---|---|---|
| `IMG_20260819_143612167.jpg.jpeg` | 1 | 1 | 0.8081 | 746 × 921 px (687,066 px²) | 746 × 921 px (687,066 px²) | Single Person | `[MEASURED]` |
| `IMG_20260819_143705541.jpg.jpeg` | 1 | 1 | 0.8383 | 788 × 1037 px (817,156 px²) | 788 × 1037 px (817,156 px²) | Single Person | `[MEASURED]` |
| `IMG_20260819_143731882.jpg.jpeg` | 1 | 1 | 0.8814 | 682 × 868 px (591,976 px²) | 682 × 868 px (591,976 px²) | Single Person | `[MEASURED]` |
| `IMG_20260819_143741100.jpg.jpeg` | 1 | 1 | 0.8929 | 699 × 929 px (649,371 px²) | 699 × 929 px (649,371 px²) | Single Person | `[MEASURED]` |
| `IMG_20260819_143843786.jpg.jpeg` | 1 | 1 | 0.8550 | 770 × 979 px (753,830 px²) | 770 × 979 px (753,830 px²) | Single Person | `[MEASURED]` |
| `IMG_20260819_144007736.jpg.jpeg` | 10 | 10 | 0.8782 – 0.9215 | 147 × 160 px (23,520 px²) | 181 × 195 px (35,295 px²) | Medium (6–15) | `[MEASURED]` |
| **Total Detected Faces** | **15** | **15** | **0.8081 – 0.9215** | — | — | — | `[MEASURED]` |

### Detection Findings:
1. **Detection Parity:** Both Dlib and SCRFD detected exactly **15 faces** across the 6 photos (100% detection count parity).
2. **High-Confidence Predictions:** Every face detected by SCRFD possessed confidence exceeding `0.80` (mean confidence across multi-person classroom: `0.8969`), well above the candidate acceptance threshold of `0.50`.
3. **Small-Face Capability:** In the wide classroom setting (`IMG_20260819_144007736`), SCRFD reliably detected distant student faces down to 147 × 160 px without spurious false-positive detections.

---

## 6. Landmark & Alignment Benchmark Results

Landmark alignment is required before feeding face crops into the ArcFace recognition model.

| Metric | Measured Value | Tag |
|---|---|---|
| Landmark Format | 5 Facial Keypoints: Left Eye, Right Eye, Nose Tip, Left Mouth Corner, Right Mouth Corner | `[MEASURED]` |
| Alignment Algorithm | Similarity Transform via Least Squares Partial Affine (`cv2.estimateAffinePartial2D`) | `[MEASURED]` |
| Target Crop Output | 112 × 112 × 3 RGB canonical face crop | `[MEASURED]` |
| Total SCRFD Detected Faces | 15 faces | `[MEASURED]` |
| Successfully Aligned Faces | 15 faces | `[MEASURED]` |
| Alignment Failures | 0 faces | `[MEASURED]` |
| Failure Rate | **0.0%** | `[MEASURED]` |
| Landmark Validity Check | 15 / 15 faces (100.0% keypoints enclosed strictly within face bounds) | `[MEASURED]` |

---

## 7. Embedding Extraction Benchmark Results

Embeddings were extracted for all 15 detected faces using both engines.

| Metric | Baseline Dlib | Candidate SCRFD + ArcFace | Tag |
|---|---|---|---|
| Output Vector Dimensionality | 128 float values | 512 float values | `[MEASURED]` |
| $L_2$ Normalization Verification | Norm varies by face | **1.0000** ($\pm 10^{-6}$) on all 15 vectors | `[MEASURED]` |
| Total Generated Embeddings | 15 | 15 | `[MEASURED]` |
| Failed Embeddings | 0 | 0 | `[MEASURED]` |
| Per-Face Embedding Latency (Mean) | **441.17 ms** | **130.74 ms** | `[MEASURED]` |
| Per-Face Embedding Latency (Median) | **437.47 ms** | **123.03 ms** | `[MEASURED]` |
| Per-Face Embedding Latency (p95) | **457.31 ms** | **178.59 ms** | `[MEASURED]` |
| Extraction Latency Advantage | Baseline | **~3.4× Faster per face** | `[MEASURED]` |

---

## 8. Latency Comparison

Latency measurements isolate cold-start loading, warm detection, and end-to-end pipeline execution on 12.58 MP classroom photographs.

### 8.1 Cold-Start Initialization Latency

| Engine | Cold-Start Initialization Time | Speedup Factor | Tag |
|---|---|---|---|
| Baseline Dlib | 11,043.56 ms (~11.04 s) | 1.0× (Baseline) | `[MEASURED]` |
| Candidate SCRFD + ArcFace | 762.88 ms (~0.76 s) | **14.47× Faster** | `[MEASURED]` |

*Note: Dlib cold start includes loading 68-point shape predictor (99.7 MB) and ResNet face recognition weights (21.4 MB) plus C++ wrapper initializations. SCRFD+ArcFace instantiates lightweight ONNX Runtime CPU session graphs.*

### 8.2 Warm Detection Latency (12.58 MP Images)

| Metric | Baseline Dlib (HOG) | Candidate SCRFD (10G ONNX) | Speedup Factor | Tag |
|---|---|---|---|---|
| Detection Latency (Mean) | 10,213.69 ms | **132.62 ms** | **77.01× Faster** | `[MEASURED]` |
| Detection Latency (Median) | 10,210.73 ms | **132.83 ms** | **76.87× Faster** | `[MEASURED]` |
| Detection Latency (p95) | 10,469.10 ms | **140.66 ms** | **74.43× Faster** | `[MEASURED]` |

*Note: Dlib's CPU HOG detector scales with pixel area ($3072 \times 4096 = 12.58\text{ MP}$), requiring ~10.2 seconds per frame. SCRFD's letterbox preprocessing and convolutional stride structure evaluate the 12.58 MP image in ~132 ms.*

### 8.3 Total Warm Pipeline Latency (Detection + Alignment + Embedding)

| Photograph Type | Baseline Dlib Pipeline | SCRFD + ArcFace Pipeline | Speedup Factor | Tag |
|---|---|---|---|---|
| Single Face (Images 1–5 Avg) | ~10,697.01 ms | **~259.05 ms** | **41.29× Faster** | `[MEASURED]` |
| 10 Faces (Image 6) | 14,414.68 ms | **1,461.57 ms** | **9.86× Faster** | `[MEASURED]` |
| Overall Dataset Mean | 11,316.61 ms | **459.47 ms** | **24.63× Faster** | `[MEASURED]` |
| Overall Dataset Median | 10,723.22 ms | **259.75 ms** | **41.28× Faster** | `[MEASURED]` |
| Overall Dataset p95 | 13,503.00 ms | **1,164.28 ms** | **11.60× Faster** | `[MEASURED]` |

---

## 9. Memory Consumption

Process memory footprint was measured using OS-level process working set monitoring.

| Metric | Measured Working Set | Attributed Component | Tag |
|---|---|---|---|
| Process Baseline Working Set | 173.64 MB | Base Python 3.13 process, imports & database models | `[MEASURED]` |
| Peak Working Set (SCRFD Warmup) | 730.02 MB | SCRFD session + ArcFace session + 12.58 MP image buffers | `[MEASURED]` |
| Peak Working Set (Dlib Warmup) | 1,408.42 MB | Dlib 12 MP HOG pyramid buffers + Shape Predictor + ResNet | `[MEASURED]` |
| Final Steady-State Working Set | 1,031.55 MB | Both engines co-resident in process memory | `[MEASURED]` |
| Additional Attributed Memory (SCRFD) | ~556.38 MB | ONNX runtime weights + internal scratch tensors | `[MEASURED]` |

---

## 10. Detection Failure & Edge Case Analysis

1. **False Positives:** Neither engine produced false positive detections across the entire dataset. Whiteboard text, door frames, clothing patterns, and background furniture did not trigger false detections.
2. **False Negatives:**
   - Single-person photos (Images 1–5): 0 false negatives. Both engines achieved 100% recall.
   - Multi-person photo (Image 6): Both engines detected exactly 10 student faces seated across multiple rows. No visible student faces were missed by SCRFD.
3. **Small-Scale Distant Faces:** In Image 6, student faces ranged from 23,520 px² to 35,295 px² (approximately $147 \times 160\text{ px}$). SCRFD demonstrated confidence scores above 0.87 for all 10 students, verifying high sensitivity for classroom seating layouts.
4. **Head Pose and Off-Angle Alignment:** Off-angle student head poses in Image 6 produced valid 5-point landmark coordinates that successfully aligned to canonical ArcFace templates with 0% transform failures.

---

## 11. Identity Recognition Evaluation & Limitation Note

> [!IMPORTANT]
> **Definitive Ground Truth Limitation:**
> In the production database (`attendance_system.db`), the `face_embeddings` table currently contains **0 records** (`count = 0`) `[MEASURED]`.
> No production student face embeddings have been registered or linked to student enrollment records.
> Consequently, **identity recognition metrics (True Positive Identification Rate, False Match Rate, Rank-1 Recognition Accuracy) cannot be empirically measured or reported** without fabricating unverified ground truth.
> Per strict project guidelines, identity accuracy is designated as `[NOT AVAILABLE]`. Milestone 14D focuses strictly on empirical detection, landmark alignment, embedding extraction, latency, and memory consumption.

---

## 12. Production Threshold Status

| Parameter | Engine | Configured Value | Status | Tag |
|---|---|---|---|---|
| Active Production Engine | Baseline | `FACE_RECOGNITION_ENGINE=dlib` | **Production Active** | `[MEASURED]` |
| Production Match Threshold | Dlib | `MATCH_THRESHOLD = 0.45` | **Production Active** | `[MEASURED]` |
| Production Uncertain Threshold | Dlib | `MAX_DISTANCE = 0.60` | **Production Active** | `[MEASURED]` |
| Candidate Match Threshold | SCRFD + ArcFace | `high_confidence = 0.50` | Development / Evaluation Only | `[MEASURED]` |
| Candidate Uncertain Threshold | SCRFD + ArcFace | `uncertain = 0.35` | Development / Evaluation Only | `[MEASURED]` |

*No production switch or cutover has taken place. The candidate SCRFD + ArcFace engine remains decoupled and evaluated in development mode.*

---

## 13. Raw Benchmark Measurements Table

| Image Filename | Engine | Faces | Smallest Face (px) | Largest Face (px) | Det. Latency (ms) | Emb. Latency / Face (ms) | Total Warm Pipeline (ms) | Peak WS (MB) | Tag |
|---|---|---|---|---|---|---|---|---|---|
| `IMG_20260819_143612167.jpg.jpeg` | SCRFD | 1 | 746 × 921 | 746 × 921 | 132.59 | 123.31 | 255.90 | 730.02 | `[MEASURED]` |
| `IMG_20260819_143612167.jpg.jpeg` | Dlib | 1 | 798 × 799 | 798 × 799 | 10,328.13 | 439.83 | 10,767.96 | 1,407.99 | `[MEASURED]` |
| `IMG_20260819_143705541.jpg.jpeg` | SCRFD | 1 | 788 × 1037 | 788 × 1037 | 132.79 | 127.64 | 260.43 | 730.02 | `[MEASURED]` |
| `IMG_20260819_143705541.jpg.jpeg` | Dlib | 1 | 799 × 798 | 799 × 798 | 10,198.41 | 444.45 | 10,642.86 | 1,407.99 | `[MEASURED]` |
| `IMG_20260819_143731882.jpg.jpeg` | SCRFD | 1 | 682 × 868 | 682 × 868 | 131.42 | 140.98 | 272.40 | 730.02 | `[MEASURED]` |
| `IMG_20260819_143731882.jpg.jpeg` | Dlib | 1 | 799 × 798 | 799 × 798 | 10,186.67 | 441.03 | 10,627.70 | 1,407.99 | `[MEASURED]` |
| `IMG_20260819_143741100.jpg.jpeg` | SCRFD | 1 | 699 × 929 | 699 × 929 | 136.04 | 123.03 | 259.07 | 730.02 | `[MEASURED]` |
| `IMG_20260819_143741100.jpg.jpeg` | Dlib | 1 | 799 × 798 | 799 × 798 | 10,290.76 | 462.30 | 10,753.07 | 1,407.99 | `[MEASURED]` |
| `IMG_20260819_143843786.jpg.jpeg` | SCRFD | 1 | 770 × 979 | 770 × 979 | 123.82 | 123.65 | 247.47 | 730.02 | `[MEASURED]` |
| `IMG_20260819_143843786.jpg.jpeg` | Dlib | 1 | 799 × 798 | 799 × 798 | 10,238.19 | 455.18 | 10,693.37 | 1,407.99 | `[MEASURED]` |
| `IMG_20260819_144007736.jpg.jpeg` | SCRFD | 10 | 147 × 160 | 181 × 195 | 139.04 | 132.25 | 1,461.57 | 730.02 | `[MEASURED]` |
| `IMG_20260819_144007736.jpg.jpeg` | Dlib | 10 | 129 × 129 | 185 × 186 | 10,039.99 | 437.47 | 14,414.68 | 1,408.42 | `[MEASURED]` |

---

## 14. Aggregate Benchmark Measurements Table

| Performance Dimension | Baseline Dlib | Candidate SCRFD + ArcFace | Empirical Comparison / Ratio | Tag |
|---|---|---|---|---|
| Total Detected Faces | 15 faces | 15 faces | 100% parity | `[MEASURED]` |
| Cold-Start Latency | 11,043.56 ms | 762.88 ms | **14.47× faster** | `[MEASURED]` |
| Detection Latency (Mean) | 10,213.69 ms | 132.62 ms | **77.01× faster** | `[MEASURED]` |
| Detection Latency (Median) | 10,210.73 ms | 132.83 ms | **76.87× faster** | `[MEASURED]` |
| Detection Latency (p95) | 10,469.10 ms | 140.66 ms | **74.43× faster** | `[MEASURED]` |
| Per-Face Embedding Latency (Mean) | 441.17 ms | 130.74 ms | **3.37× faster** | `[MEASURED]` |
| Per-Face Embedding Latency (Median) | 437.47 ms | 123.03 ms | **3.56× faster** | `[MEASURED]` |
| Per-Face Embedding Latency (p95) | 457.31 ms | 178.59 ms | **2.56× faster** | `[MEASURED]` |
| Pipeline Latency (Mean) | 11,316.61 ms | 459.47 ms | **24.63× faster** | `[MEASURED]` |
| Pipeline Latency (Median) | 10,723.22 ms | 259.75 ms | **41.28× faster** | `[MEASURED]` |
| Pipeline Latency (p95) | 13,503.00 ms | 1,164.28 ms | **11.60× faster** | `[MEASURED]` |
| Alignment Success Rate | N/A (Internal) | 100.0% (15/15) | Zero failures | `[MEASURED]` |
| Embedding Vector Size | 128 dimensions | 512 dimensions | 4× higher descriptor capacity | `[MEASURED]` |
| Norm Verification | Unnormalized | 1.0000 | Strict unit norm verified | `[MEASURED]` |
| Process Peak Working Set | 1,408.42 MB | 730.02 MB | **48.2% lower peak memory** | `[MEASURED]` |
| Identity Recognition Accuracy | Not Available | Not Available | No enrolled students in DB | `[NOT AVAILABLE]` |

---

## 15. Reproducibility Instructions

The benchmark execution is automated via a standalone benchmark harness script.

### 15.1 Prerequisites
1. Ensure virtual environment has required dependencies installed:
   ```powershell
   .venv\Scripts\python.exe -m pip install onnxruntime
   ```
2. Verify model weights exist in `models/face_recognition/`:
   - `det_10g.onnx` (SHA-256: `5838f7fe05...`)
   - `w600k_r50.onnx` (SHA-256: `4c06341c33...`)

### 15.2 Execution
Run the benchmark harness:
```powershell
.venv\Scripts\python.exe scripts/run_benchmark_14d.py
```

### 15.3 Output Artifacts
The script automatically produces:
1. Formatted console tables comparing detection, embedding, latency, and memory metrics.
2. Structured raw JSON results saved to `benchmark_results_14d.json` at repository root.
