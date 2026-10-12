from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List, Dict, Any, Tuple, Optional
import numpy as np

@dataclass
class RecognitionConfig:
    distance_threshold: float = 0.45       # High confidence match distance limit
    uncertain_threshold: float = 0.60      # Maximum match distance limit for uncertain match
    min_face_size: int = 20                # Minimum pixel width/height for detected face
    max_upload_size_mb: int = 10           # Max upload file size in megabytes
    detection_model: str = "hog"           # "hog" or "cnn"

class BaseRecognitionEngine(ABC):
    """
    Modular Service Interface for Face Recognition Engine.
    Decouples attendance logic from specific computer vision / dlib libraries.
    """

    @abstractmethod
    def detect_faces(self, image_bytes_or_array: Any, model: str = "hog") -> List[Tuple[int, int, int, int]]:
        """
        Detect face bounding boxes in an image.
        Returns list of (top, right, bottom, left) tuples.
        """
        pass

    @abstractmethod
    def generate_embeddings(
        self, image_bytes_or_array: Any, face_locations: Optional[List[Tuple[int, int, int, int]]] = None
    ) -> List[np.ndarray]:
        """
        Extract 128-dimensional facial embedding vectors from face locations.
        """
        pass

    @property
    def engine_name(self) -> str:
        """Identifier for the recognition engine (e.g. 'dlib', 'scrfd_arcface')."""
        return "dlib"

    @property
    def embedding_dimension(self) -> int:
        """Dimensionality of facial embeddings produced by this engine (e.g. 128 for Dlib, 512 for ArcFace)."""
        return 128

    @property
    def distance_metric(self) -> str:
        """Metric used for vector comparison ('euclidean' or 'cosine')."""
        return "euclidean"

    @property
    def model_name(self) -> str:
        """Model identifier for embedding generation (e.g. 'dlib_resnet', 'arcface_r50')."""
        return "dlib_resnet"

    @property
    def model_version(self) -> str:
        """Model version string."""
        return "v1"

    @property
    def detector_name(self) -> str:
        """Detector identifier (e.g. 'dlib_hog', 'scrfd')."""
        return "dlib_hog"

    @abstractmethod
    def recognize_image(
        self,
        image_bytes: bytes,
        enrolled_students: List[Dict[str, Any]],
        config: Optional[RecognitionConfig] = None
    ) -> Dict[str, Any]:
        """
        Process single or multi-face image against enrolled student embeddings.
        Returns structured candidate classifications (HIGH_CONFIDENCE, UNCERTAIN, UNKNOWN) with deduplication.
        """
        pass

