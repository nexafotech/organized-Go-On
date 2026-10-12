import os
import sys
import time
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine

def run():
    engine = ScrfdArcFaceRecognitionEngine()

    grp_path = r"C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg"
    with open(grp_path, 'rb') as fp:
        img_bytes = fp.read()

    # Stage 1: decode
    t0 = time.perf_counter()
    img = engine._decode_image(img_bytes)
    t_decode = (time.perf_counter() - t0) * 1000

    # Stage 2: SCRFD detection
    t0 = time.perf_counter()
    faces = engine.detect_faces_with_landmarks(img)
    t_det = (time.perf_counter() - t0) * 1000

    # Stage 3: Alignment + ArcFace embedding per face
    t_aligns = []
    t_embs = []
    for f in faces:
        t0 = time.perf_counter()
        aligned = engine.align_face(img, f["landmarks"])
        t_aligns.append((time.perf_counter() - t0) * 1000)

        t0 = time.perf_counter()
        rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB)
        blob = np.transpose(rgb, (2, 0, 1)).astype(np.float32)
        blob = (blob - 127.5) * (1.0 / 127.5)
        blob = np.expand_dims(blob, axis=0)
        raw_out = engine.arc_session.run(None, {engine.arc_input_name: blob})[0]
        v = raw_out[0].astype(np.float32)
        v = v / float(np.linalg.norm(v))
        t_embs.append((time.perf_counter() - t0) * 1000)

    print(f"Image decode: {t_decode:.2f} ms")
    print(f"SCRFD detect ({len(faces)} faces): {t_det:.2f} ms")
    print(f"Landmark align sum: {sum(t_aligns):.2f} ms")
    print(f"ArcFace per-face embs (ms): {[round(x, 1) for x in t_embs]}")
    print(f"ArcFace embs sum: {sum(t_embs):.2f} ms")
    print(f"Total pipeline: {t_decode + t_det + sum(t_aligns) + sum(t_embs):.2f} ms")

if __name__ == "__main__":
    run()
