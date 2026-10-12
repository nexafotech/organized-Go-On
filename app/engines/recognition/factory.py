import os
import threading
from typing import Dict, Optional
from app.engines.recognition.base import BaseRecognitionEngine


class RecognitionEngineFactory:
    """
    Factory for obtaining face recognition engine instances.
    Decouples consumers (APIs, enrollment, sessions) from concrete engine implementations.
    Thread-safe singleton caching across concurrent FastAPI requests.
    """

    _cache: Dict[str, BaseRecognitionEngine] = {}
    _lock = threading.RLock()

    @classmethod
    def get_engine(cls, engine_name: Optional[str] = None) -> BaseRecognitionEngine:
        """
        Get or instantiate a face recognition engine.
        If engine_name is not provided, defaults to the FACE_RECOGNITION_ENGINE
        environment variable, or 'dlib'.

        Supported engines:
        - 'dlib': DlibFaceRecognitionEngine (HOG / ResNet-34 128-d, Euclidean)
        - 'scrfd_arcface': SCRFD detector + ArcFace 512-d Cosine (ONNX Runtime, CUDA/CPU)
        """
        if engine_name is None:
            engine_name = os.getenv("FACE_RECOGNITION_ENGINE", "scrfd_arcface")

        name = engine_name.strip().lower()

        with cls._lock:
            if name in cls._cache:
                return cls._cache[name]

            if name == "dlib":
                from app.engines.recognition.local_dlib import DlibFaceRecognitionEngine
                engine = DlibFaceRecognitionEngine()
                cls._cache[name] = engine
                return engine
            elif name == "scrfd_arcface":
                from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine
                engine = ScrfdArcFaceRecognitionEngine()
                cls._cache[name] = engine
                return engine
            else:
                raise ValueError(
                    f"Unsupported face recognition engine: '{engine_name}'. "
                    f"Supported engines: 'dlib', 'scrfd_arcface'."
                )

    @classmethod
    def reset(cls) -> None:
        """
        Reset cached engine instances. Useful for testing and configuration changes.
        """
        with cls._lock:
            cls._cache.clear()

