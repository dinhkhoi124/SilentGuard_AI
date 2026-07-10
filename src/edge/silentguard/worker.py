from __future__ import annotations

import argparse
import json
import logging
import os
import signal
import statistics
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from .config import EdgeConfig, load_config
from .engine import PoseFallEngine
from .publisher import FramePublisher
from .sender import EventSender
from .stream import LatestFrameCapture, ResolvedStream, StreamUrlResolver

LOGGER = logging.getLogger("silentguard.worker")


class WorkerStatus:
    def __init__(self):
        self._lock = threading.Lock()
        self.started_at = time.time()
        self.model_loaded = False
        self.stream_connected = False
        self.stream_protocol = ""
        self.using_fallback = False
        self.last_frame_at = 0.0
        self.last_incident: dict[str, Any] | None = None
        self.last_error = ""
        self.inference_ms: deque[float] = deque(maxlen=120)
        self.frames_processed = 0
        self.sender_status: dict[str, Any] = {}

    def update(self, **values: Any) -> None:
        with self._lock:
            for key, value in values.items():
                setattr(self, key, value)

    def snapshot(self, stale_frame_sec: float) -> tuple[dict[str, Any], bool]:
        with self._lock:
            timings = list(self.inference_ms)
            mean_ms = statistics.fmean(timings) if timings else 0.0
            now = time.time()
            healthy = bool(
                self.model_loaded
                and self.stream_connected
                and self.last_frame_at
                and now - self.last_frame_at <= stale_frame_sec
            )
            return {
                "status": "ok" if healthy else "degraded",
                "uptime_sec": round(now - self.started_at, 1),
                "model_loaded": self.model_loaded,
                "stream_connected": self.stream_connected,
                "stream_protocol": self.stream_protocol,
                "using_fallback": self.using_fallback,
                "last_frame_at": self.last_frame_at or None,
                "last_frame_age_sec": round(now - self.last_frame_at, 2) if self.last_frame_at else None,
                "frames_processed": self.frames_processed,
                "mean_inference_ms": round(mean_ms, 2),
                "effective_inference_fps": round(1000 / mean_ms, 2) if mean_ms else 0.0,
                "last_incident": self.last_incident,
                "sender": self.sender_status,
                "last_error": self.last_error,
            }, healthy


def start_health_server(status: WorkerStatus, config: EdgeConfig) -> ThreadingHTTPServer:
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):  # noqa: N802
            if self.path not in {"/", "/health", "/ready"}:
                self.send_error(404)
                return
            payload, ready = status.snapshot(config.runtime.stale_frame_sec)
            data = json.dumps(payload).encode("utf-8")
            live = bool(payload["model_loaded"])
            self.send_response(200 if (ready if self.path == "/ready" else live) else 503)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, format: str, *args: Any) -> None:
            return

    server = ThreadingHTTPServer(("0.0.0.0", config.runtime.health_port), Handler)
    threading.Thread(target=server.serve_forever, name="health-server", daemon=True).start()
    return server


class EdgeWorker:
    def __init__(self, config: EdgeConfig):
        self.config = config
        self.status = WorkerStatus()
        self.stop_event = threading.Event()
        self.engine: PoseFallEngine | None = None
        self.sender = EventSender(config.backend, dry_run=config.runtime.dry_run)
        self.resolver = StreamUrlResolver(config.stream, config.backend)
        self.publisher = FramePublisher(
            backend_url=config.backend.base_url,
            camera_id=config.stream.camera_id,
            device_key=config.backend.device_key,
            jpeg_quality=config.backend.publish_jpeg_quality,
            enabled=bool(config.backend.base_url and config.stream.camera_id and config.backend.publish_enabled),
        )

    def stop(self, *_: Any) -> None:
        self.stop_event.set()

    def run(self) -> None:
        health = start_health_server(self.status, self.config)
        self.sender.start()
        self.publisher.start()
        try:
            self.engine = PoseFallEngine(self.config)
            self.status.update(model_loaded=True)
            while not self.stop_event.is_set():
                try:
                    source = self.resolver.resolve(allow_fallback=True)
                    self._consume(source)
                except Exception as exc:
                    LOGGER.exception("Worker source cycle failed")
                    self.status.update(last_error=str(exc), stream_connected=False)
                    self.stop_event.wait(2.0)
        finally:
            self.publisher.stop()
            self.sender.stop()
            health.shutdown()

    def _consume(self, source: ResolvedStream) -> None:
        assert self.engine is not None
        capture = LatestFrameCapture(source, self.config.stream.reconnect_max_sec)
        capture.start()
        sequence = 0
        frame_index = 0
        source_started = time.time()
        LOGGER.info("Consuming %s source (fallback=%s)", source.protocol, source.is_fallback)
        self.status.update(
            stream_protocol=source.protocol,
            using_fallback=source.is_fallback,
            last_error="",
        )
        try:
            while not self.stop_event.is_set():
                if source.expires_at and time.time() >= source.expires_at - self.config.stream.refresh_margin_sec:
                    LOGGER.info("Refreshing expiring stream URL")
                    return
                item = capture.latest(sequence, timeout=1.0)
                self.status.update(stream_connected=capture.connected)
                if item is None:
                    if source.is_fallback and capture.frames_read and not capture.connected:
                        return
                    if time.time() - source_started > self.config.runtime.stale_frame_sec and not capture.connected:
                        raise RuntimeError(f"Stream is stale: {capture.last_error}")
                    continue
                sequence, captured_at, frame = item
                frame_index += 1
                incidents, diagnostics, result = self.engine.process_frame(
                    frame,
                    timestamp=captured_at,
                    frame_index=frame_index,
                )
                self.status.inference_ms.append(diagnostics.inference_ms)
                self.status.update(
                    last_frame_at=captured_at,
                    frames_processed=self.status.frames_processed + 1,
                    stream_connected=True,
                )
                # Push annotated frame to backend relay for live monitoring.
                annotated = result.plot() if result is not None and hasattr(result, "plot") else frame
                self.publisher.put_frame(annotated)
                for incident in incidents:
                    payload = incident.payload(
                        room=self.config.runtime.room,
                        model_version=self.config.runtime.model_version,
                    )
                    self.sender.submit(payload)
                    incident_status = {
                        "event_id": incident.event_id,
                        "track_id": incident.track_id,
                        "confidence": incident.confidence,
                        "detected_at": incident.detected_at,
                    }
                    self.status.update(last_incident=incident_status)
                    LOGGER.warning("FALL CONFIRMED: %s", incident_status)
                self.status.update(sender_status=dict(self.sender.last_result))
        finally:
            capture.stop()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="SilentGuard Railway RTMP AI worker")
    parser.add_argument("--config", default="showcase.yaml")
    parser.add_argument("--dry-run", action="store_true", help="Override config and never send backend events")
    parser.add_argument("--source", help="Override stream URL or local fallback video")
    parser.add_argument("--log-level", default=os.getenv("LOG_LEVEL", "INFO"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(
        level=getattr(logging, args.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    config = load_config(args.config)
    if args.dry_run:
        config.runtime.dry_run = True
    if args.source:
        config.stream.url = args.source
    worker = EdgeWorker(config)
    signal.signal(signal.SIGINT, worker.stop)
    signal.signal(signal.SIGTERM, worker.stop)
    worker.run()


if __name__ == "__main__":
    main()
