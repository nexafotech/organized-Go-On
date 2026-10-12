import os
import time
import logging
import cv2
import numpy as np
import onnxruntime as ort
from typing import List, Dict, Any, Tuple, Optional
from app.engines.recognition.base import BaseRecognitionEngine, RecognitionConfig

logger = logging.getLogger(__name__)

# Canonical 5-point facial landmark template for 112x112 ArcFace alignment
# Format: (x, y) coordinates for [left_eye, right_eye, nose_tip, left_mouth_corner, right_mouth_corner]
ARCFACE_DST = np.array([
    [38.2946, 51.6963],  # left eye
    [73.5318, 51.5014],  # right eye
    [56.0252, 71.7366],  # nose tip
    [41.5493, 92.3655],  # left mouth corner
    [70.7299, 92.2041]   # right mouth corner
], dtype=np.float32)


def distance2bbox(points: np.ndarray, distance: np.ndarray, max_shape: Optional[Tuple[int, int]] = None) -> np.ndarray:
    """
    Decodes distance predictions from anchor points into bounding box coordinates (x1, y1, x2, y2).
    """
    x1 = points[:, 0] - distance[:, 0]
    y1 = points[:, 1] - distance[:, 1]
    x2 = points[:, 0] + distance[:, 2]
    y2 = points[:, 1] + distance[:, 3]
    if max_shape is not None:
        x1 = np.clip(x1, 0, max_shape[1])
        y1 = np.clip(y1, 0, max_shape[0])
        x2 = np.clip(x2, 0, max_shape[1])
        y2 = np.clip(y2, 0, max_shape[0])
    return np.stack([x1, y1, x2, y2], axis=-1)


def distance2kps(points: np.ndarray, distance: np.ndarray, max_shape: Optional[Tuple[int, int]] = None) -> np.ndarray:
    """
    Decodes distance predictions from anchor points into 5 facial landmark coordinates (x, y).
    """
    preds = []
    for i in range(0, distance.shape[1], 2):
        px = points[:, 0] + distance[:, i]
        py = points[:, 1] + distance[:, i + 1]
        if max_shape is not None:
            px = np.clip(px, 0, max_shape[1])
            py = np.clip(py, 0, max_shape[0])
        preds.append(px)
        preds.append(py)
    return np.stack(preds, axis=-1)


def nms(boxes: np.ndarray, scores: np.ndarray, thresh: float = 0.4) -> List[int]:
    """
    Standard Non-Maximum Suppression (NMS) for (x1, y1, x2, y2) bounding boxes.
    """
    if len(boxes) == 0:
        return []
    x1 = boxes[:, 0]
    y1 = boxes[:, 1]
    x2 = boxes[:, 2]
    y2 = boxes[:, 3]
    areas = (x2 - x1 + 1) * (y2 - y1 + 1)
    order = scores.argsort()[::-1]
    keep = []
    while order.size > 0:
        i = order[0]
        keep.append(int(i))
        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])
        w = np.maximum(0.0, xx2 - xx1 + 1)
        h = np.maximum(0.0, yy2 - yy1 + 1)
        inter = w * h
        ovr = inter / (areas[i] + areas[order[1:]] - inter)
        inds = np.where(ovr <= thresh)[0]
        order = order[inds + 1]
    return keep


class ScrfdArcFaceRecognitionEngine(BaseRecognitionEngine):
    """
    Next-generation facial recognition engine using SCRFD for face detection & 5-point landmark localization,
    OpenCV affine partial-2D transformation for face alignment, and ArcFace ResNet-50 for 512-d normalized
    feature extraction via ONNX Runtime CPU.
    """

    def __init__(
        self,
        det_model_path: Optional[str] = None,
        arc_model_path: Optional[str] = None,
        score_threshold: float = 0.40,
        nms_threshold: float = 0.40,
        input_size: int = 640
    ):
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
        default_det_path = os.path.join(base_dir, "models", "face_recognition", "det_10g.onnx")
        default_arc_path = os.path.join(base_dir, "models", "face_recognition", "w600k_r50.onnx")

        self.det_model_path = det_model_path or default_det_path
        self.arc_model_path = arc_model_path or default_arc_path
        self.score_threshold = score_threshold
        self.nms_threshold = nms_threshold
        self.input_size = input_size

        if not os.path.exists(self.det_model_path):
            raise FileNotFoundError(
                f"SCRFD model weights not found at: '{self.det_model_path}'. "
                "Ensure det_10g.onnx is present in models/face_recognition/ directory."
            )

        if not os.path.exists(self.arc_model_path):
            raise FileNotFoundError(
                f"ArcFace model weights not found at: '{self.arc_model_path}'. "
                "Ensure w600k_r50.onnx is present in models/face_recognition/ directory."
            )

        # Initialize ONNX Runtime sessions with optimized CPUExecutionProvider
        sess_options = ort.SessionOptions()
        cpu_count = os.cpu_count() or 4
        # Threading configuration tuned for multi-core CPU inference without oversubscription
        sess_options.intra_op_num_threads = min(4, cpu_count)
        sess_options.inter_op_num_threads = 1
        sess_options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
        sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        sess_options.enable_cpu_mem_arena = True
        sess_options.add_session_config_entry("session.intra_op.allow_spinning", "0")
        sess_options.log_severity_level = 3  # Suppress non-critical dynamic batch shape warnings

        force_cpu = os.getenv("RECOGNITION_FORCE_CPU", "true").strip().lower() in ("true", "1", "yes")
        if force_cpu:
            preferred_providers = ["CPUExecutionProvider"]
        else:
            available_providers = ort.get_available_providers()
            preferred_providers = [p for p in ["CUDAExecutionProvider", "CPUExecutionProvider"] if p in available_providers]
            if not preferred_providers:
                preferred_providers = ["CPUExecutionProvider"]

        try:
            self.det_session = ort.InferenceSession(
                self.det_model_path,
                sess_options=sess_options,
                providers=preferred_providers
            )
        except Exception:
            self.det_session = ort.InferenceSession(
                self.det_model_path,
                sess_options=sess_options,
                providers=["CPUExecutionProvider"]
            )

        try:
            self.arc_session = ort.InferenceSession(
                self.arc_model_path,
                sess_options=sess_options,
                providers=preferred_providers
            )
        except Exception:
            self.arc_session = ort.InferenceSession(
                self.arc_model_path,
                sess_options=sess_options,
                providers=["CPUExecutionProvider"]
            )

        self.det_input_name = self.det_session.get_inputs()[0].name
        self.arc_input_name = self.arc_session.get_inputs()[0].name

        # SCRFD FPN parameters
        self.fmc = 3
        self.feat_stride_fpn = [8, 16, 32]
        self.num_anchors = 2
        self.center_cache: Dict[Tuple[int, int, int], np.ndarray] = {}


    @property
    def engine_name(self) -> str:
        return "scrfd_arcface"

    @property
    def embedding_dimension(self) -> int:
        return 512

    @property
    def distance_metric(self) -> str:
        return "cosine"

    @property
    def model_name(self) -> str:
        return "w600k_r50"

    @property
    def model_version(self) -> str:
        return "v1"

    @property
    def detector_name(self) -> str:
        return "scrfd_10g_kps"

    def _decode_image(self, image_bytes_or_array: Any) -> Optional[np.ndarray]:
        if isinstance(image_bytes_or_array, bytes):
            if not image_bytes_or_array or len(image_bytes_or_array) == 0:
                return None
            try:
                from PIL import Image, ImageOps
                import io
                pil_img = Image.open(io.BytesIO(image_bytes_or_array))
                pil_img = ImageOps.exif_transpose(pil_img)
                if pil_img.mode != "RGB":
                    pil_img = pil_img.convert("RGB")
                return cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
            except Exception:
                try:
                    nparr = np.frombuffer(image_bytes_or_array, np.uint8)
                    if nparr.size > 0:
                        return cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                except Exception:
                    return None
                return None
        elif isinstance(image_bytes_or_array, np.ndarray):
            return image_bytes_or_array
        return None

    def detect_faces_with_landmarks(
        self,
        image_bytes_or_array: Any,
        score_thresh: Optional[float] = None
    ) -> List[Dict[str, Any]]:
        """
        Detect faces in image and extract 5 facial landmarks for each face.
        Returns list of dicts with:
        - 'bbox': (top, right, bottom, left)
        - 'confidence': float
        - 'landmarks': (5, 2) numpy array
        - 'original_xyxy': (x1, y1, x2, y2)
        """
        img = self._decode_image(image_bytes_or_array)
        if img is None:
            return []

        orig_h, orig_w = img.shape[:2]
        target_size = self.input_size
        max_dim = max(orig_h, orig_w)
        scale = target_size / float(max_dim)
        new_w = int(orig_w * scale)
        new_h = int(orig_h * scale)

        resized_img = cv2.resize(img, (new_w, new_h))
        det_img = np.zeros((target_size, target_size, 3), dtype=np.uint8)
        det_img[:new_h, :new_w, :] = resized_img

        blob = cv2.dnn.blobFromImage(
            det_img,
            scalefactor=1.0 / 128.0,
            size=(target_size, target_size),
            mean=(127.5, 127.5, 127.5),
            swapRB=False
        )

        outputs = self.det_session.run(None, {self.det_input_name: blob})

        scores_list = []
        bboxes_list = []
        kpss_list = []
        thresh = score_thresh or self.score_threshold

        for idx, stride in enumerate(self.feat_stride_fpn):
            scores = outputs[idx]
            bbox_preds = outputs[idx + self.fmc] * stride
            kps_preds = outputs[idx + self.fmc * 2] * stride

            height = target_size // stride
            width = target_size // stride
            cache_key = (height, width, stride)
            if cache_key in self.center_cache:
                anchor_centers = self.center_cache[cache_key]
            else:
                anchor_centers = np.stack(np.mgrid[:height, :width][::-1], axis=-1).astype(np.float32)
                anchor_centers = (anchor_centers * stride).reshape((-1, 2))
                if self.num_anchors > 1:
                    anchor_centers = np.stack([anchor_centers] * self.num_anchors, axis=1).reshape((-1, 2))
                self.center_cache[cache_key] = anchor_centers

            pos_inds = np.where(scores >= thresh)[0]
            if len(pos_inds) > 0:
                bboxes = distance2bbox(anchor_centers, bbox_preds)
                kpss = distance2kps(anchor_centers, kps_preds).reshape((-1, 5, 2))

                scores_list.append(scores[pos_inds])
                bboxes_list.append(bboxes[pos_inds])
                kpss_list.append(kpss[pos_inds])

        if not scores_list:
            return []

        all_scores = np.vstack(scores_list).flatten()
        all_bboxes = np.vstack(bboxes_list)
        all_kpss = np.vstack(kpss_list)

        keep = nms(all_bboxes, all_scores, thresh=self.nms_threshold)
        if not keep:
            return []

        all_scores = all_scores[keep]
        all_bboxes = all_bboxes[keep] / scale
        all_kpss = all_kpss[keep] / scale

        detected_faces = []
        for i in range(len(keep)):
            x1, y1, x2, y2 = all_bboxes[i]
            x1 = max(0, min(orig_w, x1))
            y1 = max(0, min(orig_h, y1))
            x2 = max(0, min(orig_w, x2))
            y2 = max(0, min(orig_h, y2))

            top = int(round(y1))
            right = int(round(x2))
            bottom = int(round(y2))
            left = int(round(x1))

            detected_faces.append({
                "bbox": (top, right, bottom, left),
                "original_xyxy": (float(x1), float(y1), float(x2), float(y2)),
                "confidence": float(all_scores[i]),
                "landmarks": all_kpss[i]
            })

        return detected_faces

    def detect_faces(self, image_bytes_or_array: Any, model: str = "hog") -> List[Tuple[int, int, int, int]]:
        """
        Detect face bounding boxes in an image.
        Returns list of (top, right, bottom, left) tuples conforming to BaseRecognitionEngine.
        """
        faces = self.detect_faces_with_landmarks(image_bytes_or_array)
        return [f["bbox"] for f in faces]

    def align_face(self, img: np.ndarray, landmarks: np.ndarray) -> np.ndarray:
        """
        Aligns a detected face into canonical 112x112 ArcFace input geometry using 5 facial landmarks.
        """
        M, _ = cv2.estimateAffinePartial2D(landmarks.astype(np.float32), ARCFACE_DST)
        if M is None:
            # Fallback to direct resize if affine estimation fails
            return cv2.resize(img, (112, 112))
        aligned = cv2.warpAffine(img, M, (112, 112), borderValue=0.0)
        return aligned

    def generate_embeddings(
        self,
        image_bytes_or_array: Any,
        face_locations: Optional[List[Tuple[int, int, int, int]]] = None
    ) -> List[np.ndarray]:
        """
        Extracts 512-dimensional facial embedding vectors from face locations.
        Each vector is L2-normalized (unit norm).
        """
        img = self._decode_image(image_bytes_or_array)
        if img is None:
            return []

        detected_faces = self.detect_faces_with_landmarks(img)
        if not detected_faces:
            return []

        # If specific face_locations were requested, map each location to best matching detected face
        faces_to_process = []
        if face_locations is not None:
            for loc in face_locations:
                lt, lr, lb, ll = loc
                best_face = None
                best_iou = -1.0
                for df in detected_faces:
                    dt, dr, db, dl = df["bbox"]
                    inter_t = max(lt, dt)
                    inter_l = max(ll, dl)
                    inter_b = min(lb, db)
                    inter_r = min(lr, dr)
                    inter_w = max(0, inter_r - inter_l)
                    inter_h = max(0, inter_b - inter_t)
                    inter_area = inter_w * inter_h
                    area1 = max(1, (lr - ll) * (lb - lt))
                    area2 = max(1, (dr - dl) * (db - dt))
                    iou = inter_area / float(area1 + area2 - inter_area)
                    if iou > best_iou:
                        best_iou = iou
                        best_face = df
                if best_face is not None:
                    faces_to_process.append(best_face)
        else:
            faces_to_process = detected_faces

        embeddings = []
        for face_info in faces_to_process:
            landmarks = face_info["landmarks"]
            aligned = self.align_face(img, landmarks)

            # Preprocess for ArcFace: BGR -> RGB, (3, 112, 112), normalized (x - 127.5) / 127.5
            rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB)
            blob = np.transpose(rgb, (2, 0, 1)).astype(np.float32)
            blob = (blob - 127.5) / 127.5
            blob = np.expand_dims(blob, axis=0)

            raw_out = self.arc_session.run(None, {self.arc_input_name: blob})[0]
            vector = raw_out[0].astype(np.float32)
            norm = float(np.linalg.norm(vector))
            if norm > 0:
                vector = vector / norm
            embeddings.append(vector)

        return embeddings

    def recognize_image(
        self,
        image_bytes: bytes,
        enrolled_students: List[Dict[str, Any]],
        config: Optional[RecognitionConfig] = None
    ) -> Dict[str, Any]:
        """
        Process single or multi-face image against enrolled student embeddings using SCRFD detection,
        OpenCV landmark affine alignment, ArcFace 512-d embeddings, and cosine similarity.
        Applies classroom deduplication: if multiple faces match the same student, the highest similarity
        match is retained and secondary matches are demoted to UNCERTAIN.
        """
        img = self._decode_image(image_bytes)
        if img is None:
            return {
                "success": False,
                "error": "Failed to decode image",
                "faces_detected": 0,
                "high_confidence_matches": 0,
                "uncertain_matches": 0,
                "unknown_faces": 0,
                "results": []
            }

        cfg = config or RecognitionConfig()
        min_face_size = cfg.min_face_size

        # In Cosine Similarity:
        # High confidence match: sim >= 0.50
        # Uncertain candidate match: 0.35 <= sim < 0.50
        # Unknown: sim < 0.35
        high_conf_thresh = getattr(cfg, "cosine_high_confidence_threshold", 0.50)
        uncertain_thresh = getattr(cfg, "cosine_uncertain_threshold", 0.35)

        t_r0 = time.perf_counter()
        detected_faces = self.detect_faces_with_landmarks(img)
        t_r1 = time.perf_counter()
        # Filter by minimum face size
        valid_faces = []
        for f in detected_faces:
            top, right, bottom, left = f["bbox"]
            w = right - left
            h = bottom - top
            if w >= min_face_size and h >= min_face_size:
                valid_faces.append(f)

        if not valid_faces:
            return {
                "success": True,
                "faces_detected": 0,
                "high_confidence_matches": 0,
                "uncertain_matches": 0,
                "unknown_faces": 0,
                "results": []
            }

        # Build enrolled lookup table
        student_lookup: Dict[int, Dict[str, Any]] = {}
        for st in enrolled_students:
            student_lookup[st["student_id"]] = st

        # Phase 1: Extract 512-d normalized embedding for each valid face
        t_arc0 = time.perf_counter()
        extracted_faces = []
        for face_idx, f in enumerate(valid_faces):
            landmarks = f["landmarks"]
            aligned = self.align_face(img, landmarks)

            rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB)
            blob = np.transpose(rgb, (2, 0, 1)).astype(np.float32)
            blob = (blob - 127.5) * (1.0 / 127.5)
            blob = np.expand_dims(blob, axis=0)

            raw_out = self.arc_session.run(None, {self.arc_input_name: blob})[0]
            vector = raw_out[0].astype(np.float32)
            norm = float(np.linalg.norm(vector))
            if norm > 0:
                vector = vector / norm

            extracted_faces.append({
                "face_idx": face_idx,
                "bbox": f["bbox"],
                "landmarks": [[float(pt[0]), float(pt[1])] for pt in landmarks],
                "confidence": f["confidence"],
                "embedding": vector
            })
        t_arc1 = time.perf_counter()

        # Phase 2: Compute cosine similarity against all enrolled student vectors
        t_gemm0 = time.perf_counter()
        all_enrolled_vecs = []
        enrolled_student_mapping = []
        for st_id, st_info in student_lookup.items():
            for enrolled_vec in st_info.get("embeddings", []):
                if enrolled_vec is not None and len(enrolled_vec) == self.embedding_dimension:
                    v_norm = enrolled_vec.astype(np.float32)
                    if not np.all(np.isfinite(v_norm)):
                        continue
                    norm_val = float(np.linalg.norm(v_norm))
                    if norm_val < 1e-6:
                        continue
                    v_norm = v_norm / norm_val
                    all_enrolled_vecs.append(v_norm)
                    enrolled_student_mapping.append(st_id)

        has_enrolled = len(all_enrolled_vecs) > 0
        enrolled_mat = np.vstack(all_enrolled_vecs) if has_enrolled else None

        if has_enrolled and extracted_faces:
            probe_mat = np.vstack([item["embedding"] for item in extracted_faces])
            all_sims = np.dot(probe_mat, enrolled_mat.T)
        else:
            all_sims = None
        t_gemm1 = time.perf_counter()

        logger.info(
            f"[ScrfdArcFace PERF] detect_ms={(t_r1 - t_r0)*1000:.1f}, "
            f"arcface_embs_ms={(t_arc1 - t_arc0)*1000:.1f}, "
            f"gemm_match_ms={(t_gemm1 - t_gemm0)*1000:.1f}"
        )

        face_matches = []
        for face_idx_in_extracted, item in enumerate(extracted_faces):
            candidate_list = []
            best_sim = -1.0
            best_st_id = None

            if has_enrolled and all_sims is not None:
                sims = all_sims[face_idx_in_extracted]
                student_best_sims: Dict[int, float] = {}
                for sim_val, st_id in zip(sims, enrolled_student_mapping):
                    s_val = float(sim_val)
                    if st_id not in student_best_sims or s_val > student_best_sims[st_id]:
                        student_best_sims[st_id] = s_val

                sorted_cands = sorted(student_best_sims.items(), key=lambda x: x[1], reverse=True)
                if sorted_cands:
                    best_st_id, best_sim = sorted_cands[0]
                    for cand_id, cand_sim in sorted_cands:
                        cand_st = student_lookup.get(cand_id)
                        cand_dist = max(0.0, 1.0 - cand_sim)
                        cand_score = round(max(0.0, min(100.0, cand_sim * 100.0)), 2)
                        candidate_list.append({
                            "student_id": cand_id,
                            "roll_number": cand_st["roll_number"] if cand_st else "",
                            "name": cand_st["full_name"] if cand_st else "",
                            "similarity": round(cand_sim, 4),
                            "distance": round(cand_dist, 4),
                            "derived_score": cand_score
                        })

            top_candidates = candidate_list[:5]
            top_b, right_b, bottom_b, left_b = item["bbox"]
            bbox_dict = {
                "top": int(top_b),
                "right": int(right_b),
                "bottom": int(bottom_b),
                "left": int(left_b)
            }

            face_matches.append({
                "face_index": item["face_idx"],
                "bounding_box": bbox_dict,
                "bbox": item["bbox"],
                "landmarks": item["landmarks"],
                "detection_confidence": round(item["confidence"], 4),
                "best_sim": best_sim,
                "best_st_id": best_st_id,
                "candidates": top_candidates
            })

        # Phase 3: Sort faces by best_sim descending to allocate strongest matches first (Deduplication)
        face_matches.sort(key=lambda x: x["best_sim"], reverse=True)

        assigned_students = set()
        results = []
        high_confidence_count = 0
        uncertain_count = 0
        unknown_count = 0

        for match in face_matches:
            best_sim = match["best_sim"]
            best_st_id = match["best_st_id"]
            best_st_info = student_lookup.get(best_st_id) if best_st_id else None

            # Calculate derived score percentage (0 - 100)
            derived_score = round(max(0.0, min(100.0, best_sim * 100.0)), 2)
            distance_val = round(max(0.0, 1.0 - best_sim), 4)

            if best_sim >= high_conf_thresh and best_st_id is not None:
                # High confidence candidate
                if best_st_id in assigned_students:
                    # Same student already assigned to another face in this photo -> demote to UNCERTAIN
                    status_str = "UNCERTAIN"
                    uncertain_count += 1
                else:
                    status_str = "HIGH_CONFIDENCE"
                    assigned_students.add(best_st_id)
                    high_confidence_count += 1

                results.append({
                    "face_index": match["face_index"],
                    "bounding_box": match["bounding_box"],
                    "bbox": match["bbox"],
                    "landmarks": match["landmarks"],
                    "detection_confidence": match["detection_confidence"],
                    "student_id": best_st_id,
                    "roll_number": best_st_info["roll_number"] if best_st_info else None,
                    "name": best_st_info["full_name"] if best_st_info else None,
                    "similarity": round(best_sim, 4),
                    "distance": distance_val,
                    "derived_score": derived_score,
                    "status": status_str,
                    "candidates": match["candidates"]
                })
            elif best_sim >= uncertain_thresh and best_st_id is not None:
                status_str = "UNCERTAIN"
                uncertain_count += 1
                results.append({
                    "face_index": match["face_index"],
                    "bounding_box": match["bounding_box"],
                    "bbox": match["bbox"],
                    "landmarks": match["landmarks"],
                    "detection_confidence": match["detection_confidence"],
                    "student_id": best_st_id,
                    "roll_number": best_st_info["roll_number"] if best_st_info else None,
                    "name": best_st_info["full_name"] if best_st_info else None,
                    "similarity": round(best_sim, 4),
                    "distance": distance_val,
                    "derived_score": derived_score,
                    "status": status_str,
                    "candidates": match["candidates"]
                })
            else:
                status_str = "UNKNOWN"
                unknown_count += 1
                results.append({
                    "face_index": match["face_index"],
                    "bounding_box": match["bounding_box"],
                    "bbox": match["bbox"],
                    "landmarks": match["landmarks"],
                    "detection_confidence": match["detection_confidence"],
                    "student_id": None,
                    "roll_number": None,
                    "name": None,
                    "similarity": round(best_sim, 4) if best_sim > -1 else None,
                    "distance": distance_val if best_sim > -1 else 1.0,
                    "derived_score": derived_score,
                    "status": status_str,
                    "candidates": match["candidates"]
                })

        # Re-sort results by face_index
        results.sort(key=lambda x: x["face_index"])

        return {
            "success": True,
            "faces_detected": len(valid_faces),
            "high_confidence_matches": high_confidence_count,
            "uncertain_matches": uncertain_count,
            "unknown_faces": unknown_count,
            "results": results
        }
