from fastapi import APIRouter, Depends, HTTPException, status
from app.core.security import get_current_user
from app.core.supabase_client import supabase
from app.models.schemas import ReviewRequest, AlertListResponse, AlertItem

router = APIRouter(prefix="/api", tags=["Alerts"])

@router.get("/alerts", response_model=AlertListResponse)
async def get_alerts(
    status: str = "pending",
    limit: int = 20,
    offset: int = 0,
    household_id: str = None,
    user: dict = Depends(get_current_user)
):
    """
    GET /api/alerts
    Ref: Section 4.2 of design doc
    """
    try:
        query = supabase.table("events").select("*", count="exact").eq("status", status)
        if household_id:
            query = query.eq("household_id", household_id)
        
        # Order by timestamp descending
        query = query.order("timestamp", desc=True)
        
        # Limit and Offset
        query = query.range(offset, offset + limit - 1)
        response = query.execute()
        
        items = []
        for item in (response.data or []):
            items.append(AlertItem(
                id=item.get("id"),
                event_id=item.get("event_id"),
                severity=item.get("severity"),
                confidence=float(item.get("confidence", 0.0)),
                timestamp=item.get("timestamp"),
                duration_sec=item.get("duration_sec"),
                room=item.get("room"),
                clip_path=item.get("clip_path"),
                llm_message=item.get("llm_message"),
                status=item.get("status")
            ))
            
        total = response.count or len(items)
        return AlertListResponse(items=items, total=total)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve alerts: {str(e)}"}}
        )

@router.patch("/alerts/{event_id}/review", status_code=status.HTTP_200_OK)
async def review_alert(
    event_id: str,
    req: ReviewRequest,
    user: dict = Depends(get_current_user)
):
    """
    PATCH /api/alerts/{event_id}/review
    Ref: Section 4.3 of design doc
    """
    user_id = user.get("id")
    try:
        # Check event existence
        event_query = supabase.table("events").select("*").eq("event_id", event_id).execute()
        if not event_query.data:
            # Try UUID match if event_id is uuid string
            event_query = supabase.table("events").select("*").eq("id", event_id).execute()
            if not event_query.data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail={"error": {"code": "EVENT_NOT_FOUND", "message": "Cảnh báo không tồn tại"}}
                )
        
        db_event = event_query.data[0]
        event_uuid = db_event.get("id")

        # 1. Insert alert review
        review_data = {
            "event_id": event_uuid,
            "user_id": user_id,
            "action": req.action,
            "note": req.note,
            "clip_timestamp": req.clip_timestamp
        }
        supabase.table("alert_reviews").insert(review_data).execute()

        # 2. Update event status & cancel escalation
        update_data = {"status": req.action}
        if req.action == "acknowledged":
            update_data["escalate_after"] = None

        supabase.table("events").update(update_data).eq("id", event_uuid).execute()
        return {"status": "ok"}
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to review alert: {str(e)}"}}
        )

@router.get("/events/{event_id}")
async def get_event_detail(
    event_id: str,
    user: dict = Depends(get_current_user)
):
    """
    GET /api/events/{event_id}
    Ref: Section 4.5 of design doc
    """
    try:
        event_query = supabase.table("events").select("*").eq("event_id", event_id).execute()
        if not event_query.data:
            event_query = supabase.table("events").select("*").eq("id", event_id).execute()
            if not event_query.data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail={"error": {"code": "EVENT_NOT_FOUND", "message": "Cảnh báo không tồn tại"}}
                )
        
        event = event_query.data[0]
        clip_path = event.get("clip_path")
        
        # Generate presigned download URL from Supabase Storage
        if clip_path:
            # Strip 'clips/' folder prefix if present for supabase SDK compatibility
            storage_path = clip_path.replace("clips/", "")
            try:
                signed_res = supabase.storage.from_("clips").create_signed_url(storage_path, 300)
                event["clip_url"] = signed_res.get("signedURL") or signed_res.get("url")
            except Exception as e:
                print(f"Failed to generate signed url: {e}")
                event["clip_url"] = f"https://sceygoxizfbbhqwatqhx.supabase.co/storage/v1/object/sign/clips/{storage_path}?token=mock"
        else:
            event["clip_url"] = None

        return event
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve event details: {str(e)}"}}
        )
