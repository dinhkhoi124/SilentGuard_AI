from fastapi import APIRouter, Depends, HTTPException, status
from app.core.security import get_current_user
from app.core.supabase_client import supabase
from app.models.schemas import ThresholdUpdate, ContactCreate, LLMConfigRequest
from app.services.llm_service import parse_config

router = APIRouter(prefix="/api", tags=["Settings"])

async def get_user_household_id(user_id: str) -> str:
    """Helper to retrieve user's household ID."""
    try:
        h_res = supabase.table("households").select("id").eq("owner_user_id", user_id).execute()
        if h_res.data:
            return h_res.data[0]["id"]
        # Fallback to first household in database for dev
        any_h = supabase.table("households").select("id").limit(1).execute()
        if any_h.data:
            return any_h.data[0]["id"]
    except Exception as e:
        print(f"Error fetching household: {e}")
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail={"error": {"code": "HOUSEHOLD_NOT_FOUND", "message": "Không tìm thấy hộ gia đình"}}
    )

@router.get("/settings/thresholds")
async def get_thresholds(user: dict = Depends(get_current_user)):
    """
    GET /api/settings/thresholds
    Ref: Section 4.8 of design doc
    """
    user_id = user.get("id")
    household_id = await get_user_household_id(user_id)
    try:
        res = supabase.table("thresholds").select("*").eq("household_id", household_id).execute()
        if res.data:
            return res.data[0]
        # Return default if not exists
        return {
            "low_max_sec": 30,
            "medium_max_sec": 120,
            "high_max_sec": 300,
            "dedup_window_sec": 60,
            "suppress_windows": []
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve thresholds: {str(e)}"}}
        )

@router.put("/settings/thresholds")
async def update_thresholds(
    req: ThresholdUpdate,
    user: dict = Depends(get_current_user)
):
    """
    PUT /api/settings/thresholds
    Ref: Section 4.8 of design doc
    """
    user_id = user.get("id")
    household_id = await get_user_household_id(user_id)
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
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to update thresholds: {str(e)}"}}
        )

@router.get("/contacts")
async def get_contacts(user: dict = Depends(get_current_user)):
    """
    GET /api/contacts
    Ref: Section 4.7 of design doc
    """
    user_id = user.get("id")
    household_id = await get_user_household_id(user_id)
    try:
        res = supabase.table("contacts").select("*").eq("household_id", household_id).order("priority_order").execute()
        return res.data or []
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to retrieve contacts: {str(e)}"}}
        )

@router.post("/contacts")
async def create_contact(
    req: ContactCreate,
    user: dict = Depends(get_current_user)
):
    """
    POST /api/contacts
    Ref: Section 4.7 of design doc
    """
    user_id = user.get("id")
    household_id = await get_user_household_id(user_id)
    try:
        contact_data = {
            "household_id": household_id,
            "user_id": str(req.user_id),
            "priority_order": req.priority_order
        }
        supabase.table("contacts").insert(contact_data).execute()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to create contact: {str(e)}"}}
        )

@router.patch("/contacts/{contact_id}")
async def update_contact(
    contact_id: str,
    priority_order: int,
    user: dict = Depends(get_current_user)
):
    """
    PATCH /api/contacts/{id}
    Ref: Section 4.7 of design doc
    """
    try:
        supabase.table("contacts").update({"priority_order": priority_order}).eq("id", contact_id).execute()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": {"code": "DATABASE_ERROR", "message": f"Failed to update contact: {str(e)}"}}
        )

@router.delete("/contacts/{contact_id}")
async def delete_contact(
    contact_id: str,
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
        deleted_order = deleted_contact["priority_order"]
        
        # 2. Delete contact
        supabase.table("contacts").delete().eq("id", contact_id).execute()
        
        # 3. Reorder remaining contacts to fill the gap (Section 4.7: avoid gaps)
        remaining = supabase.table("contacts").select("*").eq("household_id", household_id).order("priority_order").execute()
        for idx, item in enumerate(remaining.data or []):
            new_order = idx + 1
            if item["priority_order"] != new_order:
                supabase.table("contacts").update({"priority_order": new_order}).eq("id", item["id"]).execute()
                
        return {"status": "ok"}
    except Exception as e:
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "VALIDATION_ERROR", "message": str(e)}}
        )
