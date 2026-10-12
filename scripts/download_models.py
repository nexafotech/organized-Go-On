import os
import hashlib
import urllib.request
import sys

def main():
    target_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models", "face_recognition")
    os.makedirs(target_dir, exist_ok=True)

    models = {
        "det_10g.onnx": {
            "url": "https://huggingface.co/Aitrepreneur/insightface/resolve/main/models/buffalo_l/det_10g.onnx",
            "sha256": "5838f7fe053675b1c7a08b633df49e7af5495cee0493c7dcf6697200b85b5b91",
            "size": 16923827
        },
        "w600k_r50.onnx": {
            "url": "https://huggingface.co/Aitrepreneur/insightface/resolve/main/models/buffalo_l/w600k_r50.onnx",
            "sha256": "4c06341c33c2ca1f86781dab0e829f88ad5b64be9fba56e56bc9ebdefc619e43",
            "size": 174383860
        }
    }

    for name, meta in models.items():
        dest = os.path.join(target_dir, name)
        if os.path.exists(dest):
            with open(dest, "rb") as f:
                h = hashlib.sha256(f.read()).hexdigest()
            if h.lower() == meta["sha256"].lower():
                print(f"[OK] {name} already exists with verified SHA-256: {h}")
                continue
            else:
                print(f"[WARN] {name} exists but hash mismatched. Re-downloading...")
                os.remove(dest)

        print(f"Downloading {name} ({meta['size'] / (1024*1024):.1f} MB)...")
        urllib.request.urlretrieve(meta["url"], dest)
        with open(dest, "rb") as f:
            h = hashlib.sha256(f.read()).hexdigest()
        if h.lower() != meta["sha256"].lower():
            if os.path.exists(dest):
                os.remove(dest)
            raise ValueError(f"Hash mismatch for {name}: got {h}, expected {meta['sha256']}")
        print(f"[OK] {name} downloaded and verified: {h}")

if __name__ == "__main__":
    main()
