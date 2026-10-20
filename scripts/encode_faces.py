import cv2
import face_recognition
import pickle
import os

DATASET = "dataset"

known_encodings = []
known_names = []

for student in os.listdir(DATASET):
    student_path = os.path.join(DATASET, student)
    if not os.path.isdir(student_path):
        continue

    for img_name in os.listdir(student_path):
        img_path = os.path.join(student_path, img_name)
        image = cv2.imread(img_path)

        if image is None:
            continue

        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        boxes = face_recognition.face_locations(rgb)
        encodings = face_recognition.face_encodings(rgb, boxes)

        if len(encodings) == 1:
            known_encodings.append(encodings[0])
            known_names.append(student)

data = {"encodings": known_encodings, "names": known_names}

with open("encodings.pickle", "wb") as f:
    pickle.dump(data, f)

print("ATTENDANCE MARKER | Face encoding completed")
