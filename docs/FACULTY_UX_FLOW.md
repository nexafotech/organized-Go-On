# Faculty Mobile App UX Flow & Recognition State Machine
**Attendance Marker Mobile Suite**

---

## 1. Primary Faculty Workflow

```text
Faculty Login Screen
        │
        ▼
Faculty Mobile Dashboard
        │
        ├── Today's Timetable List
        └── Active Class Session Card
                │
                ▼
        [ Start Attendance Session ]
                │
                ▼
      Attendance Action Menu:
        ├─► [ TAKE GROUP PHOTO ]  ──► Device Camera Single Capture
        ├─► [ CHOOSE FROM GALLERY ]──► Local Image Picker
        ├─► [ MANUAL ATTENDANCE ] ──► Roster Toggle List
        └─► [ MARK OD ]           ──► Bulk OD Selection Modal
                │
                ▼
     Recognition Progress Flow (9 States)
                │
                ▼
   Faculty Review & Candidate Verification
        ├─► High Confidence (Pre-selected)
        ├─► Uncertain Matches (Requires Manual Selection)
        └─► Unknown Faces (Unmarked)
                │
                ▼
    [ Confirm Attendance & Lock Session ]
                │
                ▼
    Session Completed & Locked State
```

---

## 2. Recognition Progress UX States

1. `EMPTY`: Session initialized; awaiting faculty capture action.
2. `IMAGE_SELECTED`: Photo thumbnail displayed; faculty confirms submission.
3. `UPLOADING`: Progress bar: *"Uploading image..."*
4. `DETECTING_FACES`: Progress bar: *"Detecting student faces..."*
5. `MATCHING`: Progress bar: *"Matching candidates with class roster..."*
6. `REVIEW`: Faculty candidate verification card:
   - Green card: High confidence match ($d \le 0.45$). Pre-selected.
   - Yellow card: Uncertain match ($0.45 < d \le 0.60$). Unselected by default. Must be manually checked by faculty.
   - Red/Gray card: Unknown face ($d > 0.60$). Unmarked.
7. `CONFIRMING`: Progress bar: *"Saving attendance records..."*
8. `SUCCESS`: Success banner: *"Attendance recorded successfully."*
9. `ERROR`: Human-readable error banner with retry option.
