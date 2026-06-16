import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from app.services.alert_engine import process_event

@pytest.mark.asyncio
@patch("app.services.alert_engine.get_thresholds")
@patch("app.services.alert_engine.get_contacts_sorted")
@patch("app.services.alert_engine.send_push")
@patch("app.services.alert_engine.save_event")
@patch("app.services.alert_engine.supabase")
async def test_process_event_deduplication(
    mock_supabase, mock_save_event, mock_send_push, mock_get_contacts, mock_get_thresholds
):
    # Setup mock thresholds
    mock_get_thresholds.return_value = {
        "low_max_sec": 30,
        "medium_max_sec": 120,
        "high_max_sec": 300,
        "dedup_window_sec": 60,
        "suppress_windows": []
    }
    
    # 1. Setup mock duplicate query: return mock_execute for any chained query
    mock_execute = MagicMock()
    mock_execute.data = [{"id": "another-event-uuid"}]
    
    mock_supabase.table.return_value = mock_supabase
    mock_supabase.select.return_value = mock_supabase
    mock_supabase.eq.return_value = mock_supabase
    mock_supabase.neq.return_value = mock_supabase
    mock_supabase.gt.return_value = mock_supabase
    mock_supabase.execute.return_value = mock_execute

    event = {
        "id": "event-uuid",
        "household_id": "household-uuid",
        "event_type": "fall",
        "timestamp": "2026-06-16T12:00:00Z",
        "duration_sec": 100,
        "severity": "MEDIUM",
        "status": "pending"
    }

    # Execute
    await process_event(event)

    # Verify duplicate event was marked as logged_only and did NOT call push
    assert event["status"] == "logged_only"
    mock_send_push.assert_not_called()
