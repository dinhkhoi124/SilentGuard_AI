from fastapi import APIRouter, Depends, HTTPException, status
from app.core.security import get_current_user
from app.core.supabase_client import supabase
from app.api.settings import get_user_household_id
from app.services.llm_service import generate_daily_report

router = APIRouter(prefix="/api/reports", tags=["Reports"])

@router.get("/daily")
async def get_daily_report(
    date: str = "2026-06-13",
    user: dict = Depends(get_current_user)
):
    """
    GET /api/reports/daily
    Ref: Section 4.10 of design doc
    Fetches the daily report or dynamically generates it using Claude if missing.
    """
    user_id = user.get("id")
    household_id = await get_user_household_id(user_id)
    try:
        # 1. Try to fetch existing report
        res = supabase.table("daily_reports")\
            .select("*")\
            .eq("household_id", household_id)\
            .eq("report_date", date)\
            .execute()
            
        if res.data:
            return {
                "date": date,
                "summary": res.data[0].get("summary"),
                "events": [] # Can be populated as needed
            }
            
        # 2. Dynamic generation: Fetch all events of the date
        start_ts = f"{date}T00:00:00Z"
        end_ts = f"{date}T23:59:59Z"
        
        events_res = supabase.table("events")\
            .select("*")\
            .eq("household_id", household_id)\
            .gt("timestamp", start_ts)\
            .lt("timestamp", end_ts)\
            .execute()
            
        events = events_res.data or []
        
        # 3. Call LLM Claude Service
        report_text = await generate_daily_report(events)
        
        # 4. Save report in DB
        new_report = {
            "household_id": household_id,
            "report_date": date,
            "summary": report_text
        }
        supabase.table("daily_reports").insert(new_report).execute()
        
        return {
            "date": date,
            "summary": report_text,
            "events": events
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve or generate daily report: {str(e)}"}}
        )
