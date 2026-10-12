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
import face_recognition

def run_benchmark():
    img_path = r"C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg"
    with open(img_path, "rb") as f:
        img_bytes = f.read()

    file_size_kb = len(img_bytes) / 1024.0

    print("=" * 60)
    print("PHASE 10 BASELINE BENCHMARK")
    print(f"Image: {img_path}")
    print(f"File Size: {file_size_kb:.2f} KB")
    print("=" * 60)

    # Decode image to inspect dimensions
    t_dec0 = time.perf_counter()
    nparr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    t_dec1 = time.perf_counter()
    h, w, c = img.shape
    print(f"Image Dimensions: {w}x{h} ({c} channels)")
    print(f"Image Decode Time: {(t_dec1 - t_dec0)*1000:.2f} ms")

    # DB Query
    t_db0 = time.perf_counter()
    db = SessionLocal()
    class_id = 4
    students = db.query(Student).filter(Student.class_id == class_id, Student.is_active == True).all()
    student_ids = [s.id for s in students]
    db_embeddings = db.query(FaceEmbedding).filter(FaceEmbedding.student_id.in_(student_ids)).all()
    db.close()
    t_db1 = time.perf_counter()
    print(f"DB Query Time: {(t_db1 - t_db0)*1000:.2f} ms ({len(students)} students, {len(db_embeddings)} embeddings)")

    # Engine lookup
    t_eng0 = time.perf_counter()
    engine = RecognitionEngineFactory.get_engine()
    t_eng1 = time.perf_counter()
    print(f"Engine Factory lookup: {(t_eng1 - t_eng0)*1000:.2f} ms -> {type(engine).__name__}")

    # JSON unpacking
    t_unp0 = time.perf_counter()
    compatible_embeddings = [
        emb for emb in db_embeddings
        if (emb.dimension is None or emb.dimension == engine.embedding_dimension)
        and (emb.model_name is None or emb.model_name == engine.model_name)
        and (emb.distance_metric is None or emb.distance_metric == engine.distance_metric)
    ]
    enrolled_data_map = {}
    for st in students:
        enrolled_data_map[st.id] = {
            "student_id": st.id,
            "roll_number": st.roll_number,
            "full_name": st.full_name,
            "embeddings": []
        }
    for emb in compatible_embeddings:
        vec_list = json.loads(emb.embedding_json)
        vec = np.array(vec_list, dtype=np.float64)
        if emb.student_id in enrolled_data_map:
            enrolled_data_map[emb.student_id]["embeddings"].append(vec)
    enrolled_students = list(enrolled_data_map.values())
    t_unp1 = time.perf_counter()
    print(f"JSON Unpack Time: {(t_unp1 - t_unp0)*1000:.2f} ms ({len(compatible_embeddings)} unpacked)")

    # Internal sub-stage profiling inside recognition
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # Detection sub-stage
    t_det0 = time.perf_counter()
    locations = face_recognition.face_locations(rgb, model="hog")
    t_det1 = time.perf_counter()
    print(f"Face Detection (HOG): {(t_det1 - t_det0)*1000:.2f} ms -> {len(locations)} faces detected")

    # Embedding generation sub-stage
    t_emb0 = time.perf_counter()
    encodings = face_recognition.face_encodings(rgb, locations)
    t_emb1 = time.perf_counter()
    print(f"Face Embedding Gen (Dlib ResNet-34): {(t_emb1 - t_emb0)*1000:.2f} ms ({len(encodings)} encodings)")

    # Matching sub-stage
    t_mat0 = time.perf_counter()
    all_embeddings = []
    embedding_to_student = []
    for st in enrolled_students:
        for emb in st.get("embeddings", []):
            all_embeddings.append(emb)
            embedding_to_student.append(st["student_id"])

    for enc in encodings:
        distances = face_recognition.face_distance(all_embeddings, enc)
    t_mat1 = time.perf_counter()
    print(f"Face Matching Time: {(t_mat1 - t_mat0)*1000:.2f} ms")

    # Full recognize_image end-to-end call
    t_full0 = time.perf_counter()
    rec_out = engine.recognize_image(img_bytes, enrolled_students=enrolled_students)
    t_full1 = time.perf_counter()
    print(f"Total engine.recognize_image(): {(t_full1 - t_full0)*1000:.2f} ms")

    total_pipeline_ms = (t_db1 - t_db0 + t_unp1 - t_unp0 + t_full1 - t_full0) * 1000
    print(f"Total Backend Pipeline Time: {total_pipeline_ms:.2f} ms")

    print("\n[RECOGNITION RESULTS]")
    print(f"Faces detected: {rec_out.get('faces_detected')}")
    print(f"High confidence matches: {rec_out.get('high_confidence_matches')}")
    print(f"Uncertain matches: {rec_out.get('uncertain_matches')}")
    print(f"Unknown faces: {rec_out.get('unknown_faces')}")
    for r in rec_out.get("results", []):
        st = r.get("status")
        rn = r.get("roll_number")
        nm = r.get("name")
        dist = r.get("distance")
        score = r.get("derived_score")
        print(f"  Face {r.get('face_index')}: status={st}, student={rn} ({nm}), dist={dist}, score={score}%")

if __name__ == "__main__":
    run_benchmark()
