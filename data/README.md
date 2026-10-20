# Biometric Face Dataset Directory (`data/`)

> [!IMPORTANT]
> **BIOMETRIC DATA PRIVACY & REPOSITORY POLICIES**:
> - Real photographic biometrics of enrolled students are stored locally under `data/student_faces/<register_number>/<filename>.jpg`.
> - Personal biometric face images are **strictly excluded from source control** via `.gitignore` to protect individual biometric privacy and prevent repository binary bloat.
> - Pre-configured demo face enrollment fixtures and canonical seed manifests are securely provided in `college_data/` and `college_seed/`.

---

## Directory Layout

```text
data/
├── student_faces/          # Canonical storage for enrolled student facial photos
│   └── <register_number>/  # Directory per student (e.g. 721025149001/)
│       ├── photo_01.jpg
│       └── photo_02.jpg
└── demo/                   # Local verification images and demo fixtures
```

---

## How Biometric Enrollment Works

1. **Upload via Admin Panel / Mobile**: When an administrator or student captures an enrollment photo, the system stores the raw image under `data/student_faces/<register_number>/`.
2. **Feature Extraction**: The SCRFD face detector locates the face and aligns landmarks, and ArcFace ResNet-50 computes a 512-dimensional vector.
3. **Database Storage**: The resulting biometric embeddings are saved to the `face_embeddings` table in the database.
4. **Offline Seeding**: To seed ArcFace embeddings for existing dataset images, run:
   ```bash
   python scripts/seed_arcface_embeddings.py
   ```
