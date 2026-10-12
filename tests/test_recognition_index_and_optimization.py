import os
import sys
import threading
import pytest
import numpy as np
from unittest.mock import MagicMock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.recognition_index import RecognitionIndexManager, ClassRecognitionCache
from app.engines.recognition.local_dlib import DlibFaceRecognitionEngine


class DummyEngine:
    model_name = "dlib_resnet"
    embedding_dimension = 128
    distance_metric = "euclidean"


def test_index_manager_singleton():
    mgr1 = RecognitionIndexManager.get_instance()
    mgr2 = RecognitionIndexManager.get_instance()
    assert mgr1 is mgr2


def test_index_cache_build_and_hit():
    manager = RecognitionIndexManager()
    db = MagicMock()
    engine = DummyEngine()

    mock_student = MagicMock()
    mock_student.id = 101
    mock_student.roll_number = "TEST001"
    mock_student.full_name = "Test Student"

    mock_emb = MagicMock()
    mock_emb.id = 1
    mock_emb.student_id = 101
    mock_emb.dimension = 128
    mock_emb.model_name = "dlib_resnet"
    mock_emb.distance_metric = "euclidean"
    mock_emb.embedding_json = str([0.1] * 128)

    db.query.return_value.filter.return_value.all.side_effect = [
        [mock_student],  # students
        [mock_emb],      # embeddings
    ]

    # First access: cache miss
    cache1 = manager.get_class_index(db, class_id=99, engine=engine)
    assert cache1.class_id == 99
    assert cache1.total_templates == 1
    assert len(cache1.enrolled_students_list) == 1
    assert cache1.embedding_matrix.shape == (1, 128)

    # Second access: cache hit (db should not be called again)
    call_count_before = db.query.call_count
    cache2 = manager.get_class_index(db, class_id=99, engine=engine)
    assert cache2 is cache1
    assert db.query.call_count == call_count_before


def test_index_invalidation():
    manager = RecognitionIndexManager()
    db = MagicMock()
    engine = DummyEngine()

    mock_student = MagicMock()
    mock_student.id = 101
    mock_student.roll_number = "TEST001"
    mock_student.full_name = "Test Student"

    db.query.return_value.filter.return_value.all.side_effect = [
        [mock_student], [],  # class 1
        [mock_student], [],  # class 2
        [mock_student], [],  # class 1 reload
    ]

    cache_c1 = manager.get_class_index(db, class_id=1, engine=engine)
    cache_c2 = manager.get_class_index(db, class_id=2, engine=engine)

    assert manager.get_stats()["cached_classes"] == 2

    # Invalidate class 1 only
    manager.invalidate(class_id=1)
    stats = manager.get_stats()
    assert stats["cached_classes"] == 1

    # Invalidate all
    manager.invalidate()
    assert manager.get_stats()["cached_classes"] == 0


def test_index_concurrent_access():
    manager = RecognitionIndexManager()
    db = MagicMock()
    engine = DummyEngine()

    mock_student = MagicMock()
    mock_student.id = 101
    mock_student.roll_number = "TEST001"
    mock_student.full_name = "Test Student"

    db.query.return_value.filter.return_value.all.return_value = [mock_student]

    errors = []

    def worker():
        try:
            for _ in range(50):
                c = manager.get_class_index(db, class_id=1, engine=engine)
                assert c.class_id == 1
        except Exception as e:
            errors.append(e)

    threads = [threading.Thread(target=worker) for _ in range(10)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert len(errors) == 0


def test_dlib_vectorized_matching_fidelity():
    engine = DlibFaceRecognitionEngine()

    # Generate random enrolled vectors
    np.random.seed(42)
    enrolled_vecs = [np.random.randn(128).astype(np.float64) for _ in range(10)]
    query_vec = np.random.randn(128).astype(np.float64)

    # Manual loop
    manual_distances = [float(np.linalg.norm(ev - query_vec)) for ev in enrolled_vecs]

    # Vectorized
    emb_matrix = np.vstack(enrolled_vecs)
    diff = emb_matrix - query_vec
    vectorized_distances = np.linalg.norm(diff, axis=1)

    np.testing.assert_allclose(manual_distances, vectorized_distances, rtol=1e-12, atol=1e-12)
