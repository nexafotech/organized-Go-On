from datetime import datetime, timezone
from typing import Optional


def normalize_utc_datetime(value: Optional[datetime]) -> Optional[datetime]:
    """
    Safely normalizes any datetime (naive or aware) to a timezone-aware UTC datetime.
    - If None, returns None.
    - If timezone-naive (tzinfo is None), attaches timezone.utc.
    - If timezone-aware, converts it to UTC using astimezone(timezone.utc).
    """
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
