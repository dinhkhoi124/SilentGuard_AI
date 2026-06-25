from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from app.core.security import get_current_user
from app.core.supabase_client import supabase
from app.models.schemas import FCMTokenUpdateRequest, SwitchHouseholdRequest

def normalize_phone(phone: str) -> str:
    """
    Normalize Vietnamese phone number to E.164 format.
    0xxxxxxxxx → +84xxxxxxxxx
    """
    phone = phone.strip().replace(" ", "").replace("-", "")
    if phone.startswith("0"):
        return "+84" + phone[1:]
    if phone.startswith("84") and not phone.startswith("+"):
        return "+" + phone
    return phone

router = APIRouter(prefix="/api/users", tags=["Users"])


@router.post("/login", status_code=status.HTTP_200_OK)
async def login_user(user: dict = Depends(get_current_user)):
    """
    POST /api/users/login
    Ref: Section 3 Auth Flow
    Verifies Firebase token and registers/provisions user in the DB.
    Returns details of the logged in user.
    """
    return {
        "status": "success",
        "user": user
    }

@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout_user(user: dict = Depends(get_current_user)):
    """
    POST /api/users/logout
    Clears the user's registered FCM token on logout.
    """
    user_id = user.get("id")
    try:
        # Clear FCM token to prevent sending notifications after logout
        supabase.table("users").update({"fcm_token": None}).eq("id", user_id).execute()
        return {
            "status": "ok",
            "message": "Logged out successfully. FCM token cleared."
        }
    except Exception as e:
        print(f"Error in logout_user: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to clear FCM token on logout: {str(e)}"}}
        )

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
        print(f"Error in register_device_token: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to register FCM token: {str(e)}"}}
        )

@router.post("/switch-household", status_code=status.HTTP_200_OK)
async def switch_household(
    req: SwitchHouseholdRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    POST /api/users/switch-household
    Switches the user's active household.
    """
    user_id = current_user.get("id")
    try:
        # Verify user is a member of target household
        mem_res = supabase.table("household_members").select("*").eq("household_id", req.household_id).eq("user_id", user_id).execute()
        if not mem_res.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Bạn không thuộc về hộ gia đình này"}}
            )
            
        # Update users table
        supabase.table("users").update({"active_household_id": req.household_id}).eq("id", user_id).execute()
        
        return {
            "active_household_id": req.household_id
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in switch_household: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to switch household: {str(e)}"}}
        )

class UpdatePhoneRequest(BaseModel):
    phone: str

@router.patch("/me/phone", status_code=status.HTTP_200_OK)
async def update_phone(
    req: UpdatePhoneRequest,
    user: dict = Depends(get_current_user)
):
    """
    PATCH /api/users/me/phone
    Updates the user's phone number, normalizing Vietnamese format to E.164.
    """
    user_id = user.get("id")
    normalized = normalize_phone(req.phone)

    # Basic E.164 validation after normalization
    import re
    if not re.match(r"^\+\d{10,15}$", normalized):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "INVALID_PHONE", "message": "Số điện thoại không hợp lệ. Vui lòng nhập đúng định dạng (vd: 0347838309)"}}
        )

    try:
        supabase.table("users").update({"phone": normalized}).eq("id", user_id).execute()
        return {"status": "ok", "phone": normalized}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": str(e)}}
        )


