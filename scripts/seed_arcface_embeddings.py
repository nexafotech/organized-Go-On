import os
import sys
sys.path.insert(0, '.')
import json
import sqlite3
import cv2
import numpy as np
from datetime import datetime, timezone
from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine

def seed_arcface():
    print("=" * 60)
    print("SEEDING ARCFACE 512-D EMBEDDINGS INTO DATABASE")
    print("=" * 60)

    engine = ScrfdArcFaceRecognitionEngine()
    conn = sqlite3.connect("attendance_system.db")
    c = conn.cursor()

    c.execute("SELECT id, roll_number, full_name, class_id FROM students WHERE is_active = 1")
    students = {row[1]: {"id": row[0], "name": row[2], "class_id": row[3]} for row in c.fetchall()}

    total_inserted = 0
    total_skipped = 0

    for roll, st in sorted(students.items()):
        p_dir = os.path.join("data", "student_faces", roll)
        if not os.path.isdir(p_dir):
            continue
        files = [f for f in sorted(os.listdir(p_dir)) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
        if not files:
            continue

        student_id = st["id"]

        # Check existing ArcFace embeddings
        c.execute(
            "SELECT image_path FROM face_embeddings WHERE student_id = ? AND model_name = ?",
            (student_id, engine.model_name)
        )
        existing_paths = {row[0] for row in c.fetchall()}

        student_added = 0
        for f in files:
            fpath = os.path.join(p_dir, f)
            rel_path = f"data/student_faces/{roll}/{f}"
            if rel_path in existing_paths:
                total_skipped += 1
                continue

            img = cv2.imread(fpath)
            if img is None:
                continue

            faces = engine.detect_faces_with_landmarks(img)
            if not faces:
                print(f"  [WARN] No face in {rel_path}")
                continue

            # Pick primary face (largest area)
            faces.sort(key=lambda x: (x['bbox'][2]-x['bbox'][0])*(x['bbox'][1]-x['bbox'][3]), reverse=True)
            aligned = engine.align_face(img, faces[0]['landmarks'])
            rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB)
            blob = np.transpose(rgb, (2, 0, 1)).astype(np.float32)
            blob = (blob - 127.5) / 127.5
            blob = np.expand_dims(blob, axis=0)

            out = engine.arc_session.run(None, {engine.arc_input_name: blob})[0][0]
            norm = np.linalg.norm(out)
            if norm > 0:
                out = out / norm

            emb_json = json.dumps(out.tolist())
            now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

            top, right, bottom, left = faces[0]['bbox']
            w = right - left
            h = bottom - top

            c.execute("""
                INSERT INTO face_embeddings (
                    student_id, embedding_json, image_path,
                    model_name, model_version, dimension,
                    detector_name, distance_metric, quality_score, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                student_id,
                emb_json,
                rel_path,
                engine.model_name,
                "v1",
                engine.embedding_dimension,
                engine.detector_name,
                engine.distance_metric,
                round(float(w * h) / (img.shape[0] * img.shape[1]) * 100, 2),
                now_iso
            ))
            student_added += 1

        if student_added > 0:
            print(f"Seeded {student_added} ArcFace templates for {roll} ({st['name']})")
            total_inserted += student_added

    conn.commit()
    conn.close()
    print(f"\nDone! Inserted {total_inserted} new ArcFace embeddings (skipped {total_skipped} already present).")

if __name__ == "__main__":
    seed_arcface()
