import os
import json
import time
import glob
import cv2
import numpy as np
from typing import List, Dict, Any, Tuple, Optional

from app.engines.recognition.local_dlib import DlibFaceRecognitionEngine
from app.engines.recognition.base import RecognitionConfig

class BenchmarkEngine:
    """
    Automated Benchmarking Engine for Face Recognition Systems.
    Evaluates detection rate, recognition accuracy, threshold sensitivity,
    face bounding box sizes, and development machine latency.
    """

    def __init__(self, data_dir: str = "benchmark_data"):
        self.data_dir = data_dir
        self.engine_inst = DlibFaceRecognitionEngine()
        self.candidate_thresholds = [0.35, 0.40, 0.45, 0.50, 0.55, 0.60]

    def _ensure_synthetic_samples_if_empty(self, enrolled_students: List[Dict[str, Any]]) -> bool:
        """
        Populates synthetic/sample benchmark test cases from dataset images if no real images are present.
        Synthetic samples are explicitly tagged with SYNTHETIC_TEST.
        """
        all_json = glob.glob(os.path.join(self.data_dir, "**", "*.json"), recursive=True)
        if len(all_json) > 0:
            return False  # User has provided real benchmark images

        print("[INFO] No real classroom images found in benchmark_data/. Generating synthetic sample benchmark suite...")

        dataset_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "dataset")
        if not os.path.exists(dataset_dir):
            return False

        # Map roll numbers to student IDs from enrolled_students
        roll_to_id = {str(st["roll_number"]): st["student_id"] for st in enrolled_students}

        single_dir = os.path.join(self.data_dir, "single")
        small_group_dir = os.path.join(self.data_dir, "small_group")

        # Sample 1: Single Face (Alex - Roll 101)
        alex_dir = os.path.join(dataset_dir, "101_Alex")
        if os.path.exists(alex_dir):
            imgs = [f for f in os.listdir(alex_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            if imgs:
                src_path = os.path.join(alex_dir, imgs[0])
                dst_img = os.path.join(single_dir, "synthetic_alex_01.jpg")
                dst_json = os.path.join(single_dir, "synthetic_alex_01.json")

                img_data = cv2.imread(src_path)
                if img_data is not None:
                    cv2.imwrite(dst_img, img_data)
                    with open(dst_json, "w") as f:
                        json.dump({
                            "image": "synthetic_alex_01.jpg",
                            "category": "single",
                            "expected_students": [roll_to_id.get("101", 101)],
                            "synthetic_test": True,
                            "description": "Synthetic single face sample generated from dataset student 101 (Alex)"
                        }, f, indent=2)

        # Sample 2: Single Face (Sarah - Roll 102)
        sarah_dir = os.path.join(dataset_dir, "102_Sarah")
        if os.path.exists(sarah_dir):
            imgs = [f for f in os.listdir(sarah_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            if imgs:
                src_path = os.path.join(sarah_dir, imgs[0])
                dst_img = os.path.join(single_dir, "synthetic_sarah_01.jpg")
                dst_json = os.path.join(single_dir, "synthetic_sarah_01.json")

                img_data = cv2.imread(src_path)
                if img_data is not None:
                    cv2.imwrite(dst_img, img_data)
                    with open(dst_json, "w") as f:
                        json.dump({
                            "image": "synthetic_sarah_01.jpg",
                            "category": "single",
                            "expected_students": [roll_to_id.get("102", 102)],
                            "synthetic_test": True,
                            "description": "Synthetic single face sample generated from dataset student 102 (Sarah)"
                        }, f, indent=2)

        # Sample 3: Small Group Composite (Alex + Sarah side-by-side)
        if os.path.exists(alex_dir) and os.path.exists(sarah_dir):
            alex_imgs = [f for f in os.listdir(alex_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            sarah_imgs = [f for f in os.listdir(sarah_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            if alex_imgs and sarah_imgs:
                img_a = cv2.imread(os.path.join(alex_dir, alex_imgs[0]))
                img_s = cv2.imread(os.path.join(sarah_dir, sarah_imgs[0]))
                if img_a is not None and img_s is not None:
                    h_a, w_a = img_a.shape[:2]
                    h_s, w_s = img_s.shape[:2]
                    target_h = min(h_a, h_s, 400)
                    img_a_resized = cv2.resize(img_a, (int(w_a * target_h / h_a), target_h))
                    img_s_resized = cv2.resize(img_s, (int(w_s * target_h / h_s), target_h))

                    composite = np.hstack([img_a_resized, img_s_resized])
                    dst_img = os.path.join(small_group_dir, "synthetic_group_2faces.jpg")
                    dst_json = os.path.join(small_group_dir, "synthetic_group_2faces.json")
                    cv2.imwrite(dst_img, composite)
                    with open(dst_json, "w") as f:
                        json.dump({
                            "image": "synthetic_group_2faces.jpg",
                            "category": "small_group",
                            "expected_students": [roll_to_id.get("101", 101), roll_to_id.get("102", 102)],
                            "synthetic_test": True,
                            "description": "Synthetic 2-student group photo created by stitching student 101 and 102"
                        }, f, indent=2)

        return True

    def run_benchmark(self, enrolled_students: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Executes full benchmark evaluation across all dataset categories and candidate thresholds.
        Returns comprehensive structured benchmark results.
        """
        is_synthetic = self._ensure_synthetic_samples_if_empty(enrolled_students)

        # Build ID lookup map so expected_students can accept student IDs or roll numbers
        id_set_map = {}
        for st in enrolled_students:
            st_id = st["student_id"]
            roll = str(st["roll_number"])
            id_set_map[st_id] = st_id
            id_set_map[roll] = st_id
            try:
                id_set_map[int(roll)] = st_id
            except ValueError:
                pass

        categories = ["single", "small_group", "medium_group", "large_group", "lighting", "distance", "occlusion", "angle", "low_quality"]

        benchmark_images = []
        for cat in categories:
            cat_dir = os.path.join(self.data_dir, cat)
            if not os.path.exists(cat_dir):
                continue
            json_files = glob.glob(os.path.join(cat_dir, "*.json"))
            for jf in json_files:
                try:
                    with open(jf, "r") as f:
                        gt_data = json.load(f)

                    img_name = gt_data.get("image")
                    img_path = os.path.join(cat_dir, img_name)
                    if os.path.exists(img_path):
                        # Map raw expected values to normalized student_ids
                        raw_exp = gt_data.get("expected_students", [])
                        norm_exp = []
                        for item in raw_exp:
                            if item in id_set_map:
                                norm_exp.append(id_set_map[item])
                            elif str(item) in id_set_map:
                                norm_exp.append(id_set_map[str(item)])
                            else:
                                norm_exp.append(item)

                        gt_data["normalized_expected_students"] = norm_exp

                        benchmark_images.append({
                            "category": cat,
                            "image_path": img_path,
                            "json_path": jf,
                            "ground_truth": gt_data
                        })
                except Exception as e:
                    print(f"[WARN] Error loading ground truth file {jf}: {e}")

        if not benchmark_images:
            return {
                "success": False,
                "error": "No benchmark images or ground-truth JSON files found.",
                "total_images_tested": 0
            }

        # Structure to accumulate metrics
        threshold_matrix_results = {}
        for thresh in self.candidate_thresholds:
            threshold_matrix_results[str(thresh)] = {
                "threshold": thresh,
                "expected_faces": 0,
                "detected_faces": 0,
                "correct_matches": 0,    # True Positives
                "incorrect_matches": 0,  # False Positives
                "unknown_matches": 0,
                "uncertain_matches": 0,
                "missed_faces": 0,       # False Negatives
                "duplicate_predictions": 0,
                "total_detection_time_sec": 0.0,
                "total_embedding_time_sec": 0.0,
                "total_matching_time_sec": 0.0,
                "total_processing_time_sec": 0.0
            }

        category_breakdown = {}
        all_face_sizes = []

        # Process each image
        for item in benchmark_images:
            cat = item["category"]
            img_path = item["image_path"]
            gt = item["ground_truth"]
            expected_students = gt.get("normalized_expected_students", [])

            if cat not in category_breakdown:
                category_breakdown[cat] = {
                    "images_count": 0,
                    "expected_faces": 0,
                    "detected_faces": 0,
                    "correct_matches_baseline": 0
                }
            category_breakdown[cat]["images_count"] += 1
            category_breakdown[cat]["expected_faces"] += len(expected_students)

            # Read image buffer
            with open(img_path, "rb") as f:
                img_bytes = f.read()

            img_np = cv2.imread(img_path)
            if img_np is None:
                continue

            # Measure timing per pipeline stage
            t0 = time.time()
            locations = self.engine_inst.detect_faces(img_bytes)
            t1 = time.time()
            detection_time = t1 - t0

            # Record face size statistics
            for (top, right, bottom, left) in locations:
                face_w = right - left
                face_h = bottom - top
                all_face_sizes.append({
                    "width": face_w,
                    "height": face_h,
                    "area": face_w * face_h,
                    "category": cat
                })

            category_breakdown[cat]["detected_faces"] += len(locations)

            t2 = time.time()
            encodings = self.engine_inst.generate_embeddings(img_bytes, locations)
            t3 = time.time()
            embedding_time = t3 - t2

            # Evaluate each candidate threshold
            for thresh in self.candidate_thresholds:
                t4 = time.time()
                config = RecognitionConfig(distance_threshold=thresh, uncertain_threshold=thresh + 0.15)
                rec_out = self.engine_inst.recognize_image(img_bytes, enrolled_students, config=config)
                t5 = time.time()
                matching_time = t5 - t4

                tm = threshold_matrix_results[str(thresh)]
                tm["expected_faces"] += len(expected_students)
                tm["detected_faces"] += len(locations)
                tm["total_detection_time_sec"] += detection_time
                tm["total_embedding_time_sec"] += embedding_time
                tm["total_matching_time_sec"] += matching_time
                tm["total_processing_time_sec"] += (detection_time + embedding_time + matching_time)

                matched_student_ids = []
                assigned_count = {}

                for res in rec_out.get("results", []):
                    st_id = res.get("student_id")
                    st_status = res.get("status")

                    if st_status == "HIGH_CONFIDENCE" and st_id is not None:
                        matched_student_ids.append(st_id)
                        assigned_count[st_id] = assigned_count.get(st_id, 0) + 1

                        if st_id in expected_students:
                            tm["correct_matches"] += 1
                            if thresh == 0.45:
                                category_breakdown[cat]["correct_matches_baseline"] += 1
                        else:
                            tm["incorrect_matches"] += 1
                    elif st_status == "UNCERTAIN":
                        tm["uncertain_matches"] += 1
                    else:
                        tm["unknown_matches"] += 1

                # Calculate duplicates & missed faces (false negatives)
                for st_id, count in assigned_count.items():
                    if count > 1:
                        tm["duplicate_predictions"] += (count - 1)

                for exp_id in expected_students:
                    if exp_id not in matched_student_ids:
                        tm["missed_faces"] += 1

        # Calculate final summary statistics
        face_areas = [fs["area"] for fs in all_face_sizes]
        face_widths = [fs["width"] for fs in all_face_sizes]
        min_face_w = min(face_widths) if face_widths else 0
        avg_face_w = round(float(np.mean(face_widths)), 1) if face_widths else 0.0

        # Compute precision/recall metrics per threshold
        threshold_matrix_summary = []
        for thresh in self.candidate_thresholds:
            tm = threshold_matrix_results[str(thresh)]
            tp = tm["correct_matches"]
            fp = tm["incorrect_matches"]
            fn = tm["missed_faces"]
            exp = tm["expected_faces"]
            det = tm["detected_faces"]

            det_rate = round((det / max(1, exp)) * 100.0, 2)
            accuracy = round((tp / max(1, exp)) * 100.0, 2)
            fp_rate = round((fp / max(1, (tp + fp))) * 100.0, 2)
            fn_rate = round((fn / max(1, exp)) * 100.0, 2)

            avg_time_per_image = round(tm["total_processing_time_sec"] / max(1, len(benchmark_images)), 4)
            avg_time_per_face = round(tm["total_processing_time_sec"] / max(1, det), 4)

            threshold_matrix_summary.append({
                "threshold": thresh,
                "expected_faces": exp,
                "detected_faces": det,
                "detection_rate_pct": det_rate,
                "correct_matches_tp": tp,
                "incorrect_matches_fp": fp,
                "unknown_matches": tm["unknown_matches"],
                "uncertain_matches": tm["uncertain_matches"],
                "missed_faces_fn": fn,
                "duplicate_predictions": tm["duplicate_predictions"],
                "false_positive_rate_pct": fp_rate,
                "false_negative_rate_pct": fn_rate,
                "recognition_accuracy_pct": accuracy,
                "total_processing_time_sec": round(tm["total_processing_time_sec"], 3),
                "avg_time_per_image_sec": avg_time_per_image,
                "avg_time_per_face_sec": avg_time_per_face
            })

        return {
            "success": True,
            "is_synthetic_suite": is_synthetic,
            "total_images_tested": len(benchmark_images),
            "face_size_stats": {
                "min_face_width_px": min_face_w,
                "avg_face_width_px": avg_face_w,
                "total_faces_analyzed": len(all_face_sizes)
            },
            "category_breakdown": category_breakdown,
            "threshold_matrix": threshold_matrix_summary,
            "environment_label": "Development machine benchmark"
        }
