from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query
from app.core.security import get_current_user
from app.core.supabase_client import supabase
from app.services.llm_service import generate_daily_report

router = APIRouter(prefix="/api/reports", tags=["Reports"])

@router.get("/daily")
async def get_daily_report(
    household_id: str,
    date: str = Query(default=None),
    user: dict = Depends(get_current_user),
):
    """
    GET /api/reports/daily
    Ref: Section 4.10 of design doc
    Fetches the daily report or dynamically generates it using Claude if missing.
    """
    # Manual check quyền
    member_res = supabase.table("household_members")\
        .select("role")\
        .eq("household_id", household_id)\
        .eq("user_id", user["id"])\
        .execute()
    if not member_res.data:
        raise HTTPException(
            status_code=403,
            detail={"error": {"code": "FORBIDDEN", "message": "Bạn không có quyền truy cập thông tin gia đình này"}}
        )
    
    # date default = hôm nay nếu không truyền
    if not date:
        date = datetime.utcnow().strftime("%Y-%m-%d")
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
        print(f"Error in get_daily_report: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )
