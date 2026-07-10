from __future__ import annotations

import copy
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


@dataclass(slots=True)
class ModelConfig:
    path: str = "yolov8n-pose.pt"
    image_size: int = 416
    device: str = "cpu"
    tracker: str = "bytetrack.yaml"
    pose_confidence: float = 0.40
    single_person_mode: bool = True


@dataclass(slots=True)
class FallConfig:
    descending_velocity_bh_s: float = 0.60
    lying_torso_angle_deg: float = 50.0
    transition_limit_sec: float = 2.0
    lying_confirmation_sec: float = 1.0
    lying_gap_tolerance_sec: float = 0.35
    recovery_angle_deg: float = 30.0
    recovery_upright_sec: float = 3.0
    track_expiry_sec: float = 5.0


@dataclass(slots=True)
class StreamConfig:
    url: str = ""
    url_endpoint: str = ""
    camera_id: str = ""
    fallback_video: str = ""
    refresh_margin_sec: int = 300
    reconnect_max_sec: int = 15
    buffer_size: int = 1


@dataclass(slots=True)
class BackendConfig:
    base_url: str = ""
    event_path: str = "/api/events/detect"
    device_key: str = ""
    auth_token: str = ""
    request_timeout_sec: float = 10.0
    retry_delays_sec: list[float] = field(default_factory=lambda: [1, 2, 4, 8])
    publish_enabled: bool = True
    publish_jpeg_quality: int = 70


@dataclass(slots=True)
class RuntimeConfig:
    dry_run: bool = True
    room: str = "showcase"
    model_version: str = "fall-engine-v2-showcase"
    source_name: str = "imou_rtmp"
    health_port: int = 8080
    stale_frame_sec: float = 30.0
    diagnostics_path: str = "reports/latest_run.json"


@dataclass(slots=True)
class EdgeConfig:
    model: ModelConfig = field(default_factory=ModelConfig)
    fall: FallConfig = field(default_factory=FallConfig)
    stream: StreamConfig = field(default_factory=StreamConfig)
    backend: BackendConfig = field(default_factory=BackendConfig)
    runtime: RuntimeConfig = field(default_factory=RuntimeConfig)


ENV_OVERRIDES: dict[str, tuple[str, str, Any]] = {
    "MODEL_PATH": ("model", "path", str),
    "MODEL_IMAGE_SIZE": ("model", "image_size", int),
    "MODEL_DEVICE": ("model", "device", str),
    "STREAM_URL": ("stream", "url", str),
    "STREAM_URL_ENDPOINT": ("stream", "url_endpoint", str),
    "CAMERA_ID": ("stream", "camera_id", str),
    "FALLBACK_VIDEO": ("stream", "fallback_video", str),
    "BACKEND_URL": ("backend", "base_url", str),
    "DEVICE_KEY": ("backend", "device_key", str),
    "BACKEND_AUTH_TOKEN": ("backend", "auth_token", str),
    "FALL_DRY_RUN": ("runtime", "dry_run", lambda value: value.lower() in {"1", "true", "yes"}),
    "ROOM": ("runtime", "room", str),
    "PORT": ("runtime", "health_port", int),
    "PUBLISH_ENABLED": ("backend", "publish_enabled", lambda v: v.lower() not in {"0", "false", "no"}),
    "PUBLISH_JPEG_QUALITY": ("backend", "publish_jpeg_quality", int),
}


def _build_section(section_type: type, values: dict[str, Any] | None):
    allowed = section_type.__dataclass_fields__
    filtered = {key: value for key, value in (values or {}).items() if key in allowed}
    return section_type(**filtered)


def load_config(path: str | Path | None = None) -> EdgeConfig:
    raw: dict[str, Any] = {}
    if path:
        config_path = Path(path)
        if not config_path.exists():
            raise FileNotFoundError(f"Config file not found: {config_path}")
        raw = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}

    config = EdgeConfig(
        model=_build_section(ModelConfig, raw.get("model")),
        fall=_build_section(FallConfig, raw.get("fall")),
        stream=_build_section(StreamConfig, raw.get("stream")),
        backend=_build_section(BackendConfig, raw.get("backend")),
        runtime=_build_section(RuntimeConfig, raw.get("runtime")),
    )

    for env_name, (section_name, field_name, converter) in ENV_OVERRIDES.items():
        value = os.getenv(env_name)
        if value is not None and value != "":
            setattr(getattr(config, section_name), field_name, converter(value))
    return config


def clone_config(config: EdgeConfig) -> EdgeConfig:
    return copy.deepcopy(config)
