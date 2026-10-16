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
    
    # Optical Despill: clamp green channel to max(r, b)
    despilled_g = np.where(g > max_rb, max_rb, g)
    clean_rgb = np.stack([r, despilled_g, b], axis=-1)
    
    rgba = np.dstack([clean_rgb, alpha * 255.0]).clip(0, 255).astype(np.uint8)
    return rgba

def main():
    root_dir = r"E:\originalam"
    video_path = os.path.join(root_dir, "vedio-ch.mp4")
    if not os.path.exists(video_path):
        print(f"Error: Video not found at {video_path}")
        return
        
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    print(f"Using FFmpeg: {ffmpeg_exe}")
    
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 24.0
    print(f"Input video: {total_frames} frames @ {fps} fps")
    
    w_out, h_out = 360, 470
    frames_rgba = []
    
    print("Extracting and matting frames...")
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        rgba = matte_frame(frame)
        resized = cv2.resize(rgba, (w_out, h_out), interpolation=cv2.INTER_AREA)
        frames_rgba.append(resized)
    cap.release()
    print(f"Extracted {len(frames_rgba)} total frames.")
    
    # 1. Export Poster (Frame 0 frontal reference)
    poster_img = Image.fromarray(frames_rgba[0], 'RGBA')
    poster_paths = [
        os.path.join(root_dir, "mobile", "assets", "animations", "face-character-poster.png"),
        os.path.join(root_dir, "public", "assets", "face-character-poster.png"),
        os.path.join(root_dir, "mobile", "build", "web", "assets", "assets", "animations", "face-character-poster.png"),
        os.path.join(root_dir, "mobile", "build", "web", "public", "assets", "face-character-poster.png"),
    ]
    for p in poster_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        poster_img.save(p, format="PNG", optimize=True)
        print(f"Saved poster: {p} ({os.path.getsize(p):,} bytes)")
        
    # 2. Export 96-frame WebP (12 fps, 8.0s duration, Q=80)
    frames_96 = frames_rgba[::2]
    print(f"Encoding 96-frame Animated WebP ({len(frames_96)} frames @ 12 fps)...")
    
    webp_paths = [
        os.path.join(root_dir, "mobile", "assets", "animations", "face-character-transparent.webp"),
        os.path.join(root_dir, "public", "assets", "face-character-transparent.webp"),
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
        "-s", f"{w_out}x{h_out}",
        "-r", "12",
        "-i", "-",
        "-c:v", "libwebp",
        "-lossless", "0",
        "-q:v", "80",
        "-loop", "0",
        "-an",
        primary_webp
    ]
    proc_webp = subprocess.Popen(cmd_webp, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    for f in frames_96:
        proc_webp.stdin.write(f.tobytes())
    proc_webp.stdin.close()
    out_w, err_w = proc_webp.communicate()
    
    if proc_webp.returncode != 0:
        print("FFmpeg WebP error:", err_w.decode("utf-8", errors="replace"))
        return
        
    webp_size = os.path.getsize(primary_webp)
    print(f"Saved primary animated WebP: {primary_webp} ({webp_size:,} bytes)")
    
    with open(primary_webp, "rb") as f:
        webp_bytes = f.read()
    for p in webp_paths[1:]:
        with open(p, "wb") as f:
            f.write(webp_bytes)
        print(f"Distributed WebP to: {p}")
        
    # 3. Export Fallback GIF (48 frames @ 6 fps for compact fallback)
    frames_48 = frames_rgba[::4]
    print(f"Encoding fallback GIF ({len(frames_48)} frames @ 6 fps)...")
    gif_paths = [
        os.path.join(root_dir, "mobile", "assets", "animations", "face-character.gif"),
        os.path.join(root_dir, "public", "assets", "face-character.gif"),
    ]
    for p in gif_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        
    primary_gif = gif_paths[0]
    cmd_gif = [
        ffmpeg_exe, "-y",
        "-f", "rawvideo",
        "-pix_fmt", "rgba",
        "-s", f"{w_out}x{h_out}",
        "-r", "6",
        "-i", "-",
        "-filter_complex", "[0:v] split [a][b];[a] palettegen=reserve_transparent=on:transparency_color=00ff00 [p];[b][p] paletteuse=alpha_threshold=128",
        primary_gif
    ]
    proc_gif = subprocess.Popen(cmd_gif, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    for f in frames_48:
        proc_gif.stdin.write(f.tobytes())
    proc_gif.stdin.close()
    out_g, err_g = proc_gif.communicate()
    
    if proc_gif.returncode != 0:
        print("FFmpeg GIF error:", err_g.decode("utf-8", errors="replace"))
    else:
        gif_size = os.path.getsize(primary_gif)
        print(f"Saved primary fallback GIF: {primary_gif} ({gif_size:,} bytes)")
        with open(primary_gif, "rb") as f:
            gif_bytes = f.read()
        for p in gif_paths[1:]:
            with open(p, "wb") as f:
                f.write(gif_bytes)
            print(f"Distributed GIF to: {p}")

    print("\nGeneration and distribution completed successfully!")

if __name__ == "__main__":
    main()
