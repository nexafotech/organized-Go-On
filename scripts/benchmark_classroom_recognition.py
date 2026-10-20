#!/usr/bin/env python3
"""
Classroom Group Photo Recognition Benchmark Harness
Attendance Marker Product Suite
"""

import os
import json
import time
from typing import Dict, List, Any, Optional
from PIL import Image

from app.core.database import SessionLocal
from app.engines.face_recognition_engine import RecognitionEngine

BENCHMARK_DIR = os.path.abspath("benchmark_data")
CATEGORIES = ["low_density", "medium_density", "high_density"]

def analyze_image_metadata(image_path: str) -> Dict[str, Any]:
    try:
        with Image.open(image_path) as img:
            width, height = img.size
            return {
                "width": width,
                "height": height,
                "resolution": f"{width}x{height}",
                "megapixels": round((width * height) / 1_000_000, 2)
            }
    except Exception:
        return {"width": 0, "height": 0, "resolution": "unknown", "megapixels": 0.0}

def load_ground_truth(json_path: str) -> Optional[Dict[str, Any]]:
    if not os.path.exists(json_path):
        return None
    try:
        with open(json_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def run_benchmark():
    print("=" * 80)
    print("CLASSROOM GROUP PHOTO RECOGNITION BENCHMARK")
    print("=" * 80)
    print(f"Dataset Location: {BENCHMARK_DIR}\n")

    db = SessionLocal()
    engine = RecognitionEngine(db)

    total_images = 0
    results_by_category = {cat: [] for cat in CATEGORIES}

    for cat in CATEGORIES:
        cat_dir = os.path.join(BENCHMARK_DIR, cat)
        if not os.path.exists(cat_dir):
            continue

        for filename in sorted(os.listdir(cat_dir)):
            if filename.lower().endswith((".jpg", ".jpeg", ".png")):
                image_path = os.path.join(cat_dir, filename)
                json_path = os.path.splitext(image_path)[0] + ".json"

                total_images += 1
                meta = analyze_image_metadata(image_path)
                gt = load_ground_truth(json_path)

                # Execute recognition in READ-ONLY mode
                start_time = time.perf_counter()
                recog_output = engine.recognize_faces(image_path)
                end_time = time.perf_counter()

                latency_ms = round((end_time - start_time) * 1000, 2)
                faces_detected = recog_output.get("faces_detected", 0)
                latency_per_face = round(latency_ms / faces_detected, 2) if faces_detected > 0 else 0.0

                item_res = {
                    "filename": filename,
                    "category": cat,
                    "metadata": meta,
                    "faces_detected": faces_detected,
                    "high_confidence_matches": recog_output.get("high_confidence_matches", 0),
                    "uncertain_matches": recog_output.get("uncertain_matches", 0),
                    "unknown_faces": recog_output.get("unknown_faces", 0),
                    "latency_ms": latency_ms,
                    "latency_per_face_ms": latency_per_face,
                    "ground_truth": gt
                }

                # Calculate Precision/Recall/F1 if Ground Truth present
                if gt and "expected_students" in gt:
                    expected_ids = {s.get("student_id") for s in gt["expected_students"] if s.get("student_id")}
                    matched_ids = set()
                    for r in recog_output.get("results", []):
                        if r.get("status") == "PRESENT" and r.get("student_id"):
                            matched_ids.add(r.get("student_id"))

                    tp = len(matched_ids.intersection(expected_ids))
                    fp = len(matched_ids - expected_ids)
                    fn = len(expected_ids - matched_ids)

                    precision = round(tp / (tp + fp), 4) if (tp + fp) > 0 else 0.0
                    recall = round(tp / (tp + fn), 4) if (tp + fn) > 0 else 0.0
                    f1 = round(2 * precision * recall / (precision + recall), 4) if (precision + recall) > 0 else 0.0

                    item_res["metrics"] = {"tp": tp, "fp": fp, "fn": fn, "precision": precision, "recall": recall, "f1": f1}

                results_by_category[cat].append(item_res)

    db.close()

    if total_images == 0:
        print("\n" + "!" * 80)
        print("NOTICE: No benchmark classroom image dataset files found in benchmark_data/.")
        print("Real classroom recognition accuracy has not yet been measured.")
        print("!" * 80 + "\n")
        return

    # Print Summary Table
    print(f"{'Category':<16} | {'ImgCount':<8} | {'FacesDet':<8} | {'Matched':<8} | {'Uncertain':<9} | {'Unknown':<8} | {'AvgLatency(ms)':<14}")
    print("-" * 80)

    for cat in CATEGORIES:
        items = results_by_category[cat]
        if not items:
            print(f"{cat:<16} | {'0':<8} | {'-':<8} | {'-':<8} | {'-':<9} | {'-':<8} | {'-':<14}")
            continue

        c_count = len(items)
        c_faces = sum(i["faces_detected"] for i in items)
        c_matched = sum(i["high_confidence_matches"] for i in items)
        c_uncert = sum(i["uncertain_matches"] for i in items)
        c_unk = sum(i["unknown_faces"] for i in items)
        c_lat = round(sum(i["latency_ms"] for i in items) / c_count, 2)

        print(f"{cat:<16} | {c_count:<8} | {c_faces:<8} | {c_matched:<8} | {c_uncert:<9} | {c_unk:<8} | {c_lat:<14}")

    print("=" * 80)
    print("Benchmark execution completed in READ-ONLY mode. Production attendance records unmodified.")

if __name__ == "__main__":
    run_benchmark()
