import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import get_current_user, get_or_create_user

client = TestClient(app)

# Test users
USER_A = {"id": "user-a-uuid", "firebase_uid": "fb-uid-a", "email": "a@test.com", "role": "family"}
USER_B = {"id": "user-b-uuid", "firebase_uid": "fb-uid-b", "email": "b@test.com", "role": "family"}

@pytest.fixture
def mock_get_current_user():
    # Helper fixture to mock current user context
    pass

@patch("app.core.security.supabase")
def test_case_1_non_member_access_forbidden(mock_supabase):
    """
    User A is owner of household A. User B (non-household member) requests
    GET /api/alerts?household_id=household_A_uuid -> expect 403
    """
    # Override current user to return User B
    async def override_user():
        return USER_B
        
    app.dependency_overrides[get_current_user] = override_user
    
    # Mock database responses
    # Query for membership returns empty -> User B is not in household A
    mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=[])
    
    # Execute GET /api/alerts
    response = client.get("/api/alerts?household_id=household_A_uuid", headers={"Authorization": "Bearer mock-token"})
    
    # Clean up override
    app.dependency_overrides.pop(get_current_user, None)
    
    assert response.status_code == 403
    json_data = response.json()
    assert json_data["detail"]["error"]["code"] == "FORBIDDEN"

@patch("app.core.security.supabase")
@pytest.mark.asyncio
async def test_case_2_and_4_invite_code_flows(mock_supabase):
    """
    Test Case 2: Join with valid code -> enable access.
    Test Case 4: Expired or already used invite code -> expect 400 INVALID_INVITE_CODE.
    """
    # Mocks for invite code lookup
    # 4a. Expired code
    mock_res_expired = MagicMock(data=[{
        "id": "invite-expired-uuid",
        "household_id": "household-a-uuid",
        "code": "EXPIRED_CODE",
        "expires_at": "2020-01-01T00:00:00Z",
        "used_at": None
    }])
    
    # 4b. Used code
    mock_res_used = MagicMock(data=[{
        "id": "invite-used-uuid",
        "household_id": "household-a-uuid",
        "code": "USED_CODE",
        "expires_at": "2030-01-01T00:00:00Z",
        "used_at": "2026-06-16T00:00:00Z"
    }])

    # 4c. Not found code
    mock_res_not_found = MagicMock(data=[])

    # 2a. Valid code
    mock_res_valid = MagicMock(data=[{
        "id": "invite-valid-uuid",
        "household_id": "household-a-uuid",
        "code": "VALID_CODE",
        "expires_at": "2030-01-01T00:00:00Z",
        "used_at": None
    }])

    # Test cases validation for get_or_create_user
    # Mock check user does not exist in users table first
    mock_user_not_exist = MagicMock(data=[])
    
    # Set up mock chain
    mock_supabase.table.return_value.select.return_value.eq.return_value.execute.side_effect = [
        mock_user_not_exist,  # for expired code check
        mock_res_expired,
        mock_user_not_exist,  # for used code check
        mock_res_used,
        mock_user_not_exist,  # for non-existent code check
        mock_res_not_found,
    ]
    
    # 4a. Expired code
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as exc:
        await get_or_create_user("fb-uid-b", "b@test.com", "User B", "EXPIRED_CODE")
    assert exc.value.status_code == 400
    assert exc.value.detail["error"]["code"] == "INVALID_INVITE_CODE"

    # 4b. Used code
    with pytest.raises(HTTPException) as exc:
        await get_or_create_user("fb-uid-b", "b@test.com", "User B", "USED_CODE")
    assert exc.value.status_code == 400
    assert exc.value.detail["error"]["code"] == "INVALID_INVITE_CODE"

    # 4c. Not found code
    with pytest.raises(HTTPException) as exc:
        await get_or_create_user("fb-uid-b", "b@test.com", "User B", "NON_EXISTENT")
    assert exc.value.status_code == 400
    assert exc.value.detail["error"]["code"] == "INVALID_INVITE_CODE"

    # Reset side_effect for Case 2 (Valid Code Join)
    mock_supabase.table.return_value.select.return_value.eq.return_value.execute.side_effect = None
    mock_supabase.table.return_value.select.return_value.eq.return_value.execute.return_value = mock_user_not_exist
    
    # Mock invite code select specifically
    def mock_table_select(table_name):
        mock_query = MagicMock()
        if table_name == "users":
            mock_query.select.return_value.eq.return_value.execute.return_value = mock_user_not_exist
            mock_query.insert.return_value.execute.return_value = MagicMock(data=[USER_B])
        elif table_name == "household_invites":
            mock_query.select.return_value.eq.return_value.execute.return_value = mock_res_valid
            mock_query.update.return_value.eq.return_value.execute.return_value = MagicMock()
        elif table_name == "household_members":
            mock_query.insert.return_value.execute.return_value = MagicMock()
        return mock_query
        
    mock_supabase.table.side_effect = mock_table_select
    
    # Register/Join
    new_user = await get_or_create_user("fb-uid-b", "b@test.com", "User B", "VALID_CODE")
    assert new_user["id"] == USER_B["id"]

@patch("app.core.security.supabase")
@patch("app.api.alerts.supabase")
def test_case_2_access_allowed_after_joining(mock_alerts_supabase, mock_sec_supabase):
    """
    User B (now household member) requests GET /api/alerts?household_id=household_a_uuid -> expect 200
    """
    async def override_user():
        return USER_B
    app.dependency_overrides[get_current_user] = override_user
    
    # Mock membership check to return User B is a member of Household A
    mock_sec_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=[
        {"household_id": "household-a-uuid", "user_id": "user-b-uuid", "role": "member"}
    ])
    
    # Mock query alerts from DB
    mock_alerts_supabase.table.return_value.select.return_value.eq.return_value.order.return_value.range.return_value.execute.return_value = MagicMock(
        data=[], count=0
    )
    
    response = client.get("/api/alerts?household_id=household-a-uuid", headers={"Authorization": "Bearer mock-token"})
    app.dependency_overrides.pop(get_current_user, None)
    
    assert response.status_code == 200

@patch("app.core.security.supabase")
def test_case_3_member_thresholds_forbidden(mock_supabase):
    """
    User B (role member) calls PUT /api/settings/thresholds -> expect 403
    """
    async def override_user():
        return USER_B
    app.dependency_overrides[get_current_user] = override_user
    
    # Mock membership check to return user role as 'member' (not owner)
    mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=[
        {"household_id": "household-a-uuid", "user_id": "user-b-uuid", "role": "member"}
    ])
    
    payload = {
        "low_max_sec": 30,
        "medium_max_sec": 120,
        "high_max_sec": 300,
        "dedup_window_sec": 60,
        "suppress_windows": []
    }
    
    response = client.put("/api/settings/thresholds", json=payload, headers={"Authorization": "Bearer mock-token"})
    app.dependency_overrides.pop(get_current_user, None)
    
    assert response.status_code == 403
    json_data = response.json()
    assert json_data["detail"]["error"]["code"] == "FORBIDDEN"
