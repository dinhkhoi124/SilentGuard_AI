from __future__ import annotations

import statistics
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .config import EdgeConfig
from .features import PoseFeatureExtractor
from .state_machine import FallStateMachine
from .tracking import IoUTracker
from .types import FallIncident, FrameDiagnostics


@dataclass(slots=True)
class VideoRunResult:
    source: str
    frames: int = 0
    duration_sec: float = 0.0
    incidents: list[FallIncident] = field(default_factory=list)
    diagnostics: list[FrameDiagnostics] = field(default_factory=list)
    inference_ms: list[float] = field(default_factory=list)
    observed_pose_frames: int = 0

    def metrics(self) -> dict[str, float | int | str]:
        timings = sorted(self.inference_ms)
        mean_ms = statistics.fmean(timings) if timings else 0.0
        p95_index = max(0, min(len(timings) - 1, int(len(timings) * 0.95) - 1)) if timings else 0
        return {
            "source": self.source,
            "frames": self.frames,
            "duration_sec": round(self.duration_sec, 3),
            "incidents": len(self.incidents),
            "pose_availability": round(self.observed_pose_frames / self.frames, 4) if self.frames else 0.0,
            "mean_inference_ms": round(mean_ms, 3),
            "p95_inference_ms": round(timings[p95_index], 3) if timings else 0.0,
            "effective_inference_fps": round(1000 / mean_ms, 3) if mean_ms else 0.0,
        }


class PoseFallEngine:
    def __init__(self, config: EdgeConfig, model: Any | None = None):
        self.config = config
        self.model = model or self._load_model()
        self.features = PoseFeatureExtractor(config.model.pose_confidence)
        self.machine = FallStateMachine(config.fall)
        self.fallback_tracker = IoUTracker()
        self.byte_track_available = self._byte_track_available()

    def _load_model(self):
        from ultralytics import YOLO

        model_path = Path(self.config.model.path)
        if not model_path.exists():
            raise FileNotFoundError(f"YOLO model not found: {model_path}")
        return YOLO(str(model_path))

    @staticmethod
    def _byte_track_available() -> bool:
        try:
            import lap

            return callable(getattr(lap, "lapjv", None))
        except ImportError:
            return False

    def reset(self) -> None:
        self.features.reset()
        self.machine = FallStateMachine(self.config.fall)
        self.fallback_tracker.reset()
        if hasattr(self.model, "predictor"):
            self.model.predictor = None

    def process_frame(
        self,
        frame: Any,
        *,
        timestamp: float,
        frame_index: int,
    ) -> tuple[list[FallIncident], FrameDiagnostics, Any]:
        started = time.perf_counter()
        if self.byte_track_available:
            results = self.model.track(
                frame,
                persist=True,
                tracker=self.config.model.tracker,
                imgsz=self.config.model.image_size,
                device=self.config.model.device,
                verbose=False,
            )
            track_ids_override = None
        else:
            results = self.model.predict(
                frame,
                imgsz=self.config.model.image_size,
                device=self.config.model.device,
                verbose=False,
            )
            boxes = results[0].boxes.xyxy.cpu().numpy() if results[0].boxes is not None else []
            track_ids_override = self.fallback_tracker.update(boxes)
        inference_ms = (time.perf_counter() - started) * 1000
        result = results[0]
        observations = self.features.extract(result, timestamp, track_ids_override)
        if self.config.model.single_person_mode and observations:
            primary = max(
                observations,
                key=lambda item: (item.bbox[2] - item.bbox[0]) * (item.bbox[3] - item.bbox[1]),
            )
            primary.track_id = 1
            observations = [primary]
        incidents: list[FallIncident] = []
        for observation in observations:
            incident = self.machine.update(observation)
            if incident is not None:
                incidents.append(incident)
        self.machine.expire(timestamp)
        states = {
            observation.track_id: self.machine.state_for(observation.track_id).value
            for observation in observations
        }
        diagnostics = FrameDiagnostics(
            frame_index=frame_index,
            timestamp=timestamp,
            inference_ms=inference_ms,
            observations=observations,
            states=states,
        )
        return incidents, diagnostics, result

    def process_video(self, path: str | Path, *, keep_diagnostics: bool = True) -> VideoRunResult:
        import cv2

        source = str(path)
        capture = cv2.VideoCapture(source)
        if not capture.isOpened():
            raise RuntimeError(f"Cannot open video: {source}")
        fps = float(capture.get(cv2.CAP_PROP_FPS)) or 24.0
        result = VideoRunResult(source=source)
        self.reset()
        try:
            while True:
                ok, frame = capture.read()
                if not ok:
                    break
                result.frames += 1
                timestamp = result.frames / fps
                incidents, diagnostics, _ = self.process_frame(
                    frame,
                    timestamp=timestamp,
                    frame_index=result.frames,
                )
                result.incidents.extend(incidents)
                result.inference_ms.append(diagnostics.inference_ms)
                if diagnostics.observations:
                    result.observed_pose_frames += 1
                if keep_diagnostics:
                    result.diagnostics.append(diagnostics)
            result.duration_sec = result.frames / fps
            return result
        finally:
            capture.release()
