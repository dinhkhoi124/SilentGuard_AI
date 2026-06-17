import secrets
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.core.security import get_current_user, require_household_role
from app.core.supabase_client import supabase

router = APIRouter(prefix="/api/households", tags=["Households"])

@router.post("/invite", status_code=status.HTTP_201_CREATED)
async def create_invite(
    request: Request,
    member_info: dict = Depends(require_household_role(owner_only=True)),
    current_user: dict = Depends(get_current_user)
):
    """
    POST /api/households/invite
    Generates an invite code for the household. Owner-only.
    """
    household_id = request.state.household_id
    user_id = current_user.get("id")
    
    code = secrets.token_urlsafe(8)
    expires_at = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat()
    
    invite_data = {
        "household_id": household_id,
        "code": code,
        "created_by": user_id,
        "expires_at": expires_at
    }
    
    try:
        res = supabase.table("household_invites").insert(invite_data).execute()
        if not res.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "DATABASE_ERROR", "message": "Failed to create invite in database"}}
            )
        return {
            "code": code,
            "expires_at": expires_at
        }
    except Exception as e:
        print(f"Error in create_invite: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to create invite: {str(e)}"}}
        )

@router.get("/me")
async def get_my_household(
    current_user: dict = Depends(get_current_user)
):
    """
    GET /api/households/me
    Returns the user's household membership details and role.
    """
    user_id = current_user.get("id")
    try:
        # Fetch membership
        mem_res = supabase.table("household_members").select("*").eq("user_id", user_id).execute()
        if not mem_res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "HOUSEHOLD_NOT_FOUND", "message": "Bạn chưa thuộc về hộ gia đình nào"}}
            )
            
        membership = mem_res.data[0]
        household_id = membership["household_id"]
        role = membership["role"]
        
        # Fetch household details
        h_res = supabase.table("households").select("*").eq("id", household_id).execute()
        if not h_res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "HOUSEHOLD_NOT_FOUND", "message": "Không tìm thấy thông tin hộ gia đình"}}
            )
            
        household = h_res.data[0]
        return {
            "household_id": household_id,
            "role": role,
            "elderly_name": household.get("elderly_name", "")
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in get_my_household: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve household data: {str(e)}"}}
        )
