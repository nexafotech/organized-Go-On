import os
import sys
import shutil
import hashlib
import json
import subprocess
from datetime import datetime

PROJECT_ROOT = r"E:\originalam"
MOBILE_DIR = os.path.join(PROJECT_ROOT, "mobile")
REPORTS_DIR = os.path.join(PROJECT_ROOT, "reports")
QUARANTINE_DIR = os.path.join(PROJECT_ROOT, ".quarantine")

def get_file_hash(path):
    if not os.path.isfile(path):
        return None
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def dir_size_and_count(d, exclude_dirs=None):
    if not os.path.exists(d):
        return 0, 0
    total_sz = 0
    count = 0
    exclude = set(exclude_dirs or [])
    for root, dirs, fnames in os.walk(d):
        dirs[:] = [dr for dr in dirs if dr not in exclude]
        for f in fnames:
            p = os.path.join(root, f)
            try:
                total_sz += os.path.getsize(p)
                count += 1
            except:
                pass
    return total_sz, count

def count_image_animation_files(root_dir):
    exts = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.mp4', '.webm', '.svg'}
    count = 0
    size = 0
    for r, dirs, fnames in os.walk(root_dir):
        if any(ign in r for ign in ['.git', 'build', '.dart_tool', 'lib']):
            continue
        for f in fnames:
            if os.path.splitext(f)[1].lower() in exts:
                p = os.path.join(r, f)
                try:
                    size += os.path.getsize(p)
                    count += 1
                except:
                    pass
    return count, size

def get_git_status(path):
    try:
        res = subprocess.run(
            ["git", "status", "--porcelain", path],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=10
        )
        out = res.stdout.strip()
        if not out:
            return "Tracked (Clean)"
        if out.startswith("??"):
            return "Untracked"
        if out.startswith(" M"):
            return "Tracked (Modified)"
        return f"Tracked ({out[:2]})"
    except:
        return "Unknown"

print("Cleanup engine initialized.")
