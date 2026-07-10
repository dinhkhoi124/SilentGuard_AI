#!/usr/bin/env python3
"""
SilentGuard AI — Real-time Continuous Edge Monitoring Demo Script (MVP V3)
Ported from the updated continuous processing Kaggle notebook.

Features:
- Continuous frame loop (no break on detection).
- 5s API Cooldown to prevent spam.
- 1.5s HUD red flashing upon alert.
- Supports both Demo Flow (X-Upload-Token) and Classic Flow (X-Device-Key).

Usage:
  python src/edge/demo_edge_realtime.py --input "path/to/video.mp4" --device-key "sg_live_..."
"""

import os
import sys
import cv2
import numpy as np
import math
import time
import json
import secrets
import argparse
import requests
from collections import deque
from datetime import datetime, timezone
from ultralytics import YOLO

from silentguard.publisher import FramePublisher

# =====================================================================
# RECALL-OPTIMIZED HYPERPARAMETERS
# =====================================================================
CONFIDENCE_THRESHOLD = 0.65   # Confidence filter for pose keypoints
WINDOW_SIZE = 32              # Sliding window frame size
VELOCITY_THRESHOLD = 180      # Vertical velocity threshold (pixels/sec)
ANGLE_THRESHOLD = 35          # Torso lean angle threshold (degrees)
TRANSITION_LIMIT = 2.0        # Max transition time (seconds)

# ANSI color codes for rich CLI logging
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
GRAY = "\033[90m"
RESET = "\033[0m"
BOLD = "\033[1m"


def calculate_torso_angle(sh_x, sh_y, hip_x, hip_y):
    """
    Calculate the torso angle relative to the Y-axis.
    0 degrees = standing upright | 90 degrees = horizontal.
    """
    dx = hip_x - sh_x
    dy = hip_y - sh_y
    angle_rad = math.atan2(abs(dx), dy)
    angle_deg = math.degrees(angle_rad)
    return angle_deg


def blur_face_on_ram(frame, keypoints, padding=25):
    """
    Apply Gaussian Blur to head area using COCO eyes/nose/ears keypoints.
    """
    face_pts = keypoints[:5]
    valid_pts = face_pts[face_pts[:, 2] > 0.5]

    if len(valid_pts) > 0:
        h, w, _ = frame.shape
        x_min = max(0, int(np.min(valid_pts[:, 0])) - padding)
        y_min = max(0, int(np.min(valid_pts[:, 1])) - padding)
        x_max = min(w, int(np.max(valid_pts[:, 0])) + padding)
        y_max = min(h, int(np.max(valid_pts[:, 1])) + padding)

        face_zone = frame[y_min:y_max, x_min:x_max]

        if face_zone.size > 0 and face_zone.shape[0] > 0 and face_zone.shape[1] > 0:
            k_width = int(face_zone.shape[1] // 3) * 2 + 1
            k_height = int(face_zone.shape[0] // 3) * 2 + 1

            k_width = max(3, min(k_width, 51))
            k_height = max(3, min(k_height, 51))

            blurred_face = cv2.GaussianBlur(face_zone, (k_width, k_height), 0)
            frame[y_min:y_max, x_min:x_max] = blurred_face

    return frame


def dispatch_alert(args, frame_count, fps, confidence):
    """
    Send HTTP POST to backend to report a fall event.
    """
    event_id = f"EVT-{int(time.time())}-{secrets.token_hex(4).upper()}"
    event_timestamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    
    headers = {'Content-Type': 'application/json'}
    payload = {
        "event_id": event_id,
        "event_type": "fall",
        "severity": "HIGH",
        "confidence": round(confidence, 2),
        "timestamp": event_timestamp,
        "room": args.room,
        "model_ver": "v1.0.0"
    }

    if args.upload_token:
        headers['X-Upload-Token'] = args.upload_token
        payload['clip_url'] = args.video_url
    elif args.device_key:
        headers['X-Device-Key'] = args.device_key
        payload['clip_path'] = "clips/test-household/demo.mp4"
        payload['duration_sec'] = int(frame_count / fps)

    print(f"📤 {YELLOW}[SENDING ALERT]{RESET} Dispatching event {BLUE}{event_id}{RESET} to {args.api_url}...")
    try:
        r = requests.post(args.api_url, headers=headers, json=payload, timeout=10)
        if r.status_code in [200, 201]:
            print(f"  ✅ {GREEN}[SUCCESS]{RESET} Backend accepted event. Response code: {r.status_code}")
        else:
            print(f"  ❌ {RED}[ERROR]{RESET} Backend returned code {r.status_code}: {r.text}")
    except Exception as e:
        print(f"  ❌ {RED}[CONNECTION FAILED]{RESET} Could not reach backend: {e}")


def process_video_stream(args):
    print(f"\n=======================================================")
    print(f"🎬 {BOLD}SILENTGUARD AI EDGE REAL-TIME — PIPELINE INITIALIZATION{RESET}")
    print(f"=======================================================")

    video_source = args.video_url if args.video_url else args.input
    if not video_source:
        print(f"{RED}[ERROR]{RESET} No input source provided.")
        sys.exit(1)

    print(f"📡 Video Source: {BLUE}{video_source}{RESET}")
    print(f"📦 Loading YOLOv8-Pose model...")
    try:
        model = YOLO('yolov8n-pose.pt')
        print(f"✅ Model loaded successfully.")
    except Exception as e:
        print(f"{RED}[ERROR] Failed to load YOLO model:{RESET} {e}")
        sys.exit(1)

    cap = cv2.VideoCapture(video_source)
    if not cap.isOpened():
        print(f"{RED}[ERROR] Could not open video source:{RESET} {video_source}")
        sys.exit(1)

    fps = int(cap.get(cv2.CAP_PROP_FPS))
    if fps <= 0:
        fps = 24
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    print(f"⚙️ Video Properties: {width}x{height} | {fps} FPS | Approx {total_frames} frames")
    print(f"-------------------------------------------------------")

    # Setup output file writer
    output_dir = os.path.dirname(args.output)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(args.output, fourcc, fps, (width, height))

    # Real-time state structures
    frame_window = deque(maxlen=WINDOW_SIZE)
    prev_hip_y = None
    frame_count = 0
    
    # Cooldown & HUD alert trackers (measured in frames)
    current_cooldown = 0
    cooldown_frames = int(5.0 * fps)
    
    hud_alert_timer = 0
    hud_alert_frames = int(1.5 * fps)
    
    velocity_spike_frame = None
    any_fall_detected = False

    print(f"🏃 Starting video continuous processing loop...")

    # Setup FramePublisher for WebSocket streaming
    camera_id = "61C06BDPBVC1D91" # Fixed ID for demo
    backend_ws_url = args.api_url.replace("/api/events/detect", "")
    publisher = FramePublisher(
        backend_url=backend_ws_url,
        camera_id=camera_id,
        device_key=args.device_key,
        enabled=True
    )
    publisher.start()

    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            frame_count += 1
            results = model(frame, verbose=False)

            current_angle = 0.0
            velocity_y = 0.0

            # Count down state timers
            if current_cooldown > 0:
                current_cooldown -= 1
            if hud_alert_timer > 0:
                hud_alert_timer -= 1

            if results[0].keypoints is not None and len(results[0].keypoints.data) > 0:
                keypoints = results[0].keypoints.data[0].cpu().numpy()

                conf_shoulders = (keypoints[5][2] + keypoints[6][2]) / 2
                conf_hips = (keypoints[11][2] + keypoints[12][2]) / 2

                if conf_shoulders >= CONFIDENCE_THRESHOLD and conf_hips >= CONFIDENCE_THRESHOLD:
                    # geometric centers
                    sh_x = (keypoints[5][0] + keypoints[6][0]) / 2
                    sh_y = (keypoints[5][1] + keypoints[6][1]) / 2
                    hip_x = (keypoints[11][0] + keypoints[12][0]) / 2
                    hip_y = (keypoints[11][1] + keypoints[12][1]) / 2

                    if prev_hip_y is not None:
                        velocity_y = (hip_y - prev_hip_y) * fps
                    prev_hip_y = hip_y

                    current_angle = calculate_torso_angle(sh_x, sh_y, hip_x, hip_y)
                    
                    # Slide window updates
                    frame_window.append({'velocity': velocity_y, 'angle': current_angle})

                    # Track spike trigger frame
                    if velocity_y > VELOCITY_THRESHOLD and velocity_spike_frame is None:
                        velocity_spike_frame = frame_count

                    # Evaluate time-series fall rules
                    if len(frame_window) == frame_window.maxlen:
                        has_velocity_spike = any(f['velocity'] > VELOCITY_THRESHOLD for f in frame_window)

                        if has_velocity_spike and current_angle > ANGLE_THRESHOLD:
                            transition_time = (frame_count - velocity_spike_frame) / fps if velocity_spike_frame else 0.4

                            if transition_time < TRANSITION_LIMIT:
                                any_fall_detected = True
                                hud_alert_timer = hud_alert_frames

                                # Trigger alert if cooldown is inactive
                                if current_cooldown == 0:
                                    current_cooldown = cooldown_frames
                                    
                                    time_sec = round(frame_count / fps, 2)
                                    print(f"\n🚨 {RED}{BOLD}[ALERT] Fall detected at {time_sec}s (Frame {frame_count})!{RESET}")
                                    
                                    conf_score = 0.91
                                    if results[0].boxes.conf is not None and len(results[0].boxes.conf) > 0:
                                        conf_score = float(results[0].boxes.conf[0].cpu().numpy())

                                    # Instantly dispatch alert to backend
                                    dispatch_alert(args, frame_count, fps, conf_score)

                                # Reset tracker for next event
                                velocity_spike_frame = None
                else:
                    prev_hip_y = None
            else:
                prev_hip_y = None

            # Reset spike tracking if it exceeds transition limit without triggering a fall
            if velocity_spike_frame is not None and (frame_count - velocity_spike_frame) / fps > TRANSITION_LIMIT:
                velocity_spike_frame = None

            # Draw skeletons & face blur in RAM
            annotated_frame = results[0].plot() if results[0].keypoints is not None else frame.copy()
            if results[0].keypoints is not None and len(results[0].keypoints.data) > 0:
                annotated_frame = blur_face_on_ram(annotated_frame, keypoints, padding=25)

            # RENDER RETAINED HUD
            if hud_alert_timer > 0:
                status_text = "⚠️ FALL DETECTED!"
                color = (0, 0, 255)  # Red flashing
            elif current_cooldown > 0:
                status_text = f"⏳ COOLDOWN ACTIVE ({int(current_cooldown / fps)}s)"
                color = (0, 255, 255)  # Yellow cooldown
            else:
                status_text = "🟢 MONITORING (NORMAL)"
                color = (0, 255, 0)  # Green monitoring

            cv2.putText(annotated_frame, f"Status: {status_text}", (30, 40), cv2.FONT_HERSHEY_SIMPLEX, 1, color, 3)
            cv2.putText(annotated_frame, f"Torso Angle: {int(current_angle)} deg", (30, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(annotated_frame, f"Velocity Y: {int(velocity_y)} px/s", (30, 110), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(annotated_frame, f"Frame: {frame_count} / {total_frames}", (30, 140), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 2)
            
            out.write(annotated_frame)
            publisher.put_frame(annotated_frame)

    finally:
        # Proper release
        publisher.stop()
        cap.release()
        out.release()
        print(f"\n💾 {GREEN}[SUCCESS]{RESET} Processed video output saved to: {args.output}")
        print(f"=======================================================")


def main():
    parser = argparse.ArgumentParser(description="SilentGuard AI — Edge Continuous Real-time Monitoring")
    
    # Upload-based parameters
    parser.add_argument("--video-url", type=str, default="", help="Signed video URL for Demo Flow")
    parser.add_argument("--upload-token", type=str, default="", help="Authentication upload token")
    
    # Local file / Legacy parameters
    parser.add_argument("--input", type=str, default="mobile/assets/videos/fall_video.mp4", 
                        help="Path to input video file")
    parser.add_argument("--device-key", type=str, default="", help="Device key for Classic Flow")
    
    # Output configurations
    parser.add_argument("--output", type=str, default="clips/test-household/demo_realtime.mp4", 
                        help="Output file path")
    parser.add_argument("--room", type=str, default="bedroom", help="Default room configuration")
    parser.add_argument("--api-url", type=str, default="https://c2-app-128-production-e0f9.up.railway.app/api/events/detect",
                        help="Backend detection endpoint URL")

    args = parser.parse_args()
    
    process_video_stream(args)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{GRAY}Process interrupted by user. Exiting safely.{RESET}\n")
        sys.exit(0)
