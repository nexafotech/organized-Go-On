import cv2
import numpy as np
from dataclasses import dataclass, field
from typing import List, Dict, Any, Tuple, Optional
from app.engines.recognition.factory import RecognitionEngineFactory


@dataclass
class PoseThresholds:
    """Configurable acceptance ranges and quality thresholds for biometric enrollment."""

    # Capture 1: FRONTAL Reference
    frontal_yaw_min: float = -5.0
    frontal_yaw_max: float = 5.0
    frontal_pitch_min: float = -5.0
    frontal_pitch_max: float = 5.0
    frontal_roll_min: float = -5.0
    frontal_roll_max: float = 5.0

    # Capture 2: Slight Left (target -15°)
    left_yaw_target: float = -15.0
    left_yaw_tolerance: float = 5.0    # [-20.0, -10.0]
    left_pitch_tolerance: float = 7.0  # [-7.0, +7.0]
    left_roll_tolerance: float = 5.0   # [-5.0, +5.0]

    # Capture 3: Slight Right (target +15°)
    right_yaw_target: float = 15.0
    right_yaw_tolerance: float = 5.0   # [+10.0, +20.0]
    right_pitch_tolerance: float = 7.0 # [-7.0, +7.0]
    right_roll_tolerance: float = 5.0  # [-5.0, +5.0]

    # Common quality thresholds
    min_confidence: float = 0.80
    min_face_size: int = 60
    min_laplacian_var: float = 30.0    # Blur threshold
    min_brightness: float = 35.0        # Luminance floor
    max_brightness: float = 235.0       # Luminance ceiling
    max_center_offset_ratio: float = 0.35  # Maximum deviation from image center
    min_frame_ratio: float = 0.10      # Min face height relative to image height
    max_frame_ratio: float = 0.90      # Max face height relative to image height


# UI Guidance strings per step
STEP_GUIDANCE = {
    "FRONTAL": [
        "Look directly at the camera.",
        "Keep your head straight.",
        "Keep both eyes clearly visible.",
        "Keep your nose centered between the eyes.",
        "Do not tilt or rotate your head."
    ],
    "LEFT_15": [
        "Slowly turn your head slightly to the LEFT.",
        "Do not move the camera.",
        "Keep both eyes visible.",
        "Do not tilt your head upward or downward."
    ],
    "RIGHT_15": [
        "Slowly turn your head slightly to the RIGHT.",
        "Do not move the camera.",
        "Keep both eyes visible.",
        "Do not tilt your head upward or downward."
    ]
}


def estimate_head_pose(landmarks: np.ndarray) -> Tuple[float, float, float]:
    """
    Estimates approximate (yaw, pitch, roll) head pose angles in degrees from 5 facial landmarks.
    Landmarks format: (5, 2) array of [left_eye, right_eye, nose_tip, left_mouth, right_mouth].

    Returns:
        (yaw, pitch, roll) in degrees rounded to 2 decimal places.
        - Yaw: negative is head turned to person's left, positive is head turned to person's right.
        - Pitch: negative is head tilted down, positive is head tilted up.
        - Roll: negative is head tilted counter-clockwise, positive is head tilted clockwise.
    """
    le, re, nose, lm, rm = landmarks

    # 1. Roll: rotation around optical (camera) axis
    dx_eyes = float(re[0] - le[0])
    dy_eyes = float(re[1] - le[1])
    roll = float(np.degrees(np.arctan2(dy_eyes, dx_eyes)))

    # De-rotate landmarks by roll angle to isolate yaw & pitch from head tilt
    angle_rad = -np.radians(roll)
    rot_matrix = np.array([
        [np.cos(angle_rad), -np.sin(angle_rad)],
        [np.sin(angle_rad), np.cos(angle_rad)]
    ], dtype=np.float32)
    rotated_kps = np.dot(landmarks, rot_matrix.T)
    r_le, r_re, r_nose, r_lm, r_rm = rotated_kps

    # 2. Yaw: rotation around vertical axis (horizontal asymmetry)
    eye_mid_x = (r_le[0] + r_re[0]) / 2.0
    half_iod = (r_re[0] - r_le[0]) / 2.0
    yaw_ratio = (r_nose[0] - eye_mid_x) / half_iod if half_iod > 0 else 0.0
    # In anthropometry, 15° turn corresponds to ~0.30 relative asymmetry -> scaling factor ~50.0
    yaw = float(yaw_ratio * 50.0)

    # 3. Pitch: rotation around horizontal axis (vertical displacement)
    eye_mid_y = (r_le[1] + r_re[1]) / 2.0
    mouth_mid_y = (r_lm[1] + r_rm[1]) / 2.0
    total_h = mouth_mid_y - eye_mid_y
    if total_h > 0:
        nose_to_mouth = mouth_mid_y - r_nose[1]
        pitch_ratio = (nose_to_mouth / total_h) - 0.505
        pitch = float(pitch_ratio * 60.0)
    else:
        pitch = 0.0

    return round(yaw, 2), round(pitch, 2), round(roll, 2)


class FacePoseService:
    """
    Validates face capture quality and pose adherence for student biometric enrollment.
    """

    def __init__(self, thresholds: Optional[PoseThresholds] = None):
        self.thresholds = thresholds or PoseThresholds()

    def get_step_target_range(self, step: str) -> Dict[str, float]:
        """Returns the min and max acceptable ranges for yaw, pitch, and roll for a given capture step."""
        t = self.thresholds
        s = step.upper().strip()
        if s in ["FRONTAL", "STEP_1", "1"]:
            return {
                "yaw_min": t.frontal_yaw_min,
                "yaw_max": t.frontal_yaw_max,
                "pitch_min": t.frontal_pitch_min,
                "pitch_max": t.frontal_pitch_max,
                "roll_min": t.frontal_roll_min,
                "roll_max": t.frontal_roll_max,
            }
        elif s in ["LEFT_15", "LEFT", "STEP_2", "2"]:
            return {
                "yaw_min": t.left_yaw_target - t.left_yaw_tolerance,  # -20.0
                "yaw_max": t.left_yaw_target + t.left_yaw_tolerance,  # -10.0
                "pitch_min": -t.left_pitch_tolerance,                 # -7.0
                "pitch_max": t.left_pitch_tolerance,                  # +7.0
                "roll_min": -t.left_roll_tolerance,                   # -5.0
                "roll_max": t.left_roll_tolerance,                    # +5.0
            }
        elif s in ["RIGHT_15", "RIGHT", "STEP_3", "3"]:
            return {
                "yaw_min": t.right_yaw_target - t.right_yaw_tolerance,  # +10.0
                "yaw_max": t.right_yaw_target + t.right_yaw_tolerance,  # +20.0
                "pitch_min": -t.right_pitch_tolerance,                  # -7.0
                "pitch_max": t.right_pitch_tolerance,                   # +7.0
                "roll_min": -t.right_roll_tolerance,                    # -5.0
                "roll_max": t.right_roll_tolerance,                     # +5.0
            }
        else:
            raise ValueError(f"Unknown capture step: '{step}'. Expected FRONTAL, LEFT_15, or RIGHT_15.")

    @staticmethod
    def decode_and_orient(image_bytes: bytes, mirrored: bool = False) -> Optional[np.ndarray]:
        """
        Decodes raw image bytes into a BGR numpy array with EXIF orientation normalized.
        Optionally compensates for front-camera selfie mirroring if requested.
        """
        if not image_bytes or len(image_bytes) == 0:
            return None

        img = None
        try:
            from PIL import Image, ImageOps
            import io
            pil_img = Image.open(io.BytesIO(image_bytes))
            pil_img = ImageOps.exif_transpose(pil_img)
            if pil_img.mode != "RGB":
                pil_img = pil_img.convert("RGB")
            img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        except Exception:
            try:
                nparr = np.frombuffer(image_bytes, np.uint8)
                if nparr.size > 0:
                    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            except Exception:
                img = None

        if img is not None and mirrored:
            img = cv2.flip(img, 1)
        return img

    def validate_image_and_pose(
        self,
        image_bytes: bytes,
        step: str,
        engine: Optional[Any] = None,
        mirrored: bool = False
    ) -> Dict[str, Any]:
        """
        Processes image in-memory, detects face with landmarks, assesses quality and pose adherence.
        Does NOT store or persist the image.
        Supports EXIF orientation normalization and front-camera mirroring compensation.
        """
        step_clean = step.upper().strip()
        if step_clean in ["1", "STEP_1"]:
            step_clean = "FRONTAL"
        elif step_clean in ["2", "STEP_2"]:
            step_clean = "LEFT_15"
        elif step_clean in ["3", "STEP_3"]:
            step_clean = "RIGHT_15"

        ranges = self.get_step_target_range(step_clean)
        guidance_list = STEP_GUIDANCE.get(step_clean, [])
        t = self.thresholds

        # 1. Decode image with EXIF normalization & mirror handling
        img = self.decode_and_orient(image_bytes, mirrored=mirrored)
        if img is None:
            return {
                "valid": False,
                "status": "IMAGE_CORRUPTED",
                "message": "Failed to decode image. Please capture or upload a valid JPEG/PNG image.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
            }

        img_h, img_w = img.shape[:2]

        # 2. Face Detection & Landmark Extraction using SCRFD
        if engine is None:
            engine = RecognitionEngineFactory.get_engine("scrfd_arcface")

        detected_faces = []
        if hasattr(engine, "detect_faces_with_landmarks"):
            detected_faces = engine.detect_faces_with_landmarks(img)
        else:
            # Fallback wrapper
            locs = engine.detect_faces(img)
            for loc in locs:
                top, right, bottom, left = loc
                detected_faces.append({
                    "bbox": loc,
                    "confidence": 0.95,
                    "landmarks": np.zeros((5, 2), dtype=np.float32)
                })

        # 3. Check Face Cardinality (Exactly ONE face required)
        if len(detected_faces) == 0:
            return {
                "valid": False,
                "status": "NO_FACE",
                "message": "No face detected in the image. Please position your face inside the frame.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "frame_size": {"width": img_w, "height": img_h}
            }

        if len(detected_faces) > 1:
            return {
                "valid": False,
                "status": "MULTIPLE_FACES",
                "message": f"Multiple faces ({len(detected_faces)}) detected. Enrollment requires exactly ONE student face in frame.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "frame_size": {"width": img_w, "height": img_h}
            }

        face = detected_faces[0]
        top, right, bottom, left = face["bbox"]
        face_w = right - left
        face_h = bottom - top
        confidence = float(face.get("confidence", 0.0))
        landmarks = face.get("landmarks", None)

        face_box_dict = {
            "top": int(top),
            "right": int(right),
            "bottom": int(bottom),
            "left": int(left),
            "width": int(face_w),
            "height": int(face_h)
        }
        face_center_x = (left + right) / 2.0
        face_center_y = (top + bottom) / 2.0
        face_center_dict = {
            "x": round(face_center_x, 1),
            "y": round(face_center_y, 1)
        }

        # 4. Check SCRFD Confidence Threshold
        if confidence < t.min_confidence:
            return {
                "valid": False,
                "status": "IMAGE_QUALITY_LOW",
                "message": f"Face detection confidence ({confidence:.2f}) is below minimum requirement ({t.min_confidence:.2f}). Ensure good lighting.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3)
            }

        # 5. Check Face Bounding Box Dimensions
        if face_w < t.min_face_size or face_h < t.min_face_size:
            return {
                "valid": False,
                "status": "FACE_TOO_FAR",
                "message": "Face is too far from camera. Move closer to the screen.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3)
            }

        # 6. Check Face Scale Relative to Frame
        face_ratio = face_h / float(img_h)
        if face_ratio < t.min_frame_ratio:
            return {
                "valid": False,
                "status": "FACE_TOO_FAR",
                "message": "Move your face closer to the camera.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3)
            }
        if face_ratio > t.max_frame_ratio:
            return {
                "valid": False,
                "status": "FACE_TOO_CLOSE",
                "message": "Move your face slightly further from the camera.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3)
            }

        # 7. Check Face Centering
        center_x_offset = abs(face_center_x - (img_w / 2.0)) / float(img_w)
        center_y_offset = abs(face_center_y - (img_h / 2.0)) / float(img_h)
        if center_x_offset > t.max_center_offset_ratio or center_y_offset > t.max_center_offset_ratio:
            return {
                "valid": False,
                "status": "FACE_NOT_CENTERED",
                "message": "Move your face to the center of the camera frame.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3)
            }

        # 8. Check Lighting & Image Quality on Face Crop
        safe_top = max(0, int(top))
        safe_bottom = min(img_h, int(bottom))
        safe_left = max(0, int(left))
        safe_right = min(img_w, int(right))
        face_crop = img[safe_top:safe_bottom, safe_left:safe_right]

        if face_crop.size > 0:
            gray_crop = cv2.cvtColor(face_crop, cv2.COLOR_BGR2GRAY)
            mean_brightness = float(np.mean(gray_crop))
            laplacian_var = float(cv2.Laplacian(gray_crop, cv2.CV_64F).var())
        else:
            mean_brightness = float(np.mean(img))
            laplacian_var = 100.0

        if mean_brightness < t.min_brightness:
            return {
                "valid": False,
                "status": "POOR_LIGHTING",
                "message": "Lighting is too dark. Move to a well-lit area or face a light source.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3),
                "brightness": round(mean_brightness, 1)
            }
        if mean_brightness > t.max_brightness:
            return {
                "valid": False,
                "status": "POOR_LIGHTING",
                "message": "Lighting is too bright or overexposed. Avoid direct glare or harsh backlight.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3),
                "brightness": round(mean_brightness, 1)
            }

        if laplacian_var < t.min_laplacian_var:
            return {
                "valid": False,
                "status": "IMAGE_BLURRED",
                "message": "Face image is blurry. Hold the camera steady and focus.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3),
                "blur_score": round(laplacian_var, 1)
            }

        # 9. Landmark Availability & Head Pose Estimation
        if landmarks is None or len(landmarks) != 5:
            return {
                "valid": False,
                "status": "LANDMARKS_UNAVAILABLE",
                "message": "Facial landmarks could not be extracted. Ensure full face visibility.",
                "guidance": guidance_list,
                "step": step_clean,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h}
            }

        yaw, pitch, roll = estimate_head_pose(landmarks)
        pose_dict = {"yaw": yaw, "pitch": pitch, "roll": roll}

        # 10. Pose Verification According to Step Protocol
        # Roll Check (Common to all steps: head must remain level)
        if roll < ranges["roll_min"] or roll > ranges["roll_max"]:
            return {
                "valid": False,
                "status": "HEAD_TILTED",
                "message": "Keep your head level. Do not tilt your head sideways.",
                "guidance": guidance_list,
                "step": step_clean,
                "pose": pose_dict,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3)
            }

        # Pitch Check (Looking too high or too low)
        if pitch > ranges["pitch_max"]:
            return {
                "valid": False,
                "status": "HEAD_TOO_HIGH",
                "message": "Lower your head slightly to eye level.",
                "guidance": guidance_list,
                "step": step_clean,
                "pose": pose_dict,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3)
            }
        if pitch < ranges["pitch_min"]:
            return {
                "valid": False,
                "status": "HEAD_TOO_LOW",
                "message": "Raise your head slightly to eye level.",
                "guidance": guidance_list,
                "step": step_clean,
                "pose": pose_dict,
                "target_range": ranges,
                "face_box": face_box_dict,
                "face_center": face_center_dict,
                "frame_size": {"width": img_w, "height": img_h},
                "confidence": round(confidence, 3)
            }

        # Yaw Check (Horizontal turning)
        if step_clean == "FRONTAL":
            if yaw < ranges["yaw_min"]:
                return {
                    "valid": False,
                    "status": "POSE_TOO_LEFT",
                    "message": "Turn your head slightly to the RIGHT to face directly forward.",
                    "guidance": guidance_list,
                    "step": step_clean,
                    "pose": pose_dict,
                    "target_range": ranges,
                    "face_box": face_box_dict,
                    "face_center": face_center_dict,
                    "frame_size": {"width": img_w, "height": img_h},
                    "confidence": round(confidence, 3)
                }
            if yaw > ranges["yaw_max"]:
                return {
                    "valid": False,
                    "status": "POSE_TOO_RIGHT",
                    "message": "Turn your head slightly to the LEFT to face directly forward.",
                    "guidance": guidance_list,
                    "step": step_clean,
                    "pose": pose_dict,
                    "target_range": ranges,
                    "face_box": face_box_dict,
                    "face_center": face_center_dict,
                    "frame_size": {"width": img_w, "height": img_h},
                    "confidence": round(confidence, 3)
                }

        elif step_clean == "LEFT_15":
            if yaw > 0.0:
                return {
                    "valid": False,
                    "status": "POSE_WRONG_DIRECTION",
                    "message": "Turn your head to the LEFT, not right.",
                    "guidance": guidance_list,
                    "step": step_clean,
                    "pose": pose_dict,
                    "target_range": ranges,
                    "face_box": face_box_dict,
                    "face_center": face_center_dict,
                    "frame_size": {"width": img_w, "height": img_h},
                    "confidence": round(confidence, 3)
                }
            if yaw > ranges["yaw_max"]:  # yaw > -10.0 (e.g. -5.0) -> not turned enough left
                return {
                    "valid": False,
                    "status": "POSE_TOO_RIGHT",
                    "message": "Slowly turn your head slightly more to the LEFT (~15°).",
                    "guidance": guidance_list,
                    "step": step_clean,
                    "pose": pose_dict,
                    "target_range": ranges,
                    "face_box": face_box_dict,
                    "face_center": face_center_dict,
                    "frame_size": {"width": img_w, "height": img_h},
                    "confidence": round(confidence, 3)
                }
            if yaw < ranges["yaw_min"]:  # yaw < -20.0 (e.g. -25.0) -> turned too far left
                return {
                    "valid": False,
                    "status": "POSE_TOO_LEFT",
                    "message": "You turned too far left. Turn back slightly towards the center.",
                    "guidance": guidance_list,
                    "step": step_clean,
                    "pose": pose_dict,
                    "target_range": ranges,
                    "face_box": face_box_dict,
                    "face_center": face_center_dict,
                    "frame_size": {"width": img_w, "height": img_h},
                    "confidence": round(confidence, 3)
                }

        elif step_clean == "RIGHT_15":
            if yaw < 0.0:
                return {
                    "valid": False,
                    "status": "POSE_WRONG_DIRECTION",
                    "message": "Turn your head to the RIGHT, not left.",
                    "guidance": guidance_list,
                    "step": step_clean,
                    "pose": pose_dict,
                    "target_range": ranges,
                    "face_box": face_box_dict,
                    "face_center": face_center_dict,
                    "frame_size": {"width": img_w, "height": img_h},
                    "confidence": round(confidence, 3)
                }
            if yaw < ranges["yaw_min"]:  # yaw < 10.0 (e.g. 5.0) -> not turned enough right
                return {
                    "valid": False,
                    "status": "POSE_TOO_LEFT",
                    "message": "Slowly turn your head slightly more to the RIGHT (~15°).",
                    "guidance": guidance_list,
                    "step": step_clean,
                    "pose": pose_dict,
                    "target_range": ranges,
                    "face_box": face_box_dict,
                    "face_center": face_center_dict,
                    "frame_size": {"width": img_w, "height": img_h},
                    "confidence": round(confidence, 3)
                }
            if yaw > ranges["yaw_max"]:  # yaw > 20.0 (e.g. 25.0) -> turned too far right
                return {
                    "valid": False,
                    "status": "POSE_TOO_RIGHT",
                    "message": "You turned too far right. Turn back slightly towards the center.",
                    "guidance": guidance_list,
                    "step": step_clean,
                    "pose": pose_dict,
                    "target_range": ranges,
                    "face_box": face_box_dict,
                    "face_center": face_center_dict,
                    "frame_size": {"width": img_w, "height": img_h},
                    "confidence": round(confidence, 3)
                }

        # 11. All Checks Passed -> READY State
        return {
            "valid": True,
            "status": "READY",
            "message": "Face position is optimal. Ready for capture!",
            "guidance": guidance_list,
            "step": step_clean,
            "pose": pose_dict,
            "target_range": ranges,
            "face_box": face_box_dict,
            "face_center": face_center_dict,
            "frame_size": {"width": img_w, "height": img_h},
            "confidence": round(confidence, 3),
            "quality_score": round(confidence, 3),
            "brightness": round(mean_brightness, 1),
            "blur_score": round(laplacian_var, 1),
            "lighting": "GOOD"
        }
