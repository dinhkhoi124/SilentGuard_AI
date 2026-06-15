from fastapi import APIRouter, Depends, status
from app.core.security import get_current_user
from app.models.schemas import ReviewRequest

router = APIRouter(prefix="/api", tags=["Alerts"])

@router.get("/alerts")
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
    # TODO: Fetch alerts from database filtered by household_id
    return {"items": [], "total": 0}

@router.patch("/alerts/{event_id}/review")
async def review_alert(
    event_id: str,
    req: ReviewRequest,
    user: dict = Depends(get_current_user)
):
    """
    PATCH /api/alerts/{event_id}/review
    Ref: Section 4.3 of design doc
    """
    # TODO: Insert review record and update event status
    return {"status": "ok"}

@router.get("/events/{event_id}")
async def get_event_detail(
    event_id: str,
    user: dict = Depends(get_current_user)
):
    """
    GET /api/events/{event_id}
    Ref: Section 4.5 of design doc
    """
    # TODO: Fetch single event details and generate signed URL for clip_path
    return {}
