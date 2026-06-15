from fastapi import APIRouter, Depends
from app.core.security import get_current_user
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
    # TODO: Save FCM token to users table
    return {"updated": True}
