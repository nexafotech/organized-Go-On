import pandas as pd
import os
from datetime import datetime

COLUMNS = ["Date", "Roll No", "Name", "Time", "Confidence (%)", "Status"]

def get_today_file():
    today = datetime.now().strftime("%Y-%m-%d")
    return f"attendance_{today}.csv"

def mark_attendance(roll, name, confidence):
    file = get_today_file()
    date = datetime.now().strftime("%Y-%m-%d")
    time = datetime.now().strftime("%H:%M:%S")

    # Create file if not exists
    if not os.path.exists(file):
        pd.DataFrame(columns=COLUMNS).to_csv(file, index=False)

    try:
        df = pd.read_csv(file)
    except PermissionError:
        print("⚠️ Attendance file is open. Close Excel.")
        return False

    # Avoid duplicate attendance (same day + same roll)
    if ((df["Date"] == date) & (df["Roll No"] == roll)).any():
        return False

    new_row = pd.DataFrame(
        [[date, roll, name, time, confidence, "Present"]],
        columns=COLUMNS
    )

    try:
        new_row.to_csv(file, mode="a", header=False, index=False)
        return True
    except PermissionError:
        print("⚠️ Cannot write to attendance file.")
        return False
