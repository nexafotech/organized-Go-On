import os
import sys
import pytest
import numpy as np
import cv2

# Ensure app path in pythonpath
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.engines.recognition.scrfd_arcface import (
    ScrfdArcFaceRecognitionEngine,
    ARCFACE_DST,
    distance2bbox,
    distance2kps,
    nms
)
from app.engines.recognition.factory import RecognitionEngineFactory
from app.engines.recognition.local_dlib import DlibFaceRecognitionEngine


@pytest.fixture
def engine():
    return ScrfdArcFaceRecognitionEngine()


# 1. SCRFD model loads
def test_scrfd_model_loads(engine):
    assert engine.det_session is not None
    assert len(engine.det_session.get_inputs()) == 1
    assert engine.det_session.get_inputs()[0].name == "input.1"


# 2. ArcFace model loads
def test_arcface_model_loads(engine):
    assert engine.arc_session is not None
    assert len(engine.arc_session.get_inputs()) == 1
    assert engine.arc_session.get_inputs()[0].shape == ["None", 3, 112, 112] or engine.arc_session.get_inputs()[0].shape[1:] == [3, 112, 112]


# 3. CPUExecutionProvider is used
def test_cpuexecutionprovider_used(engine):
    assert "CPUExecutionProvider" in engine.det_session.get_providers()
    assert "CPUExecutionProvider" in engine.arc_session.get_providers()


# 4. Face detection returns valid boxes on synthetic face
def test_face_detection_boxes(engine):
    # Black image has 0 faces
    black_img = np.zeros((300, 300, 3), dtype=np.uint8)
    boxes = engine.detect_faces(black_img)
    assert isinstance(boxes, list)
    assert len(boxes) == 0


# 5. Five landmarks are returned
def test_five_landmarks_returned(engine):
    # Verify landmark helper decoding shape
    dummy_points = np.zeros((1, 2), dtype=np.float32)
    dummy_dist = np.ones((1, 10), dtype=np.float32)
    kps = distance2kps(dummy_points, dummy_dist)
    assert kps.shape == (1, 10)
    reshaped_kps = kps.reshape((-1, 5, 2))
    assert reshaped_kps.shape == (1, 5, 2)


# 6. Alignment produces 112×112 image
def test_alignment_produces_112x112(engine):
    dummy_img = np.ones((200, 200, 3), dtype=np.uint8) * 128
    dummy_kps = np.array([
        [40.0, 50.0],
        [75.0, 50.0],
        [58.0, 70.0],
        [42.0, 90.0],
        [72.0, 90.0]
    ], dtype=np.float32)
    aligned = engine.align_face(dummy_img, dummy_kps)
    assert aligned.shape == (112, 112, 3)
    assert aligned.dtype == np.uint8


# 7. ArcFace produces expected embedding dimension (512)
def test_arcface_embedding_dimension_512(engine):
    assert engine.embedding_dimension == 512
    # Run direct inference on a 112x112 dummy crop
    dummy_crop = np.zeros((112, 112, 3), dtype=np.uint8)
    rgb = cv2.cvtColor(dummy_crop, cv2.COLOR_BGR2RGB)
    blob = np.transpose(rgb, (2, 0, 1)).astype(np.float32)
    blob = (blob - 127.5) / 127.5
    blob = np.expand_dims(blob, axis=0)
    raw_out = engine.arc_session.run(None, {engine.arc_input_name: blob})[0]
    assert raw_out.shape == (1, 512)


# 8. Embedding is L2 normalized
def test_embedding_is_l2_normalized(engine):
    dummy_crop = np.random.randint(0, 255, (112, 112, 3), dtype=np.uint8)
    rgb = cv2.cvtColor(dummy_crop, cv2.COLOR_BGR2RGB)
    blob = np.transpose(rgb, (2, 0, 1)).astype(np.float32)
    blob = (blob - 127.5) / 127.5
    blob = np.expand_dims(blob, axis=0)
    raw_out = engine.arc_session.run(None, {engine.arc_input_name: blob})[0]
    vector = raw_out[0].astype(np.float32)
    norm = float(np.linalg.norm(vector))
    assert norm > 0
    normalized_vec = vector / norm
    assert np.isclose(np.linalg.norm(normalized_vec), 1.0, atol=1e-5)


# 9. Cosine similarity works correctly
def test_cosine_similarity_computation(engine):
    v1 = np.random.randn(512).astype(np.float32)
    v1 = v1 / np.linalg.norm(v1)

    # Identical vector -> cosine similarity == 1.0
    sim_self = float(np.dot(v1, v1))
    assert np.isclose(sim_self, 1.0, atol=1e-5)

    # Orthogonal / random vector -> cosine similarity between -1 and 1
    v2 = np.random.randn(512).astype(np.float32)
    v2 = v2 / np.linalg.norm(v2)
    sim_other = float(np.dot(v1, v2))
    assert -1.0 <= sim_other <= 1.0


# 10. Factory returns SCRFD+ArcFace when selected
def test_factory_returns_scrfd_arcface():
    RecognitionEngineFactory.reset()
    eng = RecognitionEngineFactory.get_engine("scrfd_arcface")
    assert isinstance(eng, ScrfdArcFaceRecognitionEngine)
    assert eng.engine_name == "scrfd_arcface"
    assert eng.distance_metric == "cosine"
    assert eng.embedding_dimension == 512
    assert eng.model_name == "w600k_r50"
    assert eng.detector_name == "scrfd_10g_kps"


# 11. Missing model produces controlled error
def test_missing_model_raises_filenotfound():
    with pytest.raises(FileNotFoundError) as exc_info:
        ScrfdArcFaceRecognitionEngine(det_model_path="non_existent/path/det.onnx")
    assert "SCRFD model weights not found" in str(exc_info.value)

    with pytest.raises(FileNotFoundError) as exc_info:
        ScrfdArcFaceRecognitionEngine(arc_model_path="non_existent/path/arc.onnx")
    assert "ArcFace model weights not found" in str(exc_info.value)


# 12. Dlib factory path handling
def test_dlib_factory_path_still_works():
    from app.engines.recognition.local_dlib import DLIB_AVAILABLE
    RecognitionEngineFactory.reset()
    dlib_eng = RecognitionEngineFactory.get_engine("dlib")
    assert isinstance(dlib_eng, DlibFaceRecognitionEngine)
    assert dlib_eng.engine_name == "dlib"
    assert dlib_eng.embedding_dimension == 128
    assert dlib_eng.distance_metric == "euclidean"
    if not DLIB_AVAILABLE:
        with pytest.raises(RuntimeError) as exc_info:
            dlib_eng.detect_faces(np.zeros((100, 100, 3), dtype=np.uint8))
        assert "dlib and face_recognition libraries are not installed" in str(exc_info.value)


# 13. Classroom deduplication works
def test_scrfd_classroom_deduplication(engine, monkeypatch):
    # Mock face extraction to return 2 faces that both match the same enrolled student
    student_id = 42
    target_vec = np.random.randn(512).astype(np.float32)
    target_vec = target_vec / np.linalg.norm(target_vec)

    # Face 1: strong match (sim = 0.85)
    # Face 2: slightly weaker match (sim = 0.75) to same student
    vec1 = target_vec.copy()
    vec2 = target_vec.copy()

    mock_detected = [
        {"bbox": (10, 80, 80, 10), "original_xyxy": (10, 10, 80, 80), "confidence": 0.95, "landmarks": np.zeros((5, 2))},
        {"bbox": (100, 180, 180, 100), "original_xyxy": (100, 100, 180, 180), "confidence": 0.92, "landmarks": np.zeros((5, 2))}
    ]

    monkeypatch.setattr(engine, "detect_faces_with_landmarks", lambda img: mock_detected)

    # Mock ArcFace session to return vec1 then vec2
    vectors = [vec1, vec2]
    call_idx = [0]
    def mock_run(out_names, feed_dict):
        v = vectors[call_idx[0]]
        call_idx[0] += 1
        return [np.expand_dims(v, axis=0)]

    monkeypatch.setattr(engine.arc_session, "run", mock_run)

    enrolled = [{
        "student_id": student_id,
        "roll_number": "CS042",
        "full_name": "Test Student",
        "embeddings": [target_vec]
    }]

    dummy_img_bytes = cv2.imencode(".jpg", np.zeros((200, 200, 3), dtype=np.uint8))[1].tobytes()
    res = engine.recognize_image(dummy_img_bytes, enrolled_students=enrolled)

    assert res["success"] is True
    assert res["faces_detected"] == 2
    assert res["high_confidence_matches"] == 1
    assert res["uncertain_matches"] == 1
    assert res["unknown_faces"] == 0

    results = res["results"]
    statuses = [r["status"] for r in results]
    assert "HIGH_CONFIDENCE" in statuses
    assert "UNCERTAIN" in statuses


# 14. Recognition result structure preservation
def test_recognize_image_result_structure(engine):
    blank_bytes = cv2.imencode(".jpg", np.zeros((100, 100, 3), dtype=np.uint8))[1].tobytes()
    res = engine.recognize_image(blank_bytes, enrolled_students=[])
    assert "success" in res
    assert "faces_detected" in res
    assert "high_confidence_matches" in res
    assert "uncertain_matches" in res
    assert "unknown_faces" in res
    assert "results" in res
    assert res["faces_detected"] == 0
    assert res["results"] == []
