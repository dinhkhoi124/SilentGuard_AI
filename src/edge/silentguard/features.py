from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from .types import PoseObservation


@dataclass(slots=True)
class PreviousPose:
    timestamp: float
    hip_x: float
    hip_y: float
    body_height: float


class PoseFeatureExtractor:
    """Convert tracked COCO keypoints into resolution-independent features."""

    def __init__(self, pose_confidence: float):
        self.pose_confidence = pose_confidence
        self.previous: dict[int, PreviousPose] = {}

    def reset(self) -> None:
        self.previous.clear()

    def extract(
        self,
        result: Any,
        timestamp: float,
        track_ids_override: list[int] | None = None,
    ) -> list[PoseObservation]:
        keypoints_obj = getattr(result, "keypoints", None)
        boxes = getattr(result, "boxes", None)
        if keypoints_obj is None or boxes is None or keypoints_obj.data is None:
            return []

        keypoints_batch = keypoints_obj.data.cpu().numpy()
        boxes_xyxy = boxes.xyxy.cpu().numpy()
        ids = getattr(boxes, "id", None)
        if track_ids_override is not None:
            track_ids = track_ids_override
        else:
            track_ids = ids.int().cpu().tolist() if ids is not None else list(range(len(keypoints_batch)))

        observations: list[PoseObservation] = []
        for index, keypoints in enumerate(keypoints_batch):
            if index >= len(boxes_xyxy) or index >= len(track_ids):
                continue
            track_id = int(track_ids[index])
            observation = self._one(track_id, timestamp, keypoints, boxes_xyxy[index])
            if observation is not None:
                observations.append(observation)
        return observations

    def _one(self, track_id: int, timestamp: float, keypoints: Any, bbox: Any) -> PoseObservation | None:
        if len(keypoints) < 13:
            return None
        shoulder_conf = float((keypoints[5][2] + keypoints[6][2]) / 2)
        hip_conf = float((keypoints[11][2] + keypoints[12][2]) / 2)
        pose_confidence = min(shoulder_conf, hip_conf)
        if pose_confidence < self.pose_confidence:
            return None

        shoulder_x = float((keypoints[5][0] + keypoints[6][0]) / 2)
        shoulder_y = float((keypoints[5][1] + keypoints[6][1]) / 2)
        hip_x = float((keypoints[11][0] + keypoints[12][0]) / 2)
        hip_y = float((keypoints[11][1] + keypoints[12][1]) / 2)

        x1, y1, x2, y2 = (float(value) for value in bbox)
        body_height = max(y2 - y1, 1.0)
        torso_angle = math.degrees(math.atan2(abs(hip_x - shoulder_x), abs(hip_y - shoulder_y) + 1e-6))

        downward_velocity = 0.0
        motion = 0.0
        previous = self.previous.get(track_id)
        if previous is not None:
            delta_time = timestamp - previous.timestamp
            if 1e-3 <= delta_time <= 2.0:
                scale = max((body_height + previous.body_height) / 2, 1.0)
                delta_x = hip_x - previous.hip_x
                delta_y = hip_y - previous.hip_y
                downward_velocity = max(0.0, delta_y / scale / delta_time)
                motion = math.hypot(delta_x, delta_y) / scale / delta_time

        self.previous[track_id] = PreviousPose(timestamp, hip_x, hip_y, body_height)
        return PoseObservation(
            track_id=track_id,
            timestamp=timestamp,
            pose_confidence=pose_confidence,
            torso_angle_deg=torso_angle,
            downward_velocity_bh_s=downward_velocity,
            motion_bh_s=motion,
            bbox=(x1, y1, x2, y2),
        )

    def expire(self, active_track_ids: set[int]) -> None:
        for track_id in list(self.previous):
            if track_id not in active_track_ids:
                self.previous.pop(track_id, None)
