from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from app.core.security import get_current_user, require_household_role
from app.core.supabase_client import supabase
from app.models.schemas import ReviewRequest, AlertListResponse, AlertItem, FeedbackRequest


router = APIRouter(prefix="/api", tags=["Alerts"])

@router.get("/alerts", response_model=AlertListResponse)
async def get_alerts(
    status: str = "pending",
    limit: int = 20,
    offset: int = 0,
    household_id: str = None,
    user: dict = Depends(get_current_user),
    _member: dict = Depends(require_household_role(owner_only=False))
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
        print(f"Error in get_alerts: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
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
        
        # Verify user is member of the household for this event
        member_check = supabase.table("household_members").select("*").eq("household_id", db_event.get("household_id")).eq("user_id", user_id).execute()
        if not member_check.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Bạn không có quyền truy cập cảnh báo của hộ gia đình này"}}
            )
            
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
        print(f"Error in review_alert: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )

@router.get("/events/history")
async def get_event_history(
    household_id: str,
    severity: Optional[str] = Query(default=None),
    room: Optional[str] = Query(default=None),
    from_date: Optional[str] = Query(default=None),
    to_date: Optional[str] = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    user: dict = Depends(get_current_user)
):
    """
    GET /api/events/history
    Retrieves history of events for a household with optional filters and pagination.
    """
    user_id = user.get("id")
    # Verify user is a member of the requested household
    try:
        member_res = supabase.table("household_members")\
            .select("role")\
            .eq("household_id", household_id)\
            .eq("user_id", user_id)\
            .execute()
        if not member_res.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Bạn không có quyền truy cập thông tin gia đình này"}}
            )
            
        # Build query
        query = supabase.table("events").select("*", count="exact").eq("household_id", household_id)
        
        if severity:
            query = query.eq("severity", severity)
        if room:
            query = query.eq("room", room)
        if from_date:
            query = query.gte("timestamp", from_date)
        if to_date:
            query = query.lte("timestamp", to_date)
            
        # Sort timestamp DESC
        query = query.order("timestamp", desc=True)
        
        # Pagination
        offset = (page - 1) * page_size
        query = query.range(offset, offset + page_size - 1)
        
        res = query.execute()
        
        return {
            "items": res.data or [],
            "total": res.count or 0,
            "page": page,
            "page_size": page_size
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in get_event_history: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )

@router.post("/events/{event_id}/feedback", status_code=status.HTTP_200_OK)
async def post_event_feedback(
    event_id: str,
    req: FeedbackRequest,
    user: dict = Depends(get_current_user)
):
    """
    POST /api/events/{event_id}/feedback
    """
    try:
        res = supabase.table("events")\
            .select("id, household_id, camera_id, cameras(serial_number)")\
            .eq("event_id", event_id).execute()
        if not res.data:
            res = supabase.table("events")\
                .select("id, household_id, camera_id, cameras(serial_number)")\
                .eq("id", event_id).execute()
            if not res.data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail={"error": {"code": "EVENT_NOT_FOUND", "message": "Cảnh báo không tồn tại"}}
                )
        
        event_data = res.data[0]
        event_uuid = event_data.get("id")
        household_id = event_data.get("household_id")
        
        member_res = supabase.table("household_members")\
            .select("role")\
            .eq("household_id", household_id)\
            .eq("user_id", user["id"])\
            .execute()
            
        if not member_res.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Bạn không có quyền truy cập cảnh báo của hộ gia đình này"}}
            )
            
        feedback_data = {
            "event_id": event_uuid,
            "household_id": household_id,
            "submitted_by": user["id"],
            "label": req.label,
            "note": req.note,
            "camera_serial": req.camera_serial or (
                event_data.get("cameras") or {}
            ).get("serial_number")
        }
        
        insert_res = supabase.table("event_feedback").upsert(
            feedback_data,
            on_conflict="event_id,submitted_by"
        ).select("id").execute()
        if not insert_res.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "DATABASE_ERROR", "message": "Không thể lưu phản hồi"}}
            )
            
        return {
            "status": "received",
            "feedback_id": insert_res.data[0]["id"]
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in post_event_feedback: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
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
        
        # Verify user is member of the household for this event
        user_id = user.get("id")
        member_check = supabase.table("household_members").select("*").eq("household_id", event.get("household_id")).eq("user_id", user_id).execute()
        if not member_check.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Bạn không có quyền truy cập cảnh báo của hộ gia đình này"}}
            )
            
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
        print(f"Error in get_event_detail: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )
