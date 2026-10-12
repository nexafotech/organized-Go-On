import time
import json
import os
import cv2
import numpy as np
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine
from app.core.database import SessionLocal
from app.models.student import Student
from app.models.attendance import FaceEmbedding

def run_benchmark():
    engine = ScrfdArcFaceRecognitionEngine()

    db = SessionLocal()
    students = db.query(Student).filter(Student.is_active == True).all()
    enrolled = []
    for s in students:
        embs = db.query(FaceEmbedding).filter(
            FaceEmbedding.student_id == s.id,
            FaceEmbedding.model_name == 'w600k_r50'
        ).all()
        vecs = [np.array(json.loads(e.embedding_json), dtype=np.float32) for e in embs if e.embedding_json]
        if vecs:
            enrolled.append({
                'student_id': s.id,
                'roll_number': s.roll_number,
                'full_name': s.full_name,
                'name': s.full_name,
                'embeddings': vecs
            })
    db.close()
    print(f"Total enrolled students with ArcFace in DB: {len(enrolled)}")
    total_templates = sum(len(e['embeddings']) for e in enrolled)
    print(f"Total templates in index: {total_templates}")

    grp_path = r"C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg"
    with open(grp_path, 'rb') as fp:
        img_bytes = fp.read()

    # Cold run
    t0 = time.perf_counter()
    res_cold = engine.recognize_image(img_bytes, enrolled_students=enrolled)
    t_cold = (time.perf_counter() - t0) * 1000
    print(f"\nCold run: {t_cold:.2f} ms | Detected: {res_cold['faces_detected']} | High: {res_cold['high_confidence_matches']} | Uncertain: {res_cold['uncertain_matches']} | Unknown: {res_cold['unknown_faces']}")
    for i, r in enumerate(res_cold['results'], 1):
        st = r.get('status')
        roll = r.get('roll_number') or '---'
        name = r.get('name') or '---'
        sim = r.get('similarity')
        dist = r.get('distance')
        print(f"  Face #{i}: {st:16s} | {roll:15s} | {name:20s} | Sim={sim} | Dist={dist}")

    # 5 Warm runs
    latencies = []
    for i in range(5):
        t0 = time.perf_counter()
        res = engine.recognize_image(img_bytes, enrolled_students=enrolled)
        dt = (time.perf_counter() - t0) * 1000
        latencies.append(dt)
        print(f"Warm run {i+1}: {dt:.2f} ms | High: {res['high_confidence_matches']} | Unknown: {res['unknown_faces']}")

    latencies.sort()
    median_val = latencies[len(latencies)//2]
    p95_val = np.percentile(latencies, 95)
    print(f"\nSummary (8-face group photo, CPU):")
    print(f"  Cold run:  {t_cold:.2f} ms")
    print(f"  Warm min:  {min(latencies):.2f} ms")
    print(f"  Warm max:  {max(latencies):.2f} ms")
    print(f"  Warm median: {median_val:.2f} ms")
    print(f"  Warm p95:  {p95_val:.2f} ms")

if __name__ == "__main__":
    run_benchmark()
