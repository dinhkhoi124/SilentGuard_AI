#!/usr/bin/env python3
"""
SilentGuard AI — Heuristics & Tracking Edge Script (MVP V5)
Ported from the upgraded v5 Kaggle notebook.

Features:
- Multi-Object Tracking (ByteTrack) to track multiple people.
- Finite State Machine (FSM): NORMAL, FALLING, LYING, STATIC_LYING.
- Floor Zone Constraint: y2 > height * 0.6 to filter high-surface falls.
- Grace Period: Ignore first 10 frames to avoid initial coordinate jitter.
- Aspect Ratio Box Check: Width-to-Height ratio > 1.1 for lying pose detection.
- 10-Second Immobility Trigger: Escalates from HIGH to CRITICAL severity.
- Dual Authentication (Upload Token / Device Key).

Usage:
  python src/edge/demo_edge_v5.py --input "path/to/video.mp4" --device-key "sg_live_..."
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

# =====================================================================
# HYPERPARAMETERS
# =====================================================================
CONFIDENCE_THRESHOLD = 0.65       # Keypoints confidence filter
WINDOW_SIZE = 32                  # Sliding window frame size
VELOCITY_THRESHOLD = 180          # Vertical velocity threshold (pixels/sec)
ANGLE_THRESHOLD = 35              # Torso angle threshold (degrees)
TRANSITION_LIMIT = 2.0            # Max transition time (seconds)

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
    Calculate torso angle relative to the vertical line (Y-axis).
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


def dispatch_alert(args, frame_count, fps, confidence, severity, track_id, model_ver):
    """
    Send HTTP POST to backend to report a fall event.
    """
    event_id = f"EVT-{int(time.time())}-{secrets.token_hex(4).upper()}"
    event_timestamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    
    headers = {'Content-Type': 'application/json'}
    payload = {
        "event_id": event_id,
        "event_type": "fall",
        "severity": severity,
        "confidence": round(float(confidence), 2),
        "timestamp": event_timestamp,
        "room": args.room,
        "model_ver": model_ver
    }

    if args.upload_token:
        headers['X-Upload-Token'] = args.upload_token
        payload['clip_url'] = args.video_url
    elif args.device_key:
        headers['X-Device-Key'] = args.device_key
        payload['clip_path'] = "clips/test-household/demo.mp4"
        payload['duration_sec'] = int(frame_count / fps)

    print(f"📤 {YELLOW}[SENDING {severity} ALERT]{RESET} Dispatching event {BLUE}{event_id}{RESET} for ID {track_id} to {args.api_url}...")
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
    print(f"🎬 {BOLD}SILENTGUARD AI EDGE V5 — CORE PIPELINE INITIALIZATION{RESET}")
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

    # --- STATE PER TRACK_ID (V5 Architecture) ---
    track_states = {}          
    track_windows = {}         
    track_prev_hips = {}       
    track_lying_timers = {}    
    track_spike_frames = {}    
    track_velocity_histories = {}
    track_ages = {}            
    
    # Anti-noise limits
    FALL_VELOCITY_THRESHOLD = 10.0     
    ASPECT_RATIO_THRESHOLD = 1.1      
    CRITICAL_LYING_FRAMES = int(10.0 * fps)
    GRACE_PERIOD_FRAMES = 10
    FLOOR_Y_MIN = height * 0.6
    Y_VELOCITY_HISTORY_LIMIT = int(fps * 0.5)

    frame_count = 0
    any_fall_detected = False

    print(f"🏃 Starting video continuous processing loop...")

    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            frame_count += 1
            current_timestamp = round(frame_count / fps, 2)
            
            # 1. Multi-Object Tracking via ByteTrack
            results = model.track(frame, persist=True, tracker="bytetrack.yaml", conf=0.3, iou=0.5, verbose=False)
            annotated_frame = frame.copy()

            # Render Floor Zone debugging line
            cv2.line(annotated_frame, (0, int(FLOOR_Y_MIN)), (width, int(FLOOR_Y_MIN)), (0, 100, 100), 1, cv2.LINE_AA)
            cv2.putText(annotated_frame, "FLOOR ZONE", (10, int(FLOOR_Y_MIN) + 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 100, 100), 1)

            global_hud_status = "🟢 MONITORING (NORMAL)"
            global_hud_color = (0, 255, 0)

            if results[0].boxes.id is not None and results[0].keypoints is not None:
                # Retrieve visual plot from YOLOv8 track
                annotated_frame = results[0].plot()

                track_ids = results[0].boxes.id.int().cpu().tolist()
                keypoints_all = results[0].keypoints.data.cpu().numpy()
                confidences_all = results[0].boxes.conf.cpu().numpy()
                boxes_all = results[0].boxes.xyxy.cpu().numpy()

                for i, track_id in enumerate(track_ids):
                    keypoints = keypoints_all[i]
                    obj_conf = confidences_all[i]
                    x1, y1, x2, y2 = boxes_all[i]

                    # Initialize state tracking for new track IDs
                    if track_id not in track_states:
                        track_states[track_id] = "NORMAL"
                        track_windows[track_id] = deque(maxlen=WINDOW_SIZE)
                        track_prev_hips[track_id] = None
                        track_lying_timers[track_id] = 0
                        track_spike_frames[track_id] = None
                        track_velocity_histories[track_id] = deque(maxlen=Y_VELOCITY_HISTORY_LIMIT)
                        track_ages[track_id] = 0

                    track_ages[track_id] += 1

                    box_w = x2 - x1
                    box_h = y2 - y1
                    aspect_ratio = box_w / float(box_h) if box_h > 0 else 0

                    conf_shoulders = (keypoints[5][2] + keypoints[6][2]) / 2
                    conf_hips = (keypoints[11][2] + keypoints[12][2]) / 2

                    current_angle = 0.0
                    current_hip_y = None

                    if conf_shoulders >= CONFIDENCE_THRESHOLD and conf_hips >= CONFIDENCE_THRESHOLD:
                        sh_x = (keypoints[5][0] + keypoints[6][0]) / 2
                        sh_y = (keypoints[5][1] + keypoints[6][1]) / 2
                        hip_x = (keypoints[11][0] + keypoints[12][0]) / 2
                        hip_y = (keypoints[11][1] + keypoints[12][1]) / 2
                        current_hip_y = hip_y
                        current_angle = calculate_torso_angle(sh_x, sh_y, hip_x, hip_y)
                    else:
                        current_hip_y = y1 + (box_h / 2)
                        current_angle = 90.0 if aspect_ratio > ASPECT_RATIO_THRESHOLD else 0.0

                    instant_velocity_y = 0.0
                    if track_prev_hips[track_id] is not None:
                        instant_velocity_y = current_hip_y - track_prev_hips[track_id]
                    
                    # Apply Grace Period anti-jitter
                    if track_ages[track_id] <= GRACE_PERIOD_FRAMES:
                        instant_velocity_y = 0.0

                    track_prev_hips[track_id] = current_hip_y
                    track_velocity_histories[track_id].append(instant_velocity_y)

                    velocity_y = instant_velocity_y * fps
                    track_windows[track_id].append({'velocity': velocity_y, 'angle': current_angle})

                    max_recent_drop = max(track_velocity_histories[track_id]) if len(track_velocity_histories[track_id]) > 0 else 0.0
                    is_lying_pose = (aspect_ratio > ASPECT_RATIO_THRESHOLD)
                    is_on_floor = (y2 > FLOOR_Y_MIN)

                    # =====================================================================
                    # FSM STATE TRANSITIONS
                    # =====================================================================
                    state = track_states[track_id]

                    if state == "NORMAL":
                        if is_lying_pose:
                            if (instant_velocity_y > FALL_VELOCITY_THRESHOLD or max_recent_drop > FALL_VELOCITY_THRESHOLD) and is_on_floor:
                                track_states[track_id] = "FALLING"
                                track_spike_frames[track_id] = frame_count
                            else:
                                track_states[track_id] = "STATIC_LYING"
                        elif velocity_y > VELOCITY_THRESHOLD and is_on_floor:
                            track_states[track_id] = "FALLING"
                            track_spike_frames[track_id] = frame_count

                    elif state == "STATIC_LYING":
                        if not is_lying_pose and current_angle < ANGLE_THRESHOLD:
                            track_states[track_id] = "NORMAL"

                    elif state == "FALLING":
                        if (current_angle > ANGLE_THRESHOLD or is_lying_pose) and is_on_floor:
                            duration = (frame_count - track_spike_frames[track_id]) / fps
                            if duration < TRANSITION_LIMIT:
                                track_states[track_id] = "LYING"
                                track_lying_timers[track_id] = 0
                                any_fall_detected = True
                                print(f"\n🚨 {RED}{BOLD}[ALERT] ID {track_id} fell onto floor at {current_timestamp}s!{RESET}")
                                dispatch_alert(args, frame_count, fps, obj_conf, "HIGH", track_id, "v1.1.0-fsm-heuristics")
                            else:
                                track_states[track_id] = "NORMAL"
                        elif velocity_y < 0 and current_angle < ANGLE_THRESHOLD:
                            track_states[track_id] = "NORMAL"
                        elif not is_on_floor:
                            track_states[track_id] = "STATIC_LYING"

                    elif state == "LYING":
                        if current_angle < ANGLE_THRESHOLD - 10 and not is_lying_pose:
                            track_states[track_id] = "NORMAL"
                            track_lying_timers[track_id] = 0
                            print(f"\n🟢 {GREEN}[INFO] ID {track_id} stood up at {current_timestamp}s.{RESET}")
                        else:
                            track_lying_timers[track_id] += 1
                            if track_lying_timers[track_id] == CRITICAL_LYING_FRAMES:
                                print(f"\n🔥 {RED}{BOLD}[CRITICAL ALERT] ID {track_id} remained immobile on the floor > 10s!{RESET}")
                                dispatch_alert(args, frame_count, fps, obj_conf, "CRITICAL", track_id, "v1.1.0-fsm-heuristics")

                    # Apply face anonymization in RAM
                    annotated_frame = blur_face_on_ram(annotated_frame, keypoints, padding=25)

                    # Manage HUD priorities per frame
                    id_state = track_states[track_id]
                    if id_state == "LYING":
                        if track_lying_timers[track_id] >= CRITICAL_LYING_FRAMES:
                            global_hud_status = f"🔥 CRITICAL: ID {track_id} INJURED"
                            global_hud_color = (0, 0, 255)
                        else:
                            global_hud_status = f"⚠️ FALL DETECTED: ID {track_id}"
                            global_hud_color = (0, 165, 255)
                    elif id_state == "FALLING" and global_hud_status == "🟢 MONITORING (NORMAL)":
                        global_hud_status = f"⏳ MONITORING STATE: ID {track_id}"
                        global_hud_color = (0, 255, 255)
                    elif id_state == "STATIC_LYING" and global_hud_status == "🟢 MONITORING (NORMAL)":
                        global_hud_status = f"ℹ️ STATIC LYING (WHITELISTED)"
                        global_hud_color = (255, 192, 203)

                    # Reset spike tracking if it exceeds transition limit without triggering a fall
                    if track_spike_frames[track_id] is not None and (frame_count - track_spike_frames[track_id]) / fps > TRANSITION_LIMIT:
                        track_spike_frames[track_id] = None

            # Render Global HUD overlays
            cv2.putText(annotated_frame, f"Status: {global_hud_status}", (30, 40), cv2.FONT_HERSHEY_SIMPLEX, 1, global_hud_color, 3)
            cv2.putText(annotated_frame, f"Frame: {frame_count} | Active IDs: {list(track_states.keys())[-3:]}", (30, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 2)
            
            out.write(annotated_frame)

    finally:
        # Proper release
        cap.release()
        out.release()
        print(f"\n💾 {GREEN}[SUCCESS]{RESET} Processed video output saved to: {args.output}")
        print(f"=======================================================")


def main():
    parser = argparse.ArgumentParser(description="SilentGuard AI — Edge V5 Continuous Heuristics Monitoring")
    
    # Upload-based parameters
    parser.add_argument("--video-url", type=str, default="", help="Signed video URL for Demo Flow")
    parser.add_argument("--upload-token", type=str, default="", help="Authentication upload token")
    
    # Local file / Legacy parameters
    parser.add_argument("--input", type=str, default="mobile/assets/videos/videoplayback.mp4", 
                        help="Path to input video file")
    parser.add_argument("--device-key", type=str, default="", help="Device key for Classic Flow")
    
    # Output configurations
    parser.add_argument("--output", type=str, default="clips/test-household/demo_v5.mp4", 
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
