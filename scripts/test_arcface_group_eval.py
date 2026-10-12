import os
import sys
sys.path.insert(0, '.')
import cv2
import time
import numpy as np
from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine

def run():
    print("Initializing SCRFD + ArcFace engine...")
    t0 = time.perf_counter()
    engine = ScrfdArcFaceRecognitionEngine()
    t_init = (time.perf_counter() - t0) * 1000
    print(f"Engine initialized in {t_init:.1f}ms")

    # 1. Enroll the 3 students from data/student_faces
    enrolled = []
    for roll, name, sid in [
        ('721025149002', 'Abishek A', 2),
        ('721025149046', 'Rethish S', 46),
        ('721025149047', 'Rithanya Shree V', 47)
    ]:
        p_dir = os.path.join('data', 'student_faces', roll)
        embs = []
        for f in sorted(os.listdir(p_dir)):
            if f.lower().endswith(('.jpg', '.jpeg', '.png')):
                fpath = os.path.join(p_dir, f)
                img = cv2.imread(fpath)
                if img is not None:
                    e = engine.generate_embeddings(img)
                    if e:
                        embs.append(e[0])
        print(f"Enrolled {roll} ({name}): {len(embs)} templates")
        enrolled.append({
            'student_id': sid,
            'roll_number': roll,
            'full_name': name,
            'name': name,
            'embeddings': embs
        })

    # 2. Test group photo
    grp_path = r"C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg"
    with open(grp_path, 'rb') as fp:
        img_bytes = fp.read()

    print(f"\nRecognizing group photo: {grp_path} ({len(img_bytes):,} bytes)")
    t0 = time.perf_counter()
    res = engine.recognize_image(img_bytes, enrolled_students=enrolled)
    t_rec = (time.perf_counter() - t0) * 1000
    print(f"Recognition completed in {t_rec:.1f}ms")

    print(f"Result summary:")
    print(f"  Faces detected:          {res['faces_detected']}")
    print(f"  High confidence matches: {res['high_confidence_matches']}")
    print(f"  Uncertain matches:       {res['uncertain_matches']}")
    print(f"  Unknown faces:           {res['unknown_faces']}")

    print("\nDetailed results per face:")
    for i, r in enumerate(res['results'], 1):
        st = r.get('status')
        roll = r.get('roll_number') or '---'
        name = r.get('name') or r.get('full_name') or '---'
        score = r.get('derived_score', 0)
        dist = r.get('distance', 1.0)
        sim = r.get('similarity', 0.0)
        bbox = r.get('bounding_box')
        print(f"  Face #{i}: {st:16s} | {roll:12s} | {name:18s} | Score={score:5.1f}% | Sim={sim:.3f} | Dist={dist:.4f} | bbox={bbox}")

if __name__ == "__main__":
    run()
