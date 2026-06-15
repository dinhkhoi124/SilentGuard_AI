from fastapi import APIRouter, Depends, HTTPException, status
from app.core.security import verify_device_key_dependency
from app.core.supabase_client import supabase
from app.models.schemas import UploadUrlRequest, UploadUrlResponse

router = APIRouter(prefix="/api/cameras", tags=["Cameras"])

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
