from __future__ import annotations

import logging
import queue
import threading
import time
from typing import Any

import requests

from .config import BackendConfig

LOGGER = logging.getLogger(__name__)


class EventSender:
    """Non-blocking event sender; retries preserve the original event_id."""

    def __init__(self, config: BackendConfig, *, dry_run: bool, session: Any | None = None):
        self.config = config
        self.dry_run = dry_run
        self.session = session or requests.Session()
        self.events: queue.Queue[dict[str, Any] | None] = queue.Queue(maxsize=100)
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.last_result: dict[str, Any] = {}

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._thread = threading.Thread(target=self._run, name="event-sender", daemon=True)
        self._thread.start()

    def submit(self, payload: dict[str, Any]) -> bool:
        if self.dry_run:
            LOGGER.info("DRY RUN event: %s", payload)
            self.last_result = {"status": "dry_run", "event_id": payload.get("event_id")}
            return True
        try:
            self.events.put_nowait(dict(payload))
            return True
        except queue.Full:
            LOGGER.error("Event queue is full; preserving incident in logs: %s", payload)
            self.last_result = {"status": "queue_full", "event_id": payload.get("event_id")}
            return False

    def stop(self, timeout: float = 5.0) -> None:
        self._stop.set()
        try:
            self.events.put_nowait(None)
        except queue.Full:
            pass
        if self._thread:
            self._thread.join(timeout=timeout)

    def send_once(self, payload: dict[str, Any]) -> bool:
        if not self.config.base_url:
            raise ValueError("BACKEND_URL is required when dry_run is false")
        url = self.config.base_url.rstrip("/") + "/" + self.config.event_path.lstrip("/")
        headers = {"Content-Type": "application/json"}
        if self.config.device_key:
            headers["X-Device-Key"] = self.config.device_key
        if self.config.auth_token:
            headers["Authorization"] = f"Bearer {self.config.auth_token}"
        response = self.session.post(
            url,
            json=payload,
            headers=headers,
            timeout=self.config.request_timeout_sec,
        )
        if response.status_code in (200, 201, 202):
            self.last_result = {
                "status": "sent",
                "event_id": payload.get("event_id"),
                "status_code": response.status_code,
            }
            return True
        self.last_result = {
            "status": "failed",
            "event_id": payload.get("event_id"),
            "status_code": response.status_code,
            "body": response.text[:500],
        }
        return False

    def _run(self) -> None:
        while not self._stop.is_set():
            try:
                payload = self.events.get(timeout=0.5)
            except queue.Empty:
                continue
            if payload is None:
                return
            delays = [0.0, *self.config.retry_delays_sec]
            for attempt, delay in enumerate(delays, start=1):
                if self._stop.is_set():
                    break
                if delay:
                    time.sleep(delay)
                try:
                    if self.send_once(payload):
                        break
                except Exception as exc:
                    self.last_result = {
                        "status": "error",
                        "event_id": payload.get("event_id"),
                        "attempt": attempt,
                        "error": str(exc),
                    }
                    LOGGER.warning("Event send attempt %s failed: %s", attempt, exc)
            self.events.task_done()
