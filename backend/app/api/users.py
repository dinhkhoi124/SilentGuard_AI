from fastapi import APIRouter, Depends, HTTPException, status
from app.core.security import get_current_user
from app.core.supabase_client import supabase
from app.models.schemas import FCMTokenUpdateRequest

router = APIRouter(prefix="/api/users", tags=["Users"])

@router.post("/device-token")
async def register_device_token(
    req: FCMTokenUpdateRequest,
    user: dict = Depends(get_current_user)
):
    """
    POST /api/users/device-token
    Ref: Section 4.6 of design doc
    """
    user_id = user.get("id")
    try:
        supabase.table("users").update({"fcm_token": req.fcm_token}).eq("id", user_id).execute()
        return {"updated": True}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to register FCM token: {str(e)}"}}
        )
