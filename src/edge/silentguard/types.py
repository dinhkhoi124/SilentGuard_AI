from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from enum import StrEnum
from typing import Any


class FallState(StrEnum):
    UPRIGHT = "UPRIGHT"
    DESCENDING = "DESCENDING"
    LYING_CONFIRMING = "LYING_CONFIRMING"
    FALL_CONFIRMED = "FALL_CONFIRMED"
    LYING = "LYING"
    RECOVERED = "RECOVERED"


@dataclass(slots=True)
class PoseObservation:
    track_id: int
    timestamp: float
    pose_confidence: float
    torso_angle_deg: float
    downward_velocity_bh_s: float
    motion_bh_s: float
    bbox: tuple[float, float, float, float]

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["bbox"] = list(self.bbox)
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> PoseObservation:
        values = dict(data)
        values["bbox"] = tuple(values.get("bbox", (0, 0, 0, 0)))
        return cls(**values)


@dataclass(slots=True)
class FallIncident:
    event_id: str
    track_id: int
    detected_at: float
    confidence: float
    lying_duration_sec: float
    state: FallState = FallState.FALL_CONFIRMED

    def payload(
        self,
        *,
        room: str,
        model_version: str,
    ) -> dict[str, Any]:
        timestamp = datetime.fromtimestamp(self.detected_at, tz=UTC)
        return {
            "event_id": self.event_id,
            "event_type": "fall",
            "severity": "HIGH",
            "confidence": round(max(0.0, min(1.0, self.confidence)), 4),
            "timestamp": timestamp.isoformat().replace("+00:00", "Z"),
            "duration_sec": max(1, round(self.lying_duration_sec)),
            "room": room,
            "model_ver": model_version,
        }


@dataclass(slots=True)
class FrameDiagnostics:
    frame_index: int
    timestamp: float
    inference_ms: float
    observations: list[PoseObservation]
    states: dict[int, str]

    def to_dict(self) -> dict[str, Any]:
        return {
            "frame_index": self.frame_index,
            "timestamp": self.timestamp,
            "inference_ms": self.inference_ms,
            "observations": [item.to_dict() for item in self.observations],
            "states": self.states,
        }
