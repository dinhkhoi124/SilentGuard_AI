from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class TrackedBox:
    track_id: int
    bbox: tuple[float, float, float, float]
    missed: int = 0


class IoUTracker:
    """Small dependency-free fallback tracker for showcase/evaluation."""

    def __init__(self, iou_threshold: float = 0.3, max_missed: int = 15):
        self.iou_threshold = iou_threshold
        self.max_missed = max_missed
        self.tracks: dict[int, TrackedBox] = {}
        self.next_id = 1

    def reset(self) -> None:
        self.tracks.clear()
        self.next_id = 1

    def update(self, boxes: Any) -> list[int]:
        detections = [tuple(float(value) for value in box) for box in boxes]
        available = set(self.tracks)
        assignments: list[int] = []
        for detection in detections:
            best_id = None
            best_iou = self.iou_threshold
            for track_id in available:
                overlap = self._iou(detection, self.tracks[track_id].bbox)
                if overlap >= best_iou:
                    best_iou = overlap
                    best_id = track_id
            if best_id is None:
                best_id = self.next_id
                self.next_id += 1
                self.tracks[best_id] = TrackedBox(best_id, detection)
            else:
                available.remove(best_id)
                self.tracks[best_id].bbox = detection
                self.tracks[best_id].missed = 0
            assignments.append(best_id)

        assigned = set(assignments)
        for track_id in list(self.tracks):
            if track_id not in assigned:
                self.tracks[track_id].missed += 1
                if self.tracks[track_id].missed > self.max_missed:
                    del self.tracks[track_id]
        return assignments

    @staticmethod
    def _iou(a: tuple[float, ...], b: tuple[float, ...]) -> float:
        x1 = max(a[0], b[0])
        y1 = max(a[1], b[1])
        x2 = min(a[2], b[2])
        y2 = min(a[3], b[3])
        intersection = max(0.0, x2 - x1) * max(0.0, y2 - y1)
        area_a = max(0.0, a[2] - a[0]) * max(0.0, a[3] - a[1])
        area_b = max(0.0, b[2] - b[0]) * max(0.0, b[3] - b[1])
        union = area_a + area_b - intersection
        return intersection / union if union else 0.0

