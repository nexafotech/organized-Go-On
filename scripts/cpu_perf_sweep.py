import os
import sys
sys.path.insert(0, '.')
import time
import cv2
import numpy as np
import onnxruntime as ort

MODEL_DET = r"models\face_recognition\det_10g.onnx"
MODEL_ARC = r"models\face_recognition\w600k_r50.onnx"
IMG_PATH = r"C:\Users\Abishek\Downloads\WhatsApp Image 2026-08-29 at 3.36.12 PM.jpeg"

def test_onnx_thread_sweep():
    print("=" * 70)
    print("STEP 1: ONNX RUNTIME CPU THREAD SWEEP (ArcFace ResNet-50)")
    print("=" * 70)

    # Prepare dummy batch of 8 aligned face crops (112x112x3)
    dummy_single = np.random.randn(1, 3, 112, 112).astype(np.float32)
    dummy_8 = np.random.randn(8, 3, 112, 112).astype(np.float32)

    configs = [
        (1, 1),
        (2, 1),
        (4, 1),
        (6, 1),
        (8, 1),
        (12, 1),
        (4, 2),
        (8, 2),
    ]

    results = []

    for intra, inter in configs:
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = intra
        opts.inter_op_num_threads = inter
        opts.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
        opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        opts.enable_cpu_mem_arena = True

        sess = ort.InferenceSession(MODEL_ARC, sess_options=opts, providers=["CPUExecutionProvider"])
        inp_name = sess.get_inputs()[0].name

        # Warmup
        sess.run(None, {inp_name: dummy_single})

        # Benchmark 1 face (warm 5 runs)
        t_1_runs = []
        for _ in range(5):
            t0 = time.perf_counter()
            sess.run(None, {inp_name: dummy_single})
            t_1_runs.append((time.perf_counter() - t0) * 1000)

        # Benchmark 8 faces batched (warm 5 runs)
        t_8_runs = []
        for _ in range(5):
            t0 = time.perf_counter()
            sess.run(None, {inp_name: dummy_8})
            t_8_runs.append((time.perf_counter() - t0) * 1000)

        # Benchmark 8 faces sequential (warm 3 runs)
        t_seq_runs = []
        for _ in range(3):
            t0 = time.perf_counter()
            for _ in range(8):
                sess.run(None, {inp_name: dummy_single})
            t_seq_runs.append((time.perf_counter() - t0) * 1000)

        res = {
            "intra": intra,
            "inter": inter,
            "1_face_median": np.median(t_1_runs),
            "1_face_p95": np.percentile(t_1_runs, 95),
            "8_batch_median": np.median(t_8_runs),
            "8_batch_p95": np.percentile(t_8_runs, 95),
            "8_seq_median": np.median(t_seq_runs),
        }
        results.append(res)
        print(f"intra={intra:2d}, inter={inter:1d} | 1-face: med={res['1_face_median']:5.1f}ms | 8-batch: med={res['8_batch_median']:6.1f}ms (p95={res['8_batch_p95']:6.1f}ms) | 8-seq: med={res['8_seq_median']:6.1f}ms")

    best = min(results, key=lambda x: x["8_batch_median"])
    print(f"\nBest config for 8-batch ArcFace: intra={best['intra']}, inter={best['inter']} ({best['8_batch_median']:.1f}ms)")
    return results

def test_scrfd_thread_sweep():
    print("\n" + "=" * 70)
    print("STEP 2: ONNX RUNTIME CPU THREAD SWEEP (SCRFD-10G Detector)")
    print("=" * 70)

    dummy_det = np.random.randn(1, 3, 640, 640).astype(np.float32)

    configs = [(1, 1), (2, 1), (4, 1), (6, 1), (8, 1), (12, 1)]
    results = []

    for intra, inter in configs:
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = intra
        opts.inter_op_num_threads = inter
        opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

        sess = ort.InferenceSession(MODEL_DET, sess_options=opts, providers=["CPUExecutionProvider"])
        inp_name = sess.get_inputs()[0].name

        # Warmup
        sess.run(None, {inp_name: dummy_det})

        runs = []
        for _ in range(5):
            t0 = time.perf_counter()
            sess.run(None, {inp_name: dummy_det})
            runs.append((time.perf_counter() - t0) * 1000)

        med = np.median(runs)
        p95 = np.percentile(runs, 95)
        results.append((intra, inter, med, p95))
        print(f"intra={intra:2d}, inter={inter:1d} | SCRFD-640: med={med:5.1f}ms, p95={p95:5.1f}ms")

    best = min(results, key=lambda x: x[2])
    print(f"\nBest config for SCRFD: intra={best[0]}, inter={best[1]} ({best[2]:.1f}ms)")

if __name__ == "__main__":
    test_onnx_thread_sweep()
    test_scrfd_thread_sweep()
