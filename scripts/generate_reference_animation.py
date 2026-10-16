import cv2
import os
import subprocess
import numpy as np
import imageio_ffmpeg
from PIL import Image

def matte_frame(frame_bgr, crop_box=(380, 40, 900, 720)):
    x0, y0, x1, y1 = crop_box
    cropped = frame_bgr[y0:y1, x0:x1]
    
    b = cropped[:, :, 0].astype(np.float32)
    g = cropped[:, :, 1].astype(np.float32)
    r = cropped[:, :, 2].astype(np.float32)
    
    hsv = cv2.cvtColor(cropped, cv2.COLOR_BGR2HSV)
    h, s, v = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    
    is_green = (h >= 35) & (h <= 85) & (s >= 50) & (v >= 50)
    max_rb = np.maximum(r, b)
    green_excess = g - max_rb
    
    alpha = np.ones_like(g)
    t_low = 10.0
    t_high = 45.0
    
    mask = is_green & (green_excess > t_low)
    edge_zone = mask & (green_excess < t_high)
    bg_zone = mask & (green_excess >= t_high)
    
    alpha[bg_zone] = 0.0
    alpha[edge_zone] = 1.0 - (green_excess[edge_zone] - t_low) / (t_high - t_low)
    
    # Despill: clamp green channel to max(r, b)
    despilled_g = np.where(g > max_rb, max_rb, g)
    clean_rgb = np.stack([r, despilled_g, b], axis=-1)
    
    rgba = np.dstack([clean_rgb, alpha * 255.0]).clip(0, 255).astype(np.uint8)
    return rgba

def test_pipeline():
    video_path = r"E:\originalam\vedio-ch.mp4"
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    
    cap = cv2.VideoCapture(video_path)
    frames_all = []
    
    print("Reading and matting video frames sequentially...")
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        rgba = matte_frame(frame)
        frames_all.append(rgba)
    cap.release()
    print(f"Total frames read: {len(frames_all)}")
    
    # Target resolution: 360x470
    w_out, h_out = 360, 470
    
    for step, fps in [(2, 12), (3, 8)]:
        subset = [cv2.resize(f, (w_out, h_out), interpolation=cv2.INTER_AREA) for f in frames_all[::step]]
        n_frames = len(subset)
        out_webp = f"test_{n_frames}f_{fps}fps.webp"
        
        # Encode via FFmpeg libwebp
        cmd = [
            ffmpeg_exe, "-y",
            "-f", "rawvideo",
            "-pix_fmt", "rgba",
            "-s", f"{w_out}x{h_out}",
            "-r", str(fps),
            "-i", "-",
            "-c:v", "libwebp",
            "-lossless", "0",
            "-q:v", "85",
            "-loop", "0",
            "-an",
            out_webp
        ]
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        for f in subset:
            proc.stdin.write(f.tobytes())
        proc.stdin.close()
        out, err = proc.communicate()
        
        size = os.path.getsize(out_webp) if os.path.exists(out_webp) else 0
        print(f"WebP ({n_frames} frames, {fps} fps): {size:,} bytes")
        
        # Test duration check
        im = Image.open(out_webp)
        im.seek(0)
        d0 = im.info.get('duration')
        print(f"  Pillow read: is_animated={getattr(im, 'is_animated', False)}, n_frames={im.n_frames}, d0={d0}ms")

if __name__ == "__main__":
    test_pipeline()
