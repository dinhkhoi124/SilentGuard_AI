from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime, timezone, time
from app.core.security import get_current_user
from app.core.supabase_client import supabase
from app.models.schemas import DashboardSummaryResponse

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])

@router.get("/summary", response_model=DashboardSummaryResponse)
async def get_dashboard_summary(user: dict = Depends(get_current_user)):
    """
    GET /api/dashboard/summary
    Ref: Section 4.4 of design doc
    """
    try:
        # Define time window for today (UTC)
        today_start = datetime.combine(datetime.now(timezone.utc).date(), time.min).isoformat()
        
        # 1. Fetch alerts for today
        events_res = supabase.table("events").select("*").gt("created_at", today_start).execute()
        events = events_res.data or []
        
        total = len(events)
        total_alerts_today = len([e for e in events if e.get("severity") in ("MEDIUM", "HIGH", "CRITICAL")])
        acknowledged = len([e for e in events if e.get("status") == "acknowledged"])
        
        by_severity = { "LOW": 0, "MEDIUM": 0, "HIGH": 0, "CRITICAL": 0 }
        for e in events:
            sev = e.get("severity")
            if sev in by_severity:
                by_severity[sev] += 1
                
        # 2. Fetch cameras status
        cameras_res = supabase.table("cameras").select("*").execute()
        cameras = []
        for cam in (cameras_res.data or []):
            cameras.append({
                "name": cam.get("name", "Camera"),
                "status": cam.get("status", "unknown"),
                "fps": cam.get("fps", 15)
            })

        # Calculate mock response time for MVP
        avg_response_time = 42 if acknowledged > 0 else 0

        return DashboardSummaryResponse(
            total_alerts_today=total_alerts_today,
            avg_response_time_sec=avg_response_time,
            acknowledged=acknowledged,
            total=total,
            by_severity=by_severity,
            cameras=cameras
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to compute dashboard stats: {str(e)}"}}
        )
