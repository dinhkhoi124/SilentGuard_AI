from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.core.security import get_current_user, require_household_role
from app.core.supabase_client import supabase
from app.models.schemas import ThresholdUpdate, ContactCreate, LLMConfigRequest
from app.services.llm_service import parse_config

router = APIRouter(prefix="/api", tags=["Settings"])

@router.get("/settings/thresholds")
async def get_thresholds(
    household_id: str,
    request: Request,
    user: dict = Depends(get_current_user),
    _member: dict = Depends(require_household_role(owner_only=False))
):
    """
    GET /api/settings/thresholds?household_id=...
    Ref: Section 4.8 of design doc
    """
    try:
        res = supabase.table("thresholds").select("*").eq("household_id", household_id).execute()
        if res.data:
            return res.data[0]
        # Return default if not exists
        return {
            "household_id": household_id,
            "low_max_sec": 30,
            "medium_max_sec": 120,
            "high_max_sec": 300,
            "dedup_window_sec": 60,
            "suppress_windows": []
        }
    except Exception as e:
        print(f"Error in get_thresholds: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve thresholds: {str(e)}"}}
        )

@router.put("/settings/thresholds")
async def update_thresholds(
    req: ThresholdUpdate,
    request: Request,
    user: dict = Depends(get_current_user),
    _owner: dict = Depends(require_household_role(owner_only=True))
):
    """
    PUT /api/settings/thresholds
    Ref: Section 4.8 of design doc
    """
    household_id = req.household_id
    try:
        data = {
            "low_max_sec": req.low_max_sec,
            "medium_max_sec": req.medium_max_sec,
            "high_max_sec": req.high_max_sec,
            "dedup_window_sec": req.dedup_window_sec,
            "suppress_windows": [w.model_dump() for w in req.suppress_windows]
        }
        supabase.table("thresholds").upsert({"household_id": household_id, **data}).execute()
        return {"status": "ok"}
    except Exception as e:
        print(f"Error in update_thresholds: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to update thresholds: {str(e)}"}}
        )

@router.get("/contacts")
async def get_contacts(
    household_id: str,
    request: Request,
    user: dict = Depends(get_current_user),
    _member: dict = Depends(require_household_role(owner_only=False))
):
    """
    GET /api/contacts?household_id=...
    Ref: Section 4.7 of design doc
    """
    try:
        res = supabase.table("contacts").select("*").eq("household_id", household_id).order("priority_order").execute()
        return res.data or []
    except Exception as e:
        print(f"Error in get_contacts: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve contacts: {str(e)}"}}
        )

@router.post("/contacts")
async def create_contact(
    req: ContactCreate,
    request: Request,
    user: dict = Depends(get_current_user),
    _owner: dict = Depends(require_household_role(owner_only=True))
):
    """
    POST /api/contacts
    Ref: Section 4.7 of design doc
    """
    household_id = str(req.household_id)
    user_id = str(req.user_id)
    try:
        # Validate user_id exists in users table and is already household_member of this household
        member_res = supabase.table("household_members")\
            .select("*")\
            .eq("household_id", household_id)\
            .eq("user_id", user_id)\
            .execute()
            
        if not member_res.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": {"code": "VALIDATION_ERROR", "message": "User is not a member of this household"}}
            )

        contact_data = {
            "household_id": household_id,
            "user_id": user_id,
            "priority_order": req.priority_order
        }
        supabase.table("contacts").insert(contact_data).execute()
        return {"status": "ok"}
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in create_contact: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to create contact: {str(e)}"}}
        )

@router.patch("/contacts/{contact_id}")
async def update_contact(
    contact_id: str,
    priority_order: int,
    request: Request,
    user: dict = Depends(get_current_user)
):
    """
    PATCH /api/contacts/{id}
    Ref: Section 4.7 of design doc
    """
    try:
        # Fetch contact to check household
        c_res = supabase.table("contacts").select("*").eq("id", contact_id).execute()
        if not c_res.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contact not found")
        
        contact = c_res.data[0]
        household_id = contact["household_id"]
        
        # Verify user is owner of this household
        user_id = user.get("id")
        member_res = supabase.table("household_members").select("*").eq("household_id", household_id).eq("user_id", user_id).execute()
        if not member_res.data or member_res.data[0]["role"] != "owner":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Yêu cầu quyền chủ hộ (owner)"}}
            )
            
        # Reorder other contacts in same household to avoid gap or duplication
        contacts_res = supabase.table("contacts").select("*").eq("household_id", household_id).execute()
        all_contacts = contacts_res.data or []
        
        # Build items score for sorting
        items = []
        for c in all_contacts:
            cid = c["id"]
            if cid == contact_id:
                # The updated one has the target priority
                score = (priority_order, 0)
            else:
                curr_priority = c["priority_order"]
                if curr_priority >= priority_order:
                    score = (curr_priority, 1)
                else:
                    score = (curr_priority, 0)
            items.append((cid, score))
            
        # Sort items based on score
        items.sort(key=lambda x: x[1])
        
        # Update priorities in DB
        for idx, (cid, _) in enumerate(items):
            new_val = idx + 1
            orig = next(c for c in all_contacts if c["id"] == cid)
            if orig["priority_order"] != new_val:
                supabase.table("contacts").update({"priority_order": new_val}).eq("id", cid).execute()
                
        return {"status": "ok"}
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in update_contact: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to update contact: {str(e)}"}}
        )

@router.delete("/contacts/{contact_id}")
async def delete_contact(
    contact_id: str,
    request: Request,
    user: dict = Depends(get_current_user)
):
    """
    DELETE /api/contacts/{id}
    Ref: Section 4.7 of design doc
    """
    try:
        # 1. Fetch contact being deleted to know household and priority
        c_res = supabase.table("contacts").select("*").eq("id", contact_id).execute()
        if not c_res.data:
            raise HTTPException(status_code=404, detail="Contact not found")
        deleted_contact = c_res.data[0]
        household_id = deleted_contact["household_id"]
        
        # Verify user is owner of this household
        user_id = user.get("id")
        member_res = supabase.table("household_members").select("*").eq("household_id", household_id).eq("user_id", user_id).execute()
        if not member_res.data or member_res.data[0]["role"] != "owner":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Yêu cầu quyền chủ hộ (owner)"}}
            )
        
        # 2. Delete contact
        supabase.table("contacts").delete().eq("id", contact_id).execute()
        
        # 3. Reorder remaining contacts to fill the gap (Section 4.7: avoid gaps)
        remaining = supabase.table("contacts").select("*").eq("household_id", household_id).order("priority_order").execute()
        for idx, item in enumerate(remaining.data or []):
            new_order = idx + 1
            if item["priority_order"] != new_order:
                supabase.table("contacts").update({"priority_order": new_order}).eq("id", item["id"]).execute()
                
        return {"status": "ok"}
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in delete_contact: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to delete contact: {str(e)}"}}
        )

@router.post("/llm/config")
async def chat_config(
    req: LLMConfigRequest,
    user: dict = Depends(get_current_user)
):
    """
    POST /api/llm/config
    Ref: Section 4.9 of design doc
    """
    try:
        parsed = await parse_config(req.message)
        return parsed
    except Exception as e:
        print(f"Error in chat_config: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "VALIDATION_ERROR", "message": str(e)}}
        )
