import os
import sys
import json
import time
import ctypes
from ctypes import wintypes
import cv2
import numpy as np

# Ensure app path in pythonpath
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.engines.recognition.local_dlib import DlibFaceRecognitionEngine
from app.engines.recognition.scrfd_arcface import ScrfdArcFaceRecognitionEngine, ARCFACE_DST


class PROCESS_MEMORY_COUNTERS(ctypes.Structure):
    _fields_ = [
        ('cb', wintypes.DWORD),
        ('PageFaultCount', wintypes.DWORD),
        ('PeakWorkingSetSize', ctypes.c_size_t),
        ('WorkingSetSize', ctypes.c_size_t),
        ('QuotaPeakPagedPoolUsage', ctypes.c_size_t),
        ('QuotaPagedPoolUsage', ctypes.c_size_t),
        ('QuotaPeakNonPagedPoolUsage', ctypes.c_size_t),
        ('QuotaNonPagedPoolUsage', ctypes.c_size_t),
        ('PagefileUsage', ctypes.c_size_t),
        ('PeakPagefileUsage', ctypes.c_size_t),
    ]


def get_process_memory_mb():
    try:
        psapi = ctypes.WinDLL('psapi')
        kernel32 = ctypes.WinDLL('kernel32')
        psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESS_MEMORY_COUNTERS), wintypes.DWORD]
        psapi.GetProcessMemoryInfo.restype = wintypes.BOOL
        kernel32.GetCurrentProcess.restype = wintypes.HANDLE

        pmc = PROCESS_MEMORY_COUNTERS()
        pmc.cb = ctypes.sizeof(PROCESS_MEMORY_COUNTERS)
        success = psapi.GetProcessMemoryInfo(kernel32.GetCurrentProcess(), ctypes.byref(pmc), pmc.cb)
        if success:
            return round(pmc.WorkingSetSize / (1024 * 1024), 2), round(pmc.PeakWorkingSetSize / (1024 * 1024), 2)
    except Exception:
        pass
    return 0.0, 0.0


def percentile(data, p):
    if not data:
        return 0.0
    return float(np.percentile(data, p))


def verify_landmarks_near_box(bbox, landmarks):
    """
    Checks if 5 landmarks are located inside or immediately adjacent to bounding box.
    bbox: (top, right, bottom, left)
    landmarks: (5, 2) array of (x, y)
    """
    top, right, bottom, left = bbox
    w = max(1, right - left)
    h = max(1, bottom - top)
    margin_x = 0.25 * w
    margin_y = 0.25 * h
    min_x, max_x = left - margin_x, right + margin_x
    min_y, max_y = top - margin_y, bottom + margin_y

    all_valid = True
    for x, y in landmarks:
        if not (min_x <= x <= max_x and min_y <= y <= max_y):
            all_valid = False
            break
    return all_valid


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    photo_dir = os.path.join(repo_root, "college_data", "official_photos")
    results_path = os.path.join(repo_root, "benchmark_results_14d.json")

    filenames = sorted([
        f for f in os.listdir(photo_dir)
        if f.lower().endswith(('.jpg', '.jpeg', '.png'))
    ])

    print(f"=== MILESTONE 14D BENCHMARK INITIALIZATION ===")
    print(f"Found {len(filenames)} official classroom photographs in {photo_dir}\n")

    baseline_mem, _ = get_process_memory_mb()
    print(f"Initial process memory: {baseline_mem:.2f} MB\n")

    benchmark_data = {
        "metadata": {
            "milestone": "14D",
            "date": "2026-09-25",
            "machine": "Windows 11 AMD64 / NVIDIA RTX 4050 / Intel/AMD Host CPU",
            "runtime": "CPUExecutionProvider",
            "num_photos": len(filenames),
            "baseline_process_memory_mb": baseline_mem,
            "images": []
        },
        "per_image": {},
        "summary": {}
    }

    # 1. Image metadata collection
    images_meta = []
    loaded_images = {}
    for fname in filenames:
        fpath = os.path.join(photo_dir, fname)
        size_bytes = os.path.getsize(fpath)
        img = cv2.imread(fpath)
        h, w, c = img.shape
        ext = os.path.splitext(fname)[1].lower()
        meta = {
            "filename": fname,
            "path": fpath,
            "width": w,
            "height": h,
            "resolution": f"{w}x{h}",
            "megapixels": round((w * h) / 1_000_000, 2),
            "size_bytes": size_bytes,
            "size_mb": round(size_bytes / (1024 * 1024), 2),
            "format": ext
        }
        images_meta.append(meta)
        loaded_images[fname] = img
        print(f"Loaded: {fname} [{meta['resolution']}, {meta['size_mb']} MB]")

    benchmark_data["metadata"]["images"] = images_meta
    print()

    # 2. Benchmark SCRFD + ArcFace Engine
    print("=" * 60)
    print("BENCHMARKING: ScrfdArcFaceRecognitionEngine (CPU)")
    print("=" * 60)

    t_cold_start = time.perf_counter()
    scrfd_engine = ScrfdArcFaceRecognitionEngine()
    # Execute cold inference on first image
    first_img = loaded_images[filenames[0]]
    _ = scrfd_engine.detect_faces_with_landmarks(first_img)
    scrfd_cold_time_ms = round((time.perf_counter() - t_cold_start) * 1000, 2)
    print(f"SCRFD + ArcFace Cold Start Initialization: {scrfd_cold_time_ms:.2f} ms")

    scrfd_results = {}
    total_scrfd_faces = 0
    total_aligned_faces = 0
    total_alignment_failures = 0
    total_embeddings = 0
    total_embedding_failures = 0
    all_scrfd_emb_latencies = []
    all_scrfd_det_latencies = []
    all_scrfd_total_latencies = []

    for idx, fname in enumerate(filenames):
        img = loaded_images[fname]
        im_h, im_w, _ = img.shape
        print(f"\n[{idx+1}/{len(filenames)}] Testing SCRFD on {fname} ({im_w}x{im_h})...")

        # Warm detection runs (3 iterations)
        det_times = []
        det_faces = None
        for it in range(3):
            t0 = time.perf_counter()
            faces = scrfd_engine.detect_faces_with_landmarks(img)
            t_det = (time.perf_counter() - t0) * 1000.0
            det_times.append(t_det)
            if det_faces is None:
                det_faces = faces

        num_faces = len(det_faces)
        total_scrfd_faces += num_faces
        all_scrfd_det_latencies.extend(det_times)

        # Analyze detected boxes
        boxes_info = []
        confidences = []
        align_success = 0
        align_failures = 0
        emb_times = []
        embs_for_image = []

        for f_idx, f in enumerate(det_faces):
            top, right, bottom, left = f["bbox"]
            bw = right - left
            bh = bottom - top
            barea = bw * bh
            conf = f["confidence"]
            confidences.append(conf)
            lms = f["landmarks"]

            landmarks_valid = verify_landmarks_near_box(f["bbox"], lms)

            # Test alignment to 112x112
            t_align_start = time.perf_counter()
            aligned = scrfd_engine.align_face(img, lms)
            t_align = (time.perf_counter() - t_align_start) * 1000.0

            if aligned is not None and aligned.shape == (112, 112, 3):
                align_success += 1
                total_aligned_faces += 1

                # Generate ArcFace embedding
                t_emb_start = time.perf_counter()
                rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB)
                blob = np.transpose(rgb, (2, 0, 1)).astype(np.float32)
                blob = (blob - 127.5) / 127.5
                blob = np.expand_dims(blob, axis=0)

                raw_out = scrfd_engine.arc_session.run(None, {scrfd_engine.arc_input_name: blob})[0]
                vec = raw_out[0].astype(np.float32)
                norm = float(np.linalg.norm(vec))
                if norm > 0:
                    vec = vec / norm
                t_emb = (time.perf_counter() - t_emb_start) * 1000.0

                emb_times.append(t_emb)
                all_scrfd_emb_latencies.append(t_emb)
                total_embeddings += 1

                embs_for_image.append({
                    "dim": len(vec),
                    "l2_norm": round(float(np.linalg.norm(vec)), 4),
                    "latency_ms": round(t_emb, 2)
                })
            else:
                align_failures += 1
                total_alignment_failures += 1
                total_embedding_failures += 1

            boxes_info.append({
                "face_idx": f_idx,
                "bbox": f["bbox"],
                "width": bw,
                "height": bh,
                "area": barea,
                "confidence": round(conf, 4),
                "landmarks_count": len(lms),
                "landmarks_within_face_region": landmarks_valid
            })

        # Calculate face size bounds
        if boxes_info:
            min_face = min(boxes_info, key=lambda b: b["area"])
            max_face = max(boxes_info, key=lambda b: b["area"])
            min_face_summary = f"{min_face['width']}x{min_face['height']} ({min_face['area']} px)"
            max_face_summary = f"{max_face['width']}x{max_face['height']} ({max_face['area']} px)"
        else:
            min_face_summary = "N/A"
            max_face_summary = "N/A"

        # Classroom density classification
        if num_faces == 0:
            density = "0 faces"
        elif 1 <= num_faces <= 5:
            density = "1-5 faces"
        elif 6 <= num_faces <= 15:
            density = "6-15 faces"
        elif 16 <= num_faces <= 30:
            density = "16-30 faces"
        else:
            density = "31+ faces"

        tot_warm_ms = np.mean(det_times) + sum(emb_times)
        all_scrfd_total_latencies.append(tot_warm_ms)

        mem_ws, mem_peak = get_process_memory_mb()

        scrfd_results[fname] = {
            "detected_faces": num_faces,
            "density_category": density,
            "detection_latency_ms": {
                "avg": round(float(np.mean(det_times)), 2),
                "median": round(float(np.median(det_times)), 2),
                "p95": round(percentile(det_times, 95), 2),
                "raw": [round(t, 2) for t in det_times]
            },
            "confidences": {
                "min": round(min(confidences), 4) if confidences else 0.0,
                "max": round(max(confidences), 4) if confidences else 0.0,
                "mean": round(float(np.mean(confidences)), 4) if confidences else 0.0
            },
            "smallest_face": min_face_summary,
            "largest_face": max_face_summary,
            "alignment": {
                "success": align_success,
                "failures": align_failures,
                "failure_rate_pct": round((align_failures / max(1, num_faces)) * 100, 2)
            },
            "embedding": {
                "count": len(embs_for_image),
                "dimension": 512,
                "norm_verified": all(np.isclose(e["l2_norm"], 1.0, atol=1e-3) for e in embs_for_image),
                "total_embedding_time_ms": round(sum(emb_times), 2),
                "avg_per_face_ms": round(float(np.mean(emb_times)), 2) if emb_times else 0.0
            },
            "total_warm_pipeline_ms": round(tot_warm_ms, 2),
            "memory_mb": {
                "working_set": mem_ws,
                "peak": mem_peak
            },
            "boxes": boxes_info
        }

        print(f"  Faces: {num_faces} ({density}) | Det: {np.mean(det_times):.1f}ms | Emb total: {sum(emb_times):.1f}ms | Pipeline: {tot_warm_ms:.1f}ms")

    # 3. Benchmark Dlib Engine
    print("\n" + "=" * 60)
    print("BENCHMARKING: DlibFaceRecognitionEngine (CPU)")
    print("=" * 60)

    t_dlib_cold = time.perf_counter()
    dlib_engine = DlibFaceRecognitionEngine()
    # Execute cold inference on first image
    _ = dlib_engine.detect_faces(loaded_images[filenames[0]])
    dlib_cold_time_ms = round((time.perf_counter() - t_dlib_cold) * 1000, 2)
    print(f"Dlib Cold Start Initialization: {dlib_cold_time_ms:.2f} ms")

    dlib_results = {}
    total_dlib_faces = 0
    all_dlib_det_latencies = []
    all_dlib_emb_latencies = []
    all_dlib_total_latencies = []

    for idx, fname in enumerate(filenames):
        img = loaded_images[fname]
        im_h, im_w, _ = img.shape
        print(f"\n[{idx+1}/{len(filenames)}] Testing Dlib on {fname} ({im_w}x{im_h})...")

        # Warm detection runs (2 iterations)
        det_times = []
        det_boxes = None
        for it in range(2):
            t0 = time.perf_counter()
            boxes = dlib_engine.detect_faces(img)
            t_det = (time.perf_counter() - t0) * 1000.0
            det_times.append(t_det)
            if det_boxes is None:
                det_boxes = boxes

        num_faces = len(det_boxes)
        total_dlib_faces += num_faces
        all_dlib_det_latencies.extend(det_times)

        boxes_info = []
        for b_idx, b in enumerate(det_boxes):
            top, right, bottom, left = b
            bw = right - left
            bh = bottom - top
            barea = bw * bh
            boxes_info.append({
                "face_idx": b_idx,
                "bbox": b,
                "width": bw,
                "height": bh,
                "area": barea
            })

        if boxes_info:
            min_face = min(boxes_info, key=lambda b: b["area"])
            max_face = max(boxes_info, key=lambda b: b["area"])
            min_face_summary = f"{min_face['width']}x{min_face['height']} ({min_face['area']} px)"
            max_face_summary = f"{max_face['width']}x{max_face['height']} ({max_face['area']} px)"
        else:
            min_face_summary = "N/A"
            max_face_summary = "N/A"

        # Dlib embedding generation (1 iteration)
        t_emb_start = time.perf_counter()
        dlib_embs = dlib_engine.generate_embeddings(img, det_boxes) if det_boxes else []
        t_emb_total = (time.perf_counter() - t_emb_start) * 1000.0

        if dlib_embs:
            avg_emb_ms = t_emb_total / len(dlib_embs)
            for _ in dlib_embs:
                all_dlib_emb_latencies.append(avg_emb_ms)
        else:
            avg_emb_ms = 0.0

        if num_faces == 0:
            density = "0 faces"
        elif 1 <= num_faces <= 5:
            density = "1-5 faces"
        elif 6 <= num_faces <= 15:
            density = "6-15 faces"
        elif 16 <= num_faces <= 30:
            density = "16-30 faces"
        else:
            density = "31+ faces"

        tot_warm_ms = np.mean(det_times) + t_emb_total
        all_dlib_total_latencies.append(tot_warm_ms)

        mem_ws, mem_peak = get_process_memory_mb()

        dlib_results[fname] = {
            "detected_faces": num_faces,
            "density_category": density,
            "detection_latency_ms": {
                "avg": round(float(np.mean(det_times)), 2),
                "median": round(float(np.median(det_times)), 2),
                "p95": round(percentile(det_times, 95), 2),
                "raw": [round(t, 2) for t in det_times]
            },
            "smallest_face": min_face_summary,
            "largest_face": max_face_summary,
            "embedding": {
                "count": len(dlib_embs),
                "dimension": 128,
                "total_embedding_time_ms": round(t_emb_total, 2),
                "avg_per_face_ms": round(avg_emb_ms, 2)
            },
            "total_warm_pipeline_ms": round(tot_warm_ms, 2),
            "memory_mb": {
                "working_set": mem_ws,
                "peak": mem_peak
            },
            "boxes": boxes_info
        }

        print(f"  Faces: {num_faces} ({density}) | Det: {np.mean(det_times):.1f}ms | Emb total: {t_emb_total:.1f}ms | Pipeline: {tot_warm_ms:.1f}ms")

    # Combine per-image results
    for fname in filenames:
        benchmark_data["per_image"][fname] = {
            "scrfd_arcface": scrfd_results[fname],
            "dlib": dlib_results[fname]
        }

    # Summary statistics
    final_mem, peak_mem = get_process_memory_mb()

    benchmark_data["summary"] = {
        "cold_start_ms": {
            "dlib": dlib_cold_time_ms,
            "scrfd_arcface": scrfd_cold_time_ms
        },
        "total_detected_faces": {
            "dlib": total_dlib_faces,
            "scrfd": total_scrfd_faces
        },
        "alignment_summary": {
            "total_scrfd_faces": total_scrfd_faces,
            "successfully_aligned": total_aligned_faces,
            "alignment_failures": total_alignment_failures,
            "failure_rate_pct": round((total_alignment_failures / max(1, total_scrfd_faces)) * 100, 2)
        },
        "embedding_summary": {
            "scrfd_arcface": {
                "total_generated": total_embeddings,
                "dimension": 512,
                "failed": total_embedding_failures,
                "avg_latency_ms": round(float(np.mean(all_scrfd_emb_latencies)), 2) if all_scrfd_emb_latencies else 0.0,
                "median_latency_ms": round(float(np.median(all_scrfd_emb_latencies)), 2) if all_scrfd_emb_latencies else 0.0,
                "p95_latency_ms": round(percentile(all_scrfd_emb_latencies, 95), 2) if all_scrfd_emb_latencies else 0.0
            },
            "dlib": {
                "total_generated": total_dlib_faces,
                "dimension": 128,
                "failed": 0,
                "avg_latency_ms": round(float(np.mean(all_dlib_emb_latencies)), 2) if all_dlib_emb_latencies else 0.0,
                "median_latency_ms": round(float(np.median(all_dlib_emb_latencies)), 2) if all_dlib_emb_latencies else 0.0,
                "p95_latency_ms": round(percentile(all_dlib_emb_latencies, 95), 2) if all_dlib_emb_latencies else 0.0
            }
        },
        "detection_latency_ms": {
            "scrfd": {
                "avg": round(float(np.mean(all_scrfd_det_latencies)), 2),
                "median": round(float(np.median(all_scrfd_det_latencies)), 2),
                "p95": round(percentile(all_scrfd_det_latencies, 95), 2)
            },
            "dlib": {
                "avg": round(float(np.mean(all_dlib_det_latencies)), 2),
                "median": round(float(np.median(all_dlib_det_latencies)), 2),
                "p95": round(percentile(all_dlib_det_latencies, 95), 2)
            }
        },
        "total_pipeline_latency_ms": {
            "scrfd_arcface": {
                "avg": round(float(np.mean(all_scrfd_total_latencies)), 2),
                "median": round(float(np.median(all_scrfd_total_latencies)), 2),
                "p95": round(percentile(all_scrfd_total_latencies, 95), 2)
            },
            "dlib": {
                "avg": round(float(np.mean(all_dlib_total_latencies)), 2),
                "median": round(float(np.median(all_dlib_total_latencies)), 2),
                "p95": round(percentile(all_dlib_total_latencies, 95), 2)
            }
        },
        "memory_mb": {
            "baseline": baseline_mem,
            "final_working_set": final_mem,
            "peak_working_set": peak_mem,
            "additional_attributed_mb": round(peak_mem - baseline_mem, 2)
        }
    }

    with open(results_path, "w", encoding="utf-8") as f:
        json.dump(benchmark_data, f, indent=2)

    print("\n" + "=" * 60)
    print("BENCHMARK COMPLETED SUCCESSFULLY")
    print(f"Results written to: {results_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()
