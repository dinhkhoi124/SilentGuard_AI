from fastapi import APIRouter, Depends, HTTPException, status
from app.core.security import verify_device_key_dependency
from app.core.supabase_client import supabase
from app.models.schemas import EventDetectRequest

router = APIRouter(prefix="/api/events", tags=["Events"])

@router.post("/detect", status_code=status.HTTP_201_CREATED)
async def detect_event(
    req: EventDetectRequest,
    camera: dict = Depends(verify_device_key_dependency)
):
    """
    POST /api/events/detect
    Ref: Section 4.1 of Design Doc (MVP V1)
    Receives fall detection events from edge devices.
    Performs authentication with X-Device-Key, checks the key, and inserts raw event into events table.
    """
    camera_id = camera.get("id")
    household_id = camera.get("household_id")

    # Insert raw event into Supabase `events` table
    # Ref: Section 4.1 Steps 1-3
    event_data = {
        "event_id": req.event_id,
        "household_id": household_id,
        "camera_id": camera_id,
        "event_type": req.event_type,
        "severity": req.severity,
        "confidence": float(req.confidence),
        "timestamp": req.timestamp.isoformat(),
        "duration_sec": req.duration_sec,
        "room": req.room,
        "clip_path": req.clip_path or req.clip_url,
        "status": "pending",
        "model_ver": req.model_ver
    }

    try:
        supabase.table("events").insert(event_data).execute()
    except Exception as e:
        print(f"Database insertion failed: {e}. Running in dev mock fallback.")

    # Step 4: Nếu severity != LOW -> gọi AlertEngine.process(event)
    # Ref: Section 4.1 & Section 6
    # TODO: Implement AlertEngine.process(event) in Sprint tasks.
    if req.severity != "LOW":
        pass

    return {
        "status": "received",
        "event_id": req.event_id
    }
