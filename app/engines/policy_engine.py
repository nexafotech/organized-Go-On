"""
M4: AttendancePolicyEngine

Centralized, configurable attendance calculation engine.
All attendance percentage calculations MUST go through this engine.
Do NOT hard-code 75%, OD=PRESENT, or any policy values in business logic.
All rules come from the active AttendancePolicy in the database.
"""

from datetime import datetime
import math
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session

from app.models.policy import AttendancePolicy, SystemSetting
from app.models.attendance import AttendanceRecord, ClassSession, AttendanceStatus, SessionStatus
from app.models.academic import TimetableEntry, FacultyAssignment, ClassSection, Subject, Period
from app.models.student import Student


def get_active_policy(db: Session) -> AttendancePolicy:
    """
    Returns the active AttendancePolicy from DB.
    If none exists, creates and returns sensible defaults.
    """
    policy = db.query(AttendancePolicy).filter(AttendancePolicy.is_active == True).first()
    if policy is None:
        # Auto-create default policy on first use
        policy = AttendancePolicy(
            calculation_unit="PERIOD",
            minimum_percentage=75.0,
            warning_threshold=75.0,
            critical_threshold=65.0,
            unmarked_behavior="NOT_ENTERED",
            exclude_no_class=True,
            exclude_suspended=True,
            exclude_timetable_not_set=True,
            od_enabled=True,
            od_faculty_can_mark=True,
            od_require_reason=False,
            od_require_approval=False,
            od_allow_retroactive=False,
            od_allow_multiple_periods=True,
            od_calculation_mode="COUNT_AS_PRESENT",
            leave_calculation_mode="ABSENT",
            calculation_mode="RECORD_BASED",
            period_present_gain=0.25,
            period_absent_loss=0.25,
            class_present_gain=1.00,
            class_absent_loss=1.00,
            day_present_gain=1.00,
            day_absent_loss=1.00,
            description="Default policy (auto-created)",
            is_active=True,
        )
        db.add(policy)
        db.commit()
        db.refresh(policy)
    else:
        # Self-healing: repair corrupted, empty, or invalid calculation_mode
        if policy.calculation_mode not in ("RECORD_BASED", "IMPACT_BASED"):
            policy.calculation_mode = "RECORD_BASED"
            db.commit()
            db.refresh(policy)
    return policy


def get_system_setting(db: Session, key: str, default: str = "") -> str:
    """Get a system setting value by key, returning default if not set."""
    setting = db.query(SystemSetting).filter(SystemSetting.key == key).first()
    if setting is None:
        return default
    return setting.value


def _status_counts(records: List[AttendanceRecord], policy: AttendancePolicy) -> Dict[str, int]:
    """
    Processes a list of attendance records and returns aggregated counts
    according to the active policy.
    """
    total = 0
    present = 0
    absent = 0
    od = 0
    uncertain = 0
    not_entered = 0
    excluded = 0

    for rec in records:
        s = rec.status

        # Handle statuses that are excluded from denominator
        if s == AttendanceStatus.NO_CLASS and policy.exclude_no_class:
            excluded += 1
            continue
        if s == AttendanceStatus.SUSPENDED and policy.exclude_suspended:
            excluded += 1
            continue
        if s == AttendanceStatus.NOT_ENTERED:
            ub = policy.unmarked_behavior
            if ub == "PRESENT":
                total += 1
                present += 1
            elif ub == "ABSENT":
                total += 1
                absent += 1
            elif ub == "EXCLUDED":
                excluded += 1
            else:  # NOT_ENTERED — keep separate
                not_entered += 1
                total += 1
            continue

        if s == AttendanceStatus.OD:
            od += 1
            mode = policy.od_calculation_mode
            if mode == "COUNT_AS_PRESENT":
                total += 1
                present += 1  # OD counts as present in percentage
            elif mode == "EXCLUDE_FROM_DENOMINATOR":
                excluded += 1
            else:  # COUNT_SEPARATELY
                total += 1  # counts toward denominator but not present
            continue

        if s == AttendanceStatus.PRESENT:
            total += 1
            present += 1
        elif s == AttendanceStatus.ABSENT:
            total += 1
            absent += 1
        elif s == AttendanceStatus.UNCERTAIN:
            total += 1
            uncertain += 1

    return {
        "total": total,
        "present": present,
        "absent": absent,
        "od": od,
        "uncertain": uncertain,
        "not_entered": not_entered,
        "excluded": excluded,
    }


def _safe_percentage(present: int, total: int) -> float:
    """Calculate percentage safely, returning 0.0 if total is 0."""
    if total == 0:
        return 0.0
    return round((present / total) * 100, 2)


def derive_daily_half_day_status(
    records: List[Any],
    policy: AttendancePolicy,
    scheduled_morning_count: int = 4,
    scheduled_afternoon_count: int = 3
) -> Dict[str, Any]:
    """
    Derives morning, afternoon, and overall daily attendance status.
    - Morning: P1, P2, P3, P4 (applicable count: scheduled_morning_count, default 4)
    - Lunch Break: 12:50 PM - 01:40 PM (excluded from calculation & denominator)
    - Afternoon: P5, P6, P7 (applicable count: scheduled_afternoon_count, default 3)
    """
    morning_records = []
    afternoon_records = []

    for r in records:
        pnum = None
        status = None
        od_reason = None
        if isinstance(r, dict):
            pnum = r.get("period_number")
            status = r.get("status")
            od_reason = r.get("od_reason")
        elif hasattr(r, "session") and r.session and r.session.timetable_entry and r.session.timetable_entry.period:
            pnum = r.session.timetable_entry.period.period_number
            status = r.status.value if hasattr(r.status, "value") else str(r.status)
            od_reason = getattr(r, "od_reason", None)
        elif hasattr(r, "period_number"):
            pnum = getattr(r, "period_number")
            status = r.status.value if hasattr(r.status, "value") else str(r.status)
            od_reason = getattr(r, "od_reason", None)

        if pnum in (1, 2, 3, 4):
            morning_records.append({"period_number": pnum, "status": status, "od_reason": od_reason})
        elif pnum in (5, 6, 7):
            afternoon_records.append({"period_number": pnum, "status": status, "od_reason": od_reason})

    def eval_half(half_recs, scheduled_count):
        present = 0
        absent = 0
        od = 0
        not_entered = 0
        for hr in half_recs:
            st = hr["status"]
            if st == "PRESENT":
                present += 1
            elif st == "OD":
                od += 1
                if policy.od_calculation_mode == "COUNT_AS_PRESENT":
                    present += 1
            elif st == "ABSENT":
                absent += 1
            else:
                not_entered += 1

        total_marked = present + absent + (od if policy.od_calculation_mode != "COUNT_AS_PRESENT" else 0)
        
        # Threshold: at least 2 periods present (or >= 50% of scheduled valid periods)
        threshold = max(1, math.ceil(scheduled_count / 2.0))
        if total_marked == 0:
            status_str = "NOT ENTERED"
        elif od > 0 and (present - (od if policy.od_calculation_mode == "COUNT_AS_PRESENT" else 0)) == 0 and absent == 0:
            status_str = "OD"
        elif present >= threshold:
            status_str = "PRESENT"
        elif present == 0 and absent > 0:
            status_str = "ABSENT"
        else:
            status_str = "PARTIAL"

        return {
            "marked_present": present,
            "marked_absent": absent,
            "marked_od": od,
            "applicable_periods": scheduled_count,
            "status": status_str,
            "text": f"{present}/{scheduled_count} applicable periods marked Present"
        }

    m_eval = eval_half(morning_records, scheduled_morning_count)
    a_eval = eval_half(afternoon_records, scheduled_afternoon_count)

    # Overall Daily Result
    m_stat = m_eval["status"]
    a_stat = a_eval["status"]

    if m_stat == "NOT ENTERED" and a_stat == "NOT ENTERED":
        daily_result = "NOT ENTERED"
    elif m_stat == "OD" and a_stat in ("OD", "NOT ENTERED"):
        daily_result = "OD"
    elif m_stat == "PRESENT" and a_stat == "PRESENT":
        daily_result = "FULL DAY PRESENT"
    elif m_stat == "ABSENT" and a_stat == "ABSENT":
        daily_result = "FULL DAY ABSENT"
    elif (m_stat == "PRESENT" and a_stat == "ABSENT") or (m_stat == "ABSENT" and a_stat == "PRESENT"):
        daily_result = "HALF-DAY PRESENT"
    elif m_stat == "PRESENT" and a_stat in ("NOT ENTERED", "PARTIAL"):
        daily_result = "HALF-DAY PRESENT"
    elif a_stat == "PRESENT" and m_stat in ("NOT ENTERED", "PARTIAL"):
        daily_result = "HALF-DAY PRESENT"
    elif m_stat == "ABSENT" and a_stat == "NOT ENTERED":
        daily_result = "HALF-DAY ABSENT"
    elif a_stat == "ABSENT" and m_stat == "NOT ENTERED":
        daily_result = "HALF-DAY ABSENT"
    else:
        daily_result = "PARTIAL / MIXED"

    return {
        "morning": {
            "periods": "P1-P4",
            "present_count": m_eval["marked_present"],
            "applicable_count": scheduled_morning_count,
            "summary_text": m_eval["text"],
            "status": m_stat,
        },
        "afternoon": {
            "periods": "P5-P7",
            "present_count": a_eval["marked_present"],
            "applicable_count": scheduled_afternoon_count,
            "summary_text": a_eval["text"],
            "status": a_stat,
        },
        "lunch": {
            "interval": "12:50 PM - 01:40 PM",
            "status": "Not counted",
            "counted": False
        },
        "daily_result": daily_result
    }


def _calculate_impact_based_percentage(
    records: List[AttendanceRecord],
    policy: AttendancePolicy,
    db: Optional[Session] = None
) -> float:
    """
    Calculates attendance percentage using policy-configured impact values.
    Hierarchical evaluation: Day level -> Session level -> Period level.
    Prevents double-counting across levels.
    Baseline starting percentage is 100.0%.
    """
    if not records:
        return 0.0

    # Filter out excluded records
    valid_records = []
    for rec in records:
        s = rec.status
        if s == AttendanceStatus.NO_CLASS and policy.exclude_no_class:
            continue
        if s == AttendanceStatus.SUSPENDED and policy.exclude_suspended:
            continue
        if s == AttendanceStatus.NOT_ENTERED and policy.unmarked_behavior == "EXCLUDED":
            continue
        if s == AttendanceStatus.OD and policy.od_calculation_mode == "EXCLUDE_FROM_DENOMINATOR":
            continue
        valid_records.append(rec)

    if not valid_records:
        return 0.0

    # Group valid records by date
    records_by_date: Dict[str, List[AttendanceRecord]] = {}
    for rec in valid_records:
        d = rec.session.date if rec.session else "UNKNOWN"
        if d not in records_by_date:
            records_by_date[d] = []
        records_by_date[d].append(rec)

    def is_present(rec: AttendanceRecord) -> bool:
        if rec.status == AttendanceStatus.PRESENT:
            return True
        if rec.status == AttendanceStatus.OD and policy.od_calculation_mode == "COUNT_AS_PRESENT":
            return True
        if rec.status == AttendanceStatus.NOT_ENTERED and policy.unmarked_behavior == "PRESENT":
            return True
        return False

    def is_absent(rec: AttendanceRecord) -> bool:
        if rec.status == AttendanceStatus.ABSENT:
            return True
        if rec.status == AttendanceStatus.NOT_ENTERED and policy.unmarked_behavior == "ABSENT":
            return True
        return False

    # Retrieve student's class_id if available to check timetable scheduled periods per day
    class_id = None
    first_rec = valid_records[0]
    if hasattr(first_rec, "student") and first_rec.student:
        class_id = first_rec.student.class_id
    elif db and hasattr(first_rec, "student_id"):
        st = db.query(Student).filter(Student.id == first_rec.student_id).first()
        if st:
            class_id = st.class_id

    current_pct = 100.0

    # Evaluate chronologically by date
    sorted_dates = sorted(records_by_date.keys())
    for d in sorted_dates:
        day_recs = records_by_date[d]
        if not day_recs:
            continue

        # Determine scheduled period count for date d from timetable / session data
        scheduled_count = len(day_recs)
        if db and class_id and d != "UNKNOWN":
            try:
                dt_obj = datetime.strptime(d, "%Y-%m-%d")
                dow = dt_obj.strftime("%A")
                tt_count = db.query(TimetableEntry).join(FacultyAssignment).filter(
                    FacultyAssignment.class_id == class_id,
                    TimetableEntry.day_of_week == dow
                ).count()
                if tt_count > 0:
                    scheduled_count = tt_count
            except Exception:
                pass

        all_day_present = all(is_present(r) for r in day_recs) and len(day_recs) >= scheduled_count
        all_day_absent = all(is_absent(r) for r in day_recs) and len(day_recs) >= scheduled_count

        day_impact = 0.0

        if all_day_present:
            day_impact += policy.day_present_gain
        elif all_day_absent:
            day_impact -= policy.day_absent_loss
        else:
            # Partial Day — evaluate Session / Class level and Period level
            recs_by_session: Dict[int, List[AttendanceRecord]] = {}
            for r in day_recs:
                sid = r.session_id
                if sid not in recs_by_session:
                    recs_by_session[sid] = []
                recs_by_session[sid].append(r)

            for sid, sess_recs in recs_by_session.items():
                all_sess_present = all(is_present(r) for r in sess_recs)
                all_sess_absent = all(is_absent(r) for r in sess_recs)

                if all_sess_present and len(sess_recs) > 1:
                    day_impact += policy.class_present_gain
                elif all_sess_absent and len(sess_recs) > 1:
                    day_impact -= policy.class_absent_loss
                else:
                    for r in sess_recs:
                        if is_present(r):
                            day_impact += policy.period_present_gain
                        elif is_absent(r):
                            day_impact -= policy.period_absent_loss

        # Apply day impact to running percentage and clamp between 0.0 and 100.0
        current_pct = max(0.0, min(100.0, current_pct + day_impact))

    return round(current_pct, 2)


class AttendancePolicyEngine:
    """
    Centralized attendance calculation engine.
    Use this class for ALL attendance percentage calculations.
    """

    def __init__(self, db: Session):
        self.db = db
        self.policy = get_active_policy(db)

    def calculate_student_attendance(self, student_id: int) -> Dict[str, Any]:
        """
        Calculate overall attendance for a student across all sessions.
        """
        records = (
            self.db.query(AttendanceRecord)
            .filter(AttendanceRecord.student_id == student_id)
            .all()
        )

        counts = _status_counts(records, self.policy)

        # Selected calculation mode
        calc_mode = getattr(self.policy, "calculation_mode", "RECORD_BASED")
        if calc_mode == "IMPACT_BASED":
            pct = _calculate_impact_based_percentage(records, self.policy, db=self.db)
        else:
            pct = _safe_percentage(counts["present"], counts["total"])

        attendance_status = "NO_DATA"
        if counts["total"] > 0 or len(records) > 0:
            if pct < self.policy.critical_threshold:
                attendance_status = "CRITICAL"
            elif pct < self.policy.warning_threshold:
                attendance_status = "WARNING"
            else:
                attendance_status = "OK"

        # Daily half-day derivation aggregations
        records_by_date: Dict[str, List[AttendanceRecord]] = {}
        for r in records:
            d = r.session.date if r.session else None
            if d:
                if d not in records_by_date:
                    records_by_date[d] = []
                records_by_date[d].append(r)

        half_day_present = 0
        half_day_absent = 0
        full_day_present = 0
        full_day_absent = 0

        for d, d_recs in records_by_date.items():
            d_summary = derive_daily_half_day_status(d_recs, self.policy)
            res = d_summary["daily_result"]
            if res == "FULL DAY PRESENT":
                full_day_present += 1
            elif res == "FULL DAY ABSENT":
                full_day_absent += 1
            elif res == "HALF-DAY PRESENT":
                half_day_present += 1
            elif res == "HALF-DAY ABSENT":
                half_day_absent += 1

        # Future recovery & missable calculations
        recovery = self.calculate_future_recovery(student_id, pct, counts)

        return {
            "student_id": student_id,
            **counts,
            "percentage": pct,
            "calculation_mode": calc_mode,
            "status": attendance_status,
            "half_day_present": half_day_present,
            "half_day_absent": half_day_absent,
            "full_day_present": full_day_present,
            "full_day_absent": full_day_absent,
            "minimum_required": self.policy.minimum_percentage,
            "warning_threshold": self.policy.warning_threshold,
            "critical_threshold": self.policy.critical_threshold,
            **recovery,
        }

    def calculate_future_recovery(self, student_id: int, current_pct: float, counts: Dict[str, int]) -> Dict[str, Any]:
        """
        Calculates required future classes to reach minimum percentage (if below minimum)
        or missable future classes (if at or above minimum).
        """
        min_req = self.policy.minimum_percentage
        calc_mode = getattr(self.policy, "calculation_mode", "RECORD_BASED")
        present = counts["present"]
        total = counts["total"]

        below_minimum = (current_pct < min_req) and (total > 0)
        alert_message = "Attendance below required minimum." if below_minimum else None

        required_future_classes = 0
        estimated_working_days = 0
        missable_future_classes = 0

        if below_minimum:
            if calc_mode == "IMPACT_BASED":
                gain = getattr(self.policy, "period_present_gain", 0.25)
                if gain <= 0:
                    gain = 1.0
                diff = min_req - current_pct
                required_future_classes = math.ceil(diff / gain)
            else:  # RECORD_BASED
                # Formula: (present + x) / (total + x) >= min_req / 100
                # x * (100 - min_req) >= min_req * total - 100 * present
                if min_req >= 100.0:
                    required_future_classes = 999  # cannot reach if < 100
                else:
                    numerator = (min_req * total) - (100.0 * present)
                    denominator = 100.0 - min_req
                    if numerator <= 0:
                        required_future_classes = 0
                    else:
                        required_future_classes = math.ceil(numerator / denominator)

            # Estimate working days based on student's timetable
            student = self.db.query(Student).filter(Student.id == student_id).first()
            if student and student.class_id:
                tt_entries = (
                    self.db.query(TimetableEntry)
                    .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
                    .filter(FacultyAssignment.class_id == student.class_id)
                    .all()
                )
                if tt_entries:
                    unique_days = len(set(e.day_of_week for e in tt_entries))
                    total_slots = len(tt_entries)
                    avg_per_day = total_slots / max(1, unique_days)
                    estimated_working_days = math.ceil(required_future_classes / max(1.0, avg_per_day))
                else:
                    estimated_working_days = required_future_classes
            else:
                estimated_working_days = required_future_classes

        else:  # At or above minimum
            if total > 0:
                if calc_mode == "IMPACT_BASED":
                    loss = getattr(self.policy, "period_absent_loss", 0.25)
                    if loss <= 0:
                        loss = 1.0
                    margin = current_pct - min_req
                    missable_future_classes = math.floor(margin / loss)
                else:  # RECORD_BASED
                    # Formula: present / (total + y) >= min_req / 100
                    # y * min_req <= 100 * present - min_req * total
                    if min_req <= 0:
                        missable_future_classes = 999
                    else:
                        numerator = (100.0 * present) - (min_req * total)
                        if numerator < 0:
                            missable_future_classes = 0
                        else:
                            missable_future_classes = math.floor(numerator / min_req)

        return {
            "below_minimum": below_minimum,
            "alert_message": alert_message,
            "required_future_classes": max(0, required_future_classes),
            "estimated_working_days": max(0, estimated_working_days),
            "missable_future_classes": max(0, missable_future_classes),
        }

    def calculate_subject_attendance(self, student_id: int, subject_id: int) -> Dict[str, Any]:
        """
        Calculate attendance for a specific subject.
        """
        records = (
            self.db.query(AttendanceRecord)
            .join(ClassSession, AttendanceRecord.session_id == ClassSession.id)
            .join(TimetableEntry, ClassSession.timetable_entry_id == TimetableEntry.id)
            .join(FacultyAssignment, TimetableEntry.assignment_id == FacultyAssignment.id)
            .filter(
                AttendanceRecord.student_id == student_id,
                FacultyAssignment.subject_id == subject_id,
            )
            .all()
        )

        counts = _status_counts(records, self.policy)
        calc_mode = getattr(self.policy, "calculation_mode", "RECORD_BASED")
        if calc_mode == "IMPACT_BASED":
            pct = _calculate_impact_based_percentage(records, self.policy)
        else:
            pct = _safe_percentage(counts["present"], counts["total"])

        return {
            "student_id": student_id,
            "subject_id": subject_id,
            **counts,
            "percentage": pct,
        }

    def calculate_all_subjects_attendance(self, student_id: int) -> List[Dict[str, Any]]:
        """
        Returns subject-wise attendance breakdown for a student.
        """
        student = self.db.query(Student).filter(Student.id == student_id).first()
        if not student or not student.class_id:
            return []

        assignments = (
            self.db.query(FacultyAssignment)
            .filter(FacultyAssignment.class_id == student.class_id)
            .all()
        )

        seen_subjects = set()
        results = []
        for assign in assignments:
            subj = assign.subject
            if subj and subj.id not in seen_subjects:
                seen_subjects.add(subj.id)
                subject_data = self.calculate_subject_attendance(student_id, subj.id)
                subject_data["subject_code"] = subj.code
                subject_data["subject_name"] = subj.name
                subject_data["subject_id"] = subj.id
                results.append(subject_data)

        return results

    def calculate_period_attendance(self, student_id: int) -> List[Dict[str, Any]]:
        """
        Returns period-level attendance summary grouped by period_number across all sessions.
        """
        records = (
            self.db.query(AttendanceRecord)
            .join(ClassSession, AttendanceRecord.session_id == ClassSession.id)
            .filter(AttendanceRecord.student_id == student_id)
            .all()
        )

        period_map: Dict[int, Dict[str, Any]] = {}

        for rec in records:
            session = rec.session
            tt = session.timetable_entry if session else None
            period = tt.period if tt else None
            if not period:
                continue

            p_num = period.period_number
            if p_num not in period_map:
                period_map[p_num] = {
                    "period_number": p_num,
                    "period_name": period.name,
                    "records": [],
                }
            period_map[p_num]["records"].append(rec)

        results = []
        calc_mode = getattr(self.policy, "calculation_mode", "RECORD_BASED")

        for p_num in sorted(period_map.keys()):
            p_data = period_map[p_num]
            p_recs = p_data["records"]
            counts = _status_counts(p_recs, self.policy)
            if calc_mode == "IMPACT_BASED":
                pct = _calculate_impact_based_percentage(p_recs, self.policy)
            else:
                pct = _safe_percentage(counts["present"], counts["total"])

            results.append({
                "period_number": p_num,
                "period_name": p_data["period_name"],
                "total": counts["total"],
                "present": counts["present"],
                "absent": counts["absent"],
                "od": counts["od"],
                "percentage": pct,
            })

        return results

    def get_date_wise_attendance(self, student_id: int) -> List[Dict[str, Any]]:
        """
        Returns date-wise attendance with period-wise breakdown.
        """
        records = (
            self.db.query(AttendanceRecord)
            .join(ClassSession, AttendanceRecord.session_id == ClassSession.id)
            .filter(AttendanceRecord.student_id == student_id)
            .order_by(ClassSession.date.asc())
            .all()
        )

        date_map: Dict[str, Dict] = {}
        for rec in records:
            session = rec.session
            date_str = session.date
            tt = session.timetable_entry
            assign = tt.assignment if tt else None
            period = tt.period if tt else None
            subj = assign.subject if assign else None

            if date_str not in date_map:
                date_map[date_str] = {"date": date_str, "periods": []}

            date_map[date_str]["periods"].append({
                "period_number": period.period_number if period else None,
                "period_name": period.name if period else None,
                "subject_code": subj.code if subj else None,
                "subject_name": subj.name if subj else None,
                "status": rec.status.value,
                "od_reason": rec.od_reason,
                "session_id": session.id,
            })

        result = []
        for date_str in sorted(date_map.keys()):
            entry = date_map[date_str]
            entry["periods"].sort(key=lambda p: (p["period_number"] or 0))
            
            # Derive daily half-day status using authoritative policy
            day_derived = derive_daily_half_day_status(entry["periods"], self.policy)
            entry["morning"] = day_derived["morning"]
            entry["afternoon"] = day_derived["afternoon"]
            entry["lunch"] = day_derived["lunch"]
            entry["morning_status"] = day_derived["morning"]["status"]
            entry["afternoon_status"] = day_derived["afternoon"]["status"]
            entry["daily_result"] = day_derived["daily_result"]
            entry["lunch_interval"] = "12:50 PM - 01:40 PM (Not Counted)"
            result.append(entry)

        return result
