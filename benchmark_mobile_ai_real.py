#!/usr/bin/env python3
"""
Real Mobile AI Benchmark Runner
Attendance Marker Product Suite
Milestone 8.2 — Empirical Model Benchmarking
"""

import os
import sys
import time
import json
import psutil
from typing import Dict, List, Any, Optional
from PIL import Image

from app.core.database import SessionLocal
from app.engines.face_recognition_engine import RecognitionEngine

BENCHMARK_DIR = os.path.abspath("benchmark_data")
MODEL_DIR = os.path.abspath("models/mobile_ai")
CATEGORIES = ["1_face", "5_faces", "10_faces", "20_faces", "30_faces"]

def get_process_ram_mb() -> float:
    process = psutil.Process(os.getpid())
    return round(process.memory_info().rss / (1024 * 1024), 2)

def check_model_file_exists(filename: str) -> bool:
    path = os.path.join(MODEL_DIR, filename)
    return os.path.exists(path)

def benchmark_dlib_baseline() -> List[Dict[str, Any]]:
    print("=" * 80)
    print("BENCHMARKING BASELINE: Dlib Recognition Engine")
    print("=" * 80)

    db = SessionLocal()
    engine = RecognitionEngine(db)
    results = []

    # Check images across benchmark_data subdirectories
    image_paths = []
    if os.path.exists(BENCHMARK_DIR):
        for root, dirs, files in os.walk(BENCHMARK_DIR):
            for file in files:
                if file.lower().endswith((".jpg", ".jpeg", ".png")):
                    image_paths.append(os.path.join(root, file))

    if not image_paths:
        print("No benchmark dataset image files found in benchmark_data/.")
        print("Measuring baseline memory and initialization footprint...")
        ram_mb = get_process_ram_mb()
        db.close()
        return [{
            "candidate": "Baseline (Dlib ResNet)",
            "status": "No Images Found",
            "ram_mb": ram_mb,
            "latency_ms": 0.0,
            "faces_detected": 0
        }]

    ram_before = get_process_ram_mb()

    for img_path in image_paths:
        filename = os.path.basename(img_path)
        start_t = time.perf_counter()
        output = engine.recognize_faces(img_path)
        end_t = time.perf_counter()

        latency_ms = round((end_t - start_t) * 1000, 2)
        ram_after = get_process_ram_mb()
        faces_det = output.get("faces_detected", 0)
        lat_per_face = round(latency_ms / faces_det, 2) if faces_det > 0 else 0.0

        res = {
            "candidate": "Baseline (Dlib ResNet)",
            "filename": filename,
            "status": "measured",
            "faces_detected": faces_det,
            "high_confidence_matches": output.get("high_confidence_matches", 0),
            "uncertain_matches": output.get("uncertain_matches", 0),
            "unknown_faces": output.get("unknown_faces", 0),
            "total_latency_ms": latency_ms,
            "latency_per_face_ms": lat_per_face,
            "ram_mb": ram_after
        }
        results.append(res)
        print(f"[{filename}] Faces: {faces_det} | Latency: {latency_ms}ms | RAM: {ram_after}MB")

    db.close()
    return results

def run_real_mobile_ai_benchmark():
    print("=" * 80)
    print("MILESTONE 8.2 — REAL MOBILE AI MODEL BENCHMARK")
    print("=" * 80)
    print(f"Dataset Location: {BENCHMARK_DIR}")
    print(f"Mobile Model Directory: {MODEL_DIR}\n")

    # Check candidate model files
    pair_a_detector = check_model_file_exists("blazeface_int8.tflite")
    pair_a_embedder = check_model_file_exists("mobilefacenet_int8.tflite")

    pair_b_detector = check_model_file_exists("scrfd_0.5g_int8.onnx")
    pair_b_embedder = check_model_file_exists("arcface_mobilenet_int8.onnx")

    print("CANDIDATE MODEL FILE STATUS:")
    print(f"  - PAIR A (BlazeFace + MobileFaceNet TFLite INT8): {'FOUND' if (pair_a_detector and pair_a_embedder) else 'MISSING MODEL WEIGHTS'}")
    print(f"  - PAIR B (SCRFD + ArcFace MobileNet ONNX INT8):  {'FOUND' if (pair_b_detector and pair_b_embedder) else 'MISSING MODEL WEIGHTS'}")
    print(f"  - BASELINE (Dlib C++ ResNet):                    INSTALLED & ACTIVE [measured]\n")

    # Benchmark Baseline
    dlib_results = benchmark_dlib_baseline()

    # Print Summary Table
    print("\n" + "=" * 80)
    print("SUMMARY COMPARISON TABLE")
    print("=" * 80)
    print(f"{'Candidate':<32} | {'Status':<22} | {'FacesDet':<8} | {'Latency(ms)':<12} | {'RAM (MB)':<8}")
    print("-" * 80)

    if dlib_results:
        avg_lat = round(sum(r["total_latency_ms"] for r in dlib_results) / len(dlib_results), 2) if dlib_results[0].get("status") == "measured" else 0.0
        avg_faces = sum(r["faces_detected"] for r in dlib_results)
        max_ram = max(r["ram_mb"] for r in dlib_results)
        print(f"{'Baseline (Dlib ResNet)':<32} | {'measured':<22} | {avg_faces:<8} | {avg_lat:<12} | {max_ram:<8}")

    print(f"{'Pair A (BlazeFace+MobileFaceNet)':<32} | {'MISSING MODEL WEIGHTS':<22} | {'-':<8} | {'-':<12} | {'-':<8}")
    print(f"{'Pair B (SCRFD+ArcFace MobileNet)':<32} | {'MISSING MODEL WEIGHTS':<22} | {'-':<8} | {'-':<12} | {'-':<8}")
    print("=" * 80)

if __name__ == "__main__":
    run_real_mobile_ai_benchmark()
