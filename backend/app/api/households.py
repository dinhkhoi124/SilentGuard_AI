import secrets
from datetime import datetime, timezone, timedelta
from typing import Optional, List
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.core.security import get_current_user, require_household_role, verify_owner_role
from app.core.supabase_client import supabase
from app.models.schemas import HouseholdCreateRequest, SwitchHouseholdRequest

router = APIRouter(prefix="/api/households", tags=["Households"])

class InviteRequest(BaseModel):
    household_id: Optional[str] = None

@router.post("/invite", status_code=status.HTTP_201_CREATED)
async def create_invite(
    req: Optional[InviteRequest] = None,
    current_user: dict = Depends(get_current_user)
):
    """
    POST /api/households/invite
    Generates an invite code for the household. Owner-only.
    """
    user_id = current_user.get("id")
    household_id = None
    if req and req.household_id:
        household_id = req.household_id
    
    if not household_id:
        # Get from active_household_id
        u_res = supabase.table("users").select("active_household_id").eq("id", user_id).execute()
        if u_res.data:
            household_id = u_res.data[0].get("active_household_id")
            
    if not household_id:
        # Fallback to first household
        mem_res = supabase.table("household_members").select("household_id").eq("user_id", user_id).order("joined_at").execute()
        if mem_res.data:
            household_id = mem_res.data[0]["household_id"]
            
    if not household_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN", "message": "Bạn không thuộc về hộ gia đình nào"}}
        )
        
    # Verify owner role
    verify_owner_role(household_id, user_id)
    
    code = secrets.token_urlsafe(8)
    expires_at = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat()
    
    invite_data = {
        "household_id": household_id,
        "code": code,
        "created_by": user_id,
        "expires_at": expires_at
    }
    
    try:
        res = supabase.table("household_invites").insert(invite_data).select().execute()
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
    Returns the user's active household details and role.
    """
    user_id = current_user.get("id")
    try:
        # 1. Fetch user's active_household_id
        u_res = supabase.table("users").select("active_household_id").eq("id", user_id).execute()
        active_id = u_res.data[0].get("active_household_id") if u_res.data else None
        
        household_id = None
        role = None
        
        if active_id:
            # Check if user is actually a member of this active household
            mem_res = supabase.table("household_members").select("*").eq("household_id", active_id).eq("user_id", user_id).execute()
            if mem_res.data:
                household_id = active_id
                role = mem_res.data[0]["role"]
        
        if not household_id:
            # Fallback: get first household member entry
            mem_res = supabase.table("household_members").select("*").eq("user_id", user_id).order("joined_at").execute()
            if not mem_res.data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail={"error": {"code": "HOUSEHOLD_NOT_FOUND", "message": "Bạn chưa thuộc về hộ gia đình nào"}}
                )
            membership = mem_res.data[0]
            household_id = membership["household_id"]
            role = membership["role"]
            # Auto-set active_household_id
            supabase.table("users").update({"active_household_id": household_id}).eq("id", user_id).execute()
            
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
            "name": household.get("name"),
            "elderly_name": household.get("elderly_name", ""),
            "address": household.get("address"),
            "created_at": household.get("created_at")
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in get_my_household: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve household data: {str(e)}"}}
        )

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_household(
    req: HouseholdCreateRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    POST /api/households
    Creates a new household for the user and sets it as active.
    """
    user_id = current_user.get("id")
    try:
        # 1. Insert household
        h_data = {
            "name": req.name,
            "elderly_name": req.elderly_name,
            "address": req.address,
            "owner_user_id": user_id
        }
        h_res = supabase.table("households").insert(h_data).select().execute()
        if not h_res.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "DATABASE_ERROR", "message": "Failed to create household"}}
            )
        household = h_res.data[0]
        household_id = household["id"]
        
        # 2. Insert membership
        supabase.table("household_members").insert({
            "household_id": household_id,
            "user_id": user_id,
            "role": "owner"
        }).execute()
        
        # 3. Set active_household_id
        supabase.table("users").update({"active_household_id": household_id}).eq("id", user_id).execute()
        
        return {
            "id": household["id"],
            "name": household.get("name"),
            "elderly_name": household.get("elderly_name"),
            "address": household.get("address"),
            "role": "owner",
            "created_at": household.get("created_at")
        }
    except Exception as e:
        print(f"Error in create_household: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to create household: {str(e)}"}}
        )

@router.get("")
async def list_households(
    current_user: dict = Depends(get_current_user)
):
    """
    GET /api/households
    Lists all households the current user belongs to.
    """
    user_id = current_user.get("id")
    try:
        u_res = supabase.table("users").select("active_household_id").eq("id", user_id).execute()
        active_id = u_res.data[0].get("active_household_id") if u_res.data else None
        
        mem_res = supabase.table("household_members").select("role, household_id, households(*)").eq("user_id", user_id).execute()
        
        households_list = []
        for item in (mem_res.data or []):
            h_info = item.get("households")
            if h_info:
                h_id = h_info.get("id")
                households_list.append({
                    "id": h_id,
                    "name": h_info.get("name"),
                    "elderly_name": h_info.get("elderly_name"),
                    "address": h_info.get("address"),
                    "role": item.get("role"),
                    "is_active": (h_id == active_id) if h_id and active_id else False
                })
        return {
            "households": households_list,
            "active_household_id": active_id
        }
    except Exception as e:
        print(f"Error in list_households: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to list households: {str(e)}"}}
        )

