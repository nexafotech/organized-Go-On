# Official Student & Campus Photographs (`college_data/official_photos/`)

> [!CAUTION]
> **BIOMETRIC DATA PRIVACY & REPOSITORY RESTRICTION**:
> - This directory contains original high-resolution photographic resources intended solely for facial biometric enrollment and attendance verification model training.
> - **RESTRICTION**: Stored exclusively within the authorized private repository. Do **NOT** publish, expose in public docs, or link to publicly accessible endpoints.
> - **DO NOT** expose student photographs under `app/static/`, `mobile/assets/`, or public documentation folders.

---

## 1. Overview
- **Original Source Folder**: `C:\Users\Abishek\OneDrive\Desktop\am-pic`
- **Total Files Copied**: 6 high-resolution JPEG images
- **Image Format**: JPEG (`.jpg.jpeg`)
- **Copy Date**: 2026-08-20
- **Integrity Checksums**: Recorded in `college_data/source_manifest.txt`.

---

## 2. File Manifest

| Filename | File Size | SHA-256 Checksum | Purpose / Scope |
| :--- | :--- | :--- | :--- |
| `IMG_20260819_143612167.jpg.jpeg` | 2,584,492 B | `5de9085068bfa4648b2904c34b7f1a87cccdc98f07e8f4182ce3b0d0e16e122c` | Source student / group photo for biometric vector extraction. |
| `IMG_20260819_143705541.jpg.jpeg` | 2,682,076 B | `f061c53de525e11faa36e09fd37cdf8245eb9983caa32eac1ed6c33c9a8334fa` | Source student / group photo for biometric vector extraction. |
| `IMG_20260819_143731882.jpg.jpeg` | 2,573,536 B | `f595b068a66f9110d279e9d55a8dc9e5ed00b4bc4a949ae7f056235f68c089bd` | Source student / group photo for biometric vector extraction. |
| `IMG_20260819_143741100.jpg.jpeg` | 1,877,464 B | `26fd9228b38f2cd4648fa69441418087c164ed2bc31ccd3c1251b6e58c72e9f0` | Source student / group photo for biometric vector extraction. |
| `IMG_20260819_143843786.jpg.jpeg` | 2,469,636 B | `35b73be498fb6fc571167891be268825305977bd8ae7825ae93b6a2a4b9176cf` | Source student / group photo for biometric vector extraction. |
| `IMG_20260819_144007736.jpg.jpeg` | 3,243,158 B | `bd03fd6dfd0f4e7fa13f7fac9826412d23c72f097956ff5f8b4cd447fd0c9f62` | Source student / group photo for biometric vector extraction. |

---

## 3. Biometric Handling & Enrollment Guidelines
1. **Verification Required**: Before mapping cropped facial vectors to student accounts, individual face crops must be matched with confirmed register numbers.
2. **Zero Fabrication**: Never generate dummy or stock embeddings. Un-enrolled students simply retain an un-enrolled face embedding status until authentic photo capture.
3. **Face Embedding Table**: The biometric extraction engine converts bounding box facial landmarks into 128-dimensional embedding vectors stored in the `face_embeddings` table.
