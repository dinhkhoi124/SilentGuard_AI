from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
from app.main import app

client = TestClient(app)

@patch("app.api.events.verify_device_key_dependency")
@patch("app.api.events.supabase")
def test_post_detect_event(mock_supabase, mock_verify_device_key):
    # Mock camera authorization dependency
    mock_verify_device_key.return_value = {
        "id": "mock-camera-id",
        "household_id": "mock-household-id",
        "name": "Camera phòng ngủ"
    }

    # Setup mock supabase insert response
    mock_supabase.table.return_value.insert.return_value.execute.return_value = MagicMock()

    payload = {
        "event_id": "EVT-20260616-001",
        "event_type": "fall",
        "severity": "HIGH",
        "confidence": 0.89,
        "timestamp": "2026-06-16T02:15:10Z",
        "duration_sec": 145,
        "room": "bedroom",
        "clip_path": "clips/household-uuid/EVT-20260616-001_blur.mp4",
        "model_ver": "v1.0.0"
    }

    headers = {"X-Device-Key": "sg_dev_bedroom_001"}

    # Execute
    response = client.post("/api/events/detect", json=payload, headers=headers)

    # Assert
    assert response.status_code == 201
    json_data = response.json()
    assert json_data["status"] == "received"
    assert json_data["event_id"] == "EVT-20260616-001"
