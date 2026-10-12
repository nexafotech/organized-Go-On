import sys
sys.path.insert(0, '.')
import os
import json
import sqlite3
import numpy as np
from datetime import datetime, timezone

from app.engines.recognition.factory import RecognitionEngineFactory

DATASET_DIR = r"C:\Users\Abishek\OneDrive\Desktop\all in\Attendance_Marker\dataset"
DB_PATH = "attendance_system.db"

def seed():
    if not os.path.exists(DATASET_DIR):
        print(f"Error: Dataset directory not found: {DATASET_DIR}")
        return

    engine = RecognitionEngineFactory.get_engine()
    print(f"Using Recognition Engine: {engine.engine_name} ({engine.model_name}, {engine.embedding_dimension}-d, {engine.distance_metric})")

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    # Find the students
    c.execute("SELECT id, roll_number, full_name, class_id FROM students WHERE roll_number IN ('721025149002', '721025149046', '721025149047')")
    students = {row[1]: {"id": row[0], "name": row[2], "class_id": row[3]} for row in c.fetchall()}

    print(f"Found {len(students)} matching students in database:")
    for roll, info in students.items():
        print(f"  Roll {roll} -> ID {info['id']}: {info['name']} (Class {info['class_id']})")

    total_seeded = 0

    for roll, st in sorted(students.items()):
        student_id = st["id"]
        roll_dir = os.path.join(DATASET_DIR, roll)
        if not os.path.isdir(roll_dir):
            print(f"Warning: No directory for {roll}")
            continue

        # Purge existing embeddings for this student to start clean
        c.execute("DELETE FROM face_embeddings WHERE student_id = ?", (student_id,))

        files = sorted([f for f in os.listdir(roll_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))])
        print(f"\nProcessing {len(files)} images for {roll} ({st['name']})...")

        student_seeded = 0
        for fname in files:
            fpath = os.path.join(roll_dir, fname)
            with open(fpath, "rb") as fp:
                img_bytes = fp.read()

            faces = engine.detect_faces(img_bytes)
            if not faces:
                print(f"  [SKIP] {fname}: No face detected")
                continue

            # For enrollment, pick primary face
            # If multiple faces, pick the largest bounding box
            if len(faces) > 1:
                faces = sorted(faces, key=lambda loc: (loc[2]-loc[0])*(loc[1]-loc[3]), reverse=True)

            face_loc = faces[0]
            top, right, bottom, left = face_loc
            w = right - left
            h = bottom - top

            embs = engine.generate_embeddings(img_bytes, [face_loc])
            if not embs:
                print(f"  [SKIP] {fname}: Failed to extract embedding")
                continue

            emb_vec = embs[0]
            emb_json = json.dumps(emb_vec.tolist())
            now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

            c.execute("""
                INSERT INTO face_embeddings (
                    student_id, embedding_json, image_path,
                    model_name, model_version, dimension,
                    detector_name, distance_metric, quality_score, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                student_id,
                emb_json,
                f"dataset:{roll}/{fname}",
                engine.model_name,
                "v1",
                engine.embedding_dimension,
                engine.detector_name,
                engine.distance_metric,
                round(float(w * h) / (1600 * 720) * 100, 2), # relative face area %
                now_iso
            ))
            student_seeded += 1
            print(f"  [SEEDED] {fname} ({w}x{h}px face)")

        print(f"Total seeded templates for {st['name']}: {student_seeded}")
        total_seeded += student_seeded

    conn.commit()

    # Also log audit log
    for roll, st in students.items():
        c.execute("""
            INSERT INTO audit_logs (user_id, action, target, details, timestamp)
            VALUES (?, ?, ?, ?, ?)
        """, (
            1,
            "FACE_ENROLLMENT_BATCH",
            roll,
            f"Batch seeded real dataset templates for Student #{st['id']} ({st['name']})",
            datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        ))

    conn.commit()
    conn.close()
    print(f"\n=== SEEDING COMPLETED ===")
    print(f"Total face embeddings in database now seeded: {total_seeded}")

if __name__ == "__main__":
    seed()
