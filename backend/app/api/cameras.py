import secrets
import hashlib
from datetime import datetime, timezone
from typing import Optional, List
from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.core.security import get_current_user, require_household_role, verify_device_key_dependency, verify_owner_role
from app.core.supabase_client import supabase
from app.models.schemas import UploadUrlRequest, UploadUrlResponse

router = APIRouter(prefix="/api/cameras", tags=["Cameras"])

class CameraCreateRequest(BaseModel):
    household_id: str
    name: str
    room: str
    fps: int = 15
    serial_number: Optional[str] = None


class CameraUpdateRequest(BaseModel):
    name: Optional[str] = None
    room: Optional[str] = None
    fps: Optional[int] = None
    serial_number: Optional[str] = None


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_camera(
    req: CameraCreateRequest,
    request: Request,
    user: dict = Depends(get_current_user)
):
    """
    POST /api/cameras
    Creates a new camera for the household. Owner-only.
    """
    plain_key = f"sg_live_{secrets.token_urlsafe(32)}"
    
    # Verify owner role
    verify_owner_role(req.household_id, user["id"])
    
    if req.serial_number:
        serial_check = supabase.table("cameras")\
            .select("id")\
            .eq("serial_number", req.serial_number)\
            .is_("deleted_at", "null")\
            .execute()
        if serial_check.data:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": {"code": "DUPLICATE_SERIAL", "message": f"Serial number '{req.serial_number}' đã được sử dụng"}}
            )
    hashed_key = hashlib.sha256(plain_key.encode()).hexdigest()
    
    camera_data = {
        "household_id": req.household_id,
        "name": req.name,
        "room": req.room,
        "fps": req.fps,
        "device_api_key_hash": hashed_key,
        "status": "unknown",
        "serial_number": req.serial_number
    }
    
    try:
        res = supabase.table("cameras").insert(camera_data).select().execute()
        if not res.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "DATABASE_ERROR", "message": "Failed to create camera in database"}}
            )
        camera = res.data[0]
        return {
            "camera_id": camera["id"],
            "name": camera["name"],
            "room": camera["room"],
            "serial_number": camera.get("serial_number"),
            "device_api_key": plain_key,
            "warning": "Lưu lại key này ngay — sẽ không hiển thị lại được"
        }
    except Exception as e:
        print(f"Error in create_camera: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )

@router.get("")
async def list_cameras(
    household_id: str,
    request: Request,
    user: dict = Depends(get_current_user),
    _member: dict = Depends(require_household_role(owner_only=False))
):
    """
    GET /api/cameras
    Lists active cameras for a household. Member-only.
    """
    try:
        res = supabase.table("cameras").select("*").eq("household_id", household_id).is_("deleted_at", "null").execute()
        cameras_list = []
        for cam in (res.data or []):
            cameras_list.append({
                "id": cam["id"],
                "name": cam["name"],
                "room": cam["room"],
                "status": cam["status"],
                "fps": cam["fps"],
                "serial_number": cam.get("serial_number"),
                "last_heartbeat": cam.get("last_heartbeat"),
                "created_at": cam["created_at"]
            })
        return cameras_list
    except Exception as e:
        print(f"Error in list_cameras: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )

@router.get("/{camera_id}")
async def get_camera_detail(
    camera_id: str,
    user: dict = Depends(get_current_user)
):
    """
    GET /api/cameras/{camera_id}
    """
    try:
        res = supabase.table("cameras").select("*").eq("id", camera_id).is_("deleted_at", "null").execute()
        if not res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "CAMERA_NOT_FOUND", "message": "Camera not found"}}
            )
            
        camera = res.data[0]
        household_id = camera.get("household_id")
        
        member_res = supabase.table("household_members")\
            .select("role")\
            .eq("household_id", household_id)\
            .eq("user_id", user["id"])\
            .execute()
            
        if not member_res.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Bạn không có quyền truy cập camera của hộ gia đình này"}}
            )
            
        return {
            "id": camera["id"],
            "name": camera["name"],
            "room": camera["room"],
            "status": camera["status"],
            "fps": camera["fps"],
            "serial_number": camera.get("serial_number"),
            "last_heartbeat": camera.get("last_heartbeat"),
            "created_at": camera["created_at"]
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in get_camera_detail: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )

@router.patch("/{camera_id}/rotate-key")
async def rotate_camera_key(
    camera_id: str,
    request: Request,
    user: dict = Depends(get_current_user)
):
    """
    PATCH /api/cameras/{camera_id}/rotate-key
    Rotates the device API key. Owner-only.
    """
    try:
        # Fetch camera to verify household
        cam_res = supabase.table("cameras").select("*").eq("id", camera_id).is_("deleted_at", "null").execute()
        if not cam_res.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")
        camera = cam_res.data[0]
        
        # Verify user is owner of this household
        verify_owner_role(camera["household_id"], user.get("id"))
            
        new_plain_key = f"sg_live_{secrets.token_urlsafe(32)}"
        new_hashed_key = hashlib.sha256(new_plain_key.encode()).hexdigest()
        
        supabase.table("cameras").update({"device_api_key_hash": new_hashed_key}).eq("id", camera_id).execute()
        
        return {
            "camera_id": camera_id,
            "device_api_key": new_plain_key,
            "warning": "Lưu lại key này ngay — sẽ không hiển thị lại được"
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in rotate_camera_key: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )

@router.delete("/{camera_id}")
async def delete_camera(
    camera_id: str,
    request: Request,
    user: dict = Depends(get_current_user)
):
    """
    DELETE /api/cameras/{camera_id}
    Soft-deletes a camera. Owner-only.
    """
    try:
        # Fetch camera
        cam_res = supabase.table("cameras").select("*").eq("id", camera_id).is_("deleted_at", "null").execute()
        if not cam_res.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")
        camera = cam_res.data[0]
        
        # Verify owner role
        verify_owner_role(camera["household_id"], user.get("id"))
            
        supabase.table("cameras").update({"deleted_at": datetime.now(timezone.utc).isoformat()}).eq("id", camera_id).execute()
        return {"status": "ok"}
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in delete_camera: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )

@router.patch("/{camera_id}")
async def update_camera_details(
    camera_id: str,
    req: CameraUpdateRequest,
    request: Request,
    user: dict = Depends(get_current_user)
):
    """
    PATCH /api/cameras/{camera_id}
    Updates camera details. Owner-only.
    """
    try:
        # Fetch camera
        cam_res = supabase.table("cameras").select("*").eq("id", camera_id).is_("deleted_at", "null").execute()
        if not cam_res.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")
        camera = cam_res.data[0]
        
        # Verify owner role
        verify_owner_role(camera["household_id"], user.get("id"))
            
        if req.serial_number is not None:
            serial_check = supabase.table("cameras")\
                .select("id")\
                .eq("serial_number", req.serial_number)\
                .neq("id", camera_id)\
                .is_("deleted_at", "null")\
                .execute()
            if serial_check.data:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={"error": {"code": "DUPLICATE_SERIAL", "message": f"Serial number '{req.serial_number}' đã được sử dụng"}}
                )

        update_data = {}
        if req.name is not None:
            update_data["name"] = req.name
        if req.room is not None:
            update_data["room"] = req.room
        if req.fps is not None:
            update_data["fps"] = req.fps
        if req.serial_number is not None:
            update_data["serial_number"] = req.serial_number
            
        if update_data:
            supabase.table("cameras").update(update_data).eq("id", camera_id).execute()
            
        return {"status": "ok"}
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in update_camera_details: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )

class CameraHeartbeatRequest(BaseModel):
    fps: Optional[int] = None

@router.post("/upload-url", response_model=UploadUrlResponse, status_code=status.HTTP_200_OK)
async def get_upload_url(
    req: UploadUrlRequest,
    camera: dict = Depends(verify_device_key_dependency)
):
    """
    POST /api/cameras/upload-url
    Ref: Section 4.0 of Design Document
    Generates a presigned URL for the edge device to upload a video clip.
    """
    # Whitelist validation
    whitelist = {"video/mp4", "video/quicktime", "video/webm"}
    if req.content_type not in whitelist:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "VALIDATION_ERROR", "message": f"Invalid content_type: {req.content_type}. Whitelisted: video/mp4, video/quicktime, video/webm"}}
        )

    household_id = camera.get("household_id", "household-uuid")
    
    # Sanitize filename to avoid 400 Bad Request on Supabase
    import re, unicodedata
    nfkd = unicodedata.normalize('NFKD', req.filename)
    ascii_str = nfkd.encode('ASCII', 'ignore').decode('ASCII')
    safe_filename = re.sub(r'[^a-zA-Z0-9.\-_]', '_', ascii_str)
    
    storage_path = f"{household_id}/{safe_filename}"
    
    try:
        # Generate signed upload URL from Supabase Storage client
        res = supabase.storage.from_("clips").create_signed_upload_url(storage_path)
        upload_url = res.get("signed_url")
    except Exception as e:
        print(f"Failed to generate signed upload URL from Supabase Storage: {e}")
        from app.core.config import settings
        if settings.APP_ENV == "production":
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "STORAGE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
            )
        # Dev fallback
        upload_url = f"https://sceygoxizfbbhqwatqhx.supabase.co/storage/v1/object/upload/sign/clips/{storage_path}?token=mock"

    return UploadUrlResponse(
        upload_url=upload_url,
        clip_path=f"clips/{storage_path}",
        expires_in=300
    )

@router.post("/{camera_id}/heartbeat", status_code=status.HTTP_200_OK)
async def camera_heartbeat(
    camera_id: str,
    req: Optional[CameraHeartbeatRequest] = None,
    camera: dict = Depends(verify_device_key_dependency)
):
    """
    POST /api/cameras/{camera_id}/heartbeat
    Ref: Section 4.18 of Design Document
    Updates the last_heartbeat timestamp and online status of the camera.
    """
    if camera_id != camera.get("id"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN", "message": "Camera ID mismatch with key"}}
        )

    timestamp = datetime.now(timezone.utc).isoformat()
    update_data = {
        "last_heartbeat": timestamp,
        "status": "online"
    }
    if req and req.fps is not None:
        update_data["fps"] = req.fps

    try:
        supabase.table("cameras").update(update_data).eq("id", camera_id).execute()
        return {
            "status": "ok",
            "last_heartbeat": timestamp
        }
    except Exception as e:
        print(f"Error in camera_heartbeat database update: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": "Lỗi hệ thống nội bộ, vui lòng thử lại sau"}}
        )

