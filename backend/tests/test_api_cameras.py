import pytest
import hashlib
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import get_current_user

client = TestClient(app)

# Test users
USER_OWNER = {"id": "owner-uuid", "firebase_uid": "owner-fb-uid", "email": "owner@test.com", "role": "family"}
USER_MEMBER = {"id": "member-uuid", "firebase_uid": "member-fb-uid", "email": "member@test.com", "role": "family"}

CAMERA_DB_ROW = {
    "id": "camera-uuid",
    "household_id": "household-uuid",
    "name": "Camera Living Room",
    "room": "living-room",
    "fps": 15,
    "device_api_key_hash": hashlib.sha256(b"mock_key").hexdigest(),
    "status": "unknown",
    "deleted_at": None,
    "created_at": "2026-06-16T00:00:00Z"
}

@patch("app.api.cameras.supabase")
@patch("app.core.security.supabase")
def test_camera_management_flows(mock_sec_supabase, mock_cam_supabase):
    """
    1. Owner creates camera -> expect 201 with plain key.
    2. GET /api/cameras immediately after -> lists cameras, no keys or hashes.
    3. Member (non-owner) calls POST /api/cameras -> expect 403.
    """
    # Override user to Owner
    async def override_owner():
        return USER_OWNER
    app.dependency_overrides[get_current_user] = override_owner

    # Mock require_household_role dependency checking (returns membership)
    # Owner has owner role in household-uuid
    mock_sec_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=[
        {"household_id": "household-uuid", "user_id": "owner-uuid", "role": "owner"}
    ])

    # Mock camera insertion
    mock_cam_supabase.table.return_value.insert.return_value.execute.return_value = MagicMock(data=[CAMERA_DB_ROW])

    # 1. Create camera
    payload = {
        "household_id": "household-uuid",
        "name": "Camera Living Room",
        "room": "living-room",
        "fps": 15
    }
    response = client.post("/api/cameras", json=payload, headers={"Authorization": "Bearer mock-token"})
    assert response.status_code == 201
    json_data = response.json()
    assert "device_api_key" in json_data
    assert json_data["device_api_key"].startswith("sg_live_")
    assert "warning" in json_data

    # 2. List cameras
    # Mock camera select return list
    mock_cam_supabase.table.return_value.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[CAMERA_DB_ROW])
    
    response = client.get("/api/cameras?household_id=household-uuid", headers={"Authorization": "Bearer mock-token"})
    assert response.status_code == 200
    cameras_list = response.json()
    assert len(cameras_list) == 1
    assert "device_api_key" not in cameras_list[0]
    assert "device_api_key_hash" not in cameras_list[0]

    # 3. Member tries to create camera -> expect 403
    async def override_member():
        return USER_MEMBER
    app.dependency_overrides[get_current_user] = override_member

    # Mock member role check
    mock_sec_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=[
        {"household_id": "household-uuid", "user_id": "member-uuid", "role": "member"}
    ])

    response = client.post("/api/cameras", json=payload, headers={"Authorization": "Bearer mock-token"})
    assert response.status_code == 403
    assert response.json()["detail"]["error"]["code"] == "FORBIDDEN"

    # Reset overrides
    app.dependency_overrides.pop(get_current_user, None)

@patch("app.core.security.supabase")
@patch("app.api.events.supabase")
def test_device_auth_and_rotate(mock_events_supabase, mock_sec_supabase):
    """
    4. Call POST /api/events/detect with Key A -> 201 (verify key works with route).
    5. Rotate key -> old key (Key A) -> 401, new key (Key B) -> 201.
    """
    # Key A and Key B
    key_a = "sg_live_key_a_12345678901234567890123"
    key_b = "sg_live_key_b_12345678901234567890123"
    hash_a = hashlib.sha256(key_a.encode()).hexdigest()
    hash_b = hashlib.sha256(key_b.encode()).hexdigest()

    # Database state mock - initially holds Key A
    current_camera_state = CAMERA_DB_ROW.copy()
    current_camera_state["device_api_key_hash"] = hash_a

    # Define dynamic mock for verify_device_key_dependency lookup
    def mock_table_select(table_name):
        mock_query = MagicMock()
        if table_name == "cameras":
            def execute_side_effect():
                args, kwargs = mock_query.select.return_value.eq.call_args
                hashed_val = args[1]
                if hashed_val == current_camera_state["device_api_key_hash"]:
                    return MagicMock(data=[current_camera_state])
                else:
                    return MagicMock(data=[])
            mock_query.select.return_value.eq.return_value.execute.side_effect = execute_side_effect
        return mock_query

    mock_sec_supabase.table.side_effect = mock_table_select
    mock_events_supabase.table.return_value.insert.return_value.execute.return_value = MagicMock(data=[])

    # 4. Call POST /api/events/detect with Key A -> works (201)
    payload = {
        "event_id": "EVT-20260616-099",
        "event_type": "fall",
        "severity": "HIGH",
        "confidence": 0.95,
        "timestamp": "2026-06-16T09:00:00Z"
    }
    response = client.post("/api/events/detect", json=payload, headers={"X-Device-Key": key_a})
    assert response.status_code == 201

    # 5. Rotate key (simulating key change in DB)
    current_camera_state["device_api_key_hash"] = hash_b

    # Verify old key (Key A) now fails with 401
    response_old = client.post("/api/events/detect", json=payload, headers={"X-Device-Key": key_a})
    assert response_old.status_code == 401

    # Verify new key (Key B) now works with 201
    response_new = client.post("/api/events/detect", json=payload, headers={"X-Device-Key": key_b})
    assert response_new.status_code == 201
