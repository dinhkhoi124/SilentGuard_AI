from fastapi import APIRouter, Depends, status
from app.core.security import verify_device_key_dependency
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
    clip_path = f"clips/{household_id}/{req.filename}"
    
    # TODO: Generate real presigned URL from Supabase Storage client
    upload_url = f"https://your-supabase-url.supabase.co/storage/v1/object/sign/{clip_path}?token=mock-presigned-token"
    
    return UploadUrlResponse(
        upload_url=upload_url,
        clip_path=clip_path,
        expires_in=300
    )
