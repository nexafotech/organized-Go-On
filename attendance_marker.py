import cv2
import pickle
import numpy as np
import face_recognition
from attendance_manager import mark_attendance

# =========================
# CONFIGURATION
# =========================
MATCH_THRESHOLD = 0.45   # strict matching (prevents false names)
MAX_DISTANCE = 0.60      # used only for confidence scaling

# =========================
# LOAD FACE ENCODINGS
# =========================
with open("encodings.pickle", "rb") as f:
    data = pickle.load(f)

print("[INFO] Loaded faces:", len(data["encodings"]))

# =========================
# START CAMERA
# =========================
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("❌ Camera not opening")
    exit()

marked_today = set()   # prevent duplicate marking per run

# =========================
# MAIN LOOP
# =========================
while True:
    ret, frame = cap.read()
    if not ret:
        break

    # Resize for faster processing
    small_frame = cv2.resize(frame, (0, 0), fx=0.25, fy=0.25)
    rgb_small = cv2.cvtColor(small_frame, cv2.COLOR_BGR2RGB)

    # Detect faces
    face_locations = face_recognition.face_locations(rgb_small, model="hog")
    face_encodings = face_recognition.face_encodings(rgb_small, face_locations)

    for encoding, (top, right, bottom, left) in zip(face_encodings, face_locations):
        # Scale back to original frame
        top, right, bottom, left = top*4, right*4, bottom*4, left*4

        distances = face_recognition.face_distance(data["encodings"], encoding)
        best_index = np.argmin(distances)
        best_distance = distances[best_index]

        # =========================
        # MATCH DECISION
        # =========================
        if best_distance <= MATCH_THRESHOLD:
            full_id = data["names"][best_index]
            roll, name = full_id.split("_", 1)

            # Proper confidence calculation
            confidence = (1 - (best_distance / MAX_DISTANCE)) * 100
            confidence = max(0, min(100, confidence))
            confidence = round(confidence, 2)

            color = (0, 255, 0)  # GREEN
            label = f"{name} | {confidence}%"

            # Save attendance once per run
            if roll not in marked_today:
                saved = mark_attendance(roll, name, confidence)
                if saved:
                    print(f"[SAVED] {name} - {confidence}%")
                    marked_today.add(roll)

        else:
            # ❌ Not matched
            color = (0, 0, 255)  # RED
            label = "UNKNOWN"

        # Draw box and label
        cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
        cv2.putText(frame, label, (left, top - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

    cv2.imshow("ATTENDANCE MARKER", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
