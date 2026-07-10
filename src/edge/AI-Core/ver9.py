#!/usr/bin/env python3
"""
SilentGuard AI — Heuristics & Tracking Edge Script (MVP V9 - Hybrid FSM & LightGBM)
Ported and synchronized from e:/merged_partition_content/Khoi_Project/VinUni/project_build/C2-App-128/src/edge_ai/core-v9.ipynb

Features:
- Multi-Object Tracking (ByteTrack) to track multiple people.
- Hybrid FSM (Finite State Machine): NORMAL, FALLING, LYING.
- Standing History: collections.deque(maxlen=20) standing ratio constraint.
- Height Drop Ratio: track median heights of standing frames to check for vertical collapse.
- Fall Confidence Score: LightGBM model evaluating 12 key static and dynamic features.
- Floor Zone Constraint: y2 > height * 0.8 to filter high-surface falls.
- Grace Period: Ignore first 10 frames to avoid initial coordinate jitter.
- Aspect Ratio Box Check: Width-to-Height ratio > ASPECT_RATIO_THRESHOLD (default 1.5) for lying pose detection.
- 10-Second Immobility Trigger: Escalates from HIGH to CRITICAL severity.
- Dual Authentication (Upload Token / Device Key).
- Raw Socket DoH resolver and Imou stream API connection.
"""

import os
os.environ["OPENCV_FFMPEG_CAPTURE_OPTIONS"] = "timeout;10000000|reconnect;1|reconnect_at_eof;1|reconnect_streamed;1|reconnect_delay_max;2"

import sys
import socket
import ssl
import hashlib
import uuid
import warnings
import cv2

# Restrict OpenCV threading safely
cv2.setNumThreads(1)

import numpy as np
import math
import lightgbm as lgb
import time
import json
import secrets
import argparse
import requests
import queue
import threading
from collections import deque
from datetime import datetime, timezone

def check_edge_truncated(x1, y1, x2, y2, width, height, margin=5):
    return (x1 < margin or y1 < margin or x2 > width - margin or y2 > height - margin)

def check_id_swap_warning(instant_velocity_y, threshold=200.0):
    return abs(instant_velocity_y) > threshold

# Configuration Constants
import torch
torch.set_num_threads(1)
from ultralytics import YOLO

# Resolve silentguard module
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)
from silentguard.publisher import FramePublisher

# =====================================================================
# HYPERPARAMETERS / DEFAULT CONSTANTS
# =====================================================================
CONFIDENCE_THRESHOLD = 0.65       # Keypoints confidence filter
WINDOW_SIZE = 32                  # Sliding window frame size
VELOCITY_THRESHOLD = 180          # Vertical velocity threshold (pixels/sec)
ANGLE_THRESHOLD = 35              # Torso angle threshold (degrees)
TRANSITION_LIMIT = 2.0            # Max transition time (seconds)
FALL_VELOCITY_THRESHOLD = 10.0    # Heuristic hip pixel velocity threshold
ASPECT_RATIO_THRESHOLD = 1.5      # Aspect ratio threshold (width/height)

# --- CẤU HÌNH V9 TỐI ƯU HÓA ---
STANDING_RATIO_THRESHOLD = 1.0         # Tỷ lệ Chiều cao/Chiều rộng bounding box tối thiểu khi đứng thẳng (H/W)
STANDING_HISTORY_RATIO_THRESHOLD = 0.5  # Ngưỡng tỷ lệ lịch sử đứng thẳng trong 20 frames gần nhất
HEIGHT_DROP_THRESHOLD = 0.5            # Ngưỡng tỷ lệ tụt chiều cao đột ngột (chiều cao hiện tại / chiều cao đứng thẳng baseline)
SCORE_THRESHOLD = 50                   # Ngưỡng điểm số tối thiểu để xác nhận ngã (thang điểm 100)
FLOOR_ZONE_RATIO = 0.80                # Tỷ lệ chiều cao sàn nhà mặc định (80% từ trên xuống)
CONFIRMATION_LIMIT_SEC = 1.5           # Thời gian xác nhận nằm sàn (giây) trước khi báo HIGH

# ANSI color codes for rich CLI logging
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
GRAY = "\033[90m"
RESET = "\033[0m"
BOLD = "\033[1m"


# =====================================================================
# PATH HELPER FUNCTIONS
# =====================================================================
def find_model_file(model_path="models/fall_lgb_model.txt"):
    """
    Search for LightGBM model file in multiple standard locations.
    """
    if os.path.exists(model_path):
        return model_path
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidate1 = os.path.join(script_dir, model_path)
    if os.path.exists(candidate1):
        return candidate1

    parent_dir = os.path.dirname(script_dir)
    candidate2 = os.path.join(parent_dir, "edge_ai", "model", model_path)
    if os.path.exists(candidate2):
        return candidate2

    root_dir = os.path.dirname(parent_dir)
    candidate3 = os.path.join(root_dir, "src", "edge_ai", "model", model_path)
    if os.path.exists(candidate3):
        return candidate3
        
    candidate4 = os.path.join(root_dir, model_path)
    if os.path.exists(candidate4):
        return candidate4

    return model_path


def find_yolo_model(model_name="yolov8n-pose.pt"):
    """
    Search for YOLO model in standard locations.
    """
    if os.path.exists(model_name):
        return model_name
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidate1 = os.path.join(script_dir, model_name)
    if os.path.exists(candidate1):
        return candidate1
    
    parent_dir = os.path.dirname(script_dir)
    root_dir = os.path.dirname(parent_dir)
    candidate2 = os.path.join(root_dir, model_name)
    if os.path.exists(candidate2):
        return candidate2
        
    return model_name


# =====================================================================
# RAW SOCKET DNS-OVER-HTTPS RESOLVER
# Connects directly to DNS servers via raw TCP+TLS — zero DNS dependency.
# Tries Google (8.8.8.8) then Cloudflare (1.1.1.1).
# Also follows CNAME chains and tries alternative hostnames.
# =====================================================================
def _raw_doh_query(dns_ip, hostname, qtype="A"):
    """Resolve hostname using DNS-over-HTTPS via requests bypassing system DNS."""
    import requests
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    if dns_ip == '8.8.8.8':
        url = f"https://{dns_ip}/resolve?name={hostname}&type={qtype}"
        host_header = "dns.google"
    else:
        url = f"https://{dns_ip}/dns-query?name={hostname}&type={qtype}"
        host_header = "cloudflare-dns.com"
        
    try:
        r = requests.get(url, headers={"Host": host_header, "Accept": "application/dns-json"}, verify=False, timeout=10)
        return r.json()
    except Exception as e:
        print(f"[DNS-RAW] Lỗi kết nối tới DoH server {dns_ip}: {e}")
        return None


def _resolve_via_raw_doh(hostname):
    """Resolve hostname via DoH, trying multiple DNS servers and following CNAMEs.
    
    Tries Google (8.8.8.8) then Cloudflare (1.1.1.1).
    If A record not found, follows CNAME chain.
    """
    dns_servers = ['8.8.8.8', '1.1.1.1']
    
    for dns_ip in dns_servers:
        print(f"[DNS-RAW] Thử resolve {hostname} qua {dns_ip} ...")
        data = _raw_doh_query(dns_ip, hostname, "A")
        if data is None:
            continue
        
        status = data.get('Status', -1)
        print(f"[DNS-RAW] {dns_ip} trả về Status={status} cho {hostname}")
        
        if status == 0:  # NOERROR
            # Look for A records
            for answer in data.get('Answer', []):
                if answer.get('type') == 1:  # A record
                    ip = answer['data']
                    print(f"[DNS-RAW] ✅ Resolved {hostname} → {ip} (via {dns_ip})")
                    return ip
            # Follow CNAME chain
            for answer in data.get('Answer', []):
                if answer.get('type') == 5:  # CNAME
                    cname_target = answer['data'].rstrip('.')
                    print(f"[DNS-RAW] CNAME {hostname} → {cname_target}, following...")
                    result = _resolve_via_raw_doh(cname_target)
                    if result:
                        return result
        
        elif status == 3:  # NXDOMAIN
            print(f"[DNS-RAW] {dns_ip}: NXDOMAIN cho {hostname} (domain không tồn tại)")
            continue
    
    print(f"[DNS-RAW] ❌ Không thể resolve {hostname} từ bất kỳ DNS server nào")
    return None


def _imou_api_post(session, url, body, imou_ip, timeout=30):
    """POST to Imou API using resolved IP directly (bypass DNS).
    
    Replaces hostname in URL with IP, adds Host header for TLS SNI,
    and disables SSL verification since cert is for hostname not IP.
    """
    from urllib.parse import urlparse
    
    parsed = urlparse(url)
    direct_url = url.replace(parsed.hostname, imou_ip)
    
    return session.post(
        direct_url,
        json=body,
        headers={'Host': parsed.hostname},
        timeout=timeout,
        verify=False  # cert is for easy4ip/imoulife, not the IP
    )


def get_imou_live_stream_url():
    """Dynamically fetches the live HLS stream (.m3u8) from Imou Cloud OpenAPI.
    
    Uses raw socket DoH to resolve Imou's domain, then connects directly
    to the resolved IP — completely bypasses system DNS.
    """
    import warnings
    warnings.filterwarnings('ignore', message='Unverified HTTPS request')
    
    app_id = os.getenv("IMOU_APP_ID")
    app_secret = os.getenv("IMOU_APP_SECRET")
    device_sn = os.getenv("IMOU_DEVICE_SN")
    
    print(f"[Imou] Kiểm tra env — IMOU_APP_ID={'set' if app_id else 'MISSING'}, IMOU_APP_SECRET={'set' if app_secret else 'MISSING'}, IMOU_DEVICE_SN={device_sn or 'MISSING'}")
    
    if not app_id or not app_secret or not device_sn:
        raise Exception("Thiếu cấu hình IMOU_APP_ID, IMOU_APP_SECRET, hoặc IMOU_DEVICE_SN trong biến môi trường")
    
    # ── Step 0: Resolve Imou API IP ──────────────────────────────────
    manual_ip = os.getenv("IMOU_API_IP")
    IMOU_HOST = os.getenv("IMOU_API_HOST", "openapi.easy4ip.com")
    
    if manual_ip:
        imou_ip = manual_ip
        print(f"[Imou] Bước 0: Dùng IP thủ công từ IMOU_API_IP={imou_ip}")
    else:
        candidate_hosts = [IMOU_HOST]
        if IMOU_HOST == "openapi.easy4ip.com":
            candidate_hosts.extend(["openapi-sg.easy4ip.com", "openapi.imoulife.com"])
        elif "imoulife.com" in IMOU_HOST:
            candidate_hosts.extend(["openapi.easy4ip.com", "openapi-sg.easy4ip.com"])
        
        imou_ip = None
        for host in candidate_hosts:
            print(f"[Imou] Bước 0: Resolve {host} bằng raw socket DoH ...")
            imou_ip = _resolve_via_raw_doh(host)
            if imou_ip:
                IMOU_HOST = host
                break
        
        if not imou_ip:
            raise Exception(
                f"Không thể resolve Imou API host. Đã thử: {candidate_hosts}. "
                f"Hãy đặt IMOU_API_IP=<ip> trong biến môi trường Railway để bypass DNS."
            )
    
    print(f"[Imou] IP đã resolve: {imou_ip} (host: {IMOU_HOST})")
    
    # ── Build request body ───────────────────────────────────────────
    url = f"https://{IMOU_HOST}/openapi/accessToken"
    current_time = str(round(time.time()))
    nonce = secrets.token_urlsafe()
    
    raw_str = f"time:{current_time},nonce:{nonce},appSecret:{app_secret}"
    sign = hashlib.md5(raw_str.encode()).hexdigest()
    
    body = {
        "system": {
            "ver": "1.0",
            "appId": app_id,
            "sign": sign,
            "time": int(current_time),
            "nonce": nonce
        },
        "id": str(uuid.uuid4()),
        "params": {}
    }
    
    session = requests.Session()
    
    # ── Step 1: Fetch access token ───────────────────────────────────
    print(f"[Imou] Bước 1: Gọi accessToken (qua IP {imou_ip}) ...")
    try:
        res = _imou_api_post(session, url, body, imou_ip)
        print(f"[Imou] accessToken HTTP {res.status_code}")
    except Exception as e:
        raise Exception(f"[Imou] Network error khi gọi accessToken: {e}")
    
    res_json = res.json()
    code = res_json.get("result", {}).get("code")
    msg = res_json.get("result", {}).get("msg")
    print(f"[Imou] accessToken result: code={code}, msg={msg}")
    if code != "0":
        raise Exception(f"Imou Auth Error: {msg}")
        
    token_data = res_json.get("result", {}).get("data", {})
    access_token = token_data.get("accessToken")
    print(f"[Imou] accessToken nhận được thành công.")
    
    # ── Step 1b: Switch to currentDomain if provided ─────────────────
    current_domain = token_data.get("currentDomain")
    if current_domain:
        if "://" not in current_domain:
            current_domain = f"https://{current_domain}"
        from urllib.parse import urlparse as _urlparse
        parsed_domain = _urlparse(current_domain)
        if parsed_domain.hostname:
            new_host = parsed_domain.hostname
            print(f"[Imou] Bước 1b: API trả về currentDomain={new_host}, chuyển sang domain mới ...")
            new_ip = _resolve_via_raw_doh(new_host)
            if new_ip:
                IMOU_HOST = new_host
                imou_ip = new_ip
                print(f"[Imou] Đã chuyển sang {IMOU_HOST} → IP {imou_ip}")
            else:
                print(f"[Imou] Warning: Không resolve được {new_host}, tiếp tục dùng {IMOU_HOST}")
    
    # ── Step 2: Fetch live stream URL ────────────────────────────────
    live_url = f"https://{IMOU_HOST}/openapi/getLiveStreamInfo"
    body["params"] = {
        "token": access_token,
        "deviceId": device_sn,
        "channelId": "0",
    }
    
    # Update signature
    current_time_2 = str(round(time.time()))
    nonce_2 = secrets.token_urlsafe()
    raw_str_2 = f"time:{current_time_2},nonce:{nonce_2},appSecret:{app_secret}"
    body["system"]["time"] = int(current_time_2)
    body["system"]["nonce"] = nonce_2
    body["system"]["sign"] = hashlib.md5(raw_str_2.encode()).hexdigest()
    
    print(f"[Imou] Bước 2: Gọi liveList cho device={device_sn} (host={IMOU_HOST}, ip={imou_ip}) ...")
    try:
        res_live = _imou_api_post(session, live_url, body, imou_ip)
        print(f"[Imou] liveList HTTP {res_live.status_code}")
    except Exception as e:
        raise Exception(f"[Imou] Network error khi gọi liveList: {e}")
    
    live_json = res_live.json()
    live_code = live_json.get("result", {}).get("code")
    live_msg = live_json.get("result", {}).get("msg")
    print(f"[Imou] liveList result: code={live_code}, msg={live_msg}")
    
    if live_code != "0":
        print(f"[Imou] Bước 2b: Stream chưa bind, thử bindDeviceLive ...")
        bind_time = round(time.time())
        bind_nonce = secrets.token_urlsafe()
        raw_str_3 = f"time:{bind_time},nonce:{bind_nonce},appSecret:{app_secret}"
        body["system"]["time"] = bind_time
        body["system"]["nonce"] = bind_nonce
        body["system"]["sign"] = hashlib.md5(raw_str_3.encode()).hexdigest()
        body["params"] = {
            "token": access_token,
            "deviceId": device_sn,
            "channelId": "0",
            "streamId": 0,
        }
        body["id"] = str(uuid.uuid4())
        
        try:
            bind_url = f"https://{IMOU_HOST}/openapi/bindDeviceLive"
            bind_res = _imou_api_post(session, bind_url, body, imou_ip)
            print(f"[Imou] bindDeviceLive HTTP {bind_res.status_code}: {bind_res.text[:200]}")
        except Exception as e:
            print(f"[Imou] Warning: bindDeviceLive thất bại: {e}")
        
        # Retry liveList
        current_time_4 = str(round(time.time()))
        nonce_4 = secrets.token_urlsafe()
        raw_str_4 = f"time:{current_time_4},nonce:{nonce_4},appSecret:{app_secret}"
        body["system"]["time"] = int(current_time_4)
        body["system"]["nonce"] = nonce_4
        body["system"]["sign"] = hashlib.md5(raw_str_4.encode()).hexdigest()
        body["params"] = {
            "token": access_token,
            "deviceId": device_sn,
            "channelId": "0",
        }
        body["id"] = str(uuid.uuid4())
        
        print(f"[Imou] Bước 2c: Thử lại liveList sau bind ...")
        try:
            res_live = _imou_api_post(session, live_url, body, imou_ip)
            live_json = res_live.json()
            print(f"[Imou] Retry result: code={live_json.get('result', {}).get('code')}")
        except Exception as e:
            raise Exception(f"[Imou] Network error khi gọi liveList lần 2: {e}")
        
    live_data = live_json.get("result", {}).get("data", {})
    best_url = None
    
    if isinstance(live_data, dict):
        best_url = (
            live_data.get("flvUrl") or live_data.get("flv") or
            live_data.get("rtspUrl") or live_data.get("rtsp") or
            live_data.get("hlsUrl") or live_data.get("hls")
        )
        streams = live_data.get("streams", [])
        if not best_url and streams:
            for s in streams:
                if s.get("flv"):
                    best_url = s["flv"]; break
            if not best_url:
                for s in streams:
                    if s.get("rtsp"):
                        best_url = s["rtsp"]; break
            if not best_url:
                for s in streams:
                    if s.get("hls"):
                        best_url = s["hls"]; break
    elif isinstance(live_data, list) and live_data:
        for item in live_data:
            if isinstance(item, dict):
                best_url = (
                    item.get("flvUrl") or item.get("flv") or
                    item.get("rtspUrl") or item.get("rtsp") or
                    item.get("hlsUrl") or item.get("hls")
                )
                if best_url:
                    break
    
    if not best_url:
        raise Exception(f"Không thể lấy link stream từ Imou: {live_json.get('result', {}).get('msg')} | data: {str(live_data)[:300]}")
    
    print(f"[Imou] ✅ Stream URL lấy thành công: {best_url}")
    return best_url
    
    print(f"[Imou] ✅ HLS URL lấy thành công.")
    return hls_url


# =====================================================================
# GEOMETRY & UTILITIES
# =====================================================================
def calculate_iou(box1, box2):
    """
    Calculate Intersection over Union (IoU) between two bounding boxes (x1, y1, x2, y2).
    """
    x_left = max(box1[0], box2[0])
    y_top = max(box1[1], box2[1])
    x_right = min(box1[2], box2[2])
    y_bottom = min(box1[3], box2[3])

    if x_right < x_left or y_bottom < y_top:
        return 0.0

    intersection_area = (x_right - x_left) * (y_bottom - y_top)
    box1_area = (box1[2] - box1[0]) * (box1[3] - box1[1])
    box2_area = (box2[2] - box2[0]) * (box2[3] - box2[1])
    union_area = float(box1_area + box2_area - intersection_area)

    if union_area <= 0:
        return 0.0
    return intersection_area / union_area


def calculate_torso_angle(sh_x, sh_y, hip_x, hip_y):
    """
    Tính góc nghiêng thân người so với trục dọc (Y-axis, hướng xuống).

    CONVENTION (Image coordinate system — gốc ở góc trên-trái, Y tăng xuống dưới):
        0°   → Đứng thẳng: vai và hông thẳng hàng theo chiều dọc (sh_x ≈ hip_x, hip_y > sh_y)
        90°  → Nằm ngang hoàn toàn: vai và hông cùng độ cao (dy ≈ 0, dx lớn)
        45°  → Nghiêng 45°: dx ≈ dy

    NGƯỠNG THỰC TẾ TRONG HỆ THỐNG:
        < 30°  → is_standing = True (đứng)
        > 60°  → ANGLE_THRESHOLD — escalate FALLING (nằm/ngã)

    INPUTS:
        sh_x, sh_y  : tọa độ điểm vai trung bình (avg left+right shoulder, COCO kp 5+6)
        hip_x, hip_y: tọa độ điểm hông trung bình (avg left+right hip, COCO kp 11+12)

    RETURNS:
        (angle_deg: float, is_keypoint_unreliable: bool)
        - angle_deg            : góc 0–90°. Khi dy ≤ 0, clamp về 90°.
        - is_keypoint_unreliable: True khi dy ≤ 0 (hông trên hoặc trùng vai).
          Tên biến tại caller: is_angle_inverted — cùng ý nghĩa.
          Caller nên gắn fsm.low_confidence = True khi cờ này là True,
          để FSM không dùng góc này escalate FALLING trực tiếp.

    GUARD (dy < 0) — Đây là chính sách có chủ đích:
        Khi hip_y < sh_y (hông trên vai), tần suất trong pipeline thực tế:
          • Gần như luôn là lỗi keypoint (che khuất một phần, model nhầm vị trí).
          • Người cao tuổi trong nhà hiếm khi gập bụng sâu đủ tạo ra trường hợp này hợp lệ.
        Nguy hiểm nếu để atan2(abs(dx), negative_dy) chạy tự do:
          • Tạo ra góc 90–180° — hệ thống càng tin tưởng ngã hơn khi keypoint càng lỗi hơn.
          • Vi phạm nguyên tắc GIGO: rác vào → tăng confidence ra.
        Giải pháp: clamp về 90° (ngưỡng bão hòa, đủ vượt ANGLE_THRESHOLD 60° nhưng không
        phóng đại tín hiệu) + trả is_inverted=True để caller có thể gắn low_confidence.

    GUARD (dx=0, dy=0) — suy biến:
        Ảnh hưởng: atan2(0,0) không xác định. Clamp về 90° + is_inverted=True.
    """
    dx = hip_x - sh_x
    dy = hip_y - sh_y

    # Guard: suy biến (va trùng hông)
    if dx == 0.0 and dy == 0.0:
        return 90.0, True

    # Guard: hông trên vai (dy < 0) — clamp về 90°, báo caller là không tin cậy
    if dy < 0:
        return 90.0, True

    angle_rad = math.atan2(abs(dx), dy)
    angle_deg = math.degrees(angle_rad)
    return angle_deg, False



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


import threading
import json
import requests

def _post_alert(api_url, headers, payload, severity, track_id):
    """Publish fall alert via HTTP POST."""
    print(f"📤 {YELLOW}[SENDING {severity} ALERT VIA HTTP]{RESET} event={payload.get('event_id')} ID={track_id}")
    try:
        response = requests.post(api_url, json=payload, headers=headers, timeout=10)
        if response.status_code in [200, 201]:
            print(f"  ✅ {GREEN}[HTTP PUBLISHED]{RESET}")
        else:
            print(f"  ❌ {RED}[HTTP FAILED]{RESET} status {response.status_code}")
    except Exception as e:
        print(f"  ❌ {RED}[HTTP FAILED]{RESET} {e}")


def _put_heartbeat(api_url, event_id, duration_sec, status_str, device_key, upload_token):
    """Publish heartbeat via HTTP PUT."""
    headers = {}
    if device_key:
        headers['X-Device-Key'] = device_key
    elif upload_token:
        headers['X-Upload-Token'] = upload_token
        
    payload = {"duration_sec": int(duration_sec), "status": status_str}
    print(f"  💓 [HEARTBEAT HTTP] event={event_id} duration={int(duration_sec)}s status={status_str}")
    
    # Dựa vào api_url (ví dụ http://host/api/events/detect) để suy ra heartbeat_url
    import urllib.parse
    parsed_url = urllib.parse.urlparse(api_url)
    base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
    heartbeat_url = f"{base_url}/api/events/heartbeat/{event_id}"
    
    try:
        response = requests.put(heartbeat_url, json=payload, headers=headers, timeout=5)
        if response.status_code == 200:
            print("  ✅ [HB PUBLISHED]")
        else:
            print(f"  ❌ [HB FAILED] status {response.status_code}")
    except Exception as e:
        print(f"  ❌ [HB FAILED] {e}")





# =====================================================================
# [P4] SIMPLE KALMAN 1D — Dead Reckoning khi mất frame/mạng
# State vector: [hip_y (px), velocity_y (px/frame)]
# Predict-only trong thời gian track biến mất — không update từ YOLO.
# Mọ đích: duy trì velocity signal không bị gãy 0 khi mất 15+ frame.
# Bắt buộc gán low_confidence=True cho mọi dữ liệu dự đoán.
# Ref: vulnerability_analysis.md mục 12.1 (Dead Reckoning)
# =====================================================================
class SimpleKalman1D:
    """
    Minimal constant-velocity Kalman filter (2-state, pure numpy).
    State: [position_y, velocity_y] (both in pixels per frame).
    """
    def __init__(self, initial_y: float, initial_vy: float = 0.0):
        self.y   = float(initial_y)
        self.vy  = float(initial_vy)
        # Covariance matrix P (2x2)
        self.P00 = 100.0;  self.P01 = 0.0
        self.P10 = 0.0;    self.P11 = 25.0
        # Process noise Q — velocity uncertainty per frame
        self.Q11 = 9.0   # 3px/frame std dev
        # Measurement noise R — YOLO keypoint std ~5px
        self.R   = 25.0

    def predict(self) -> tuple:
        """Constant-velocity predict step (F = [[1,1],[0,1]])."""
        # State extrapolation
        self.y  += self.vy
        # Covariance extrapolation (F*P*F.T + Q)
        self.P00 += self.P10 + self.P01 + self.P11
        self.P01 += self.P11
        self.P10  = self.P01
        self.P11 += self.Q11
        return self.y, self.vy

    def update(self, measured_y: float) -> tuple:
        """Measurement update step. Gọi khi YOLO detect lại."""
        S   = self.P00 + self.R
        K0  = self.P00 / S
        K1  = self.P10 / S
        inn = measured_y - self.y
        self.y  += K0 * inn
        self.vy += K1 * inn
        # Covariance update (Joseph form simplified)
        self.P00 *= (1.0 - K0)
        self.P01 *= (1.0 - K0)
        self.P10 -= K1 * self.P00
        self.P11 -= K1 * self.P01
        return self.y, self.vy


# =====================================================================
# SYSTEM HEALTH LAYER (GLOBAL FLAGS) — REQ-013a/b/c/d
# =====================================================================
class SystemHealthMonitor:
    """
    Global health monitor cho toàn bộ camera stream.
    Tách biệt hoàn toàn với PersonFSM (per-track).
    Ref: vulnerability_analysis.md mục 11, 13.
    """
    def __init__(self):
        self.CAMERA_OFFLINE = False
        self.STREAM_FROZEN = False
        self.CAMERA_SHIFTED = False
        self.LENS_DEGRADED = False

        self.last_frame_time = time.monotonic()
        self.watchdog_timeout = 15.0  # seconds (REQ-013a)

        # Stream Frozen detection (REQ-013d)
        self.prev_frame_gray = None
        self.frozen_start_time = None
        self.frozen_timeout = 2.0  # Đã calibrate bằng video thật (REQ-BACKLOG-002)

        # Camera Shift & Lens Degraded detection (REQ-013b/c)
        self.last_shift_check_time = 0
        self.baseline_features = None
        self.baseline_gray = None
        self.LENS_DEGRADED_THRESHOLD = 55.0  # Laplacian variance threshold
        self.lens_degraded_consecutive_frames = 0
        self.camera_shifted_consecutive_frames = 0

        # Occlusion detection (REQ-023)
        self.CAMERA_OCCLUDED = False
        self.OCCLUSION_AREA_THRESHOLD = 0.95
        self.camera_occluded_consecutive_frames = 0
        self.empty_frame_start = None
        self.EMPTY_FRAME_DURATION_THRESHOLD = 5.0
        self.signal_1 = False
        self.last_known_max_ar = 0.0

        # Corrupted Frame Gate (P2)
        self.FRAME_CORRUPTED = False
        self.corrupted_frame_count = 0
        self.CORRUPTED_PIXEL_STD_THRESHOLD = 5.0   # std < 5 → gần như đồng màu
        self.CORRUPTED_LAPLACIAN_THRESHOLD = 3.0   # Laplacian < 3 → không có cạnh nào

    def is_frame_corrupted(self, frame) -> bool:
        """
        [P2] Phát hiện frame bị vỡ/đơn sắc trước khi đưa vào YOLO.
        Kiểm tra 2 điều kiện độc lập:
          1. std pixel toàn frame < ngưỡng → frame gần như đồng màu (xanh/đen/trắng)
          2. Laplacian variance < ngưỡng → không có cạnh/cấu trúc nào trong ảnh
        Trả về True nếu frame bị hỏng (nên bỏ qua inference).
        """
        if frame is None:
            self.FRAME_CORRUPTED = True
            self.corrupted_frame_count += 1
            return True
        pixel_std = float(np.std(frame))
        if pixel_std < self.CORRUPTED_PIXEL_STD_THRESHOLD:
            self.FRAME_CORRUPTED = True
            self.corrupted_frame_count += 1
            return True
        gray_check = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        lap_var = float(cv2.Laplacian(gray_check, cv2.CV_64F).var())
        if lap_var < self.CORRUPTED_LAPLACIAN_THRESHOLD:
            self.FRAME_CORRUPTED = True
            self.corrupted_frame_count += 1
            return True
        self.FRAME_CORRUPTED = False
        return False

    def update_watchdog(self, has_frame: bool):
        """Cập nhật watchdog. Gọi mỗi frame, bất kể có frame thật hay không."""
        now = time.monotonic()
        if has_frame:
            self.last_frame_time = now
            self.CAMERA_OFFLINE = False
        else:
            if now - self.last_frame_time > self.watchdog_timeout:
                self.CAMERA_OFFLINE = True

    def check_frame(self, frame, current_time: float, active_area_ratios: list = None, person_count: int = 0):
        """Check for frozen stream, lens degradation, camera shift, and occlusion."""
        self.update_watchdog(True)

        if frame is None:
            return

        # =====================================================================
        # REQ-023: Tín hiệu 2 (Mất track do che sát) - Chạy mỗi frame
        # =====================================================================
        if person_count > 0:
            if active_area_ratios:
                self.last_known_max_ar = max(active_area_ratios)
            self.empty_frame_start = None
        else:
            if self.empty_frame_start is None:
                self.empty_frame_start = current_time

        empty_duration = (current_time - self.empty_frame_start) if self.empty_frame_start is not None else 0.0
        signal_2 = (empty_duration > self.EMPTY_FRAME_DURATION_THRESHOLD) \
                   and (not self.CAMERA_OFFLINE) \
                   and (self.last_known_max_ar >= 0.50)

        # Kết hợp Signal 1 (từ block 2s) và Signal 2 (từ frame hiện tại)
        self.CAMERA_OCCLUDED = self.signal_1 or signal_2

        gray_full = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # 1. STREAM FROZEN — resize nhỏ để tiết kiệm CPU
        #
        # CHÍNH SÁCH LỚP 1 (bất biến không được sửa mà không có phê duyệt):
        #   STREAM_FROZEN=True KHÔNG BAO GIỜ được dùng để suppress LYING/FALLING alert.
        #   Nguyên tắc: "thà báo giả còn hơn bỏ lọt". Flag chỉ được dùng để:
        #     - Ghi log cảnh báo hạ tầng
        #     - Kích hoạt thông báo kỹ thuật (camera health alert cho admin)
        #   REF: SPEC.md §REQ-013d, vulnerability_analysis.md mục 11.2
        #
        # KỸ THUẬT LỚP 2 — Dual-gate (mean + std_diff):
        #   Chỉ báo frozen khi CẢ HAI điều kiện đúng:
        #     mean_diff < FROZEN_MEAN_THRESHOLD  — pixel trung bình gần như không đổi
        #     std_diff  < FROZEN_STD_THRESHOLD   — phân tán cũng gần như bằng 0
        #   Phân biệt:
        #     Frozen thật (same frame duplicated): mean≈0, std≈0
        #     Scene tĩnh có nhiễu camera: mean thấp NHƯNG std > 0 (noise phân tán đều)
        #
        # NGƯỠNG — ĐÃ HIỆU CHỈNH QUA DỮ LIỆU THỰC NGHIỆM:
        #   Lưu ý 1: Calibration được thực hiện bằng video webcam thông thường. Nhiễu trắng (white noise) 
        #            của webcam có thể không đại diện 100% cho IP cam (như Imou) có NR (Noise Reduction) mạnh.
        #   Lưu ý 2: Ngưỡng 0.05 dựa trên giả định byte-identical (khi đứng hình, buffer gửi lại đúng
        #            1 frame cũ không đổi). Nếu camera tự tái nén frame đứng, ta có thể phải nới epsilon.
        #   frozen_timeout = 2.0s
        FROZEN_MEAN_THRESHOLD = 0.05
        FROZEN_STD_THRESHOLD  = 0.05

        small = cv2.resize(gray_full, (64, 64))
        if self.prev_frame_gray is not None:
            diff = cv2.absdiff(small, self.prev_frame_gray)
            mean_diff = float(np.mean(diff))
            std_diff  = float(np.std(diff))
            # Dual-gate: frozen thật có mean VÀ std đều gần 0
            # Still scene với camera noise: mean có thể thấp nhưng std > 0
            is_candidate_frozen = (mean_diff < FROZEN_MEAN_THRESHOLD) and (std_diff < FROZEN_STD_THRESHOLD)
            if is_candidate_frozen:
                if self.frozen_start_time is None:
                    self.frozen_start_time = current_time
                elif current_time - self.frozen_start_time > self.frozen_timeout:
                    self.STREAM_FROZEN = True
            else:
                self.frozen_start_time = None
                self.STREAM_FROZEN = False
        self.prev_frame_gray = small


        # 2. LENS_DEGRADED & CAMERA_SHIFTED — chạy mỗi 2s để tiết kiệm CPU
        if current_time - self.last_shift_check_time > 2.0:
            self.last_shift_check_time = current_time

            laplacian_var = cv2.Laplacian(gray_full, cv2.CV_64F).var()
            raw_lens_degraded = bool(laplacian_var < self.LENS_DEGRADED_THRESHOLD)
            raw_camera_shifted = False

            if self.baseline_features is None or self.baseline_gray is None:
                self.baseline_gray = gray_full.copy()
                self.baseline_features = cv2.goodFeaturesToTrack(
                    self.baseline_gray, maxCorners=100, qualityLevel=0.3,
                    minDistance=7, blockSize=7
                )
            else:
                if self.baseline_features is not None and len(self.baseline_features) > 0:
                    p1, st, err = cv2.calcOpticalFlowPyrLK(
                        self.baseline_gray, gray_full, self.baseline_features, None
                    )
                    if p1 is not None and st is not None:
                        good_new = p1[st == 1]
                        good_old = self.baseline_features[st == 1]
                        if len(good_new) > 10:
                            distances = np.linalg.norm(good_new - good_old, axis=1)
                            median_shift = float(np.median(distances))
                            raw_camera_shifted = bool(median_shift > 50.0)
                        else:
                            # Quá ít feature (<=10) do bị người che khuất hoặc motion blur mờ mịt.
                            # KHÔNG kích hoạt CAMERA_SHIFTED, giữ nguyên trạng thái cũ.
                            # KHÔNG reset baseline để khi người đi khỏi, hệ thống tiếp tục so sánh với baseline cũ.
                            pass

            if raw_camera_shifted:
                raw_lens_degraded = False

            # =====================================================================
            # REQ-023: Tín hiệu 1 (Diện tích bất kỳ track nào > 95%) - Tính mỗi 2s
            # =====================================================================
            if active_area_ratios is None:
                active_area_ratios = []
            max_ar = max(active_area_ratios) if active_area_ratios else 0.0
            
            if max_ar > self.OCCLUSION_AREA_THRESHOLD:
                self.camera_occluded_consecutive_frames += 1
            else:
                self.camera_occluded_consecutive_frames = 0
                
            self.signal_1 = (self.camera_occluded_consecutive_frames >= 2)
            self.CAMERA_OCCLUDED = self.signal_1 or signal_2

            # Cross-reference (Tham chiếu chéo)
            if self.CAMERA_OCCLUDED:
                raw_lens_degraded = False
                self.STREAM_FROZEN = False

            # Duration Check: Cần 2 lần check liên tiếp (khoảng 4 giây) mới kích hoạt báo động
            if raw_lens_degraded:
                self.lens_degraded_consecutive_frames += 1
                if self.lens_degraded_consecutive_frames >= 2:
                    self.LENS_DEGRADED = True
            else:
                self.lens_degraded_consecutive_frames = 0
                self.LENS_DEGRADED = False

            if raw_camera_shifted:
                self.camera_shifted_consecutive_frames += 1
                if self.camera_shifted_consecutive_frames >= 2:
                    self.CAMERA_SHIFTED = True
                    # Reset baseline khi đã xác nhận shift thật (đủ 2 lần check)
                    self.baseline_gray = gray_full.copy()
                    self.baseline_features = cv2.goodFeaturesToTrack(
                        self.baseline_gray, maxCorners=100, qualityLevel=0.3,
                        minDistance=7, blockSize=7
                    )
            else:
                self.camera_shifted_consecutive_frames = 0
                self.CAMERA_SHIFTED = False


class PersonFSM:
    def __init__(self, track_id: int):
        self.track_id = track_id
        
        # Core State
        self.state = "NORMAL"  # NORMAL, SUSPECT, FALLING, LYING
        
        # Wall-clock timers
        self.lying_start_wall = None
        self.lying_wall_sec = 0.0
        
        # Alerting
        self.alert_sent_high = False
        self.alert_sent_critical = False
        self.event_id_str = None
        self.last_heartbeat = 0.0
        
        # Counters
        self.suspect_frames = 0
        self.above_threshold = 0
        self.grace_cooldown_timer = 0
        self.geometry_clear_frames = 0
        self.is_suspect_cleared = False
        
        # Per-Track Quality Flags
        self.EDGE_TRUNCATED = False
        self.ID_SWAP_WARNING = False
        self.TRANSITION_GAP = False
        self.STREAM_FROZEN = False
        self.ema_velocity_y = 0.0        # [P1] EMA state — khởi tạo = 0
        self.prev_velocity_y = 0.0       # [P3] Velocity frame trước — dùng tính jerk
        self.low_confidence = False
        self.is_suspect = False
        self.id_swap_frames = 0

    @property
    def severity_rank(self) -> int:
        ranks = {"NORMAL": 0, "SUSPECT": 1, "FALLING": 2, "LYING": 3}
        rank = ranks.get(self.state, 0)
        if rank == 0 and getattr(self, 'is_suspect', False):
            return 1
        return rank

    def transition_to(self, new_state: str, current_time: float):
        if new_state == "LYING" and self.state != "LYING":
            self.lying_start_wall = current_time
            self.lying_wall_sec = 0.0
        
        if self.state == "LYING" and new_state != "LYING":
            self.lying_start_wall = None
            self.lying_wall_sec = 0.0
            
        self.state = new_state

    def update_lying_timer(self, current_time: float):
        if self.state == "LYING" and self.lying_start_wall is not None:
            self.lying_wall_sec = current_time - self.lying_start_wall


def evaluate_fsm_transition(fsm: PersonFSM, score: int, is_on_floor: bool, is_lying_pose: bool, current_angle: float, wall_now: float, frame_count: int, args_score_threshold: int) -> str:
    """
    Evaluates and applies state transitions for a PersonFSM instance.
    Returns the decision string (e.g., "NORMAL", "FALL", "SUSPECT", "IGNORED (LOW CONFIDENCE)").
    """
    state = fsm.state
    decision = "NORMAL"
    SUSPECT_ZONE_MARGIN = 15
    SUSPECT_LOW = args_score_threshold - SUSPECT_ZONE_MARGIN
    SUSPECT_HIGH = args_score_threshold
    FALL_CONFIRM_FRAMES = 3
    SUSPECT_CONFIRM_FRAMES = 10
    SUSPECT_CLEAR_FRAMES = 30
    ANGLE_THRESHOLD = 60.0

    if getattr(fsm, 'low_confidence', False):
        if state == "NORMAL":
            decision = "IGNORED (LOW CONFIDENCE)"
        elif state == "FALLING":
            decision = "FALL"
        elif state == "LYING":
            # NOTE: update_lying_timer() KHÔNG được gọi ở đây nữa.
            # Timer được tick bởi main loop (while cap.isOpened()) độc lập với AI inference,
            # đảm bảo wall-clock không dừng dù frame bị skip hoặc stream frozen (REQ-019).
            decision = "FALL"
    else:
        if getattr(fsm, 'TRANSITION_GAP', False) and state in ("NORMAL", "SUSPECT"):
            if is_on_floor and is_lying_pose:
                fsm.transition_to("SUSPECT", wall_now)
                decision = "SUSPECT"
                print(f"[DATA_QUALITY_EVENT] ID {getattr(fsm, 'track_id', '?')} | Gap-triggered SUSPECT entry (TRANSITION_GAP)")
            fsm.TRANSITION_GAP = False

        if getattr(fsm, 'STREAM_FROZEN', False) and state == "NORMAL":
            fsm.transition_to("SUSPECT", wall_now)
            decision = "SUSPECT"
            print(f"[DATA_QUALITY_EVENT] ID {getattr(fsm, 'track_id', '?')} | Frozen-triggered SUSPECT entry (STREAM_FROZEN) — data quality event, not AI decision")
        

        if state in ("NORMAL", "SUSPECT"):
            geometry_confirms = is_on_floor and (is_lying_pose or current_angle > ANGLE_THRESHOLD)
            
            if geometry_confirms:
                fsm.geometry_clear_frames = 0
                fsm.is_suspect_cleared = False
            else:
                if not hasattr(fsm, 'geometry_clear_frames'):
                    fsm.geometry_clear_frames = 0
                fsm.geometry_clear_frames += 1

            if score >= SUSPECT_HIGH:
                fsm.above_threshold += 1
                fsm.suspect_frames = 0
                fsm.geometry_clear_frames = 0
                fsm.is_suspect_cleared = False
                if fsm.above_threshold >= FALL_CONFIRM_FRAMES:
                    fsm.transition_to("FALLING", wall_now)
                    fsm.grace_cooldown_timer = 0
                    fsm.alert_sent_high = False
                    fsm.alert_sent_critical = False
                    fsm.event_id_str = None
                    fsm.last_heartbeat = 0.0
                    fsm.above_threshold = 0
                    decision = "FALL"
                    print(f"[DEBUG FSM] ID {getattr(fsm, 'track_id', '?')} | NORMAL -> FALLING (confirmed {FALL_CONFIRM_FRAMES} frames) | Score: {score}% | Angle: {current_angle:.1f}°")
                else:
                    decision = "SUSPECT"
                    print(f"[DEBUG FSM] ID {getattr(fsm, 'track_id', '?')} | NORMAL suspect ({fsm.above_threshold}/{FALL_CONFIRM_FRAMES}) | Score: {score}%")

            elif SUSPECT_LOW <= score < SUSPECT_HIGH:
                fsm.above_threshold = 0
                
                if getattr(fsm, 'geometry_clear_frames', 0) >= SUSPECT_CLEAR_FRAMES:
                    fsm.suspect_frames = 0
                    fsm.geometry_clear_frames = 0
                    fsm.is_suspect_cleared = True
                
                if getattr(fsm, 'is_suspect_cleared', False):
                    decision = "NORMAL"
                else:
                    fsm.suspect_frames += 1
                    if fsm.suspect_frames >= SUSPECT_CONFIRM_FRAMES:
                        if geometry_confirms:
                            fsm.transition_to("FALLING", wall_now)
                            fsm.grace_cooldown_timer = 0
                            fsm.alert_sent_high = False
                            fsm.alert_sent_critical = False
                            fsm.event_id_str = None
                            fsm.last_heartbeat = 0.0
                            fsm.suspect_frames = 0
                            decision = "FALL"
                            print(f"[DEBUG FSM] ID {getattr(fsm, 'track_id', '?')} | NORMAL -> FALLING (suspect zone + geometric) | Score: {score}%")
                        else:
                            decision = "SUSPECT"
                    else:
                        decision = "SUSPECT"
            else:
                fsm.above_threshold = 0
                
                if getattr(fsm, 'geometry_clear_frames', 0) >= SUSPECT_CLEAR_FRAMES:
                    fsm.suspect_frames = 0
                    fsm.geometry_clear_frames = 0
                    fsm.is_suspect_cleared = True
                
                if getattr(fsm, 'is_suspect_cleared', False):
                    decision = "NORMAL"
                else:
                    if geometry_confirms:
                        fsm.suspect_frames += 1
                        if fsm.suspect_frames >= SUSPECT_CONFIRM_FRAMES:
                            fsm.transition_to("FALLING", wall_now)
                            fsm.grace_cooldown_timer = 0
                            fsm.alert_sent_high = False
                            fsm.alert_sent_critical = False
                            fsm.event_id_str = None
                            fsm.last_heartbeat = 0.0
                            fsm.suspect_frames = 0
                            decision = "FALL"
                            print(f"[DEBUG FSM] ID {getattr(fsm, 'track_id', '?')} | NORMAL -> FALLING (Slow Slide Geometric Override) | Angle: {current_angle:.1f}°")
                        else:
                            decision = "SUSPECT"
                    else:
                        if getattr(fsm, 'suspect_frames', 0) > 0:
                            decision = "SUSPECT"
                        else:
                            decision = "NORMAL"

        elif state == "FALLING":
            decision = "FALL"
            if is_on_floor and (is_lying_pose or current_angle > ANGLE_THRESHOLD):
                fsm.transition_to("LYING", wall_now)
                print(f"[DEBUG FSM] ID {getattr(fsm, 'track_id', '?')} | State: FALLING -> LYING (Geometric Confirmed) | Angle: {current_angle:.1f}°")
            elif score < args_score_threshold and current_angle <= 30.0 and not is_lying_pose:
                fsm.transition_to("NORMAL", wall_now)
                decision = "NORMAL"
                print(f"[DEBUG FSM] ID {getattr(fsm, 'track_id', '?')} | State: FALLING -> NORMAL (Stood up) | Angle: {current_angle:.1f}°")

        elif state == "LYING":
            decision = "FALL"
            # NOTE: update_lying_timer() KHÔNG được gọi ở đây nữa — xem main loop.

    fsm.is_suspect = (decision == "SUSPECT")
    return decision

def calculate_worst_state(all_fsm_states: list) -> int:
    """
    Calculates the maximum severity rank among all active PersonFSM instances.
    Returns:
        -1 if no tracks exist (empty list)
        0 for NORMAL
        1 for SUSPECT
        2 for FALLING
        3 for LYING
    """
    if not all_fsm_states:
        return -1
    return max(fsm.severity_rank for fsm in all_fsm_states)

def calculate_adaptive_skip_frames(worst_state_rank: int, skip_frames_param: int) -> int:
    """
    Determines the number of frames to skip based on the worst severity rank.
    Returns:
        0 if worst_state_rank >= 1 (SUSPECT or worse, process all frames)
        skip_frames_param if worst_state_rank == 0 (NORMAL, skip frames)
        -1 if worst_state_rank == -1 (No tracks, hibernate/motion trigger)
    """
    if worst_state_rank >= 1:
        return 0
    elif worst_state_rank == 0:
        return skip_frames_param
    else:
        return -1  # Signal for hibernation

def dispatch_alert(args, lying_elapsed, confidence, track_id, model_ver):
    """
    POST 1 lần duy nhất khi fall confirmed.
    duration_sec = max(30, lying_elapsed) để classify_severity → HIGH ngay lập tức.
    Trả về event_id để dùng cho heartbeat.
    """
    event_id = f"EVT-V9-{int(time.time())}-{secrets.token_hex(4).upper()}"
    event_timestamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    # duration_sec = thời gian nằm thực tế (giây).
    # Backend classify_severity sẽ tự phân loại:
    #   < low_max_sec (30s)   → LOW    → pending, không push ngay
    #   < medium_max_sec(120s)→ MEDIUM → push lần đầu
    #   < high_max_sec (300s) → HIGH   → push khẩn
    #   ≥ high_max_sec        → CRITICAL → gọi điện
    # LOW được lưu pending (đã fix backend) nên heartbeat vẫn leo thang được.
    duration_to_send = max(1, int(lying_elapsed))

    headers = {'Content-Type': 'application/json'}
    payload = {
        "event_id": event_id,
        "event_type": "fall",
        "severity": "HIGH",
        "confidence": round(float(confidence), 2),
        "timestamp": event_timestamp,
        "room": args.room,
        "model_ver": model_ver,
        "duration_sec": duration_to_send,
    }

    if args.upload_token:
        headers['X-Upload-Token'] = args.upload_token
        payload['clip_url'] = args.video_url
    elif args.device_key:
        headers['X-Device-Key'] = args.device_key
        payload['clip_path'] = "clips/test-household/demo.mp4"
    else:
        headers['X-Device-Key'] = "sg_dummy_key_for_testing"

    # Non-blocking — không block frame loop
    threading.Thread(
        target=_post_alert,
        args=(args.api_url, headers, payload, "HIGH", track_id),
        daemon=True
    ).start()

    return event_id  # caller lưu lại để dùng cho heartbeat


# =====================================================================
# BACKGROUND VIDEO UPLOADER
# =====================================================================
def _save_and_upload_clip(api_url, device_key, event_id, pre_frames, post_frames, fps, width, height):
    """
    Tạo clip MP4 từ buffer (pre + post frames) và gọi /api/events/upload_clip trên Backend.
    Chạy background để không block camera stream.
    """
    if not device_key or not event_id:
        return
        
    def worker():
        try:
            print(f"\n🎬 [CLIP RECORDER] Đang lưu video ngã ({len(pre_frames)+len(post_frames)} frames) ra ổ đĩa tạm...")
            tmp_path = f"/tmp/fall_clip_{event_id}.mp4"
            fourcc = cv2.VideoWriter_fourcc(*'mp4v')
            out = cv2.VideoWriter(tmp_path, fourcc, fps, (width, height))
            for f_jpeg in pre_frames + post_frames:
                import numpy as np
                f_dec = cv2.imdecode(f_jpeg, cv2.IMREAD_COLOR)
                if f_dec is not None:
                    out.write(f_dec)
            out.release()
            
            print(f"☁️ [CLIP RECORDER] Đang upload video lên Cloud Storage qua Backend...")
            import urllib.parse
            parsed_url = urllib.parse.urlparse(api_url)
            base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
            upload_url = f"{base_url}/api/events/upload_clip"
            
            with open(tmp_path, 'rb') as f:
                files = {'file': (os.path.basename(tmp_path), f, 'video/mp4')}
                data = {'event_id': event_id}
                headers_up = {'X-Device-Key': device_key}
                r_up = requests.post(upload_url, headers=headers_up, files=files, data=data, timeout=60)
                
                if r_up.status_code in [200, 201]:
                    clip_url = r_up.json().get('clip_url')
                    print(f"✅ {GREEN}[CLIP RECORDER] Upload thành công lên Supabase: {clip_url}{RESET}")
                else:
                    print(f"❌ {RED}[CLIP RECORDER] Upload thất bại (Lỗi {r_up.status_code}): {r_up.text}{RESET}")
            
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
        except Exception as e:
            print(f"❌ {RED}[CLIP RECORDER] Lỗi khi save/upload video: {e}{RESET}")

    threading.Thread(target=worker, daemon=True).start()


# =====================================================================
# THREADED CAMERA READER (RAM Optimized)
# =====================================================================
import threading
import queue

class ThreadedCamera:
    def __init__(self, src):
        self.src = src
        # Buffer to absorb instant bursts of HLS chunks (max 5 seconds of 30FPS)
        self.buffer_q = queue.Queue(maxsize=150)
        # Queue for the AI loop
        self.output_q = queue.Queue(maxsize=3)
        self.running = True
        
        import cv2
        tmp = cv2.VideoCapture(self.src)
        self.fps = tmp.get(cv2.CAP_PROP_FPS)
        if self.fps <= 0 or math.isnan(self.fps):
            self.fps = 20.0
        self.width = int(tmp.get(cv2.CAP_PROP_FRAME_WIDTH))
        self.height = int(tmp.get(cv2.CAP_PROP_FRAME_HEIGHT))
        if self.width <= 0: self.width = 2304
        if self.height <= 0: self.height = 1296
        
        # [RAM OPTIMIZATION FOR RAILWAY FREE TIER]
        if self.width > 1280:
            scale = 1280.0 / self.width
            self.width = 1280
            self.height = int(self.height * scale)
            
        tmp.release()
        self.shape = (self.height, self.width, 3)
        
        self.reader_thread = threading.Thread(target=self._downloader, daemon=True)
        self.pacer_thread = threading.Thread(target=self._pacer, daemon=True)
        self.reader_thread.start()
        self.pacer_thread.start()
        
    def _downloader(self):
        """Drains the OpenCV HLS stream as fast as possible to prevent Connection Reset"""
        import cv2
        cap = cv2.VideoCapture(self.src)
        error_count = 0
        
        while self.running:
            ret, frame = cap.read()
            if not ret:
                error_count += 1
                if error_count > 1:
                    break
                print(f"⚠️ [ThreadedCamera] HLS EOF or drop. Reconnecting... ({error_count}/2)")
                cap.release()
                import time
                time.sleep(0.5)
                cap = cv2.VideoCapture(self.src)
                continue
                
            error_count = 0
            
            if frame.shape != self.shape:
                frame = cv2.resize(frame, (self.shape[1], self.shape[0]))
                
            if self.buffer_q.full():
                try:
                    self.buffer_q.get_nowait()
                except queue.Empty:
                    pass
                    
            self.buffer_q.put(frame)
            
        cap.release()
        self.buffer_q.put(None)

    def _pacer(self):
        """Paces the buffered frames out at exactly the target FPS"""
        import time
        fps_delay = 1.0 / self.fps
        
        while self.running:
            start_time = time.time()
            
            try:
                frame = self.buffer_q.get(timeout=1.0)
            except queue.Empty:
                continue
                
            if frame is None:
                break
                
            if self.output_q.full():
                try:
                    self.output_q.get_nowait()
                except queue.Empty:
                    pass
            self.output_q.put(frame)
            
            elapsed = time.time() - start_time
            if elapsed < fps_delay:
                time.sleep(fps_delay - elapsed)
                
        self.output_q.put(None)

    def read(self, timeout=2.0):
        try:
            frame = self.output_q.get(timeout=timeout)
            if frame is None:
                return False, None
            return True, frame
        except queue.Empty:
            return False, None
            
    def isOpened(self):
        return self.running
        
    def release(self):
        self.running = False
        self.reader_thread.join(timeout=1.0)
        self.pacer_thread.join(timeout=1.0)
        
    def get(self, propId):
        import cv2
        if propId == cv2.CAP_PROP_FPS:
            return self.fps
        elif propId == cv2.CAP_PROP_FRAME_WIDTH:
            return self.width
        elif propId == cv2.CAP_PROP_FRAME_HEIGHT:
            return self.height
        return 0

# =====================================================================
# CORE PIPELINE PROCESSOR
# =====================================================================
def process_video_stream(args):
    print(f"\n=======================================================")
    print(f"🎬 {BOLD}SILENTGUARD AI EDGE V9 — HYBRID FSM + LIGHTGBM PIPELINE{RESET}")
    print(f"=======================================================")

    video_source = args.video_url if args.video_url else args.input
    is_imou = False
    if video_source and video_source.lower() == "imou":
        is_imou = True

    # 1. Load YOLOv8 Model (OpenVINO export for RAM efficiency on Railway Free)
    # YOLO.export saves to CWD by default. Check CWD first!
    cwd_ov_path = os.path.join(os.getcwd(), 'yolov8n-pose_openvino_model')
    script_ov_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'yolov8n-pose_openvino_model')
    
    if os.path.exists(cwd_ov_path):
        ov_path = cwd_ov_path
    elif os.path.exists(script_ov_path):
        ov_path = script_ov_path
    else:
        ov_path = cwd_ov_path # default to where it will be saved
        
    yolo_pt_path = find_yolo_model('yolov8n-pose.pt')
    print(f"📦 Loading YOLOv8-Pose model...")
    try:
        if not os.path.exists(ov_path):
            print(f"⚙️ OpenVINO model not found. Exporting from {yolo_pt_path} (imgsz=640, half=True)...")
            import subprocess
            export_cmd = [sys.executable, "-c", f"from ultralytics import YOLO; YOLO('{yolo_pt_path}').export(format='openvino', imgsz=640, half=True)"]
            try:
                subprocess.run(export_cmd, check=True)
                print(f"✅ Export subprocess completed.")
            except Exception as e_export:
                print(f"⚠️ Export subprocess had issues: {e_export}. Continuing anyway...")
            
        model = YOLO(ov_path, task='pose')
        print(f"✅ OpenVINO YOLO model loaded successfully (RAM-optimised).")
    except Exception as e:
        print(f"{YELLOW}[WARNING] OpenVINO load failed ({e}). Falling back to PyTorch .pt...{RESET}")
        try:
            model = YOLO(yolo_pt_path)
            print(f"✅ PyTorch YOLO model loaded (fallback).")
            # [P7] FP16 quantization: giảm 40-50% CPU cho cài đặt 3-5 camera
            if getattr(args, 'quantize', 'none') == 'fp16':
                try:
                    model.model.half()
                    print(f"✅ [P7] FP16 quantization applied — giảm CPU load cho multi-camera.")
                except Exception as e_fp16:
                    print(f"⚠️ [P7] FP16 không khả dụng trên thiết bị này: {e_fp16}")
        except Exception as e2:
            print(f"{RED}[ERROR] Failed to load YOLO model:{RESET} {e2}")
            sys.exit(1)

    # 2. Load LightGBM model
    lgb_txt_path = find_model_file(args.model_path)
    print(f"📦 Loading LightGBM model from {lgb_txt_path}...")
    try:
        if not os.path.exists(lgb_txt_path):
            print(f"{YELLOW}[WARNING] Model file {lgb_txt_path} not found. Creating a dummy model file for dry-run...{RESET}")
            # Write a dummy training block to create a minimal LightGBM booster
            dummy_data = pd = None
            try:
                import pandas as pd
                dummy_data = pd.DataFrame({
                    'max_vel': [0.0, 500.0, 0.0, 500.0],
                    'mean_vel': [0.0, 100.0, 0.0, 200.0],
                    'vel_std': [0.0, 50.0, 0.0, 100.0],
                    'max_angle': [10.0, 90.0, 20.0, 90.0],
                    'min_height_drop': [1.0, 0.3, 0.9, 0.2],
                    'lying_ratio': [0.0, 0.5, 0.0, 0.8],
                    'on_floor_ratio': [0.0, 0.5, 0.0, 0.9],
                    'current_vel': [0.0, 500.0, 0.0, 10.0],
                    'current_angle': [0.0, 80.0, 10.0, 90.0],
                    'current_height_drop': [1.0, 0.3, 0.9, 0.4],
                    'current_is_lying_pose': [0.0, 1.0, 0.0, 1.0],
                    'current_is_on_floor': [0.0, 1.0, 0.0, 1.0],
                    'label': [0, 1, 0, 1]
                })
                features_cols = [
                    'max_vel', 'mean_vel', 'vel_std', 'max_angle', 'min_height_drop', 'lying_ratio', 'on_floor_ratio',
                    'current_vel', 'current_angle', 'current_height_drop', 'current_is_lying_pose', 'current_is_on_floor'
                ]
                X_d = dummy_data[features_cols]
                y_d = dummy_data['label']
                train_ds = lgb.Dataset(X_d, label=y_d)
                dummy_gbm = lgb.train({'objective': 'binary', 'verbose': -1}, train_ds, num_boost_round=5)
                dummy_gbm.save_model(lgb_txt_path)
                print(f"✅ Dummy model file saved to {lgb_txt_path}.")
            except Exception as e_dummy:
                print(f"{RED}[ERROR] Could not build dummy model: {e_dummy}. LightGBM inference will fail.{RESET}")

        lgb_model = lgb.Booster(model_file=lgb_txt_path)
        print(f"✅ LightGBM model loaded successfully.")
    except Exception as e:
        print(f"{RED}[ERROR] Failed to load LightGBM model:{RESET} {e}")
        sys.exit(1)

    # Initialize WebSocket FramePublisher (Only enabled for live camera streams)
    camera_id = os.getenv("IMOU_DEVICE_SN", "default_cam")
    backend_ws_url = args.api_url.replace("/api/events/detect", "")
    publisher = FramePublisher(
        backend_url=backend_ws_url,
        camera_id=camera_id,
        device_key=args.device_key or "demo_key",
        enabled=is_imou
    )
    publisher.start()

    health_monitor = SystemHealthMonitor()

    # --- Architecture State Storage (Dời ra ngoài để bảo toàn qua các lần Reconnect) ---
    fsm_states = {}                # track_id -> PersonFSM instance
    track_windows = {}         
    track_prev_hips = {}       
    track_ages = {}            
    track_standing_history = {}    # Collections.deque(maxlen=20) standing flag
    track_standing_heights = {}    # History of standing heights for median baseline
    track_score = {}               # LightGBM fall score
    
    # --- Integration & Alert State ---
    track_spike_frames = {}
    track_lying_start_wall = {}
    track_lying_wall_sec = {}
    track_alert_sent_high = {}
    track_alert_sent_critical = {}
    track_event_id = {}
    track_last_heartbeat = {}
    track_suspect_frames = {}
    track_above_threshold = {}
    
    track_lost_cache = {}          # Spatial Re-ID cache
    track_last_bboxes = {}         # Bounding boxes history

    # [P5] Debounce person_count — chống ROI flickering khi y tá bước vào/ra
    person_count_history = deque(maxlen=15)  # Buffer 15 frame (~0.5s @ 30fps)
    person_count_stable = 0                  # Giá trị ổn định sau debounce
    
    frame_count = 0
    any_fall_detected = False
    last_log_second = -1   # for per-second log
    
    skip_counter = 0
    prev_gray_frame = None
    last_loop_wall = time.time()

    backoff_time = 5.0             # Khởi tạo Exponential Backoff

    while True:
        current_source = video_source
        if is_imou:
            print(f"🔄 Resolving dynamic HLS Stream URL from Imou Cloud API...")
            try:
                current_source = get_imou_live_stream_url()
                print(f"✅ Resolved Imou Stream URL: {BLUE}{current_source}{RESET}")
            except Exception as e:
                print(f"{RED}[ERROR] Failed to resolve Imou stream URL: {e}{RESET}")
                print(f"⏳ Chờ {backoff_time}s trước khi thử resolve lại...")
                time.sleep(backoff_time)
                backoff_time = min(backoff_time * 2, 60.0)
                continue

        if not current_source:
            print(f"{RED}[ERROR]{RESET} No input source resolved.")
            if is_imou:
                print(f"⏳ Chờ {backoff_time}s trước khi thử lại...")
                time.sleep(backoff_time)
                backoff_time = min(backoff_time * 2, 60.0)
                continue
            sys.exit(1)

        print(f"📡 Video Source: {BLUE}{current_source}{RESET}")

        # Download HTTP videos locally first to prevent cv2.VideoCapture from hanging
        # (Critical on Railway Free where network timeouts cause silent deadlocks)
        tmp_file_path = None
        if not is_imou and current_source.startswith("http"):
            import tempfile
            import urllib.request
            print(f"📥 Downloading video locally to avoid OpenCV HTTP stream hanging...")
            tmp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
            tmp_file_path = tmp_file.name
            tmp_file.close()
            try:
                req_dl = urllib.request.Request(current_source, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(req_dl, timeout=60) as response, open(tmp_file_path, 'wb') as out_file:
                    out_file.write(response.read())
                print(f"✅ Download complete: {tmp_file_path}")
                current_source = tmp_file_path
            except Exception as e:
                print(f"{RED}❌ Failed to download video: {e}{RESET}")
                try:
                    os.unlink(tmp_file_path)
                except Exception:
                    pass
                sys.exit(1)

        if is_imou:
            cap = ThreadedCamera(current_source)
        else:
            cap = cv2.VideoCapture(current_source)
            
        if not cap.isOpened():
            print(f"{RED}[ERROR] Could not open video source:{RESET} {current_source}")
            if is_imou:
                print(f"⏳ Thử kết nối lại sau {backoff_time}s...")
                time.sleep(backoff_time)
                backoff_time = min(backoff_time * 2, 60.0)
                continue
            sys.exit(1)

        # Reconnect thành công -> Reset backoff
        backoff_time = 5.0

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

        # --- Video Buffering State (for uploading short clips) ---
        pre_fall_buffer = deque(maxlen=fps * 5)
        post_fall_buffer = []
        recording_frames_left = 0
        current_upload_event_id = None



        # FIX: Frame-based thresholds kept only for grace period (not for alert timing)
        GRACE_PERIOD_FRAMES = 10
        FLOOR_Y_MIN = height * args.floor_zone_ratio
        # Wall-clock thresholds (accurate regardless of stream FPS jitter)
        CONFIRMATION_LIMIT_SEC = args.confirmation_limit  # default 1.5s
        CRITICAL_LYING_SEC = 10.0
        # Min bounding-box height: ignore persons too small/far to be reliable
        MIN_BOX_HEIGHT_PX = max(40, int(height * 0.08))  # at least 8% of frame height
        # Multi-frame confirmation thresholds
        FALL_CONFIRM_FRAMES = 3        # NORMAL→FALLING: cần N frame liên tiếp >= threshold
        SUSPECT_CONFIRM_FRAMES = 5     # SUSPECT: cần N frame liên tiếp trong vùng biên
        SUSPECT_ZONE_MARGIN = 15       # vùng biên: [threshold-15, threshold)
        MIN_TRACK_AGE = 5              # bỏ qua track quá mới (< 5 frame), tránh ghost detection
        MIN_VALID_KEYPOINTS = 6        # cần ít nhất 6/17 keypoint hợp lệ (confidence > 0.3)

        print(f"🏃 Starting video continuous processing loop...")

        # Ép check CAMERA_SHIFTED (Post-Offline Self-Check)
        # Vì current_timestamp tăng tự nhiên (không reset), trừ 0 chắc chắn > 2.0s
        health_monitor.last_shift_check_time = 0

        try:
            while cap.isOpened():
                ret, frame = cap.read()
                
                # =====================================================================
                # REQ-016 Kịch bản A: Global Gap (Bắt sự cố đứt luồng/rớt mạng)
                # Đo lường gap vật lý giữa 2 lần cap.read() liên tiếp.
                # Nếu gap > 0.5s, tức là camera/mạng bị treo, bật cờ cho mọi track đang active.
                # Đo trước khi xử lý skip frame, nên hoàn toàn miễn nhiễm với skip_frames_param.
                # =====================================================================
                current_wall = time.time()
                global_gap = current_wall - last_loop_wall
                if global_gap > 0.5:
                    for _fsm in fsm_states.values():
                        _fsm.TRANSITION_GAP = True
                last_loop_wall = current_wall

                if not ret:
                    health_monitor.CAMERA_OFFLINE = True
                    if is_imou:
                        print(f"{YELLOW}[Stream] Hết buffer HLS hoặc mất kết nối tạm thời. Đang reconnect...{RESET}")
                    break

                frame_count += 1
                current_timestamp = round(frame_count / fps, 2)

                # =====================================================================
                # LYING TIMER — tick mỗi frame, ĐỘC LẬP với AI inference và skip logic
                # REQ-019: Wall-clock không dừng dù frame bị skip hoặc stream frozen.
                # Đặt TẠI ĐÂY (trước skip), không đặt trong evaluate_fsm_transition()
                # để tránh timer bị "treo" khi skip counter > 0 hoặc STREAM_FROZEN.
                # =====================================================================
                _lying_tick_now = time.time()
                for _fsm in fsm_states.values():
                    if _fsm.state == "LYING":
                        _fsm.update_lying_timer(_lying_tick_now)
                
                # =====================================================================
                # ADAPTIVE SKIP FRAME & MOTION HIBERNATION (REQ-001 & REQ-002)
                # =====================================================================
                worst_rank = calculate_worst_state(list(fsm_states.values()))
                skip_frames_param = getattr(args, 'skip_frames', 2)
                target_skips = calculate_adaptive_skip_frames(worst_rank, skip_frames_param)
                
                if target_skips == -1:
                    # Hibernation Mode - Motion Trigger (Masked Hysteresis)
                    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                    gray = cv2.GaussianBlur(gray, (21, 21), 0)
                    
                    # Mask: Bỏ qua phần trên khung hình (bóng cây, ánh sáng, quạt trần)
                    # TODO (BACKLOG): mask_y_start hiện hardcode 30% — cần tham số hóa thành
                    # --motion-mask-ratio (default 0.3) hoặc tự động suy ra từ floor_zone_ratio.
                    # Trường hợp camera đặt thấp (phòng nhỏ) có thể chỉ cần mask 15%;
                    # camera đặt cao (hành lang) cần tới 40%. Hardcode 0.3 là giá trị
                    # hợp lý cho phần lớn deployment nhưng không phải tối ưu cho mọi cảnh.
                    h, w = gray.shape
                    mask_y_start = int(h * 0.3)  # TODO: parameterize via args.motion_mask_ratio
                    
                    is_motion_detected = True
                    if prev_gray_frame is None:
                        prev_gray_frame = gray
                    else:
                        # Chỉ so sánh phần dưới của khung hình
                        frame_delta = cv2.absdiff(prev_gray_frame[mask_y_start:h, :], gray[mask_y_start:h, :])
                        thresh = cv2.threshold(frame_delta, 25, 255, cv2.THRESH_BINARY)[1]
                        motion_score = cv2.countNonZero(thresh)
                        is_motion_detected = motion_score > 500  # Motion threshold
                        prev_gray_frame = gray
                    
                    if not is_motion_detected:
                        if skip_counter > 0:
                            skip_counter -= 1
                            continue
                        else:
                            skip_counter = 5  # sleep for 5 frames
                            target_skips = 5
                            continue
                    else:
                        target_skips = 0
                        skip_counter = 0
                
                if skip_counter > 0 and target_skips > 0:
                    skip_counter -= 1
                    continue
                
                skip_counter = target_skips

                # ── [P2] CORRUPTED FRAME GATE — chặn frame vỡ/đơn sắc trước YOLO ──
                if health_monitor.is_frame_corrupted(frame):
                    print(f"[FRAME_CORRUPTED] Frame {frame_count} bị vỡ/đơn sắc (total: {health_monitor.corrupted_frame_count}) — bỏ qua inference")
                    continue

                # Multi-Object Tracking using standard bytetrack
                results = model.track(frame, persist=True, tracker="bytetrack.yaml", conf=0.3, iou=0.5, verbose=False)
                annotated_frame = frame.copy()

                # Render Floor Zone debugging line
                cv2.line(annotated_frame, (0, int(FLOOR_Y_MIN)), (width, int(FLOOR_Y_MIN)), (0, 100, 100), 1, cv2.LINE_AA)
                cv2.putText(annotated_frame, "FLOOR ZONE", (10, int(FLOOR_Y_MIN) + 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 100, 100), 1)

                global_hud_status = "🟢 MONITORING (NORMAL)"
                global_hud_color = (0, 255, 0)

                track_ids = []
                if results[0].boxes is not None and results[0].boxes.id is not None and results[0].keypoints is not None:
                    # Render YOLO pose markers (disabling default box labels to keep it clean)
                    annotated_frame = results[0].plot(labels=False, conf=False)

                    track_ids = results[0].boxes.id.int().cpu().tolist()
                    keypoints_all = results[0].keypoints.data.cpu().numpy()
                    confidences_all = results[0].boxes.conf.cpu().numpy()
                    boxes_all = results[0].boxes.xyxy.cpu().numpy()

                    # NOTE: Cache expiry is now handled per-state at end of loop (FIX #4)
                    # LYING/FALLING: 15s TTL | NORMAL: 7s TTL

                    active_area_ratios = []
                    person_count = len(track_ids)

                    # [P5] Debounce person_count: chỉ cập nhật stable khi count giữ nguyên 15 frame
                    person_count_history.append(person_count)
                    if len(person_count_history) == 15 and len(set(person_count_history)) == 1:
                        person_count_stable = person_count_history[0]

                    for i, track_id in enumerate(track_ids):
                        keypoints = keypoints_all[i]
                        obj_conf = confidences_all[i]
                        x1, y1, x2, y2 = boxes_all[i]
                        box_w = x2 - x1
                        box_h = y2 - y1
                        
                        ar = (box_w * box_h) / (width * height)
                        active_area_ratios.append(ar)

                        track_last_bboxes[track_id] = (x1, y1, x2, y2)

                        # Re-ID inherit logic
                        # Re-ID inherit logic
                        if track_id not in fsm_states:
                            matched_old_id = None
                            current_cx = x1 + box_w / 2
                            current_cy = y1 + box_h / 2
                            current_time = time.time()
                            
                            for old_id, info in list(track_lost_cache.items()):
                                old_x1, old_y1, old_x2, old_y2 = info["bbox"]
                                old_cx = old_x1 + (old_x2 - old_x1) / 2
                                old_cy = old_y1 + (old_y2 - old_y1) / 2
                                dist = math.sqrt((current_cx - old_cx)**2 + (current_cy - old_cy)**2)
                                iou_val = calculate_iou((x1, y1, x2, y2), info["bbox"])
                                
                                if dist < 120 or iou_val > 0.15:
                                    matched_old_id = old_id
                                    break
                                    
                            if matched_old_id is not None:
                                old_info = track_lost_cache.pop(matched_old_id)

                                # [P4] Update Kalman với vị trí hông thật khi Re-ID thành công
                                _re_kalman = old_info.get("kalman")
                                if _re_kalman is not None:
                                    _re_hip = float(x1 + box_w / 2)  # centroid x as proxy (hip not yet computed)
                                    _re_kalman.update(_re_hip)
                                
                                # =====================================================================
                                # REQ-016 Kịch bản B: Per-track Gap (Bắt sự cố Occlusion/YOLO miss)
                                # Gap từ lúc track biến mất (vào cache) đến lúc xuất hiện lại.
                                # =====================================================================
                                cache_gap = current_time - old_info["timestamp"]
                                
                                fsm_states[track_id] = old_info["fsm"]
                                fsm_states[track_id].track_id = track_id  # Update ID
                                
                                if cache_gap > 0.5:
                                    fsm_states[track_id].TRANSITION_GAP = True
                                
                                track_windows[track_id] = old_info["window"]
                                track_prev_hips[track_id] = old_info["prev_hip"]
                                track_ages[track_id] = old_info["age"]
                                track_standing_history[track_id] = old_info["standing_history"]
                                track_standing_heights[track_id] = old_info["standing_heights"]
                                track_score[track_id] = old_info["score"]
                                
                                print(f"🔄 {GREEN}[Re-ID SUCCESS] ID {track_id} kế thừa từ ID cũ {matched_old_id} (State: {fsm_states[track_id].state}, LyingTime: {fsm_states[track_id].lying_wall_sec:.1f}s){RESET}")
                            else:
                                fsm_states[track_id] = PersonFSM(track_id)
                                track_windows[track_id] = deque(maxlen=WINDOW_SIZE)
                                track_prev_hips[track_id] = None
                                track_ages[track_id] = 0
                                track_standing_history[track_id] = deque([True] * 20, maxlen=20)
                                track_standing_heights[track_id] = []
                                track_score[track_id] = 0

                        track_ages[track_id] += 1
                        aspect_ratio = float(box_w / box_h) if box_h > 0 else 0.0

                        # ── GIGO FILTER 1: Track age — bỏ qua track quá mới ──────────────
                        if track_ages[track_id] < MIN_TRACK_AGE:
                            continue

                        # ── GIGO FILTER 2: Keypoint quality — cần đủ số điểm hợp lệ ─────
                        valid_kp_count = int(np.sum(keypoints[:, 2] > 0.3))
                        if valid_kp_count < MIN_VALID_KEYPOINTS:
                            if track_id in fsm_states:
                                fsm_states[track_id].id_swap_frames = 0
                            track_prev_hips[track_id] = None
                            continue

                        # ── GIGO FILTER 3: Partial body — bbox chạm cạnh frame ───────────
                        is_clipped = check_edge_truncated(x1, y1, x2, y2, width, height, margin=5)
                        
                        if track_id in fsm_states:
                            fsm_states[track_id].EDGE_TRUNCATED = is_clipped
                            fsm_states[track_id].low_confidence = False  # [FIX BUG] Reset per-frame

                        # Chỉ block nếu clipped VÀ đang NORMAL (không reset người đang LYING)
                        if is_clipped and track_id in fsm_states and fsm_states[track_id].state == "NORMAL":
                            fsm_states[track_id].id_swap_frames = 0
                            track_prev_hips[track_id] = None
                            continue

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
                            current_angle, is_angle_inverted = calculate_torso_angle(sh_x, sh_y, hip_x, hip_y)
                            current_angle = float(current_angle)
                            # dy < 0 (hông trên vai): hầu như luôn là lỗi keypoint
                            # → giảm độ tin cậy quyết định, không dùng góc này để escalate trực tiếp
                            if is_angle_inverted and track_id in fsm_states:
                                fsm_states[track_id].low_confidence = True
                        else:
                            current_hip_y = float(y1 + (box_h / 2))
                            current_angle = 90.0 if aspect_ratio > args.aspect_ratio_threshold else 0.0

                        instant_velocity_y = 0.0
                        if track_prev_hips[track_id] is not None:
                            raw_velocity_y = current_hip_y - track_prev_hips[track_id]
                            if track_ages[track_id] <= GRACE_PERIOD_FRAMES:
                                raw_velocity_y = 0.0
                            # [P1] EMA smoothing: lọc jitter keypoint ±2-3px
                            # alpha=0.4: trọng số hiện tại 40%, cũ 60%
                            # — đủ nhạy với cú ngã thật (nhiều frame cùng chiều)
                            # — lọc bỏ đột biến đơn lẻ do jitter
                            EMA_ALPHA = 0.4
                            _fsm_ema = fsm_states.get(track_id)
                            if _fsm_ema is not None:
                                _fsm_ema.ema_velocity_y = EMA_ALPHA * raw_velocity_y + (1.0 - EMA_ALPHA) * _fsm_ema.ema_velocity_y
                                instant_velocity_y = _fsm_ema.ema_velocity_y
                            else:
                                instant_velocity_y = raw_velocity_y
                        if track_ages[track_id] <= GRACE_PERIOD_FRAMES:
                            instant_velocity_y = 0.0

                        if track_id in fsm_states:
                            is_swap = check_id_swap_warning(instant_velocity_y)
                            fsm_states[track_id].ID_SWAP_WARNING = is_swap
                            
                            if is_swap:
                                fsm_states[track_id].id_swap_frames += 1
                            else:
                                fsm_states[track_id].id_swap_frames = 0
                                
                            # Ép low_confidence nếu bị 3 frame liên tiếp (N=3)
                            if fsm_states[track_id].id_swap_frames >= 3:
                                fsm_states[track_id].low_confidence = True

                        track_prev_hips[track_id] = current_hip_y
                        velocity_y = float(instant_velocity_y * fps)

                        # [P3] JERK HEURISTIC (Option A — không feed vào LightGBM)
                        # Jerk = đạo hàm velocity: dấu hiệu phân biệt ngã đột ngột vs ngồi xuống từ từ
                        # Cú ngã thật: jerk dương lớn (tăng tốc) rồi âm lớn (phanh khi đập sàn)
                        # Ngồi từ từ: jerk nhỏ, liên tục và đều
                        _fsm_jerk = fsm_states.get(track_id)
                        if _fsm_jerk is not None:
                            jerk = velocity_y - _fsm_jerk.prev_velocity_y
                            _fsm_jerk.prev_velocity_y = velocity_y
                            # Nếu jerk âm lớn (phanh đột ngột) ngay sau velocity dương lớn
                            # → dấu hiệu ngã vật lý cao → giảm xác suất low_confidence sai
                            JERK_FALL_THRESHOLD = 300.0  # px/s² — cần calibrate sau
                            if abs(jerk) > JERK_FALL_THRESHOLD and not _fsm_jerk.low_confidence:
                                # Jerk lớn → tăng cường cảnh giác: reset id_swap_frames (để không bị suppress sai)
                                _fsm_jerk.id_swap_frames = 0
                        else:
                            jerk = 0.0

                        # Standing feature computation
                        head_pts = keypoints[:5]
                        valid_head_pts = head_pts[head_pts[:, 2] > 0.5]
                        head_y = float(np.mean(valid_head_pts[:, 1])) if len(valid_head_pts) > 0 else float(y1)
                        hip_pts = keypoints[11:13]
                        valid_hip_pts = hip_pts[hip_pts[:, 2] > 0.5]
                        hip_y = float(np.mean(valid_hip_pts[:, 1])) if len(valid_hip_pts) > 0 else float(y1 + box_h / 2)

                        # Check if standing
                        # FIX #3: Skip persons too small (far from camera) to be reliable
                        if box_h < MIN_BOX_HEIGHT_PX:
                            continue

                        is_standing = (current_angle < 30.0) and (box_h / box_w >= STANDING_RATIO_THRESHOLD) and (head_y < hip_y)
                        track_standing_history[track_id].append(is_standing)
                        standing_ratio = sum(track_standing_history[track_id]) / len(track_standing_history[track_id])

                        # Standing height baseline for collapse ratio
                        if is_standing:
                            track_standing_heights[track_id].append(box_h)
                            if len(track_standing_heights[track_id]) > 100:
                                track_standing_heights[track_id].pop(0)

                        baseline_height = float(np.median(track_standing_heights[track_id])) if len(track_standing_heights[track_id]) > 0 else float(box_h)
                        height_drop_ratio = float(box_h / baseline_height) if baseline_height > 0 else 1.0
                        
                        # [P6] Khi EDGE_TRUNCATED=True, bbox bị cắt cụt làm aspect ratio méo
                        # → không thể tin vào is_lying_pose từ aspect ratio
                        # → chỉ tin vào velocity (vẫn đo được từ vai/đầu)
                        _fsm_edge = fsm_states.get(track_id)
                        _is_edge_trunc = getattr(_fsm_edge, 'EDGE_TRUNCATED', False)
                        if _is_edge_trunc:
                            is_lying_pose = False
                        else:
                            is_lying_pose = (aspect_ratio > args.aspect_ratio_threshold)
                        is_on_floor = (y2 > FLOOR_Y_MIN)

                        # Append to sliding window
                        track_windows[track_id].append({
                            'velocity_y': velocity_y,
                            'current_angle': current_angle,
                            'height_drop_ratio': height_drop_ratio,
                            'is_lying_pose': 1.0 if is_lying_pose else 0.0,
                            'is_on_floor': 1.0 if is_on_floor else 0.0
                        })

                        # Extract statistics
                        vels = [w['velocity_y'] for w in track_windows[track_id]]
                        angles = [w['current_angle'] for w in track_windows[track_id]]
                        h_drops = [w['height_drop_ratio'] for w in track_windows[track_id]]
                        lying_flags = [w['is_lying_pose'] for w in track_windows[track_id]]
                        floor_flags = [w['is_on_floor'] for w in track_windows[track_id]]

                        # AI Prediction via LightGBM
                        features_input = [[
                            float(np.max(vels)) if vels else 0.0, float(np.mean(vels)) if vels else 0.0, float(np.std(vels)) if vels else 0.0,
                            float(np.max(angles)) if angles else 0.0, float(np.min(h_drops)) if h_drops else 1.0,
                            float(np.mean(lying_flags)) if lying_flags else 0.0, float(np.mean(floor_flags)) if floor_flags else 0.0,
                            velocity_y, current_angle, height_drop_ratio,
                            1.0 if is_lying_pose else 0.0, 1.0 if is_on_floor else 0.0
                        ]]
                        
                        fall_prob = lgb_model.predict(features_input)[0]
                        score = int(fall_prob * 100)
                        track_score[track_id] = score

                        # =====================================================================
                        # HYBRID FSM STATE TRANSITIONS — object-oriented
                        # =====================================================================
                        if track_id not in fsm_states:
                            fsm_states[track_id] = PersonFSM(track_id)
                        
                        fsm = fsm_states[track_id]
                        fsm.STREAM_FROZEN = health_monitor.STREAM_FROZEN
                        wall_now = time.time()
                        
                        decision = evaluate_fsm_transition(
                            fsm=fsm,
                            score=score,
                            is_on_floor=is_on_floor,
                            is_lying_pose=is_lying_pose,
                            current_angle=current_angle,
                            wall_now=wall_now,
                            frame_count=frame_count,
                            args_score_threshold=args.score_threshold
                        )
                        
                        # ALERTS (Based on new fsm state)
                        if fsm.state == "LYING":
                            lying_elapsed = fsm.lying_wall_sec
                            
                            # ── BƯỚC 1: POST 1 lần duy nhất khi fall confirmed ─────────────
                            if not fsm.alert_sent_high and lying_elapsed >= CONFIRMATION_LIMIT_SEC:
                                print(f"\n🚨 {RED}{BOLD}[CONFIRMED FALL] ID {track_id} nằm > {CONFIRMATION_LIMIT_SEC:.1f}s!{RESET}")
                                any_fall_detected = True
                                evt_id = dispatch_alert(args, lying_elapsed, obj_conf, track_id, "v1.2.0-v9-reid-lgb")
                                fsm.event_id_str = evt_id
                                fsm.alert_sent_high = True
                                fsm.last_heartbeat = wall_now
                                
                                if is_imou and recording_frames_left == 0:
                                    recording_frames_left = int(fps * 5)
                                    current_upload_event_id = evt_id

                            # ── BƯỚC 2: Heartbeat PUT mỗi 30s (mirror demo_edge) ──────────
                            elif fsm.alert_sent_high:
                                evt_id = fsm.event_id_str
                                last_hb = fsm.last_heartbeat
                                if evt_id and (wall_now - last_hb) >= 30.0:
                                    threading.Thread(
                                        target=_put_heartbeat,
                                        args=(args.api_url, evt_id, int(lying_elapsed),
                                              "tracking", args.device_key, args.upload_token),
                                        daemon=True
                                    ).start()
                                    fsm.last_heartbeat = wall_now
                                    if lying_elapsed >= CRITICAL_LYING_SEC and not fsm.alert_sent_critical:
                                        print(f"\n🔥 {RED}{BOLD}[CRITICAL] ID {track_id} bất động > {CRITICAL_LYING_SEC:.0f}s — backend sẽ escalate qua heartbeat!{RESET}")
                                        fsm.alert_sent_critical = True
                                        
                        elif fsm.state == "NORMAL" and fsm.event_id_str:
                            # ── BƯỚC 3: PUT recovered khi đứng dậy ──────────────────
                            evt_id = fsm.event_id_str
                            lying_elapsed = fsm.lying_wall_sec
                            threading.Thread(
                                target=_put_heartbeat,
                                args=(args.api_url, evt_id, int(lying_elapsed),
                                      "recovered", args.device_key, args.upload_token),
                                daemon=True
                            ).start()
                            fsm.event_id_str = None
                            print(f"\n🟢 {GREEN}[INFO] ID {track_id} đã đứng dậy tại t={current_timestamp}s.{RESET}")

                        # FIX #1: Per-second log — in ra mỗi giây 1 dòng tóm tắt
                        current_second = int(frame_count / fps) if fps > 0 else 0
                        if current_second != last_log_second:
                            last_log_second = current_second
                            lying_sec_display = round(track_lying_wall_sec.get(track_id, 0.0), 1)
                            suspect_disp = track_suspect_frames.get(track_id, 0)
                            above_disp  = track_above_threshold.get(track_id, 0)
                            print(f"[{current_second:>5}s] ID {track_id:<3} | {fsm.state:<7} "
                                  f"| Score:{score:>3}% | Angle:{current_angle:>5.1f}° | Vel:{velocity_y:>7.1f} "
                                  f"| Lying:{lying_sec_display}s | KP:{valid_kp_count}/17 "
                                  f"| Suspect:{suspect_disp} Above:{above_disp} | Box:{int(box_w)}x{int(box_h)}px")

                        # Apply face anonymization in RAM
                        annotated_frame = blur_face_on_ram(annotated_frame, keypoints, padding=25)

                        # Set HUD bounding box colors and messages
                        id_state = fsm.state
                        box_color = (0, 255, 0)  # Green for Normal
                        if id_state == "FALLING":
                            box_color = (0, 165, 255)  # Orange for Falling
                        elif id_state == "LYING":
                            box_color = (0, 0, 255)  # Red for Lying

                        cv2.rectangle(annotated_frame, (int(x1), int(y1)), (int(x2), int(y2)), box_color, 2)
                        
                        hud_text_1 = f"ID {track_id} | State: {id_state}"
                        hud_text_2 = f"Score: {score}% | {decision}"
                        text_y1 = max(15, int(y1) - 25)
                        text_y2 = max(30, int(y1) - 8)
                        cv2.putText(annotated_frame, hud_text_1, (int(x1), text_y1), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
                        cv2.putText(annotated_frame, hud_text_2, (int(x1), text_y2), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255) if decision == "FALL" else (0, 255, 0), 1, cv2.LINE_AA)

                        if id_state == "LYING":
                            _lying_elapsed = track_lying_wall_sec.get(track_id, 0.0)
                            if track_alert_sent_critical.get(track_id, False):
                                global_hud_status = f"🔥 CRITICAL: ID {track_id} INJURED ({_lying_elapsed:.0f}s)"
                                global_hud_color = (0, 0, 255)
                            elif fsm_states[track_id].alert_sent_high:
                                global_hud_status = f"⚠️ CONFIRMED FALL: ID {track_id} ({_lying_elapsed:.1f}s)"
                                global_hud_color = (0, 165, 255)
                            else:
                                global_hud_status = f"⏳ PENDING ({_lying_elapsed:.1f}/{CONFIRMATION_LIMIT_SEC:.1f}s): ID {track_id}"
                                global_hud_color = (0, 255, 255)
                        elif id_state == "FALLING" and global_hud_status == "🟢 MONITORING (NORMAL)":
                            global_hud_status = f"⏳ MONITORING STATE: ID {track_id}"
                            global_hud_color = (0, 255, 255)

                else:
                    active_area_ratios = []
                    person_count = 0

                # Chặn bắt cờ CAMERA_OFFLINE trước khi nó bị check_frame() reset về False
                if health_monitor.CAMERA_OFFLINE:
                    health_monitor.last_offline_display_time = time.time()

                health_monitor.check_frame(frame, current_timestamp, active_area_ratios, person_count)

                # --- XỬ LÝ SYSTEM HEALTH LAYER (HUD & CACHE) ---
                if time.time() - getattr(health_monitor, 'last_offline_display_time', 0) < 5.0:
                    global_hud_status = "🔴 CAMERA RECOVERING"
                    global_hud_color = (0, 0, 255)
                elif health_monitor.CAMERA_OCCLUDED:
                    global_hud_status = "👁️ CAMERA OCCLUDED"
                    global_hud_color = (0, 0, 255)
                    track_lost_cache.clear()
                elif health_monitor.CAMERA_SHIFTED:
                    global_hud_status = "🔀 CAMERA SHIFTED"
                    global_hud_color = (0, 165, 255)
                    track_lost_cache.clear()
                elif health_monitor.LENS_DEGRADED:
                    global_hud_status = "🌫️ LENS DEGRADED"
                    global_hud_color = (0, 165, 255)
                elif health_monitor.STREAM_FROZEN:
                    global_hud_status = "❄️ STREAM FROZEN"
                    global_hud_color = (0, 255, 255)

                # =====================================================================
                # FIX #4: Lost tracks Re-ID — game "Entity Resurrection" pattern
                # =====================================================================
                detected_ids_set = set(track_ids) if (results[0].boxes is not None and results[0].boxes.id is not None) else set()
                wall_now_cache = time.time()
                for active_id in list(fsm_states.keys()):
                    if active_id not in detected_ids_set:
                        cached_state = fsm_states[active_id].state
                        track_lost_cache[active_id] = {
                            "fsm": fsm_states[active_id],
                            "bbox": track_last_bboxes.get(active_id, (0,0,0,0)),
                            "window": track_windows.get(active_id, deque(maxlen=WINDOW_SIZE)),
                            "prev_hip": track_prev_hips.get(active_id, None),
                            "age": track_ages.get(active_id, 0),
                            "standing_history": track_standing_history.get(active_id, deque([True]*20, maxlen=20)),
                            "standing_heights": track_standing_heights.get(active_id, []),
                            "score": track_score.get(active_id, 0),
                            "timestamp": wall_now_cache,
                        }
                        if cached_state in ("LYING", "FALLING"):
                            print(f"[Re-ID CACHE] ID {active_id} lost (state={cached_state}). Holding 15s...")

                        # [P4] Khởi tạo Kalman từ vị trí hông & velocity cuối cùng biết
                        _last_hip  = track_prev_hips.get(active_id)
                        _last_vel  = (fsm_states[active_id].ema_velocity_y
                                      if hasattr(fsm_states[active_id], 'ema_velocity_y') else 0.0)
                        track_lost_cache[active_id]["kalman"] = (
                            SimpleKalman1D(_last_hip, _last_vel / fps if fps > 0 else 0.0)
                            if _last_hip is not None else None
                        )

                        # Remove from active trackers
                        fsm_states.pop(active_id, None)
                        track_windows.pop(active_id, None)
                        track_prev_hips.pop(active_id, None)
                        track_spike_frames.pop(active_id, None)
                        track_ages.pop(active_id, None)
                        track_standing_history.pop(active_id, None)
                        track_standing_heights.pop(active_id, None)
                        track_score.pop(active_id, None)
                        track_lying_start_wall.pop(active_id, None)
                        track_lying_wall_sec.pop(active_id, None)
                        track_alert_sent_high.pop(active_id, None)
                        track_alert_sent_critical.pop(active_id, None)
                        track_event_id.pop(active_id, None)
                        track_last_heartbeat.pop(active_id, None)
                        track_suspect_frames.pop(active_id, None)
                        track_above_threshold.pop(active_id, None)

                # Expire cache: NORMAL=5s, LYING/FALLING=15s (game entity resurrection)
                for old_id in list(track_lost_cache.keys()):
                    info = track_lost_cache[old_id]
                    st = info["fsm"].state
                    ttl = 15.0 if st in ("LYING", "FALLING") else 7.0  # NORMAL: 7s (≥ OCCLUSION_TIMEOUT 4s + 2s buffer, REQ-023)
                    if not is_imou:
                        ttl = 300.0 # Bỏ qua expire với video upload để vớt flush cuối video chắc chắn 100%
                    
                    # =========================================================
                    # REQ-023: OCCLUSION_SUSPECT (Per-track)
                    # =========================================================
                    time_in_cache = wall_now_cache - info["timestamp"]

                    # REQ-014 Logic: Xóa an toàn nếu track biến mất khi đang chạm biên
                    if getattr(info["fsm"], 'EDGE_TRUNCATED', False):
                        print(f"[EDGE_TRUNCATED] ID {old_id} lost at edge. Safely deleted.")
                        track_lost_cache.pop(old_id, None)
                        continue

                    if time_in_cache >= 4.0 and st != "SUSPECT":
                        x1, y1, x2, y2 = info["bbox"]
                        EDGE_MARGIN = 30
                        is_near_edge = (x1 <= EDGE_MARGIN or y1 <= EDGE_MARGIN
                                        or x2 >= width - EDGE_MARGIN or y2 >= height - EDGE_MARGIN)
                        if not is_near_edge:
                            info["fsm"].transition_to("SUSPECT", wall_now_cache)
                            st = "SUSPECT"
                            print(f"[OCCLUSION_SUSPECT] ID {old_id} lost mid-frame for >=4s. Transitioning to SUSPECT.")
                    # =========================================================

                    if time_in_cache > ttl:
                        print(f"[Re-ID EXPIRE] ID {old_id} (state={st}) expired from cache after {ttl:.0f}s.")
                        track_lost_cache.pop(old_id, None)
                        continue

                    # [P4] DEAD RECKONING — predict-only khi track đang trong cache
                    # Mọ đích: duy trì velocity signal không bị gãy về 0 trong lúc mất YOLO
                    _kalman = info.get("kalman")
                    if _kalman is not None:
                        pred_y, pred_vy = _kalman.predict()
                        # Append dữ liệu dự đoán vào sliding window của track
                        pred_vel_scaled = float(pred_vy * fps)  # px/frame → px/s
                        info["window"].append({
                            'velocity_y':      pred_vel_scaled,
                            'current_angle':   0.0,    # không có keypoint thật
                            'height_drop_ratio': 1.0,  # không rõ — giữ trung lập
                            'is_lying_pose':   0.0,    # không rõ
                            'is_on_floor':     0.0     # không rõ
                        })
                        # Bắt buộc low_confidence — FSM không được escalate tự dự liệu này
                        info["fsm"].low_confidence = True

                # --- RENDER HUD AND PUSH FRAME FOR EVERY FRAME ---
                # Even if no person is detected, we must write to output and push to WebSocket
                # so the frontend video player receives a continuous stream and doesn't freeze.
                cv2.rectangle(annotated_frame, (10, 10), (450, 95), (0, 0, 0), -1)
                cv2.putText(annotated_frame, f"Status: {global_hud_status}", (20, 45), cv2.FONT_HERSHEY_SIMPLEX, 0.7, global_hud_color, 2)
                cv2.putText(annotated_frame, f"Frame: {frame_count} | Active IDs: {list(fsm_states.keys())}", (20, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

                # --- Resize for Publisher and Buffering ---
                small_frame = cv2.resize(annotated_frame, (640, 360)) if is_imou else annotated_frame

                if args.output:
                    out.write(annotated_frame)
                if publisher:
                    publisher.put_frame(small_frame)

                # --- Video Buffering Logic ---
                if is_imou:
                    # RAM OPTIMIZATION: Encode to JPEG to save 95% RAM (691KB -> 30KB per frame)
                    # Prevents Railway 500MB OOM Killer when buffer is full (100+ frames)
                    _, jpeg_buf = cv2.imencode('.jpg', small_frame, [cv2.IMWRITE_JPEG_QUALITY, 60])
                    
                    if recording_frames_left > 0:
                        post_fall_buffer.append(jpeg_buf)
                        recording_frames_left -= 1
                        if recording_frames_left == 0:
                            _save_and_upload_clip(
                                args.api_url, 
                                args.device_key, 
                                current_upload_event_id, 
                                list(pre_fall_buffer), 
                                post_fall_buffer, 
                                fps, 640, 360
                            )
                            post_fall_buffer = []
                            current_upload_event_id = None
                    else:
                        pre_fall_buffer.append(jpeg_buf)

        finally:
            # End-of-Video Flush: Vớt các cảnh báo lửng lơ ở video clip ngắn
            # Chỉ flush khi video_upload (không phải Imou live) để tránh false positive
            if not is_imou:
                # Flush active trackers
                for tid, fsm in fsm_states.items():
                    if fsm.state in ["FALLING", "LYING"]:
                        print(f"\n🚨 {RED}{BOLD}[END-OF-VIDEO FLUSH] Active ID {tid} kẹt ở trạng thái {fsm.state} khi video kết thúc! Triggering fallback alert...{RESET}")
                        lying_elapsed = max(60.0, fsm.lying_wall_sec) # Ép lên 60s để backend nhận định HIGH ngay lập tức
                        dispatch_alert(args, lying_elapsed, 0.99, tid, "v1.2.0-v9-reid-lgb-flush")
                
                # Flush cached (lost) trackers
                for old_id, info in track_lost_cache.items():
                    fsm = info["fsm"]
                    if fsm.state in ["FALLING", "LYING"]:
                        print(f"\n🚨 {RED}{BOLD}[END-OF-VIDEO FLUSH] Lost ID {old_id} (cache) kẹt ở trạng thái {fsm.state} khi video kết thúc! Triggering fallback alert...{RESET}")
                        lying_elapsed = max(60.0, fsm.lying_wall_sec) # Ép lên 60s để backend nhận định HIGH ngay lập tức
                        dispatch_alert(args, lying_elapsed, 0.99, old_id, "v1.2.0-v9-reid-lgb-flush")
            if publisher:
                publisher.stop()
            cap.release()
            out.release()
            # Cleanup temp downloaded file to prevent disk fill on Railway Free
            if tmp_file_path and os.path.exists(tmp_file_path):
                try:
                    os.unlink(tmp_file_path)
                    print(f"🗑️ Temp file cleaned up: {tmp_file_path}")
                except Exception:
                    pass
            print(f"\n💾 {GREEN}[SUCCESS]{RESET} Processed video output saved to: {args.output}")
            print(f"=======================================================")

        if not is_imou:
            print(f"⏳ Đang đợi 3 giây để các tiến trình mạng (gửi cảnh báo, websocket) hoàn tất...")
            time.sleep(3)
            break
        else:
            print(f"⏳ HLS Stream completed or dropped. Reconnecting in 5 seconds to avoid API rate limits...")
            time.sleep(5)


# =====================================================================
# MAIN ENTRYPOINT
# =====================================================================
def main():
    parser = argparse.ArgumentParser(description="SilentGuard AI — Edge V9 Continuous Monitoring (FSM + LightGBM)")
    
    # Sign-in / Upload flow parameters
    parser.add_argument("--video-url", type=str, default="", help="Signed video HLS/MP4 URL for remote streaming")
    parser.add_argument("--upload-token", type=str, default="", help="Authentication token for upload-based flow")
    
    # Classic local file / Camera parameters
    parser.add_argument("--input", type=str, default="mobile/assets/videos/videoplayback.mp4", 
                        help="Path to input video file or RTSP stream URL")
    parser.add_argument("--device-key", type=str, default="", help="Device license API key for direct posting")
    
    # Outputs & Model configurations
    parser.add_argument("--output", type=str, default="clips/test-household/demo_v9.mp4", 
                        help="Output file path to save annotated frames")
    parser.add_argument("--model-path", type=str, default="models/fall_lgb_model.txt", 
                        help="Path to LightGBM model file (fall_lgb_model.txt)")
    parser.add_argument("--room", type=str, default="bedroom", help="Identifier of monitored room")
    parser.add_argument("--api-url", type=str, default="https://c2-app-128-production-e0f9.up.railway.app/api/events/detect",
                        help="FastAPI POST detection API endpoint URL")
    
    # Algorithm configuration overrides
    parser.add_argument("--floor-zone-ratio", type=float, default=FLOOR_ZONE_RATIO,
                        help="Floor zone starting ratio relative to frame height (0.0 to 1.0)")
    parser.add_argument("--aspect-ratio-threshold", type=float, default=ASPECT_RATIO_THRESHOLD,
                        help="Bounding box aspect ratio threshold for lying posture check")
    parser.add_argument("--score-threshold", type=int, default=SCORE_THRESHOLD,
                        help="Threshold for LightGBM fall probability score (0 to 100)")
    parser.add_argument("--confirmation-limit", type=float, default=CONFIRMATION_LIMIT_SEC,
                        help="Seconds of continuous floor lying required to trigger fall warning")
    parser.add_argument("--quantize", type=str, default="none", choices=["none", "fp16"],
                        help="[P7] YOLO model quantization: 'fp16' giảm CPU load khi 3-5 camera, 'none' FP32 mặc định")

    args = parser.parse_args()
    
    # Check for environmental overrides (common in Railway/Edge deployments)
    env_device_key = os.getenv("DEVICE_API_KEY")
    if env_device_key and not args.device_key:
        args.device_key = env_device_key
        
    env_backend_url = os.getenv("BACKEND_URL")
    if env_backend_url:
        args.api_url = f"{env_backend_url.rstrip('/')}/api/events/detect"

    process_video_stream(args)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{GRAY}Process interrupted by keyboard command. Shutting down Edge pipe.{RESET}\n")
        sys.exit(0)
