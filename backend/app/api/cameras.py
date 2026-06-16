import secrets
import hashlib
from datetime import datetime, timezone
from typing import Optional, List
from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.core.security import get_current_user, require_household_role, verify_device_key_dependency
from app.core.supabase_client import supabase
from app.models.schemas import UploadUrlRequest, UploadUrlResponse

router = APIRouter(prefix="/api/cameras", tags=["Cameras"])

class CameraCreateRequest(BaseModel):
    household_id: str
    name: str
    room: str
    fps: int = 15

class CameraUpdateRequest(BaseModel):
    name: Optional[str] = None
    room: Optional[str] = None
    fps: Optional[int] = None

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_camera(
    req: CameraCreateRequest,
    request: Request,
    user: dict = Depends(get_current_user),
    _owner: dict = Depends(require_household_role(owner_only=True))
):
    """
    POST /api/cameras
    Creates a new camera for the household. Owner-only.
    """
    plain_key = f"sg_live_{secrets.token_urlsafe(32)}"
    hashed_key = hashlib.sha256(plain_key.encode()).hexdigest()
    
    camera_data = {
        "household_id": req.household_id,
        "name": req.name,
        "room": req.room,
        "fps": req.fps,
        "device_api_key_hash": hashed_key,
        "status": "unknown"
    }
    
    try:
        res = supabase.table("cameras").insert(camera_data).execute()
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
            "device_api_key": plain_key,
            "warning": "Lưu lại key này ngay — sẽ không hiển thị lại được"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to create camera: {str(e)}"}}
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
        res = supabase.table("cameras").select("*").eq("household_id", household_id).execute()
        cameras_list = []
        for cam in (res.data or []):
            if cam.get("deleted_at") is not None:
                continue
            cameras_list.append({
                "id": cam["id"],
                "name": cam["name"],
                "room": cam["room"],
                "status": cam["status"],
                "fps": cam["fps"],
                "last_heartbeat": cam.get("last_heartbeat"),
                "created_at": cam["created_at"]
            })
        return cameras_list
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve cameras: {str(e)}"}}
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
        cam_res = supabase.table("cameras").select("*").eq("id", camera_id).execute()
        if not cam_res.data or cam_res.data[0].get("deleted_at") is not None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")
        camera = cam_res.data[0]
        
        # Verify user is owner of this household
        user_id = user.get("id")
        member_res = supabase.table("household_members").select("*").eq("household_id", camera["household_id"]).eq("user_id", user_id).execute()
        if not member_res.data or member_res.data[0]["role"] != "owner":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Yêu cầu quyền chủ hộ (owner)"}}
            )
            
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
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to rotate key: {str(e)}"}}
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
        cam_res = supabase.table("cameras").select("*").eq("id", camera_id).execute()
        if not cam_res.data or cam_res.data[0].get("deleted_at") is not None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")
        camera = cam_res.data[0]
        
        # Verify owner role
        user_id = user.get("id")
        member_res = supabase.table("household_members").select("*").eq("household_id", camera["household_id"]).eq("user_id", user_id).execute()
        if not member_res.data or member_res.data[0]["role"] != "owner":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Yêu cầu quyền chủ hộ (owner)"}}
            )
            
        supabase.table("cameras").update({"deleted_at": datetime.now(timezone.utc).isoformat()}).eq("id", camera_id).execute()
        return {"status": "ok"}
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to delete camera: {str(e)}"}}
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
        cam_res = supabase.table("cameras").select("*").eq("id", camera_id).execute()
        if not cam_res.data or cam_res.data[0].get("deleted_at") is not None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")
        camera = cam_res.data[0]
        
        # Verify owner role
        user_id = user.get("id")
        member_res = supabase.table("household_members").select("*").eq("household_id", camera["household_id"]).eq("user_id", user_id).execute()
        if not member_res.data or member_res.data[0]["role"] != "owner":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Yêu cầu quyền chủ hộ (owner)"}}
            )
            
        update_data = {}
        if req.name is not None:
            update_data["name"] = req.name
        if req.room is not None:
            update_data["room"] = req.room
        if req.fps is not None:
            update_data["fps"] = req.fps
            
        if update_data:
            supabase.table("cameras").update(update_data).eq("id", camera_id).execute()
            
        return {"status": "ok"}
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to update camera: {str(e)}"}}
        )

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
    household_id = camera.get("household_id", "household-uuid")
    clip_path = f"{household_id}/{req.filename}"
    
    try:
        # Generate signed upload URL from Supabase Storage client
        res = supabase.storage.from_("clips").create_signed_upload_url(clip_path)
        upload_url = res.get("url")
    except Exception as e:
        from app.core.config import settings
        if settings.APP_ENV == "production":
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "STORAGE_ERROR", "message": f"Failed to generate presigned upload URL: {str(e)}"}}
            )
        print(f"Failed to generate signed upload URL from Supabase Storage: {e}")
        # Dev fallback
        upload_url = f"https://sceygoxizfbbhqwatqhx.supabase.co/storage/v1/object/upload/sign/clips/{clip_path}?token=mock"

    return UploadUrlResponse(
        upload_url=upload_url,
        clip_path=f"clips/{clip_path}",
        expires_in=300
    )
