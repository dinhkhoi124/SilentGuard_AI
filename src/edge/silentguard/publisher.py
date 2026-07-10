"""FramePublisher — Streams annotated JPEG frames to the Backend WebSocket relay.

Runs in a background daemon thread, reconnects automatically on failure.
Push frames via put_frame(); frames are dropped if the queue is full (back-pressure).
"""
from __future__ import annotations

import logging
import queue
import threading
import time
from typing import Any

import cv2

LOGGER = logging.getLogger("silentguard.publisher")

# Maximum JPEG quality — lower = smaller payload, less bandwidth, higher latency tolerance.
_JPEG_QUALITY = int(50)
# Maximum frames queued before old frames are dropped to avoid memory growth.
_QUEUE_MAX = 90


class FramePublisher:
    """Non-blocking WebSocket frame publisher for the Backend MJPEG relay."""

    def __init__(
        self,
        backend_url: str,
        camera_id: str,
        *,
        device_key: str = "",
        jpeg_quality: int = _JPEG_QUALITY,
        enabled: bool = True,
    ) -> None:
        self.backend_url = backend_url.rstrip("/")
        self.camera_id = camera_id
        self.device_key = device_key
        self.jpeg_quality = jpeg_quality
        self.enabled = enabled

        self._queue: queue.Queue[Any] = queue.Queue(maxsize=_QUEUE_MAX)
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def start(self) -> None:
        if not self.enabled:
            LOGGER.info("[FramePublisher] disabled — skipping start")
            return
        if self._thread and self._thread.is_alive():
            return
        self._thread = threading.Thread(
            target=self._run, name="frame-publisher", daemon=True
        )
        self._thread.start()
        LOGGER.info(
            "[FramePublisher] started → %s/api/streams/%s/publish",
            self.backend_url,
            self.camera_id,
        )

    def stop(self, timeout: float = 3.0) -> None:
        self._stop.set()
        try:
            self._queue.put_nowait(None)
        except queue.Full:
            pass
        if self._thread:
            self._thread.join(timeout=timeout)

    def put_frame(self, frame: Any) -> None:
        """Encode *frame* (numpy BGR array) as JPEG and enqueue for publishing.

        Frames are dropped silently when the internal queue is full so that the
        main inference loop is never blocked.
        """
        if not self.enabled or self._stop.is_set():
            return
        ok, buf = cv2.imencode(
            ".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, self.jpeg_quality]
        )
        if not ok:
            return
        try:
            self._queue.put_nowait(buf.tobytes())
        except queue.Full:
            # Drop oldest frame, then try once more
            try:
                self._queue.get_nowait()
                self._queue.put_nowait(buf.tobytes())
            except (queue.Empty, queue.Full):
                pass

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _ws_url(self) -> str:
        base = self.backend_url
        if base.startswith("https://"):
            base = "wss://" + base[len("https://"):]
        elif base.startswith("http://"):
            base = "ws://" + base[len("http://"):]
        return f"{base}/api/streams/{self.camera_id}/publish"

    def _run(self) -> None:
        import websockets.sync.client as wsc

        reconnect_delay = 2.0

        while not self._stop.is_set():
            url = self._ws_url()
            headers = {}
            if self.device_key:
                headers["X-Device-Key"] = self.device_key

            try:
                LOGGER.info("[FramePublisher] connecting to %s", url)
                with wsc.connect(url, additional_headers=headers, open_timeout=10) as ws:
                    LOGGER.info("[FramePublisher] connected ✓")
                    reconnect_delay = 2.0
                    while not self._stop.is_set():
                        try:
                            frame_bytes = self._queue.get(timeout=0.5)
                        except queue.Empty:
                            continue
                        if frame_bytes is None:
                            return
                        ws.send(frame_bytes)
            except Exception as exc:
                if self._stop.is_set():
                    break
                LOGGER.warning(
                    "[FramePublisher] disconnected (%s) — retry in %.1fs",
                    exc,
                    reconnect_delay,
                )
                self._stop.wait(reconnect_delay)
                reconnect_delay = min(reconnect_delay * 2, 30.0)

        LOGGER.info("[FramePublisher] stopped")
