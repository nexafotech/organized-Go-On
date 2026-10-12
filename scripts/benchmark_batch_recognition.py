import os
import sys
import time
import cv2
import numpy as np

# Ensure root in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.engines.recognition.factory import RecognitionEngineFactory
from app.services.recognition_index import recognition_index

def run_batch_benchmark():
    img_path = r"C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg"
    with open(img_path, "rb") as f:
        img_bytes = f.read()

    print("=" * 70)
    print("PHASE 10 BATCH RECOGNITION PERFORMANCE BENCHMARK")
    print(f"Testing Batch of 3 Photos")
    print("=" * 70)

    engine = RecognitionEngineFactory.get_engine()
    recognition_index.invalidate(class_id=4)
    db = SessionLocal()

    BATCH_SIZE = 3
    # Simulate batch upload of 3 photos
    per_image_times = []
    total_batch_t0 = time.perf_counter()

    for idx_num in range(1, BATCH_SIZE + 1):
        t_photo_start = time.perf_counter()

        # Step 1: Decode image
        t_dec0 = time.perf_counter()
        nparr = np.frombuffer(img_bytes, np.uint8)
        decoded_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        t_dec1 = time.perf_counter()

        # Step 2: In-memory index hit
        t_idx0 = time.perf_counter()
        class_idx = recognition_index.get_class_index(db, class_id=4, engine=engine)
        enrolled_students = class_idx.enrolled_students_list
        t_idx1 = time.perf_counter()

        # Step 3: Engine recognize_image
        t_rec0 = time.perf_counter()
        res = engine.recognize_image(decoded_img, enrolled_students=enrolled_students)
        t_rec1 = time.perf_counter()

        t_photo_end = time.perf_counter()
        total_photo_ms = (t_photo_end - t_photo_start) * 1000
        dec_ms = (t_dec1 - t_dec0) * 1000
        idx_ms = (t_idx1 - t_idx0) * 1000
        rec_ms = (t_rec1 - t_rec0) * 1000

        per_image_times.append(total_photo_ms)
        print(f"Photo #{idx_num}: Total = {total_photo_ms:.2f} ms (Decode: {dec_ms:.2f} ms, Index: {idx_ms:.4f} ms, Recognition: {rec_ms:.2f} ms)")
        print(f"   Matches: {res.get('high_confidence_matches')} High, {res.get('uncertain_matches')} Uncertain, {res.get('unknown_faces')} Unknown")

    total_batch_t1 = time.perf_counter()
    db.close()
    total_batch_ms = (total_batch_t1 - total_batch_t0) * 1000

    print("=" * 70)
    print(f"BATCH SUMMARY ({BATCH_SIZE} photos):")
    print(f"Total Batch Latency: {total_batch_ms:.2f} ms ({total_batch_ms/1000:.2f} s)")
    print(f"Average Per-Photo Latency: {np.mean(per_image_times):.2f} ms")
    print("=" * 70)

if __name__ == "__main__":
    run_batch_benchmark()
