"""
In-Memory Biometric Recognition Index (Phase 10).

Provides high-performance, thread-safe in-memory caching of active student face embeddings
and roster metadata. Eliminates per-request database queries, repeated JSON deserialization,
and redundant NumPy array conversions.

Supports automatic invalidation when admin or student biometric enrollments are updated.
"""
import json
import logging
import threading
from typing import Dict, Any, List, Optional, Tuple
import numpy as np
from sqlalchemy.orm import Session

from app.models.student import Student
from app.models.attendance import FaceEmbedding
from app.engines.recognition.base import BaseRecognitionEngine

logger = logging.getLogger("recognition.index")


class ClassRecognitionCache:
    """Cached embedding matrix and student lookup for a single class section."""
    def __init__(
        self,
        class_id: int,
        engine_name: str,
        dimension: int,
        metric: str,
        embedding_matrix: np.ndarray,
        embedding_student_ids: np.ndarray,
        student_lookup: Dict[int, Dict[str, Any]],
        enrolled_students_list: List[Dict[str, Any]],
        total_templates: int,
    ):
        self.class_id = class_id
        self.engine_name = engine_name
        self.dimension = dimension
        self.metric = metric
        self.embedding_matrix = embedding_matrix
        self.embedding_student_ids = embedding_student_ids
        self.student_lookup = student_lookup
        self.enrolled_students_list = enrolled_students_list
        self.total_templates = total_templates


class RecognitionIndexManager:
    """
    Process-level singleton managing in-memory recognition indices.
    Thread-safe under concurrent requests.
    """
    _instance: Optional["RecognitionIndexManager"] = None
    _lock = threading.RLock()

    def __init__(self):
        self._cache: Dict[Tuple[int, str, int, str], ClassRecognitionCache] = {}
        self._version: int = 1

    @classmethod
    def get_instance(cls) -> "RecognitionIndexManager":
        with cls._lock:
            if cls._instance is None:
                cls._instance = RecognitionIndexManager()
            return cls._instance

    def invalidate(self, class_id: Optional[int] = None) -> None:
        """
        Invalidate cache for a specific class section or all classes.
        Call whenever face enrollments are added, updated, or deleted.
        """
        with self._lock:
            if class_id is None:
                cleared_count = len(self._cache)
                self._cache.clear()
                self._version += 1
                logger.info(f"Invalidated entire recognition index ({cleared_count} classes cleared, version={self._version})")
            else:
                keys_to_remove = [k for k in self._cache if k[0] == class_id]
                for k in keys_to_remove:
                    del self._cache[k]
                self._version += 1
                logger.info(f"Invalidated recognition index for class #{class_id} ({len(keys_to_remove)} entries, version={self._version})")

    def get_stats(self) -> Dict[str, Any]:
        """Return diagnostic metrics about in-memory cached indices."""
        with self._lock:
            return {
                "cached_classes": len(self._cache),
                "version": self._version,
                "cached_keys": list(self._cache.keys()),
            }

    def get_class_index(
        self,
        db: Session,
        class_id: int,
        engine: BaseRecognitionEngine
    ) -> ClassRecognitionCache:
        """
        Retrieve or build the cached recognition index for a class section and active engine.
        Thread-safe; queries database and deserializes embeddings only on cache miss.
        """
        cache_key = (
            class_id,
            engine.model_name,
            engine.embedding_dimension,
            engine.distance_metric
        )

        with self._lock:
            if cache_key in self._cache:
                return self._cache[cache_key]

        # Cache miss - construct index from database
        students = (
            db.query(Student)
            .filter(Student.class_id == class_id, Student.is_active == True)
            .all()
        )
        student_ids = [s.id for s in students]

        db_embeddings = []
        if student_ids:
            chunk_size = 900
            for i in range(0, len(student_ids), chunk_size):
                chunk = student_ids[i:i + chunk_size]
                chunk_embs = (
                    db.query(FaceEmbedding)
                    .filter(
                        FaceEmbedding.student_id.in_(chunk),
                        FaceEmbedding.model_name == engine.model_name,
                        FaceEmbedding.dimension == engine.embedding_dimension,
                        FaceEmbedding.distance_metric == engine.distance_metric
                    )
                    .all()
                )
                db_embeddings.extend(chunk_embs)

        # Filter compatible embeddings strictly matching active engine
        compatible_embeddings = [
            emb for emb in db_embeddings
            if emb.dimension == engine.embedding_dimension
            and emb.model_name == engine.model_name
            and emb.distance_metric == engine.distance_metric
        ]

        # Build student lookup and unpack embeddings
        student_lookup: Dict[int, Dict[str, Any]] = {}
        enrolled_data_map: Dict[int, Dict[str, Any]] = {}
        for st in students:
            info = {
                "student_id": st.id,
                "roll_number": st.roll_number,
                "full_name": st.full_name,
            }
            student_lookup[st.id] = info
            enrolled_data_map[st.id] = {
                **info,
                "embeddings": []
            }

        matrix_rows: List[np.ndarray] = []
        matrix_student_ids: List[int] = []

        for emb in compatible_embeddings:
            try:
                vec_list = json.loads(emb.embedding_json)
                if len(vec_list) != engine.embedding_dimension:
                    continue
                vec = np.array(vec_list, dtype=np.float32)
                if not np.all(np.isfinite(vec)):
                    logger.warning(f"Embedding #{emb.id} contains non-finite values (NaN/inf); skipping.")
                    continue

                norm = float(np.linalg.norm(vec))
                if norm < 1e-6:
                    logger.warning(f"Embedding #{emb.id} has degenerate near-zero norm; skipping.")
                    continue

                # For cosine similarity, ensure L2-normalized vector
                if engine.distance_metric == "cosine":
                    vec = vec / norm

                if emb.student_id in enrolled_data_map:
                    enrolled_data_map[emb.student_id]["embeddings"].append(vec)
                    matrix_rows.append(vec)
                    matrix_student_ids.append(emb.student_id)
            except Exception as e:
                logger.warning(f"Failed to parse embedding #{emb.id}: {e}")
                continue

        if matrix_rows:
            embedding_matrix = np.vstack(matrix_rows)
            embedding_student_ids = np.array(matrix_student_ids, dtype=np.int64)
        else:
            embedding_matrix = np.empty((0, engine.embedding_dimension), dtype=np.float32)
            embedding_student_ids = np.empty((0,), dtype=np.int64)

        enrolled_students_list = list(enrolled_data_map.values())

        index_entry = ClassRecognitionCache(
            class_id=class_id,
            engine_name=engine.model_name,
            dimension=engine.embedding_dimension,
            metric=engine.distance_metric,
            embedding_matrix=embedding_matrix,
            embedding_student_ids=embedding_student_ids,
            student_lookup=student_lookup,
            enrolled_students_list=enrolled_students_list,
            total_templates=len(matrix_rows),
        )

        with self._lock:
            self._cache[cache_key] = index_entry
            logger.info(
                f"Built recognition index for Class #{class_id}: "
                f"{len(students)} students, {len(matrix_rows)} templates ({engine.model_name}, {engine.distance_metric})"
            )

        return index_entry


# Module-level convenience singleton
recognition_index = RecognitionIndexManager.get_instance()
