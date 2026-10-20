# Facial Recognition ONNX Models

This directory contains the pre-trained neural network weights for the SCRFD face detector and ArcFace feature extractor used by `ScrfdArcFaceRecognitionEngine`.

> **Note**: Binary `.onnx` files in this directory are excluded from Git via `.gitignore` to prevent large binary bloat in the repository.

---

## 1. Face Detector: SCRFD-10G (`det_10g.onnx`)

- **Model Name**: SCRFD-10G (Sample and Computation Redistribution for Efficient Face Detection)
- **Model Version**: 10GF with 5 facial keypoints (`10g_kps`)
- **Official Source**: [DeepInsight / InsightFace Official Release v0.7 (`buffalo_l`)](https://github.com/deepinsight/insightface/releases/tag/v0.7)
- **License**: Non-Commercial Research & Educational Academic License (DeepInsight)
- **Format**: ONNX (Opset 11)
- **File Size**: 16,923,827 bytes (~16.13 MB)
- **SHA-256 Checksum**: `5838f7fe053675b1c7a08b633df49e7af5495cee0493c7dcf6697200b85b5b91`
- **MD5 Checksum**: `4c10eef5c9e168357a16fdd580fa8371`
- **Input Dimensions**: Dynamic batch and spatial dimensions: `[1, 3, height, width]`, standard inference input: `[1, 3, 640, 640]`
- **Input Preprocessing**: BGR image format, float32, normalized with `(image - 127.5) / 128.0`
- **Output Dimensions**: 
  - Stride 8: Scores `[1, 12800, 1]`, Bounding Boxes `[1, 12800, 4]`, Landmarks (5 points) `[1, 12800, 10]`
  - Stride 16: Scores `[1, 3200, 1]`, Bounding Boxes `[1, 3200, 4]`, Landmarks (5 points) `[1, 3200, 10]`
  - Stride 32: Scores `[1, 800, 1]`, Bounding Boxes `[1, 800, 4]`, Landmarks (5 points) `[1, 800, 10]`

---

## 2. Feature Extractor: ArcFace ResNet-50 (`w600k_r50.onnx`)

- **Model Name**: ArcFace ResNet-50 (`w600k_r50`)
- **Model Version**: ResNet-50 trained on WebFace600K
- **Official Source**: [DeepInsight / InsightFace Official Release v0.7 (`buffalo_l`)](https://github.com/deepinsight/insightface/releases/tag/v0.7)
- **License**: Non-Commercial Research & Educational Academic License (DeepInsight)
- **Format**: ONNX (Opset 11)
- **File Size**: 174,383,860 bytes (~166.30 MB)
- **SHA-256 Checksum**: `4c06341c33c2ca1f86781dab0e829f88ad5b64be9fba56e56bc9ebdefc619e43`
- **MD5 Checksum**: `80248d427976241cbd1343889ed132b3`
- **Input Dimensions**: Fixed shape: `[1, 3, 112, 112]` (batch, channels, height, width)
- **Input Preprocessing**: Aligned 5-point crop, RGB format, float32, normalized with `(image - 127.5) / 127.5`
- **Output Dimensions**: `[1, 512]` float32 facial feature vector (L2-normalized)
