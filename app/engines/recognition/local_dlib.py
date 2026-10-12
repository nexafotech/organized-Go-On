import json
import io
import os
import cv2
import numpy as np

try:
    import dlib
    import face_recognition
    from face_recognition.api import _raw_face_landmarks, face_encoder
    DLIB_AVAILABLE = True
except ImportError:
    dlib = None
    face_recognition = None
    _raw_face_landmarks = None
    face_encoder = None
    DLIB_AVAILABLE = False

from concurrent.futures import ThreadPoolExecutor
from typing import List, Dict, Any, Tuple, Optional
from app.engines.recognition.base import BaseRecognitionEngine, RecognitionConfig

class DlibFaceRecognitionEngine(BaseRecognitionEngine):
    """
    Local Dlib/face_recognition implementation of BaseRecognitionEngine.
    Processes multi-face single/group photographs against enrolled student embeddings.
    Optimized in Phase 10 with parallelized encoding, image dimension clamping,
    and vectorized NumPy matching.
    """

    def __init__(self):
        pass

    def _check_available(self):
        if not DLIB_AVAILABLE:
            raise RuntimeError(
                "dlib and face_recognition libraries are not installed in this environment. "
                "Please configure FACE_RECOGNITION_ENGINE='scrfd_arcface' to use the ONNX Runtime engine."
            )

    def _decode_image(self, image_bytes_or_array: Any) -> Optional[np.ndarray]:
        if isinstance(image_bytes_or_array, np.ndarray):
            return image_bytes_or_array
        if isinstance(image_bytes_or_array, bytes):
            nparr = np.frombuffer(image_bytes_or_array, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            return img
        return None

    def detect_faces(self, image_bytes_or_array: Any, model: str = "hog") -> List[Tuple[int, int, int, int]]:
        self._check_available()
        img = self._decode_image(image_bytes_or_array)
        if img is None:
            return []

        h, w = img.shape[:2]
        max_dim = 1600
        if max(h, w) > max_dim:
            scale = max_dim / float(max(h, w))
            new_w, new_h = int(w * scale), int(h * scale)
            proc_img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
            rgb = cv2.cvtColor(proc_img, cv2.COLOR_BGR2RGB)
            raw_locs = face_recognition.face_locations(rgb, model=model)
            return [(int(t / scale), int(r / scale), int(b / scale), int(l / scale)) for (t, r, b, l) in raw_locs]

        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        locations = face_recognition.face_locations(rgb, model=model)
        return locations

    def generate_embeddings(
        self, image_bytes_or_array: Any, face_locations: Optional[List[Tuple[int, int, int, int]]] = None
    ) -> List[np.ndarray]:
        self._check_available()
        img = self._decode_image(image_bytes_or_array)
        if img is None:
            return []

        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        if face_locations is None:
            face_locations = self.detect_faces(img)

        if not face_locations:
            return []

        if len(face_locations) > 1:
            workers = min(len(face_locations), os.cpu_count() or 4)
            def _encode_single(loc):
                return face_recognition.face_encodings(rgb, [loc])[0]
            with ThreadPoolExecutor(max_workers=workers) as pool:
                return list(pool.map(_encode_single, face_locations))

        return face_recognition.face_encodings(rgb, face_locations)

    def recognize_image(
        self,
        image_bytes: Any,
        enrolled_students: List[Dict[str, Any]],
        config: Optional[RecognitionConfig] = None
    ) -> Dict[str, Any]:
        self._check_available()
        if config is None:
            config = RecognitionConfig()

        img = self._decode_image(image_bytes)
        if img is None:
            return {
                "success": False,
                "error": "Invalid or unreadable image file format",
                "faces_detected": 0,
                "high_confidence_matches": 0,
                "uncertain_matches": 0,
                "unknown_faces": 0,
                "results": []
            }

        height, width = img.shape[:2]
        max_dim = 1600

        # Preprocessing: clamp oversized phone camera photos (e.g., 12MP 3000x4000) to max 1600px
        if max(height, width) > max_dim:
            scale = max_dim / float(max(height, width))
            new_w, new_h = int(width * scale), int(height * scale)
            proc_img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
            proc_rgb = cv2.cvtColor(proc_img, cv2.COLOR_BGR2RGB)
            raw_locations = face_recognition.face_locations(proc_rgb, model=config.detection_model)
            # Map back to original coordinate system
            locations = [
                (int(t / scale), int(r / scale), int(b / scale), int(l / scale))
                for (t, r, b, l) in raw_locations
            ]
            rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        else:
            rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            locations = face_recognition.face_locations(rgb, model=config.detection_model)

        if not locations:
            return {
                "success": True,
                "faces_detected": 0,
                "high_confidence_matches": 0,
                "uncertain_matches": 0,
                "unknown_faces": 0,
                "results": []
            }

        # Filter locations by minimum face dimension
        valid_locations = []
        for (top, right, bottom, left) in locations:
            face_w = right - left
            face_h = bottom - top
            if face_w >= config.min_face_size and face_h >= config.min_face_size:
                valid_locations.append((top, right, bottom, left))

        if not valid_locations:
            return {
                "success": True,
                "faces_detected": len(locations),
                "high_confidence_matches": 0,
                "uncertain_matches": 0,
                "unknown_faces": len(locations),
                "warning": "Detected face(s) below minimum size threshold",
                "results": []
            }

        # High-performance C++ batch descriptor computation via Dlib OpenMP
        try:
            raw_landmarks = _raw_face_landmarks(rgb, valid_locations, model="small")
            detections = dlib.full_object_detections()
            for landmark_set in raw_landmarks:
                detections.append(landmark_set)
            raw_descriptors = face_encoder.compute_face_descriptor(rgb, detections, num_jitters=1)
            encodings = [np.array(desc, dtype=np.float64) for desc in raw_descriptors]
        except Exception:
            # Safe fallback to standard face_recognition.face_encodings
            encodings = face_recognition.face_encodings(rgb, valid_locations)

        # Build lookup of student embeddings
        student_lookup = {}
        all_embeddings = []
        embedding_to_student = []

        for st in enrolled_students:
            student_lookup[st["student_id"]] = st
            for emb in st.get("embeddings", []):
                all_embeddings.append(emb)
                embedding_to_student.append(st["student_id"])

        results = []
        assigned_students = set()  # Tracks assigned student IDs to prevent duplicate identity assignment

        high_confidence_count = 0
        uncertain_count = 0
        unknown_count = 0

        # Vectorized Euclidean matching against pre-stacked embedding matrix
        has_enrolled = len(all_embeddings) > 0
        emb_matrix = np.vstack(all_embeddings) if has_enrolled else None

        for face_idx, (encoding, loc) in enumerate(zip(encodings, valid_locations), start=1):
            top, right, bottom, left = loc
            face_box = {"top": top, "right": right, "bottom": bottom, "left": left}

            if not has_enrolled:
                # No enrolled embeddings available
                results.append({
                    "face_index": face_idx,
                    "bounding_box": face_box,
                    "student_id": None,
                    "roll_number": None,
                    "name": None,
                    "distance": None,
                    "derived_score": 0.0,
                    "status": "UNKNOWN",
                    "candidates": []
                })
                unknown_count += 1
                continue

            # Vectorized Euclidean distances to all enrolled embeddings in C/NumPy
            diff = emb_matrix - encoding
            distances = np.linalg.norm(diff, axis=1)

            # Map distances per student (take min distance per student)
            student_min_distances: Dict[int, float] = {}
            for dist, st_id in zip(distances, embedding_to_student):
                dist_val = float(dist)
                if st_id not in student_min_distances or dist_val < student_min_distances[st_id]:
                    student_min_distances[st_id] = dist_val

            # Sort candidate students by distance ascending
            sorted_candidates = sorted(student_min_distances.items(), key=lambda x: x[1])

            if not sorted_candidates:
                results.append({
                    "face_index": face_idx,
                    "bounding_box": face_box,
                    "student_id": None,
                    "roll_number": None,
                    "name": None,
                    "distance": None,
                    "derived_score": 0.0,
                    "status": "UNKNOWN",
                    "candidates": []
                })
                unknown_count += 1
                continue

            best_st_id, best_dist = sorted_candidates[0]

            # Build top candidate choices list for UI review
            candidate_list = []
            for cand_id, cand_dist in sorted_candidates[:3]:
                cand_st = student_lookup.get(cand_id)
                cand_score = max(0.0, min(100.0, (1.0 - (cand_dist / config.uncertain_threshold)) * 100.0))
                candidate_list.append({
                    "student_id": cand_id,
                    "roll_number": cand_st["roll_number"] if cand_st else "",
                    "name": cand_st["full_name"] if cand_st else "",
                    "distance": round(cand_dist, 4),
                    "derived_score": round(cand_score, 2)
                })

            derived_score = max(0.0, min(100.0, (1.0 - (best_dist / config.uncertain_threshold)) * 100.0))
            derived_score = round(derived_score, 2)
            best_st_info = student_lookup.get(best_st_id)

            # Classify match status
            if best_dist <= config.distance_threshold:
                # HIGH_CONFIDENCE candidate
                if best_st_id in assigned_students:
                    # Same student already assigned to another face -> treat as UNCERTAIN
                    status_str = "UNCERTAIN"
                    uncertain_count += 1
                else:
                    status_str = "HIGH_CONFIDENCE"
                    assigned_students.add(best_st_id)
                    high_confidence_count += 1

                results.append({
                    "face_index": face_idx,
                    "bounding_box": face_box,
                    "student_id": best_st_id,
                    "roll_number": best_st_info["roll_number"] if best_st_info else None,
                    "name": best_st_info["full_name"] if best_st_info else None,
                    "distance": round(best_dist, 4),
                    "derived_score": derived_score,
                    "status": status_str,
                    "candidates": candidate_list
                })

            elif best_dist <= config.uncertain_threshold:
                # UNCERTAIN candidate
                status_str = "UNCERTAIN"
                uncertain_count += 1
                results.append({
                    "face_index": face_idx,
                    "bounding_box": face_box,
                    "student_id": best_st_id,
                    "roll_number": best_st_info["roll_number"] if best_st_info else None,
                    "name": best_st_info["full_name"] if best_st_info else None,
                    "distance": round(best_dist, 4),
                    "derived_score": derived_score,
                    "status": status_str,
                    "candidates": candidate_list
                })
            else:
                # UNKNOWN face
                status_str = "UNKNOWN"
                unknown_count += 1
                results.append({
                    "face_index": face_idx,
                    "bounding_box": face_box,
                    "student_id": None,
                    "roll_number": None,
                    "name": None,
                    "distance": round(best_dist, 4),
                    "derived_score": derived_score,
                    "status": status_str,
                    "candidates": candidate_list
                })

        return {
            "success": True,
            "faces_detected": len(valid_locations),
            "high_confidence_matches": high_confidence_count,
            "uncertain_matches": uncertain_count,
            "unknown_faces": unknown_count,
            "results": results
        }

