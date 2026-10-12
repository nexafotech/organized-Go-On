import os
import sys
import json
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine

def run_gate():
    print("==================================================================")
    print("PHASE 10B ACCURACY REGRESSION GATE VERIFICATION (CPU)")
    print("==================================================================")
    engine = ScrfdArcFaceRecognitionEngine()

    # Load 3 enrolled students from data/student_faces
    enrolled_data = []
    enrolled_specs = [
        ("721025149002", "Abishek A", 2),
        ("721025149046", "Rethish S", 46),
        ("721025149047", "Rithanya Shree V", 47)
    ]

    for roll, name, sid in enrolled_specs:
        p_dir = os.path.join("data", "student_faces", roll)
        embs = []
        for f in sorted(os.listdir(p_dir)):
            if f.lower().endswith(('.jpg', '.jpeg', '.png')):
                fpath = os.path.join(p_dir, f)
                img = cv2.imread(fpath)
                if img is not None:
                    e = engine.generate_embeddings(img)
                    if e:
                        embs.append(e[0])
        print(f"Enrolled {roll} ({name}): {len(embs)} templates loaded")
        enrolled_data.append({
            "student_id": sid,
            "roll_number": roll,
            "full_name": name,
            "name": name,
            "embeddings": embs
        })

    # Golden classroom group photo
    grp_path = r"C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg"
    with open(grp_path, "rb") as fp:
        img_bytes = fp.read()

    res = engine.recognize_image(img_bytes, enrolled_students=enrolled_data)

    print("\nRecognition Results:")
    print(f"  Faces detected:          {res['faces_detected']}")
    print(f"  High confidence matches: {res['high_confidence_matches']}")
    print(f"  Uncertain matches:       {res['uncertain_matches']}")
    print(f"  Unknown faces:           {res['unknown_faces']}")

    assert res["faces_detected"] == 8, f"Expected 8 faces detected, got {res['faces_detected']}"
    assert res["high_confidence_matches"] == 3, f"Expected 3 high confidence matches, got {res['high_confidence_matches']}"
    assert res["uncertain_matches"] == 0, f"Expected 0 uncertain matches, got {res['uncertain_matches']}"
    assert res["unknown_faces"] == 5, f"Expected 5 unknown faces, got {res['unknown_faces']}"

    matched_rolls = set()
    for r in res["results"]:
        status = r["status"]
        roll = r.get("roll_number")
        name = r.get("name")
        score = r.get("derived_score", 0.0)
        sim = r.get("similarity", 0.0)
        dist = r.get("distance", 1.0)
        if status == "HIGH_CONFIDENCE":
            matched_rolls.add(roll)
            print(f"  [MATCH]   {roll}: {name} (Score: {score}%, Sim: {sim}, Dist: {dist})")
        else:
            print(f"  [UNKNOWN] Face #{r['face_index']} (Max Sim: {sim})")

    assert "721025149002" in matched_rolls, "Abishek A must be matched with HIGH_CONFIDENCE"
    assert "721025149046" in matched_rolls, "Rethish S must be matched with HIGH_CONFIDENCE"
    assert "721025149047" in matched_rolls, "Rithanya Shree V must be matched with HIGH_CONFIDENCE"

    print("\n[SUCCESS] ACCURACY REGRESSION GATE PASSED WITH 100% PRECISION!")
    print("  - Zero false positives on unknown faces")
    print("  - 100% recall on golden enrolled students")
    print("  - All invariants satisfied")

if __name__ == "__main__":
    run_gate()
