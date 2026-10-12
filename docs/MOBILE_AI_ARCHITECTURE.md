# Mobile AI Integration & 130-Student Matching Architecture
**Attendance Marker Product Suite**
**Milestone 8.3 — Edge & Server Architectural Specification**

---

## 1. Final Architecture Comparison & Selection (Step 7)

We evaluate three candidate system integration architectures:

### Option A: Fully On-Device Architecture
- *Flow*: Camera $\rightarrow$ On-Device Detection $\rightarrow$ On-Device Embedding $\rightarrow$ Local Vector Match $\rightarrow$ Faculty Review $\rightarrow$ Sync Attendance Records to Backend.
- *Pros*: 100% offline capability; zero network dependency during capture.
- *Cons*: Student face embeddings must be downloaded and stored locally on mobile devices; increased mobile RAM/storage footprint; vulnerability to mobile database extraction.

### Option B: Hybrid Architecture (Recommended Primary Production Architecture)
- *Flow*: Camera $\rightarrow$ Lightweight On-Device Detection & Face Cropping $\rightarrow$ Transmit Face Crops to Backend API $\rightarrow$ Backend Embedding & Roster Vector Matching $\rightarrow$ Faculty Review UI $\rightarrow$ Faculty Confirmation.
- *Pros*: Minimal mobile bandwidth (transmits small cropped faces instead of 4K full photo); 100% biometric security (embeddings never stored on client device); zero risk of student vector database leakage; offloads vector math from budget mobile CPUs; 100% consistent matching engine.
- *Cons*: Requires network connectivity for session confirmation.

### Option C: Backend-First Architecture (Current Baseline Production Architecture)
- *Flow*: Camera $\rightarrow$ Transmit Full Group Photo $\rightarrow$ Backend Detection (Dlib/CNN) $\rightarrow$ Backend Embedding & Matching $\rightarrow$ Faculty Review $\rightarrow$ Confirmation.
- *Pros*: Zero mobile AI dependency; 100% compatible with any low-end device capable of taking a photo; uses production-proven C++ Dlib engine.
- *Cons*: Transmits full resolution group photo over network.

---

### Architectural Trade-off Matrix

| Evaluation Criterion | Option A (Fully On-Device) | Option B (Hybrid - Recommended) | Option C (Backend-First Baseline) |
| :--- | :--- | :--- | :--- |
| **Biometric Privacy** | Moderate (Local DB vector storage) | **Superior** (Zero mobile vector storage) | **Superior** (Zero mobile vector storage) |
| **Network Bandwidth** | **Zero** | **Low** (Small face crops only) | Moderate (Full photo upload) |
| **Mobile RAM Footprint** | $\sim 100 \text{ MB}$ | **$< 25 \text{ MB}$** | **$< 15 \text{ MB}$** |
| **Mobile CPU Load** | High | **Low** (Detection only) | **Minimal** (Camera capture only) |
| **Offline Capability** | **100% Offline** | Requires network for sync | Requires network for sync |
| **Implementation Risk** | High (Cross-compiling C++/TFLite) | **Low** (Clean HTTP API boundaries) | **Zero** (Production Baseline Active) |
| **Matching Reliability** | Moderate (Depends on Mobile CPU) | **Superior** (Server authority) | **Superior** (Server authority) |

> [!TIP]
> **Final Recommendation**: Adopt **Option B (Hybrid Architecture)** as the primary production architecture for Flutter Mobile AI, backed by **Option C (Backend-First Baseline)** for legacy devices and fallback operational modes.

---

## 2. 130-Student Vector Matching Architecture (Step 8)

The target deployment manages initial capacity for ~130 enrolled students across 2 classes (Class 1 & Class 2):

```text
       Enrolled Students (~130 Roster Entries)
                        │
                        ▼
      [ PostgreSQL / SQLite Vector Store ]
        (128D / 512D L2-Normalized Vectors)
                        │
                        ▼
       [ In-Memory Session Roster Filter ] (Filtered by Class ID)
                        │
                        ▼
    Input Query Vector (Face Crop from Photo)
                        │
                        ▼
    [ Vector Distance Calculator (Euclidean) ] ──► d(u, v) = sqrt(sum((u_i - v_i)^2))
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
   d <= 0.45       0.45 < d <= 0.60    d > 0.60
   [PRESENT]       [UNCERTAIN]        [UNKNOWN]
  Auto-Checked    Flagged Review      Unmarked
```

### Thresholding & Categorization Rules:
- **High Confidence Match ($d \le 0.45$)**: Automatically selected as `PRESENT` in faculty review UI.
- **Uncertain Review Range ($0.45 < d \le 0.60$)**: Highlighted with yellow warning badge; requires explicit faculty checkbox confirmation.
- **Unknown Face ($d > 0.60$)**: Isolated as unknown face box; no student profile assigned.

---

## 3. Model Initialization & Frame Processing Strategy (Step 9)

To ensure smooth UI performance on low-spec Android hardware:

1. **Lazy Loading**: Mobile AI vision libraries (`tflite_flutter` / camera controllers) initialize **only when opening the attendance capture screen**.
2. **Model Singleton & Instance Reuse**: Detector models remain cached in volatile memory during the active session; unallocated upon leaving screen.
3. **Capture-Driven Execution**: Mobile AI processes **one static captured photo on shutter press**. Continuous 30fps camera preview inference is explicitly disabled to prevent battery drain and thermal throttling.

---

## 4. Privacy, Security & Audit Protocol (Step 10)

1. **Zero Raw Photo Persistence**: Group photographs and face crop bitmaps exist strictly in volatile RAM and are scrubbed immediately after inference.
2. **Encrypted Transport**: All network payload communications use HTTPS / TLS 1.3 with Bearer JWT tokens.
3. **No Biometric Data in Logs**: Raw face embeddings, vector arrays, and secret tokens are strictly excluded from application log files and console outputs.
4. **Audit Trail Logging**: Every confirmation action generates an immutable `AuditLog` entry in the database:
   - `action`: `CONFIRM_FACIAL_RECOGNITION`
   - `details`: `Session #{session_id}: confirmed {present_count} present, {od_count} OD`.
