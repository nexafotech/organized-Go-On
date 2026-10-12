import os
import re
import hashlib
from typing import Tuple, List, Optional, Dict, Any
import numpy as np

from app.core.config import settings

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

def ensure_dataset_root() -> str:
    """Ensures the root student face dataset directory exists and returns its absolute path."""
    root_dir = settings.student_face_dataset_path
    os.makedirs(root_dir, exist_ok=True)
    return root_dir


def sanitize_roll_number(roll_number: str) -> str:
    """
    Sanitizes roll number / register number to prevent path traversal attacks.
    Allows alphanumeric characters, underscores, and hyphens.
    """
    if not roll_number:
        raise ValueError("Register number cannot be empty.")
    
    clean = roll_number.strip()
    # Reject directory traversal attempts
    if ".." in clean or "/" in clean or "\\" in clean:
        raise ValueError(f"Invalid register number '{roll_number}': path traversal characters are forbidden.")
    
    # Enforce safe naming
    clean = re.sub(r"[^a-zA-Z0-9_\-]", "", clean)
    if not clean:
        raise ValueError(f"Register number '{roll_number}' contains no valid characters.")
    
    return clean


def get_student_dir(roll_number: str, create: bool = True) -> str:
    """
    Returns the absolute path to a student's dataset directory:
    data/student_faces/<register_number>/
    """
    root_dir = ensure_dataset_root()
    clean_roll = sanitize_roll_number(roll_number)
    student_dir = os.path.normpath(os.path.join(root_dir, clean_roll))
    
    # Assert path safety: student_dir must be strictly a direct child of root_dir
    if not student_dir.startswith(root_dir):
        raise ValueError("Directory traversal attempt detected.")
    
    if create:
        os.makedirs(student_dir, exist_ok=True)
    return student_dir


def sanitize_filename(filename: str, default_ext: str = ".jpg") -> str:
    """Sanitizes an uploaded filename to ensure safe storage."""
    base = os.path.basename(filename.strip().replace("\\", "/"))
    name, ext = os.path.splitext(base)
    ext = ext.lower()
    if ext not in ALLOWED_EXTENSIONS:
        ext = default_ext
    
    # Clean the base name
    clean_name = re.sub(r"[^a-zA-Z0-9_\-\.]", "_", name).strip("._")
    if not clean_name:
        clean_name = "photo"
    return f"{clean_name}{ext}"


def compute_image_sha256(image_bytes: bytes) -> str:
    """Returns SHA256 hex digest of image bytes."""
    return hashlib.sha256(image_bytes).hexdigest()


def check_duplicate_photo(
    roll_number: str,
    image_bytes: bytes,
    new_embedding: Optional[np.ndarray] = None,
    existing_embeddings: Optional[List[np.ndarray]] = None
) -> Tuple[bool, Optional[str]]:
    """
    Checks if photo or face template is an uncontrolled duplicate:
    1. Checks SHA256 against existing stored files in student directory.
    2. Checks Euclidean distance against existing templates (< 0.03 = identical vector).
    """
    student_dir = get_student_dir(roll_number, create=False)
    new_sha = compute_image_sha256(image_bytes)

    if os.path.exists(student_dir):
        for fname in os.listdir(student_dir):
            fpath = os.path.join(student_dir, fname)
            if os.path.isfile(fpath):
                try:
                    with open(fpath, "rb") as fp:
                        existing_data = fp.read()
                    if compute_image_sha256(existing_data) == new_sha:
                        return True, f"Duplicate photo: exact file identical to already stored '{fname}'"
                except Exception:
                    continue

    if new_embedding is not None and existing_embeddings:
        for idx, emb in enumerate(existing_embeddings):
            dist = float(np.linalg.norm(new_embedding - emb))
            if dist < 0.03:
                return True, f"Duplicate biometric template: facial features identical to template #{idx + 1} (dist={dist:.4f})"

    return False, None


def save_student_face_image(
    roll_number: str,
    image_bytes: bytes,
    original_filename: str
) -> Tuple[str, str]:
    """
    Saves an uploaded student face photo into the student's canonical directory:
    data/student_faces/<register_number>/<filename>
    Returns (relative_path, absolute_path).
    """
    student_dir = get_student_dir(roll_number, create=True)
    clean_roll = sanitize_roll_number(roll_number)
    safe_name = sanitize_filename(original_filename)

    target_path = os.path.join(student_dir, safe_name)

    # If file with same name exists, check if contents are identical
    if os.path.exists(target_path):
        with open(target_path, "rb") as fp:
            existing_bytes = fp.read()
        if existing_bytes != image_bytes:
            # Different image with same filename -> append hash prefix
            name_part, ext_part = os.path.splitext(safe_name)
            short_hash = compute_image_sha256(image_bytes)[:8]
            safe_name = f"{name_part}_{short_hash}{ext_part}"
            target_path = os.path.join(student_dir, safe_name)

    with open(target_path, "wb") as fp:
        fp.write(image_bytes)

    # Relative path stored in database / metadata
    rel_path = f"data/student_faces/{clean_roll}/{safe_name}"
    return rel_path, target_path


def resolve_photo_path(stored_path: str, roll_number: Optional[str] = None) -> Optional[str]:
    """
    Resolves a stored image_path string to an absolute path on disk.
    Guards strictly against directory traversal outside student_faces.
    """
    if not stored_path:
        return None

    root_dir = ensure_dataset_root()

    # If path starts with data/student_faces/ or student_faces/
    clean_p = stored_path.replace("\\", "/").strip()
    if clean_p.startswith("data/student_faces/"):
        rel_sub = clean_p[len("data/student_faces/"):]
    elif clean_p.startswith("student_faces/"):
        rel_sub = clean_p[len("student_faces/"):]
    elif clean_p.startswith("folder:") and roll_number:
        # Legacy Phase 7.7 format: folder:721025149046/fname.jpg
        prefix = f"folder:{roll_number}/"
        if clean_p.startswith(prefix):
            rel_sub = f"{roll_number}/{clean_p[len(prefix):]}"
        else:
            rel_sub = clean_p[len("folder:"):]
    elif clean_p.startswith("upload:") and roll_number:
        # Legacy Phase 7.7 format: upload:fname.jpg
        rel_sub = f"{roll_number}/{clean_p[len('upload:'):]}"
    else:
        rel_sub = clean_p

    abs_path = os.path.normpath(os.path.join(root_dir, rel_sub))
    if not abs_path.startswith(root_dir):
        return None

    if os.path.exists(abs_path) and os.path.isfile(abs_path):
        return abs_path
    return None


def delete_student_photo_file(image_path: str, roll_number: Optional[str] = None) -> bool:
    """Safely removes a stored photo file if it exists in the student's dataset directory."""
    abs_path = resolve_photo_path(image_path, roll_number)
    if abs_path and os.path.exists(abs_path):
        try:
            os.remove(abs_path)
            return True
        except Exception:
            return False
    return False


def clear_student_photos_dir(roll_number: str) -> int:
    """Removes all photo files in data/student_faces/<register_number>/."""
    student_dir = get_student_dir(roll_number, create=False)
    if not os.path.exists(student_dir):
        return 0

    count = 0
    for fname in os.listdir(student_dir):
        fpath = os.path.join(student_dir, fname)
        if os.path.isfile(fpath):
            try:
                os.remove(fpath)
                count += 1
            except Exception:
                pass
    return count
