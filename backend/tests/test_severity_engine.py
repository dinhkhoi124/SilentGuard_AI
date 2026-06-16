from datetime import datetime
from app.services.severity_engine import classify_severity, is_suppressed

def test_classify_severity():
    thresholds = {
        "low_max_sec": 30,
        "medium_max_sec": 120,
        "high_max_sec": 300
    }
    
    assert classify_severity(10, thresholds) == "LOW"
    assert classify_severity(29, thresholds) == "LOW"
    assert classify_severity(30, thresholds) == "MEDIUM"
    assert classify_severity(119, thresholds) == "MEDIUM"
    assert classify_severity(120, thresholds) == "HIGH"
    assert classify_severity(299, thresholds) == "HIGH"
    assert classify_severity(300, thresholds) == "CRITICAL"
    assert classify_severity(500, thresholds) == "CRITICAL"

def test_is_suppressed():
    suppress_windows = [
        {"start": "13:00", "end": "15:00", "max_still_sec": 3600}
    ]
    
    # Within window, duration less than max_still_sec
    dt1 = datetime.fromisoformat("2026-06-16T14:00:00")
    assert is_suppressed(dt1, 1800, suppress_windows) is True
    
    # Within window, duration greater than max_still_sec
    assert is_suppressed(dt1, 4000, suppress_windows) is False
    
    # Outside window
    dt2 = datetime.fromisoformat("2026-06-16T16:00:00")
    assert is_suppressed(dt2, 1800, suppress_windows) is False
