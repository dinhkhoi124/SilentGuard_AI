# app/db/queries.py
"""
Supabase / Postgres Queries Module for SilentGuard
Ref: Section 2 - Database Schema and Section 6 - Alert Engine
"""
from app.core.supabase_client import supabase

async def get_thresholds(household_id: str) -> dict:
    """
    Fetch household specific thresholds.
    Ref: Section 2 thresholds table & Section 6 get_thresholds
    """
    try:
        response = supabase.table("thresholds").select("*").eq("household_id", household_id).execute()
        if response.data and len(response.data) > 0:
            return response.data[0]
    except Exception as e:
        print(f"Error fetching thresholds: {e}")
    
    # Fallback to default thresholds
    return {
        "household_id": household_id,
        "low_max_sec": 30,
        "medium_max_sec": 120,
        "high_max_sec": 300,
        "dedup_window_sec": 60,
        "suppress_windows": []
    }

async def get_contacts_sorted(household_id: str) -> list:
    """
    Fetch contacts sorted by priority order for escalation, joined with users to get FCM tokens.
    Ref: Section 2 contacts/users tables & Section 6 get_contacts_sorted
    """
    try:
        # We perform a select joining users table to fetch user details (including fcm_token)
        response = supabase.table("contacts")\
            .select("*, users(*)")\
            .eq("household_id", household_id)\
            .order("priority_order", desc=False)\
            .execute()
        
        # Flatten structure for convenience
        contacts_list = []
        for item in (response.data or []):
            user_info = item.get("users") or {}
            contact_detail = {
                "id": item.get("id"),
                "household_id": item.get("household_id"),
                "user_id": item.get("user_id"),
                "priority_order": item.get("priority_order"),
                "full_name": user_info.get("full_name"),
                "email": user_info.get("email"),
                "phone": user_info.get("phone"),
                "fcm_token": user_info.get("fcm_token")
            }
            contacts_list.append(contact_detail)
        return contacts_list
    except Exception as e:
        print(f"Error fetching contacts: {e}")
        return []

async def save_event(event_data: dict) -> None:
    """
    Create or update event record in events table.
    Ref: Section 2 events table & Section 6 save_event
    """
    try:
        supabase.table("events").upsert(event_data).execute()
    except Exception as e:
        print(f"Error saving event data: {e}")
