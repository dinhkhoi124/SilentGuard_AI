from fastapi import APIRouter, Depends
from app.core.security import get_current_user
from app.models.schemas import ThresholdUpdate, ContactCreate, LLMConfigRequest

router = APIRouter(prefix="/api", tags=["Settings"])

@router.get("/settings/thresholds")
async def get_thresholds(user: dict = Depends(get_current_user)):
    """
    GET /api/settings/thresholds
    Ref: Section 4.8 of design doc
    """
    # TODO: Fetch threshold configuration
    return {}

@router.put("/settings/thresholds")
async def update_thresholds(
    req: ThresholdUpdate,
    user: dict = Depends(get_current_user)
):
    """
    PUT /api/settings/thresholds
    Ref: Section 4.8 of design doc
    """
    # TODO: Update thresholds config
    return {"status": "ok"}

@router.get("/contacts")
async def get_contacts(user: dict = Depends(get_current_user)):
    """
    GET /api/contacts
    Ref: Section 4.7 of design doc
    """
    # TODO: Get priority contacts
    return []

@router.post("/contacts")
async def create_contact(
    req: ContactCreate,
    user: dict = Depends(get_current_user)
):
    """
    POST /api/contacts
    Ref: Section 4.7 of design doc
    """
    # TODO: Create priority contact
    return {}

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
    # TODO: Update priority order and reorder gaps
    return {"status": "ok"}

@router.delete("/contacts/{contact_id}")
async def delete_contact(
    contact_id: str,
    user: dict = Depends(get_current_user)
):
    """
    DELETE /api/contacts/{id}
    Ref: Section 4.7 of design doc
    """
    # TODO: Delete priority contact and reorder lists
    return {"status": "ok"}

@router.post("/llm/config")
async def chat_config(
    req: LLMConfigRequest,
    user: dict = Depends(get_current_user)
):
    """
    POST /api/llm/config
    Ref: Section 4.9 of design doc
    """
    # TODO: Call LLMService.parse_config and return config preview
    return {}
