import os
import sys
import json
import pytest
import numpy as np

# Ensure app path in pythonpath
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.engines.benchmark.benchmark_engine import BenchmarkEngine
from run_benchmark import load_enrolled_students_from_db, generate_benchmark_report_md
from app.core.database import SessionLocal

def test_benchmark_engine_initialization_and_synthetic_suite():
    data_dir = "benchmark_data"
    engine = BenchmarkEngine(data_dir=data_dir)
    assert engine.data_dir == data_dir
    assert 0.45 in engine.candidate_thresholds

def test_benchmark_run_execution():
    db = SessionLocal()
    try:
        enrolled = load_enrolled_students_from_db(db)
        assert len(enrolled) >= 3

        engine = BenchmarkEngine(data_dir="benchmark_data")
        results = engine.run_benchmark(enrolled)

        assert results["success"] is True
        assert "threshold_matrix" in results
        assert len(results["threshold_matrix"]) == 6
        assert results["total_images_tested"] >= 1
    finally:
        db.close()

def test_benchmark_report_markdown_generation(tmp_path):
    report_file = os.path.join(tmp_path, "TEST_BENCHMARK_REPORT.md")
    dummy_results = {
        "success": True,
        "is_synthetic_suite": True,
        "total_images_tested": 2,
        "face_size_stats": {"min_face_width_px": 45, "avg_face_width_px": 120.5, "total_faces_analyzed": 3},
        "category_breakdown": {"single": {"images_count": 2, "expected_faces": 2, "detected_faces": 2, "correct_matches_baseline": 2}},
        "threshold_matrix": [
            {
                "threshold": 0.45,
                "expected_faces": 2,
                "detected_faces": 2,
                "detection_rate_pct": 100.0,
                "correct_matches_tp": 2,
                "incorrect_matches_fp": 0,
                "unknown_matches": 0,
                "uncertain_matches": 0,
                "missed_faces_fn": 0,
                "duplicate_predictions": 0,
                "false_positive_rate_pct": 0.0,
                "false_negative_rate_pct": 0.0,
                "recognition_accuracy_pct": 100.0,
                "total_processing_time_sec": 0.5,
                "avg_time_per_image_sec": 0.25,
                "avg_time_per_face_sec": 0.25
            }
        ],
        "environment_label": "Development machine benchmark"
    }

    generate_benchmark_report_md(dummy_results, report_file)
    assert os.path.exists(report_file)

    with open(report_file, "r") as f:
        content = f.read()
    assert "Real-World Face Recognition Benchmark Report" in content
    assert "Development machine benchmark" in content
    assert "KEEP_CURRENT_ENGINE" in content
