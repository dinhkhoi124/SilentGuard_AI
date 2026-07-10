from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import requests

from .config import BackendConfig, StreamConfig

LOGGER = logging.getLogger(__name__)


@dataclass(slots=True)
class ResolvedStream:
    url: str
    protocol: str
    expires_at: float | None = None
    is_fallback: bool = False


class StreamUrlResolver:
    def __init__(
        self,
        stream: StreamConfig,
        backend: BackendConfig,
        *,
        session: Any | None = None,
    ):
        self.stream = stream
        self.backend = backend
        self.session = session or requests.Session()

    def resolve(self, *, allow_fallback: bool = True) -> ResolvedStream:
        if self.stream.url:
            return ResolvedStream(self.stream.url, self._protocol(self.stream.url))
        if self.stream.url_endpoint:
            try:
                return self._from_backend()
            except Exception:
                if not allow_fallback or not self.stream.fallback_video:
                    raise
                LOGGER.exception("Stream URL resolution failed; using fallback video")
        if self.stream.fallback_video and allow_fallback:
            return ResolvedStream(
                self.stream.fallback_video,
                "file",
                is_fallback=True,
            )
        raise ValueError("Configure STREAM_URL, STREAM_URL_ENDPOINT, or FALLBACK_VIDEO")

    def _from_backend(self) -> ResolvedStream:
        endpoint = self.stream.url_endpoint.format(camera_id=self.stream.camera_id)
        if not endpoint.startswith(("http://", "https://")):
            if not self.backend.base_url:
                raise ValueError("BACKEND_URL is required for a relative stream URL endpoint")
            endpoint = self.backend.base_url.rstrip("/") + "/" + endpoint.lstrip("/")
        headers: dict[str, str] = {}
        if self.backend.device_key:
            headers["X-Device-Key"] = self.backend.device_key
        if self.backend.auth_token:
            headers["Authorization"] = f"Bearer {self.backend.auth_token}"
        response = self.session.get(endpoint, headers=headers, timeout=self.backend.request_timeout_sec)
        response.raise_for_status()
        body = response.json()
        url = str(body.get("url", "")).strip()
        if not url:
            raise RuntimeError("Stream URL endpoint returned no url")
        return ResolvedStream(
            url=url,
            protocol=str(body.get("protocol") or self._protocol(url)),
            expires_at=self._parse_expiry(body.get("expires_at")),
        )

    @staticmethod
    def _protocol(url: str) -> str:
        return url.split(":", 1)[0].lower() if ":" in url else "file"

    @staticmethod
    def _parse_expiry(value: Any) -> float | None:
        if value in (None, ""):
            return None
        if isinstance(value, (int, float)):
            return float(value)
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=UTC)
        return parsed.timestamp()


class LatestFrameCapture:
    """Capture in a daemon thread while retaining only the newest frame."""

    def __init__(self, source: ResolvedStream, reconnect_max_sec: int = 15):
        self.source = source
        self.reconnect_max_sec = reconnect_max_sec
        self._condition = threading.Condition()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._frame: Any | None = None
        self._timestamp = 0.0
        self._sequence = 0
        self.connected = False
        self.last_error = ""
        self.frames_read = 0

    def start(self) -> None:
        self._thread = threading.Thread(target=self._run, name="stream-capture", daemon=True)
        self._thread.start()

    def stop(self, timeout: float = 2.0) -> None:
        self._stop.set()
        with self._condition:
            self._condition.notify_all()
        if self._thread:
            self._thread.join(timeout=timeout)

    def latest(self, after_sequence: int, timeout: float = 1.0) -> tuple[int, float, Any] | None:
        with self._condition:
            self._condition.wait_for(
                lambda: self._sequence > after_sequence or self._stop.is_set(),
                timeout=timeout,
            )
            if self._sequence <= after_sequence or self._frame is None:
                return None
            return self._sequence, self._timestamp, self._frame.copy()

    def _run(self) -> None:
        import cv2

        delay = 1.0
        while not self._stop.is_set():
            capture = cv2.VideoCapture(self.source.url)
            if not capture.isOpened():
                self.connected = False
                self.last_error = "open_failed"
                self._sleep(delay)
                delay = min(delay * 2, float(self.reconnect_max_sec))
                continue
            capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            self.connected = True
            self.last_error = ""
            delay = 1.0
            try:
                while not self._stop.is_set():
                    ok, frame = capture.read()
                    if not ok:
                        self.connected = False
                        self.last_error = "read_failed"
                        break
                    now = time.time()
                    with self._condition:
                        self._frame = frame
                        self._timestamp = now
                        self._sequence += 1
                        self.frames_read += 1
                        self._condition.notify_all()
                    if self.source.is_fallback:
                        fps = float(capture.get(cv2.CAP_PROP_FPS)) or 24.0
                        self._sleep(1.0 / fps)
            finally:
                capture.release()
            self._sleep(delay)
            delay = min(delay * 2, float(self.reconnect_max_sec))

    def _sleep(self, seconds: float) -> None:
        self._stop.wait(seconds)
