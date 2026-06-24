import secrets
from datetime import datetime, timezone, timedelta
from typing import Optional, List
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.core.security import get_current_user, require_household_role, verify_owner_role
from app.core.supabase_client import supabase
from app.models.schemas import (
    HouseholdCreateRequest,
    SwitchHouseholdRequest,
    HouseholdUpdateRequest,
    InviteByEmailRequest,
    RespondInviteRequest
)
from app.services.notification_service import send_fcm_notification


router = APIRouter(prefix="/api/households", tags=["Households"])


@router.post("/invite-by-email", status_code=status.HTTP_201_CREATED)
async def invite_by_email(
    req: InviteByEmailRequest,
    user: dict = Depends(get_current_user)
):
    user_id = user.get("id")

    # Verify requester is owner of the household
    verify_owner_role(req.household_id, user_id)

    # Find invitee by email
    try:
        invitee_res = supabase.table("users")\
            .select("id, fcm_token, full_name")\
            .eq("email", req.email)\
            .execute()
        if not invitee_res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "USER_NOT_FOUND", "message": "Không tìm thấy người dùng với email này"}}
            )
        invitee = invitee_res.data[0]
        invitee_id = invitee["id"]
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": str(e)}}
        )

    # Check if already a member
    member_check = supabase.table("household_members")\
        .select("id")\
        .eq("household_id", req.household_id)\
        .eq("user_id", invitee_id)\
        .execute()
    if member_check.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "ALREADY_MEMBER", "message": "Người dùng này đã là thành viên của hộ gia đình"}}
        )

    # Create invite request
    try:
        invite_data = {
            "household_id": req.household_id,
            "invited_by": user_id,
            "invitee_id": invitee_id,
            "status": "pending"
        }
        invite_res = supabase.table("household_invite_requests")\
            .insert(invite_data)\
            .select()\
            .execute()
        if not invite_res.data:
            raise Exception("Failed to insert invite request")
        invite = invite_res.data[0]
    except Exception as e:
        if "23505" in str(e) or "unique" in str(e).lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": {"code": "INVITE_ALREADY_SENT", "message": "Lời mời đã được gửi trước đó"}}
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": str(e)}}
        )

    # Get household name for notification
    try:
        h_res = supabase.table("households").select("name").eq("id", req.household_id).execute()
        household_name = h_res.data[0]["name"] if h_res.data else "Hộ gia đình"
    except Exception:
        household_name = "Hộ gia đình"

    # Send FCM push to invitee
    fcm_token = invitee.get("fcm_token")
    if fcm_token:
        try:
            await send_fcm_notification(
                token=fcm_token,
                title="Lời mời tham gia hộ gia đình",
                body=f"Bạn được mời tham gia '{household_name}' trên SilentGuard",
                data={
                    "type": "household_invite",
                    "invite_request_id": str(invite["id"])
                }
            )
        except Exception as e:
            print(f"FCM push failed: {e}")

    return {
        "invite_request_id": str(invite["id"]),
        "invitee_id": str(invitee_id),
        "status": "pending"
    }


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

@router.get("/invite-requests/pending", status_code=status.HTTP_200_OK)
async def get_pending_invites(
    user: dict = Depends(get_current_user)
):
    user_id = user.get("id")
    try:
        res = supabase.table("household_invite_requests")\
            .select("id, household_id, invited_by, status, created_at, households(name, elderly_name), users!invited_by(full_name, email)")\
            .eq("invitee_id", user_id)\
            .eq("status", "pending")\
            .order("created_at", desc=True)\
            .execute()

        items = []
        for row in (res.data or []):
            items.append({
                "id": row["id"],
                "household_id": row["household_id"],
                "household_name": row.get("households", {}).get("name"),
                "elderly_name": row.get("households", {}).get("elderly_name"),
                "invited_by_name": row.get("users", {}).get("full_name"),
                "invited_by_email": row.get("users", {}).get("email"),
                "status": row["status"],
                "created_at": row["created_at"]
            })

        return {"items": items, "total": len(items)}
    except Exception as e:
        print(f"Error in get_pending_invites: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": str(e)}}
        )


@router.post("/invite-requests/{invite_id}/respond", status_code=status.HTTP_200_OK)
async def respond_invite(
    invite_id: str,
    req: RespondInviteRequest,
    user: dict = Depends(get_current_user)
):
    user_id = user.get("id")

    # Fetch invite
    try:
        invite_res = supabase.table("household_invite_requests")\
            .select("*")\
            .eq("id", invite_id)\
            .eq("invitee_id", user_id)\
            .execute()
        if not invite_res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "INVITE_NOT_FOUND", "message": "Lời mời không tồn tại"}}
            )
        invite = invite_res.data[0]
        if invite["status"] != "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": {"code": "INVITE_ALREADY_RESPONDED", "message": "Lời mời này đã được xử lý"}}
            )
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": str(e)}}
        )

    household_id = invite["household_id"]
    now = datetime.now(timezone.utc).isoformat()

    if req.action == "accepted":
        # Insert into household_members
        try:
            supabase.table("household_members").insert({
                "household_id": household_id,
                "user_id": user_id,
                "role": "member"
            }).execute()
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to add member: {str(e)}"}}
            )

        # Insert into contacts with last priority
        try:
            priority_res = supabase.table("contacts")\
                .select("priority_order")\
                .eq("household_id", household_id)\
                .order("priority_order", desc=True)\
                .limit(1)\
                .execute()
            next_priority = (priority_res.data[0]["priority_order"] + 1) if priority_res.data else 1

            supabase.table("contacts").insert({
                "household_id": household_id,
                "user_id": user_id,
                "priority_order": next_priority
            }).execute()
        except Exception as e:
            # Rollback: remove from household_members
            try:
                supabase.table("household_members")\
                    .delete()\
                    .eq("household_id", household_id)\
                    .eq("user_id", user_id)\
                    .execute()
            except Exception:
                pass
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to add contact: {str(e)}"}}
            )

    # Update invite status
    supabase.table("household_invite_requests").update({
        "status": req.action,
        "responded_at": now
    }).eq("id", invite_id).execute()

    return {"status": req.action}


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

@router.get("/{household_id}/members", status_code=status.HTTP_200_OK)
async def get_household_members(
    household_id: str,
    user: dict = Depends(get_current_user)
):
    user_id = user.get("id")

    # Verify requester is member
    member_check = supabase.table("household_members")\
        .select("role")\
        .eq("household_id", household_id)\
        .eq("user_id", user_id)\
        .execute()
    if not member_check.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN", "message": "Bạn không có quyền truy cập hộ gia đình này"}}
        )

    try:
        # Fetch all members
        members_res = supabase.table("household_members")\
            .select("user_id, role, joined_at, users(id, full_name, email, phone)")\
            .eq("household_id", household_id)\
            .execute()

        # Fetch contacts for this household
        contacts_res = supabase.table("contacts")\
            .select("user_id, priority_order")\
            .eq("household_id", household_id)\
            .execute()
        contacts_map = {
            c["user_id"]: c["priority_order"]
            for c in (contacts_res.data or [])
        }

        result = []
        for m in (members_res.data or []):
            u = m.get("users") or {}
            uid = m["user_id"]
            result.append({
                "user_id": uid,
                "full_name": u.get("full_name"),
                "email": u.get("email"),
                "phone": u.get("phone"),
                "role": m["role"],
                "joined_at": m.get("joined_at"),
                "is_in_contacts": uid in contacts_map,
                "contacts_priority": contacts_map.get(uid)
            })

        return {"members": result, "total": len(result)}
    except Exception as e:
        print(f"Error in get_household_members: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": str(e)}}
        )


@router.patch("/{household_id}")
async def update_household(
    household_id: str,
    req: HouseholdUpdateRequest,
    user: dict = Depends(get_current_user)
):
    """
    PATCH /api/households/{household_id}
    """
    user_id = user.get("id")
    verify_owner_role(household_id, user_id)
    
    update_data = {}
    if req.name is not None:
        update_data["name"] = req.name
    if req.elderly_name is not None:
        update_data["elderly_name"] = req.elderly_name
    if req.address is not None:
        update_data["address"] = req.address
        
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "BAD_REQUEST", "message": "Yêu cầu ít nhất một trường để cập nhật"}}
        )
        
    try:
        res = supabase.table("households").update(update_data).eq("id", household_id).select().execute()
        if not res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "HOUSEHOLD_NOT_FOUND", "message": "Không tìm thấy hộ gia đình"}}
            )
        household = res.data[0]
        return {
            "id": household["id"],
            "name": household.get("name"),
            "elderly_name": household.get("elderly_name"),
            "address": household.get("address"),
            "created_at": household.get("created_at")
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in update_household: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to update household: {str(e)}"}}
        )


