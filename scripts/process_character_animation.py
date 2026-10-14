"""
Fast and High-Quality Video Chroma-Key Processing Script
Removes the green background completely from 'charecter vedio.mp4',
despills edges, removes background artifacts,
and exports:
1. Transparent WebM (VP9 + yuva420p + alpha_mode=1)
2. Transparent Animated WebP (via FFmpeg libwebp, 24fps, infinite loop, RGBA)
3. Transparent Poster PNG (high-res frontal frame)
"""
import os
import sys
import subprocess
import cv2
import numpy as np
from PIL import Image
import imageio_ffmpeg

def process_frame_rgba(frame_bgr, crop_box=None):
    """
    Applies high-precision chroma keying with smooth anti-aliased edge feathering,
    despill on edge pixels, and removal of unwanted background artifacts.
    """
    if crop_box is not None:
        x0, y0, x1, y1 = crop_box
        frame_bgr = frame_bgr[y0:y1, x0:x1]
    
    h, w, _ = frame_bgr.shape
    frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
    r = frame_rgb[:, :, 0]
    g = frame_rgb[:, :, 1]
    b = frame_rgb[:, :, 2]
    
    # Calculate green excess: g - max(r, b)
    max_rb = np.maximum(r, b)
    green_excess = g - max_rb
    
    # HSV analysis
    hsv = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2HSV).astype(np.float32)
    hue = hsv[:, :, 0]
    sat = hsv[:, :, 1]
    val = hsv[:, :, 2]
    
    # Green background definition: Hue between 32 and 88, saturation > 40, value > 40
    is_green = (hue >= 32) & (hue <= 88) & (sat > 40) & (val > 40)
    
    # Smooth alpha ramp
    alpha = np.ones((h, w), dtype=np.float32)
    t_low = 6.0
    t_high = 32.0
    
    mask = is_green & (green_excess > t_low)
    edge_zone = mask & (green_excess < t_high)
    bg_zone = mask & (green_excess >= t_high)
    
    alpha[bg_zone] = 0.0
    alpha[edge_zone] = 1.0 - (green_excess[edge_zone] - t_low) / (t_high - t_low)
    
    # Despill: neutralise any residual green tinge on anti-aliased edges
    despilled_g = np.where(g > max_rb, (r + b) * 0.5, g)
    clean_rgb = np.stack([r, despilled_g, b], axis=-1)
    
    # If uncropped (width > 1600), clean background decorations (e.g. star in bottom right)
    if w > 1600:
        alpha[:, :250] = 0.0
        alpha[:, 1620:] = 0.0
        alpha[750:, 1580:] = 0.0
    
    rgba = np.dstack([clean_rgb, alpha * 255.0]).clip(0, 255).astype(np.uint8)
    return rgba

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    video_path = os.path.join(root_dir, "charecter vedio.mp4")
    if not os.path.exists(video_path):
        print(f"Error: Video not found at {video_path}", flush=True)
        sys.exit(1)
        
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    print(f"Using FFmpeg: {ffmpeg_exe}", flush=True)
    
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 24.0
    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    print(f"Input video: {orig_w}x{orig_h}, {fps} fps, {total_frames} frames", flush=True)
    
    # Crop box for centered character:
    # Character x bounds are [353, 1566].
    # Center is 960. Width 1280 (from 320 to 1600) gives perfectly balanced margins.
    crop_x0, crop_y0, crop_x1, crop_y1 = 320, 0, 1600, 1080
    crop_w = crop_x1 - crop_x0
    crop_h = crop_y1 - crop_y0
    
    # Target directories
    dirs_to_create = [
        os.path.join(root_dir, "public", "assets"),
        os.path.join(root_dir, "mobile", "assets", "animations"),
        os.path.join(root_dir, "mobile", "web", "assets"),
        os.path.join(root_dir, "mobile", "build", "web", "assets", "assets", "animations"),
        os.path.join(root_dir, "mobile", "build", "web", "public", "assets"),
    ]
    for d in dirs_to_create:
        os.makedirs(d, exist_ok=True)
        
    # Read and process all frames
    print("Extracting and chroma-keying all frames...", flush=True)
    frames_rgba_cropped = []
    
    webp_w, webp_h = 640, 540
    frames_rgba_webp = []
    
    frame_idx = 0
    while True:
        ret, frame_bgr = cap.read()
        if not ret:
            break
        rgba = process_frame_rgba(frame_bgr, crop_box=(crop_x0, crop_y0, crop_x1, crop_y1))
        frames_rgba_cropped.append(rgba)
        
        # Resize with INTER_AREA for crisp WebP
        small_rgba = cv2.resize(rgba, (webp_w, webp_h), interpolation=cv2.INTER_AREA)
        frames_rgba_webp.append(small_rgba)
        
        frame_idx += 1
        if frame_idx % 48 == 0 or frame_idx == total_frames:
            print(f"  Chroma-keyed {frame_idx}/{total_frames} frames ({frame_idx/total_frames*100:.1f}%)", flush=True)
            
    cap.release()
    print(f"Total processed frames: {len(frames_rgba_cropped)}", flush=True)
    
    # 1. Export Poster (Frame 0 frontal reference)
    poster_small = Image.fromarray(frames_rgba_webp[0], 'RGBA')
    poster_paths = [
        os.path.join(root_dir, "public", "assets", "face-character-poster.png"),
        os.path.join(root_dir, "mobile", "assets", "animations", "face-character-poster.png"),
        os.path.join(root_dir, "mobile", "build", "web", "assets", "assets", "animations", "face-character-poster.png"),
        os.path.join(root_dir, "mobile", "build", "web", "public", "assets", "face-character-poster.png"),
    ]
    for p in poster_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        poster_small.save(p, format="PNG", optimize=True)
        print(f"Saved poster: {p} ({os.path.getsize(p)} bytes)", flush=True)
        
    # 2. Export Transparent WebM via FFmpeg (libvpx-vp9 with yuva420p)
    print("Encoding transparent WebM with libvpx-vp9...", flush=True)
    webm_paths = [
        os.path.join(root_dir, "public", "assets", "face-character-transparent.webm"),
        os.path.join(root_dir, "mobile", "assets", "animations", "face-character-transparent.webm"),
        os.path.join(root_dir, "mobile", "web", "assets", "face-character-transparent.webm"),
        os.path.join(root_dir, "mobile", "build", "web", "assets", "assets", "animations", "face-character-transparent.webm"),
        os.path.join(root_dir, "mobile", "build", "web", "public", "assets", "face-character-transparent.webm"),
    ]
    for p in webm_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        
    primary_webm = webm_paths[0]
    cmd_webm = [
        ffmpeg_exe, "-y",
        "-f", "rawvideo",
        "-pix_fmt", "rgba",
        "-s", f"{crop_w}x{crop_h}",
        "-r", "24",
        "-i", "-",
        "-c:v", "libvpx-vp9",
        "-pix_fmt", "yuva420p",
        "-metadata:s:v:0", "alpha_mode=1",
        "-auto-alt-ref", "0",
        "-b:v", "1200k",
        "-crf", "25",
        "-an",
        primary_webm
    ]
    proc = subprocess.Popen(cmd_webm, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    for frame in frames_rgba_cropped:
        proc.stdin.write(frame.tobytes())
    proc.stdin.close()
    out, err = proc.communicate()
    
    if proc.returncode != 0:
        print("FFmpeg WebM error:", err.decode("utf-8", errors="replace"), flush=True)
        sys.exit(1)
        
    print(f"Saved primary transparent WebM: {primary_webm} ({os.path.getsize(primary_webm)} bytes)", flush=True)
    
    with open(primary_webm, "rb") as f:
        webm_bytes = f.read()
    for p in webm_paths[1:]:
        with open(p, "wb") as f:
            f.write(webm_bytes)
        print(f"Distributed WebM to: {p}", flush=True)

    # 3. Export Animated WebP via FFmpeg libwebp (fast multi-threaded)
    print("Encoding animated WebP via FFmpeg libwebp...", flush=True)
    webp_paths = [
        os.path.join(root_dir, "public", "assets", "face-character-transparent.webp"),
        os.path.join(root_dir, "mobile", "assets", "animations", "face-character-transparent.webp"),
        os.path.join(root_dir, "mobile", "build", "web", "assets", "assets", "animations", "face-character-transparent.webp"),
        os.path.join(root_dir, "mobile", "build", "web", "public", "assets", "face-character-transparent.webp"),
    ]
    for p in webp_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        
    primary_webp = webp_paths[0]
    cmd_webp = [
        ffmpeg_exe, "-y",
        "-f", "rawvideo",
        "-pix_fmt", "rgba",
        "-s", f"{webp_w}x{webp_h}",
        "-r", "24",
        "-i", "-",
        "-c:v", "libwebp",
        "-lossless", "0",
        "-q:v", "88",
        "-loop", "0",
        "-an",
        primary_webp
    ]
    proc_webp = subprocess.Popen(cmd_webp, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    for frame in frames_rgba_webp:
        proc_webp.stdin.write(frame.tobytes())
    proc_webp.stdin.close()
    out_w, err_w = proc_webp.communicate()
    
    if proc_webp.returncode != 0:
        print("FFmpeg WebP error:", err_w.decode("utf-8", errors="replace"), flush=True)
        sys.exit(1)
        
    print(f"Saved primary animated WebP: {primary_webp} ({os.path.getsize(primary_webp)} bytes)", flush=True)
    
    with open(primary_webp, "rb") as f:
        webp_bytes = f.read()
    for p in webp_paths[1:]:
        with open(p, "wb") as f:
            f.write(webp_bytes)
        print(f"Distributed WebP to: {p}", flush=True)
        
    print("\nAll assets successfully generated and distributed!", flush=True)

if __name__ == "__main__":
    main()
