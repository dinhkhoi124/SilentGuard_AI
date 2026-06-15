from fastapi import APIRouter, Depends
from app.core.security import get_current_user

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])

@router.get("/summary")
async def get_dashboard_summary(user: dict = Depends(get_current_user)):
    """
    GET /api/dashboard/summary
    Ref: Section 4.4 of design doc
    """
    # TODO: Fetch dashboard counts, average response times, and camera status
    return {
        "total_alerts_today": 0,
        "avg_response_time_sec": 0,
        "acknowledged": 0,
        "total": 0,
        "by_severity": { "LOW": 0, "MEDIUM": 0, "HIGH": 0, "CRITICAL": 0 },
        "cameras": []
    }
