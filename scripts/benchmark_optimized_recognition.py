import os
import sys
import time
import json
import cv2
import numpy as np

# Ensure root in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models.student import Student
from app.models.attendance import FaceEmbedding
from app.engines.recognition.factory import RecognitionEngineFactory
from app.services.recognition_index import recognition_index

def run_comparison():
    img_path = r"C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg"
    with open(img_path, "rb") as f:
        img_bytes = f.read()

    file_size_kb = len(img_bytes) / 1024.0

    print("=" * 70)
    print("PHASE 10 PERFORMANCE VERIFICATION: BEFORE vs AFTER")
    print(f"Image: {img_path}")
    print(f"File Size: {file_size_kb:.2f} KB")
    print("=" * 70)

    # Decode image to inspect dimensions
    nparr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    h, w, c = img.shape
    print(f"Image Dimensions: {w}x{h} ({c} channels)")

    # 1. Warm-up engine and index
    engine = RecognitionEngineFactory.get_engine()
    print(f"Active Engine: {type(engine).__name__} (model: {engine.model_name}, dim: {engine.embedding_dimension})")

    # Invalidate index to test cold vs warm index lookup
    recognition_index.invalidate(class_id=4)
    db = SessionLocal()
    t_idx_cold0 = time.perf_counter()
    cold_index = recognition_index.get_class_index(db, class_id=4, engine=engine)
    t_idx_cold1 = time.perf_counter()
    cold_idx_ms = (t_idx_cold1 - t_idx_cold0) * 1000

    t_idx_warm0 = time.perf_counter()
    warm_index = recognition_index.get_class_index(db, class_id=4, engine=engine)
    t_idx_warm1 = time.perf_counter()
    warm_idx_ms = (t_idx_warm1 - t_idx_warm0) * 1000
    db.close()

    print(f"Index Cold Load: {cold_idx_ms:.2f} ms ({len(cold_index.enrolled_students_list)} students, {cold_index.total_templates} vectors)")
    print(f"Index Warm Hit:  {warm_idx_ms:.4f} ms")

    # Warm run of detection
    _ = engine.recognize_image(img, enrolled_students=warm_index.enrolled_students_list)

    # Benchmark Multiple Runs for Statistical Rigor
    NUM_RUNS = 3
    print(f"\nRunning {NUM_RUNS} benchmark passes...")

    timings = []
    results = None
    for i in range(NUM_RUNS):
        db = SessionLocal()
        t0 = time.perf_counter()

        # Step 1: Decode image
        t_dec0 = time.perf_counter()
        nparr = np.frombuffer(img_bytes, np.uint8)
        decoded_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        t_dec1 = time.perf_counter()

        # Step 2: Index lookup
        t_idx0 = time.perf_counter()
        idx_data = recognition_index.get_class_index(db, class_id=4, engine=engine)
        enrolled_students = idx_data.enrolled_students_list
        t_idx1 = time.perf_counter()

        # Step 3: Engine recognize_image
        t_rec0 = time.perf_counter()
        res = engine.recognize_image(decoded_img, enrolled_students=enrolled_students)
        t_rec1 = time.perf_counter()

        t1 = time.perf_counter()
        db.close()

        total_ms = (t1 - t0) * 1000
        dec_ms = (t_dec1 - t_dec0) * 1000
        idx_ms = (t_idx1 - t_idx0) * 1000
        rec_ms = (t_rec1 - t_rec0) * 1000

        timings.append({
            "total_ms": total_ms,
            "dec_ms": dec_ms,
            "idx_ms": idx_ms,
            "rec_ms": rec_ms,
        })
        results = res
        print(f"  Run #{i+1}: Total = {total_ms:.2f} ms (Decode: {dec_ms:.2f} ms, Index: {idx_ms:.3f} ms, Recognition: {rec_ms:.2f} ms)")

    avg_total = np.mean([t["total_ms"] for t in timings])
    avg_dec = np.mean([t["dec_ms"] for t in timings])
    avg_idx = np.mean([t["idx_ms"] for t in timings])
    avg_rec = np.mean([t["rec_ms"] for t in timings])

    print("\n" + "=" * 70)
    print("AFTER OPTIMIZATION BENCHMARK SUMMARY (AVERAGE)")
    print(f"Total Pipeline:    {avg_total:.2f} ms")
    print(f"Image Decode:      {avg_dec:.2f} ms")
    print(f"Index Retrieval:   {avg_idx:.4f} ms")
    print(f"Engine Recognize:  {avg_rec:.2f} ms")
    print("=" * 70)

    # Verification of recognition results
    print("\n[VERIFICATION OF RECOGNITION OUTPUT]")
    print(f"Faces Detected:          {results.get('faces_detected')}")
    print(f"High Confidence Matches: {results.get('high_confidence_matches')}")
    print(f"Uncertain Matches:       {results.get('uncertain_matches')}")
    print(f"Unknown Faces:           {results.get('unknown_faces')}")
    print("\nDetailed Face Match Output:")
    for r in results.get("results", []):
        f_idx = r.get("face_index")
        status = r.get("status")
        rn = r.get("roll_number")
        nm = r.get("name")
        dist = r.get("distance")
        score = r.get("derived_score")
        box = r.get("box")
        print(f"  Face {f_idx}: status={status}, roll={rn}, name={nm}, distance={dist}, score={score}%, box={box}")

    # Check assertions for accuracy preservation
    matched_rolls = {r.get("roll_number") for r in results.get("results", []) if r.get("status") in ("HIGH_CONFIDENCE", "high_confidence")}
    assert "721025149002" in matched_rolls, "Abishek A (721025149002) must be recognized"
    assert "721025149046" in matched_rolls, "Rethish S (721025149046) must be recognized"
    assert "721025149047" in matched_rolls, "Rithanya Shree V (721025149047) must be recognized"
    assert results.get("faces_detected") == 8, "Expected 8 faces detected"
    print("\n>>> ALL ACCURACY & THRESHOLD ASSERTIONS PASSED! <<<")

if __name__ == "__main__":
    run_comparison()
