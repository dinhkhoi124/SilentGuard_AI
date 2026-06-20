import uuid
import secrets
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks, Form, UploadFile, File, Header
from app.core.security import verify_device_key_dependency, get_current_user, require_household_role
from app.core.supabase_client import supabase
from app.models.schemas import EventDetectRequest
from app.services.alert_engine import process_event

router = APIRouter(prefix="/api/events", tags=["Events"])

@router.post("/upload-video", status_code=status.HTTP_201_CREATED)
async def upload_video(
    background_tasks: BackgroundTasks,
    household_id: str = Form(...),
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    """
    POST /api/events/upload-video
    Uploads a video to Supabase Storage and inserts a record into video_uploads.
    Manually verifies that the user belongs to the requested household.
    """
    # Verify access to the requested household manually
    user_id = current_user.get("id")
    try:
        res = supabase.table("household_members")\
            .select("*")\
            .eq("household_id", household_id)\
            .eq("user_id", user_id)\
            .execute()
        if not res.data or len(res.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Bạn không có quyền truy cập thông tin gia đình này"}}
            )
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Database verification error: {str(e)}"}}
        )

    filename = file.filename
    unique_id = uuid.uuid4()
    storage_path = f"videos/{household_id}/{unique_id}_{filename}"
    
    try:
        # Read file content
        file_bytes = await file.read()
        
        # Upload to Supabase Storage 'clips' bucket
        supabase.storage.from_("clips").upload(
            path=storage_path,
            file=file_bytes,
            file_options={"content-type": file.content_type}
        )
        
        # Create a signed URL valid for 1 year (or similar long duration for demo)
        # 31536000 seconds = 1 year
        signed_res = supabase.storage.from_("clips").create_signed_url(storage_path, 31536000)
        video_url = signed_res.get("signedURL") or signed_res.get("signed_url")
        if not video_url:
            raise Exception("Failed to obtain signed URL")
            
    except Exception as e:
        print(f"File upload or signing failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "UPLOAD_ERROR", "message": f"Failed to upload/sign video file: {str(e)}"}}
        )
        
    upload_token = f"vid_{secrets.token_urlsafe(32)}"
    
    upload_data = {
        "household_id": household_id,
        "uploaded_by": current_user.get("id"),
        "storage_path": storage_path,
        "video_url": video_url,
        "upload_token": upload_token,
        "status": "pending"
    }
    
    try:
        db_res = supabase.table("video_uploads").insert(upload_data).select().execute()
        if not db_res.data:
            raise Exception("No data returned from DB insert")
        inserted = db_res.data[0]
    except Exception as e:
        print(f"Database insertion for video_uploads failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to save video upload to database: {str(e)}"}}
        )
        
    return {
        "upload_id": inserted["id"],
        "video_url": video_url,
        "upload_token": upload_token
    }

@router.post("/detect", status_code=status.HTTP_201_CREATED)
async def detect_event(
    req: EventDetectRequest,
    background_tasks: BackgroundTasks,
    x_device_key: str = Header(None, alias="X-Device-Key"),
    x_upload_token: str = Header(None, alias="X-Upload-Token")
):
    """
    POST /api/events/detect
    Receives fall detection events. Supports either X-Device-Key or X-Upload-Token authentication.
    """
    camera_id = None
    household_id = None
    source = "camera"
    video_upload_record = None

    if x_device_key:
        # Standard camera auth flow
        camera = await verify_device_key_dependency(x_device_key)
        camera_id = camera.get("id")
        household_id = camera.get("household_id")
        source = "camera"
    elif x_upload_token:
        # Video upload auth flow
        try:
            res = supabase.table("video_uploads").select("*").eq("upload_token", x_upload_token).execute()
            if not res.data or res.data[0].get("status") != "pending":
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail={"error": {"code": "UNAUTHORIZED", "message": "Invalid or already processed upload token"}}
                )
            video_upload_record = res.data[0]
            household_id = video_upload_record.get("household_id")
            camera_id = None
            source = "video_upload"
        except HTTPException as he:
            raise he
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={"error": {"code": "UNAUTHORIZED", "message": "Failed to authenticate upload token"}}
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHORIZED", "message": "Missing X-Device-Key or X-Upload-Token header"}}
        )

    # Force severity to HIGH and set default duration_sec to 999 if video upload source
    if source == "video_upload":
        req.severity = "HIGH"
        req.duration_sec = 999

    # Insert raw event into Supabase `events` table
    event_data = {
        "event_id": req.event_id,
        "household_id": household_id,
        "camera_id": camera_id,
        "source": source,
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
        res = supabase.table("events").insert(event_data).select().execute()
        if res.data and len(res.data) > 0:
            inserted_event = res.data[0]
        else:
            inserted_event = event_data
    except Exception as e:
        if "23505" in str(e) or "unique" in str(e).lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": {"code": "DUPLICATE_EVENT", "message": f"Event {req.event_id} đã tồn tại"}}
            )
        print(f"Database insertion failed: {e}")
        from app.core.config import settings
        if settings.APP_ENV == "production":
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to save event to database: {str(e)}"}}
            )
        inserted_event = event_data

    # If processed from a video upload, update status & link event_id
    if source == "video_upload" and video_upload_record:
        try:
            event_uuid = inserted_event.get("id")
            if event_uuid:
                supabase.table("video_uploads").update({
                    "status": "processed",
                    "event_id": event_uuid
                }).eq("id", video_upload_record["id"]).execute()
        except Exception as e:
            print(f"Failed to update video_uploads record: {e}")

    # Step 4: Nếu severity != LOW -> gọi AlertEngine.process(event)
    if req.severity != "LOW":
        background_tasks.add_task(process_event, inserted_event)

    return {
        "status": "received",
        "event_id": req.event_id
    }

