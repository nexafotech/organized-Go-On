import os
import sys
import time
import json
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models.student import Student
from app.models.attendance import FaceEmbedding
from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine
from app.engines.recognition.local_dlib import DlibFaceRecognitionEngine
from app.engines.recognition.factory import RecognitionEngineFactory

def prepare_test_images():
    os.makedirs("scratch/benchmarks", exist_ok=True)

    # 1. Single face image
    single_path = "scratch/benchmarks/case1_single_face.jpg"
    p1 = "data/student_faces/721025149002"
    p1_file = os.path.join(p1, sorted(os.listdir(p1))[0])
    img1 = cv2.imread(p1_file)
    cv2.imwrite(single_path, img1)

    # 2. Three faces image (Abishek, Rethish, Rithanya)
    three_path = "scratch/benchmarks/case2_three_faces.jpg"
    p2 = "data/student_faces/721025149046"
    p3 = "data/student_faces/721025149047"
    img2 = cv2.imread(os.path.join(p2, sorted(os.listdir(p2))[0]))
    img3 = cv2.imread(os.path.join(p3, sorted(os.listdir(p3))[0]))
    h_target, w_target = 480, 480
    c1 = cv2.resize(img1, (w_target, h_target))
    c2 = cv2.resize(img2, (w_target, h_target))
    c3 = cv2.resize(img3, (w_target, h_target))
    img_3faces = np.hstack([c1, c2, c3])
    cv2.imwrite(three_path, img_3faces)

    # 3. Eight faces group photo (WhatsApp group photo)
    eight_source = r"C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg"
    eight_path = "scratch/benchmarks/case3_eight_faces.jpg"
    with open(eight_source, "rb") as f_in, open(eight_path, "wb") as f_out:
        f_out.write(f_in.read())

    # 4. Ten faces classroom image (Grid of 10 students: 2 rows of 5)
    ten_path = "scratch/benchmarks/case4_ten_faces.jpg"
    crops = []
    from PIL import Image
    all_dirs = sorted([d for d in os.listdir("data/student_faces") if os.path.isdir(os.path.join("data/student_faces", d))])
    for d in all_dirs:
        dir_p = os.path.join("data/student_faces", d)
        fnames = [f for f in os.listdir(dir_p) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
        for fn in fnames:
            try:
                full_p = os.path.join(dir_p, fn)
                pil_im = Image.open(full_p).convert("RGB")
                np_im = cv2.cvtColor(np.array(pil_im), cv2.COLOR_RGB2BGR)
                if np_im is not None and np_im.size > 0:
                    crops.append(cv2.resize(np_im, (320, 320)))
                    break
            except Exception:
                continue
        if len(crops) >= 10:
            break
    while len(crops) < 10:
        crops.append(crops[-1].copy())
    row1 = np.hstack(crops[:5])
    row2 = np.hstack(crops[5:10])
    img_10faces = np.vstack([row1, row2])
    cv2.imwrite(ten_path, img_10faces)

    # Batch test images
    batch_paths = [
        single_path,
        three_path,
        eight_path,
        ten_path,
        single_path
    ]

    return {
        "1_face": single_path,
        "3_faces": three_path,
        "8_faces": eight_path,
        "10_faces": ten_path,
        "3_photo_batch": batch_paths[:3],
        "5_photo_batch": batch_paths[:5]
    }

def get_enrolled_students(model_name="w600k_r50"):
    db = SessionLocal()
    # Class #4 students
    students = db.query(Student).filter(Student.class_id == 4, Student.is_active == True).all()
    enrolled = []
    dim = 512 if model_name == "w600k_r50" else 128
    for s in students:
        embs = db.query(FaceEmbedding).filter(
            FaceEmbedding.student_id == s.id,
            FaceEmbedding.model_name == model_name
        ).all()
        vecs = []
        for e in embs:
            if e.embedding_json:
                v = json.loads(e.embedding_json)
                if len(v) == dim:
                    vecs.append(np.array(v, dtype=np.float32))
        if vecs:
            enrolled.append({
                "student_id": s.id,
                "roll_number": s.roll_number,
                "full_name": s.full_name,
                "name": s.full_name,
                "embeddings": vecs
            })
    db.close()
    return enrolled

def benchmark_single_case(engine, image_path, enrolled_students, n_warm=5):
    with open(image_path, "rb") as f:
        img_bytes = f.read()

    # Cold run
    t0 = time.perf_counter()
    cold_res = engine.recognize_image(img_bytes, enrolled_students=enrolled_students)
    t_cold = (time.perf_counter() - t0) * 1000

    # Warm runs
    warm_times = []
    warm_res = None
    for _ in range(n_warm):
        time.sleep(0.02)  # realistic small inter-request gap
        t0 = time.perf_counter()
        warm_res = engine.recognize_image(img_bytes, enrolled_students=enrolled_students)
        dt = (time.perf_counter() - t0) * 1000
        warm_times.append(dt)

    warm_times.sort()
    return {
        "faces_detected": warm_res.get("faces_detected", 0),
        "high_confidence_matches": warm_res.get("high_confidence_matches", 0) if isinstance(warm_res.get("high_confidence_matches"), int) else len(warm_res.get("high_confidence_matches", [])),
        "uncertain_matches": warm_res.get("uncertain_matches", 0) if isinstance(warm_res.get("uncertain_matches"), int) else len(warm_res.get("uncertain_matches", [])),
        "unknown_faces": warm_res.get("unknown_faces", 0),
        "cold_ms": round(t_cold, 2),
        "warm_min_ms": round(min(warm_times), 2),
        "warm_max_ms": round(max(warm_times), 2),
        "warm_median_ms": round(float(np.median(warm_times)), 2),
        "warm_p95_ms": round(float(np.percentile(warm_times, 95)), 2),
    }

def benchmark_batch_case(engine, batch_paths, enrolled_students, n_warm=3):
    loaded_bytes = []
    for p in batch_paths:
        with open(p, "rb") as f:
            loaded_bytes.append(f.read())

    # Cold run
    t0 = time.perf_counter()
    cold_faces = 0
    cold_high = 0
    for b in loaded_bytes:
        res = engine.recognize_image(b, enrolled_students=enrolled_students)
        cold_faces += res.get("faces_detected", 0)
        h = res.get("high_confidence_matches", 0)
        cold_high += h if isinstance(h, int) else len(h)
    t_cold = (time.perf_counter() - t0) * 1000

    # Warm runs
    warm_times = []
    warm_faces = 0
    warm_high = 0
    for _ in range(n_warm):
        time.sleep(0.05)
        t0 = time.perf_counter()
        cur_faces = 0
        cur_high = 0
        for b in loaded_bytes:
            res = engine.recognize_image(b, enrolled_students=enrolled_students)
            cur_faces += res.get("faces_detected", 0)
            h = res.get("high_confidence_matches", 0)
            cur_high += h if isinstance(h, int) else len(h)
        dt = (time.perf_counter() - t0) * 1000
        warm_times.append(dt)
        warm_faces = cur_faces
        warm_high = cur_high

    warm_times.sort()
    return {
        "photos_count": len(batch_paths),
        "total_faces_detected": warm_faces,
        "total_high_confidence": warm_high,
        "cold_ms": round(t_cold, 2),
        "warm_min_ms": round(min(warm_times), 2),
        "warm_max_ms": round(max(warm_times), 2),
        "warm_median_ms": round(float(np.median(warm_times)), 2),
        "warm_p95_ms": round(float(np.percentile(warm_times, 95)), 2),
    }

def run():
    print("Preparing test case images...")
    cases = prepare_test_images()

    print("\n=======================================================")
    print("INITIALIZING ENGINES ON CPU")
    print("=======================================================")
    arc_engine = ScrfdArcFaceRecognitionEngine()
    dlib_engine = DlibFaceRecognitionEngine()

    arc_enrolled = get_enrolled_students(model_name="w600k_r50")
    dlib_enrolled = get_enrolled_students(model_name="dlib_resnet")
    print(f"ArcFace Enrolled Students (Class #4): {len(arc_enrolled)} (Total templates: {sum(len(x['embeddings']) for x in arc_enrolled)})")
    print(f"Dlib Enrolled Students (Class #4):    {len(dlib_enrolled)} (Total templates: {sum(len(x['embeddings']) for x in dlib_enrolled)})")

    results = {
        "scrfd_arcface": {},
        "dlib_resnet": {}
    }

    # 1. SCRFD + ArcFace Matrix
    print("\n--- Benchmarking SCRFD + ArcFace (CPU) ---")
    for case_name in ["1_face", "3_faces", "8_faces", "10_faces"]:
        p = cases[case_name]
        print(f"  Evaluating {case_name} ({p})...")
        res = benchmark_single_case(arc_engine, p, arc_enrolled, n_warm=5)
        results["scrfd_arcface"][case_name] = res
        print(f"    -> Cold: {res['cold_ms']}ms, Warm Median: {res['warm_median_ms']}ms, Faces: {res['faces_detected']}, High: {res['high_confidence_matches']}")

    for batch_name in ["3_photo_batch", "5_photo_batch"]:
        paths = cases[batch_name]
        print(f"  Evaluating {batch_name} ({len(paths)} photos)...")
        res = benchmark_batch_case(arc_engine, paths, arc_enrolled, n_warm=3)
        results["scrfd_arcface"][batch_name] = res
        print(f"    -> Cold: {res['cold_ms']}ms, Warm Median: {res['warm_median_ms']}ms, Total Faces: {res['total_faces_detected']}")

    # 2. Dlib Baseline Matrix (single warm run for batch to save time if Dlib is slow)
    print("\n--- Benchmarking Dlib Baseline (CPU) ---")
    for case_name in ["1_face", "3_faces", "8_faces", "10_faces"]:
        p = cases[case_name]
        print(f"  Evaluating {case_name} ({p})...")
        res = benchmark_single_case(dlib_engine, p, dlib_enrolled, n_warm=3)
        results["dlib_resnet"][case_name] = res
        print(f"    -> Cold: {res['cold_ms']}ms, Warm Median: {res['warm_median_ms']}ms, Faces: {res['faces_detected']}, High: {res['high_confidence_matches']}")

    for batch_name in ["3_photo_batch", "5_photo_batch"]:
        paths = cases[batch_name]
        print(f"  Evaluating {batch_name} ({len(paths)} photos)...")
        res = benchmark_batch_case(dlib_engine, paths, dlib_enrolled, n_warm=1)
        results["dlib_resnet"][batch_name] = res
        print(f"    -> Cold: {res['cold_ms']}ms, Warm Median: {res['warm_median_ms']}ms, Total Faces: {res['total_faces_detected']}")

    out_json = "scratch/benchmarks/benchmark_matrix_results.json"
    with open(out_json, "w") as fp:
        json.dump(results, fp, indent=2)

    print(f"\nAll benchmark results saved to {out_json}")

if __name__ == "__main__":
    run()
