from datetime import datetime, time

def classify_severity(duration_sec: int, thresholds: dict) -> str:
    """
    Classify event severity based on duration_sec and thresholds.
    Ref: Section 5 Severity Engine
    """
    if duration_sec < (thresholds.get("low_max_sec") or 30):
        return "LOW"
    elif duration_sec < (thresholds.get("medium_max_sec") or 120):
        return "MEDIUM"
    elif duration_sec < (thresholds.get("high_max_sec") or 300):
        return "HIGH"
    else:
        return "CRITICAL"

def _within_window(dt: datetime, start_str: str, end_str: str) -> bool:
    """
    Helper to check if datetime time matches HH:MM window. Supports overnight windows.
    """
    try:
        sh, sm = map(int, start_str.split(":"))
        eh, em = map(int, end_str.split(":"))
        start_time = time(sh, sm)
        end_time = time(eh, em)
        
        current_time = dt.time()
        
        if start_time <= end_time:
            return start_time <= current_time <= end_time
        else:
            # Handle overnight window (e.g., 22:00 to 06:00)
            return current_time >= start_time or current_time <= end_time
    except Exception as e:
        print(f"Error parsing suppress window time: {e}")
        return False

def is_suppressed(timestamp: datetime, duration_sec: int, suppress_windows: list) -> bool:
    """
    Check if event is suppressed during specific windows.
    Ref: Section 5 Severity Engine
    """
    for w in (suppress_windows or []):
        start = w.get("start")
        end = w.get("end")
        max_still_sec = w.get("max_still_sec")
        if start and end and max_still_sec is not None:
            if _within_window(timestamp, start, end) and duration_sec < max_still_sec:
                return True
    return False
