#!/usr/bin/env python3
"""
SilentGuard AI — Edge Device Demo Script (MVP V1)
Ported from Kaggle core AI pipeline with privacy blur and dual authentication flow.

Usage:
  # Demo Flow (Web/App Client Upload)
  python src/edge/demo_edge.py --video-url "https://..." --upload-token "vid_..."

  # Classic Flow (Local Camera Stream Simulation)
  python src/edge/demo_edge.py --input "path/to/video.mp4" --device-key "sg_live_..."
"""

import os
import sys
import socket
import cv2
import numpy as np
import math
import threading
import queue
import time
import json
import secrets
import argparse
import requests
from collections import deque
from datetime import datetime, timezone
from ultralytics import YOLO

# =====================================================================
# WEBSOCKET RELAY PUBLISHER
# Push annotated frames (before face-blur) to Backend Relay.
# Only activates when --camera-id is supplied. Fully isolated from
# existing Demo Flow and Classic Flow logic.
# =====================================================================
ws_queue = queue.Queue(maxsize=30)  # Drop old frames if relay is slow
ws_backend_url = None
ws_camera_id = None

def websocket_publisher():
    """Background thread: reads frames from ws_queue, pushes to Backend Relay via WebSocket."""
    if not ws_camera_id or not ws_backend_url:
        return
    import urllib.parse
    parsed = urllib.parse.urlparse(ws_backend_url)
    scheme = "wss" if parsed.scheme == "https" else "ws"
    uri = f"{scheme}://{parsed.netloc}/api/streams/{ws_camera_id}/publish"

    while True:
        try:
            from websockets.sync.client import connect
            print(f"[WebSocket] Connecting to relay: {uri}")
            with connect(uri) as ws:
                print("[WebSocket] Relay connected.")
                while True:
                    frame_bytes = ws_queue.get()
                    if frame_bytes is None:  # Poison pill — stop thread
                        return
                    ws.send(frame_bytes)
        except ImportError:
            print("[WebSocket] 'websockets' library not installed. Relay disabled.")
            break
        except Exception as e:
            print(f"[WebSocket] Relay disconnected ({e}). Retrying in 5s...")
            time.sleep(5)

# =====================================================================
# RAW SOCKET DNS-OVER-HTTPS RESOLVER
# Connects directly to DNS servers via raw TCP+TLS — zero DNS dependency.
# Tries Google (8.8.8.8) then Cloudflare (1.1.1.1).
# Also follows CNAME chains and tries alternative hostnames.
# =====================================================================

def _raw_doh_query(dns_ip, hostname, qtype="A"):
    """Low-level: send a single DoH query to a DNS server IP via raw TCP+TLS.
    
    Returns the parsed JSON dict, or None on failure.
    """
    import ssl

    # Google uses /resolve, Cloudflare uses /dns-query
    if dns_ip == '8.8.8.8':
        path = f"/resolve?name={hostname}&type={qtype}"
        host_header = "dns.google"
    else:
        path = f"/dns-query?name={hostname}&type={qtype}"
        host_header = "cloudflare-dns.com"
    
    http_request = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {host_header}\r\n"
        f"Accept: application/dns-json\r\n"
        f"Connection: close\r\n"
        f"\r\n"
    )

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10)

    try:
        wrapped = ctx.wrap_socket(sock)
        wrapped.connect((dns_ip, 443))
        wrapped.sendall(http_request.encode('utf-8'))

        response = b''
        while True:
            chunk = wrapped.recv(4096)
            if not chunk:
                break
            response += chunk
        wrapped.close()
    except Exception as e:
        sock.close()
        print(f"[DNS-RAW] Lỗi kết nối tới DoH server {dns_ip}: {e}")
        return None

    # Split HTTP headers from body
    header_body = response.split(b'\r\n\r\n', 1)
    if len(header_body) < 2:
        print(f"[DNS-RAW] Response không hợp lệ từ {dns_ip}")
        return None

    headers_raw, body_raw = header_body

    # Properly decode chunked transfer encoding
    if b'Transfer-Encoding: chunked' in headers_raw or b'transfer-encoding: chunked' in headers_raw:
        decoded_body = b''
        remaining = body_raw
        while remaining:
            # Find end of chunk size line
            crlf_pos = remaining.find(b'\r\n')
            if crlf_pos == -1:
                break
            # Parse chunk size (hex)
            size_hex = remaining[:crlf_pos].strip()
            try:
                chunk_size = int(size_hex, 16)
            except ValueError:
                break
            if chunk_size == 0:
                break
            # Extract chunk data
            chunk_data = remaining[crlf_pos + 2 : crlf_pos + 2 + chunk_size]
            decoded_body += chunk_data
            # Move past chunk data + trailing \r\n
            remaining = remaining[crlf_pos + 2 + chunk_size + 2:]
        body_raw = decoded_body

    try:
        data = json.loads(body_raw)
        return data
    except (json.JSONDecodeError, ValueError) as e:
        print(f"[DNS-RAW] JSON parse error từ {dns_ip}: {e} | body: {body_raw[:300]}")
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
            # Maybe it's a CNAME chain — follow it
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


# =====================================================================
# RECALL-OPTIMIZED HYPERPARAMETERS (PASSED FROM PRODUCT SPEC & LABS)
# =====================================================================
CONFIDENCE_THRESHOLD = 0.45   # Confidence filter for pose keypoints
WINDOW_SIZE = 32              # Sliding window frame size (16-32 frames at ~15 FPS)
VELOCITY_THRESHOLD = 50       # Vertical velocity threshold (pixels/sec) to capture slow falls
ANGLE_THRESHOLD = 35          # Torso lean angle threshold (degrees) relative to vertical
TRANSITION_LIMIT = 2.0        # Max transition time (seconds) to distinguish from active lying down

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
    Calculate the torso angle relative to the vertical line (Y-axis).
    0 degrees = standing upright | 90 degrees = horizontal on floor.
    """
    dx = hip_x - sh_x
    dy = hip_y - sh_y
    # Avoid zero division and calculate absolute angle
    angle_rad = math.atan2(abs(dx), dy)
    angle_deg = math.degrees(angle_rad)
    return angle_deg


def blur_face_on_ram(frame, keypoints, padding=25):
    """
    Locate the head area using COCO face keypoints (indices 0-4: nose, eyes, ears)
    and apply Gaussian Blur directly on the image matrix in RAM.
    """
    face_pts = keypoints[:5]
    # Filter points that are confidently detected (confidence > 0.5)
    valid_pts = face_pts[face_pts[:, 2] > 0.5]

    if len(valid_pts) > 0:
        h, w, _ = frame.shape
        x_min = max(0, int(np.min(valid_pts[:, 0])) - padding)
        y_min = max(0, int(np.min(valid_pts[:, 1])) - padding)
        x_max = min(w, int(np.max(valid_pts[:, 0])) + padding)
        y_max = min(h, int(np.max(valid_pts[:, 1])) + padding)

        face_zone = frame[y_min:y_max, x_min:x_max]

        if face_zone.size > 0 and face_zone.shape[0] > 0 and face_zone.shape[1] > 0:
            # Dynamically calculate odd kernel dimensions based on size
            k_width = int(face_zone.shape[1] // 3) * 2 + 1
            k_height = int(face_zone.shape[0] // 3) * 2 + 1

            # Keep kernel bounds safe to prevent segmentation faults
            k_width = max(3, min(k_width, 51))
            k_height = max(3, min(k_height, 51))

            # Apply blur
            blurred_face = cv2.GaussianBlur(face_zone, (k_width, k_height), 0)
            frame[y_min:y_max, x_min:x_max] = blurred_face

    return frame

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
        verify=False  # cert is for openapi.imoulife.com, not the IP
    )


def get_imou_live_stream_url():
    """Dynamically fetches the live HLS stream (.m3u8) from Imou Cloud OpenAPI.
    
    Uses raw socket DoH to resolve Imou's domain, then connects directly
    to the resolved IP — completely bypasses system DNS.
    """
    import hashlib
    import uuid
    import requests
    import warnings
    warnings.filterwarnings('ignore', message='Unverified HTTPS request')
    
    app_id = os.getenv("IMOU_APP_ID")
    app_secret = os.getenv("IMOU_APP_SECRET")
    device_sn = os.getenv("IMOU_DEVICE_SN")
    
    print(f"[Imou] Kiểm tra env — IMOU_APP_ID={'set' if app_id else 'MISSING'}, IMOU_APP_SECRET={'set' if app_secret else 'MISSING'}, IMOU_DEVICE_SN={device_sn or 'MISSING'}")
    
    if not app_id or not app_secret or not device_sn:
        raise Exception("Thiếu cấu hình IMOU_APP_ID, IMOU_APP_SECRET, hoặc IMOU_DEVICE_SN trong biến môi trường")
    
    # ── Step 0: Resolve Imou API IP ──────────────────────────────────
    # Priority: IMOU_API_IP env var > DoH resolve > fallback hostnames
    manual_ip = os.getenv("IMOU_API_IP")
    IMOU_HOST = os.getenv("IMOU_API_HOST", "openapi.easy4ip.com")
    
    if manual_ip:
        imou_ip = manual_ip
        print(f"[Imou] Bước 0: Dùng IP thủ công từ IMOU_API_IP={imou_ip}")
    else:
        # Try multiple hostnames — easy4ip.com is the standard Imou API domain
        # openapi-sg.easy4ip.com is the Asia-Pacific regional gateway
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
    # Official SDK does this — the accessToken response tells us which
    # regional server to use for all subsequent API calls.
    current_domain = token_data.get("currentDomain")
    if current_domain:
        if "://" not in current_domain:
            current_domain = f"https://{current_domain}"
        from urllib.parse import urlparse as _urlparse
        parsed_domain = _urlparse(current_domain)
        if parsed_domain.hostname:
            new_host = parsed_domain.hostname  # hostname strips port, netloc keeps it
            print(f"[Imou] Bước 1b: API trả về currentDomain={new_host}, chuyển sang domain mới ...")
            # Resolve the new domain's IP
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
        "streamId": 1,
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
    print(f"[Imou] liveList full response: {json.dumps(live_json, indent=2)[:500]}")
    
    if live_code != "0":
        # Try bindDeviceLive then retry
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
            "streamId": 1,
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
            "streamId": 1,
        }
        body["id"] = str(uuid.uuid4())
        
        print(f"[Imou] Bước 2c: Thử lại liveList sau bind ...")
        try:
            res_live = _imou_api_post(session, live_url, body, imou_ip)
            live_json = res_live.json()
            print(f"[Imou] Retry result: code={live_json.get('result', {}).get('code')}")
        except Exception as e:
            raise Exception(f"[Imou] Network error khi gọi liveList lần 2: {e}")
        
    # Extract HLS URL from response
    live_data = live_json.get("result", {}).get("data", {})
    # liveList may return data in different formats
    hls_url = None
    if isinstance(live_data, dict):
        hls_url = live_data.get("hlsUrl") or live_data.get("hls")
        # Sometimes data contains a "streams" list
        streams = live_data.get("streams", [])
        if not hls_url and streams:
            # Ưu tiên lấy luồng phụ (streamId = 1) vì nó thường là H.264
            for s in streams:
                if s.get("hls") and s.get("streamId") in [1, "1"]:
                    hls_url = s["hls"]
                    break
            # Nếu không tìm thấy luồng phụ, lấy luồng đầu tiên có
            if not hls_url:
                for s in streams:
                    if s.get("hls"):
                        hls_url = s["hls"]
                        break
    elif isinstance(live_data, list) and live_data:
        for item in live_data:
            if isinstance(item, dict) and (item.get("hlsUrl") or item.get("hls")):
                hls_url = item.get("hlsUrl") or item.get("hls")
                break
    
    if not hls_url:
        raise Exception(f"Không thể lấy link stream từ Imou: {live_json.get('result', {}).get('msg')} | data: {str(live_data)[:300]}")
    
    print(f"[Imou] ✅ HLS URL lấy thành công.")
    return hls_url



class ThreadedCamera:
    def __init__(self, src):
        self.cap = cv2.VideoCapture(src)
        self.q = queue.Queue(maxsize=30)
        self.stopped = False
        self.t = threading.Thread(target=self._reader)
        self.t.daemon = True
        self.t.start()
        
    def _reader(self):
        while not self.stopped:
            if not self.q.full():
                ret, frame = self.cap.read()
                if not ret:
                    self.stopped = True
                    break
                self.q.put((ret, frame))
            else:
                time.sleep(0.01)
                
    def read(self, timeout=10.0):
        try:
            return self.q.get(timeout=timeout)
        except queue.Empty:
            return False, None
            
    def release(self):
        self.stopped = True
        self.cap.release()
        
    def isOpened(self):
        return self.cap.isOpened()
        
    def get(self, propId):
        return self.cap.get(propId)

def process_video_stream(args):

    print(f"\n=======================================================")
    print(f"🎬 {BOLD}SILENTGUARD AI EDGE ENGINE — CORE PIPELINE INITIALIZATION{RESET}")
    print(f"=======================================================")

    # Determine video source
    video_source = args.video_url if args.video_url else args.input
    is_imou = False
    if video_source and video_source.lower() == "imou":
        is_imou = True

    print(f"📦 Loading YOLOv8-Pose model...")
    try:
        ov_path = 'yolov8n-pose_openvino_model'
        if not os.path.exists(ov_path):
            print(f"⚙️ Exporting YOLOv8 to OpenVINO for Intel CPU optimization (imgsz=640)...")
            temp_model = YOLO('yolov8n-pose.pt')
            temp_model.export(format="openvino", imgsz=640, half=True)
            del temp_model
            import gc; gc.collect()
            
        model = YOLO(ov_path, task='pose')
        print(f"✅ OpenVINO Model loaded successfully.")
    except Exception as e:
        print(f"{RED}[ERROR] Failed to load YOLOv8 model:{RESET} {e}")
        sys.exit(1)

    cooldown_until = 0.0

    while True:
        current_source = video_source
        if is_imou:
            print(f"🔄 Resolving dynamic HLS Stream URL from Imou Cloud API...")
            try:
                current_source = get_imou_live_stream_url()
                print(f"✅ Resolved Imou Stream URL: {BLUE}{current_source}{RESET}")
            except Exception as e:
                print(f"{RED}[ERROR] Failed to resolve Imou stream URL: {e}{RESET}")
                if is_imou:
                    print(f"⏳ Chờ 10 giây trước khi thử resolve lại...")
                    time.sleep(10)
                    continue
                else:
                    sys.exit(1)

        if not current_source:
            print(f"{RED}[ERROR]{RESET} No input source resolved.")
            if is_imou:
                time.sleep(5)
                continue
            sys.exit(1)

        print(f"📡 Video Source: {BLUE}{current_source}{RESET}")
        
        # Download HTTP videos locally first to prevent cv2.VideoCapture from hanging on large files
        if not is_imou and current_source.startswith("http"):
            import tempfile
            import urllib.request
            print(f"📥 Downloading video locally to avoid OpenCV HTTP stream hanging...")
            tmp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
            try:
                req = urllib.request.Request(current_source, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(req, timeout=30) as response, open(tmp_file.name, 'wb') as out_file:
                    out_file.write(response.read())
                print(f"✅ Download complete: {tmp_file.name}")
                current_source = tmp_file.name
            except Exception as e:
                print(f"{RED}❌ Failed to download video: {e}{RESET}")
                # Không fallback sang stream trực tiếp vì OpenCV sẽ treo, huỷ luôn
                sys.exit(1)

        cap = ThreadedCamera(current_source)
        if not cap.isOpened():
            print(f"{RED}[ERROR] Could not open video source:{RESET} {current_source}")
            if is_imou:
                print(f"⏳ Thử kết nối lại sau 5 giây...")
                time.sleep(5)
                continue
            sys.exit(1)

        # Retrieve video parameters
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        if fps <= 0:
            fps = 15
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        print(f"⚙️ Video Properties: {width}x{height} | {fps} FPS | Approx {total_frames} frames")
        print(f"-------------------------------------------------------")

        # Set up output directory and video writer
        output_dir = os.path.dirname(args.output)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir, exist_ok=True)

        

        # Sliding window queue and state variables
        pre_fall_buffer = deque(maxlen=int(fps * 10))
        post_fall_buffer = []
        recording_frames_left = 0
        dynamic_clip_path = args.output

        frame_count = 0
        
        # Multi-person tracking states
        person_states = {}
        
        import threading
        def send_heartbeat(e_id, dur, st):
            import urllib.parse
            parsed_url = urllib.parse.urlparse(args.api_url)
            base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
            hb_url = f"{base_url}/api/events/{e_id}/duration"
            headers_hb = {'Content-Type': 'application/json'}
            if args.device_key:
                headers_hb['X-Device-Key'] = args.device_key
            elif args.upload_token:
                headers_hb['X-Upload-Token'] = args.upload_token
                
            payload_hb = {"duration_sec": dur, "status": st}
            try:
                requests.put(hb_url, headers=headers_hb, json=payload_hb, timeout=10)
            except Exception as ex:
                print(f"{RED}❌ Lỗi gửi Heartbeat:{RESET} {ex}")
                

        
        # Biến tracking hiển thị trạng thái ngã tạm thời trên luồng live
        fall_display_frames_remaining = 0

        print(f"🏃 Starting video processing loop...")

        # Track if a fall event was dispatched to prevent double callbacks
        fall_dispatched = False
        last_results = None

        try:
            while cap.isOpened():
                ret, frame = cap.read()
                if not ret:
                    if is_imou:
                        print(f"{YELLOW}[Stream] Hết buffer HLS hoặc mất kết nối tạm thời. Đang reconnect...{RESET}")
                    break


                frame_count += 1
                
                # Garbage Collection để chống đầy RAM (OOM)
                if frame_count % 300 == 0:
                    import gc; gc.collect()
                
                vid_stride = 5 if is_imou else 3
                if frame_count % vid_stride == 0 or last_results is None:
                    # Run YOLOv8 Pose inference (imgsz=480 to save CPU)
                    results = model.track(frame, persist=True, tracker="botsort.yaml", imgsz=640, verbose=False)
                    last_results = results
                else:
                    results = last_results

                active_track_ids = set()
                any_fall_display = False
                annotated_frame = results[0].plot() if results[0].keypoints is not None else frame.copy()

                if results[0].boxes is not None and results[0].boxes.id is not None and results[0].keypoints is not None:
                    for i in range(len(results[0].boxes.id)):
                        track_id = int(results[0].boxes.id[i].item())
                        active_track_ids.add(track_id)
                        
                        if track_id not in person_states:
                            person_states[track_id] = {
                                'frame_window': deque(maxlen=WINDOW_SIZE),
                                'prev_hip_y': None,
                                'velocity_spike_frame': None,
                                'transition_time': 0.0,
                                'detected_conf': 0.88,
                                'event_timestamp': None,
                                'tracking_event_id': None,
                                'tracking_start_time': None,
                                'tracking_last_heartbeat': None,
                                'recovery_frames': 0,
                                'cooldown_until': 0.0,
                                'fall_display_frames_remaining': 0,
                                'current_angle': 0.0,
                                'fall_triggered_this_frame': False
                            }
                        state = person_states[track_id]
                        state['fall_triggered_this_frame'] = False

                        keypoints = results[0].keypoints.data[i].cpu().numpy()
                        if len(keypoints) < 13: continue
                        
                        conf_shoulders = (keypoints[5][2] + keypoints[6][2]) / 2
                        conf_hips = (keypoints[11][2] + keypoints[12][2]) / 2

                        aspect_ratio = 0.0
                        box = results[0].boxes.data[i].cpu().numpy()
                        x1, y1, x2, y2 = box[:4]
                        box_w = x2 - x1
                        box_h = y2 - y1
                        if box_h > 0:
                            aspect_ratio = box_w / box_h

                        is_keypoints_valid = conf_shoulders >= CONFIDENCE_THRESHOLD and conf_hips >= CONFIDENCE_THRESHOLD
                        is_lying_bb = aspect_ratio > 1.2 and conf_shoulders >= 0.3
                        velocity_y = 0.0
                        
                        if is_keypoints_valid or is_lying_bb:
                            if is_keypoints_valid:
                                sh_x = (keypoints[5][0] + keypoints[6][0]) / 2
                                sh_y = (keypoints[5][1] + keypoints[6][1]) / 2
                                hip_x = (keypoints[11][0] + keypoints[12][0]) / 2
                                hip_y = (keypoints[11][1] + keypoints[12][1]) / 2

                                if state['prev_hip_y'] is not None:
                                    fps_multiplier = fps / 3.0 if not is_imou else fps
                                    velocity_y = (hip_y - state['prev_hip_y']) * fps_multiplier
                                state['prev_hip_y'] = hip_y
                                state['current_angle'] = calculate_torso_angle(sh_x, sh_y, hip_x, hip_y)
                            else:
                                state['current_angle'] = 90.0
                                velocity_y = 0.0
                                state['prev_hip_y'] = None

                            state['frame_window'].append({'velocity': velocity_y, 'angle': state['current_angle']})

                            if velocity_y > VELOCITY_THRESHOLD:
                                state['velocity_spike_frame'] = frame_count

                            if len(state['frame_window']) == state['frame_window'].maxlen:
                                has_velocity_spike = any(f['velocity'] > VELOCITY_THRESHOLD for f in state['frame_window'])

                                if has_velocity_spike and state['current_angle'] > ANGLE_THRESHOLD:
                                    if state['velocity_spike_frame'] is not None:
                                        state['transition_time'] = (frame_count - state['velocity_spike_frame']) / fps
                                    else:
                                        state['transition_time'] = 0.4

                                    if state['transition_time'] < TRANSITION_LIMIT:
                                        state['fall_triggered_this_frame'] = True
                                        state['event_timestamp'] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
                                        if results[0].boxes.conf is not None and len(results[0].boxes.conf) > i:
                                            state['detected_conf'] = float(results[0].boxes.conf[i].cpu().numpy())
                                        else:
                                            state['detected_conf'] = 0.91

                        else:
                            state['prev_hip_y'] = None

                        if state['fall_triggered_this_frame']:
                            now = time.time()
                            if now > state['cooldown_until']:
                                state['cooldown_until'] = now + 20.0
                                state['fall_display_frames_remaining'] = int(fps * 5)
                                
                                print(f"\\n=======================================================")
                                print(f"{RED}{BOLD}⚠️ FALL DETECTED FOR ID {track_id}!{RESET}")
                                print(f"-------------------------------------------------------")
                                print(f"  - Torso Fall Angle : {int(state['current_angle'])}°")
                                print(f"  - Transition Time  : {round(state['transition_time'], 2)} seconds")
                                print(f"  - Output Clip Saved: {args.output}")
                                print(f"=======================================================")

                                event_id = f"EVT-P{track_id}-{int(time.time())}-{secrets.token_hex(4).upper()}"
                                
                                state['tracking_event_id'] = event_id
                                state['tracking_start_time'] = time.time()
                                state['tracking_last_heartbeat'] = time.time()
                                state['recovery_frames'] = 0
                                
                                headers = {'Content-Type': 'application/json'}
                                payload = {
                                    "event_id": event_id,
                                    "event_type": "fall",
                                    "severity": "HIGH",
                                    "confidence": round(state['detected_conf'], 2),
                                    "timestamp": state['event_timestamp'],
                                    "room": args.room,
                                    "model_ver": "v1.0.0"
                                }

                                base, ext = os.path.splitext(args.output)
                                dynamic_clip_path = f"{base}_{track_id}_{int(time.time())}{ext}"
                                recording_frames_left = int(fps * 10)
                                post_fall_buffer = list(pre_fall_buffer) 

                                if args.upload_token:
                                    headers['X-Upload-Token'] = args.upload_token
                                    payload['clip_url'] = args.video_url
                                elif args.device_key:
                                    headers['X-Device-Key'] = args.device_key
                                    payload['clip_path'] = dynamic_clip_path
                                    payload['duration_sec'] = 20

                                try:
                                    r = requests.post(args.api_url, headers=headers, json=payload, timeout=12)
                                except Exception as e:
                                    pass
                            
                        # --- STATE TRACKING (HEARTBEAT) ---
                        if state['tracking_event_id']:
                            is_still_down = (state['current_angle'] > 35) or (not is_keypoints_valid)

                            if is_still_down:
                                state['recovery_frames'] = 0
                                now = time.time()
                                if now - state['tracking_last_heartbeat'] >= 30: 
                                    duration = int(now - state['tracking_start_time'])
                                    state['tracking_last_heartbeat'] = now
                                    threading.Thread(target=send_heartbeat, args=(state['tracking_event_id'], duration, "tracking")).start()
                            else:
                                state['recovery_frames'] += 1
                                if state['recovery_frames'] >= int(fps * 5): 
                                    duration = int(time.time() - state['tracking_start_time'])
                                    threading.Thread(target=send_heartbeat, args=(state['tracking_event_id'], duration, "recovered")).start()
                                    
                                    state['tracking_event_id'] = None
                                    state['tracking_start_time'] = None
                                    state['tracking_last_heartbeat'] = None
                                    state['recovery_frames'] = 0

                # Cleanup lost tracks
                for t_id in list(person_states.keys()):
                    if t_id not in active_track_ids:
                        del person_states[t_id]

                # --- WEBSOCKET RELAY: push blurred frame to frontend ---
                # This block is fully additive — does not affect main flow logic below.
                if args.camera_id:
                    relay_frame = annotated_frame.copy()
                    if results[0].boxes is not None and results[0].keypoints is not None:
                        for i in range(len(results[0].boxes)):
                            keypoints = results[0].keypoints.data[i].cpu().numpy()
                            relay_frame = blur_face_on_ram(relay_frame, keypoints, padding=25)
                            
                    _ret, _buf = cv2.imencode('.jpg', relay_frame, [int(cv2.IMWRITE_JPEG_QUALITY), 60])
                    if _ret and not ws_queue.full():
                        ws_queue.put_nowait(_buf.tobytes())

                if is_imou:
                    if results[0].boxes is not None and results[0].keypoints is not None:
                        for i in range(len(results[0].boxes)):
                            keypoints = results[0].keypoints.data[i].cpu().numpy()
                            annotated_frame = blur_face_on_ram(annotated_frame, keypoints, padding=25)
                            
                    for t_id, state in person_states.items():
                        if state['fall_display_frames_remaining'] > 0:
                            state['fall_display_frames_remaining'] -= 1
                            any_fall_display = True
                            cv2.putText(annotated_frame, f"ID {t_id} FALL!", (30, 40 + (t_id%10)*40), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 3)

                    if not any_fall_display:
                        cv2.putText(annotated_frame, "Status: NORMAL", (30, 40), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 3)
                    
                    if recording_frames_left > 0:
                        post_fall_buffer.append(annotated_frame)
                        recording_frames_left -= 1
                        if recording_frames_left == 0:
                            print(f"🎬 Đang lưu video ngã (20s) ra ổ đĩa: {dynamic_clip_path}...")
                            fourcc = cv2.VideoWriter_fourcc(*'mp4v')
                            out = cv2.VideoWriter(dynamic_clip_path, fourcc, fps, (width, height))
                            for f in post_fall_buffer:
                                out.write(f)
                            out.release()
                            print(f"✅ Đã lưu xong video cảnh báo ngã.")
                            
                            # TỰ ĐỘNG UPLOAD LÊN BACKEND NẾU CÓ DEVICE_KEY
                            if args.device_key and event_id:
                                try:
                                    print(f"☁️ Đang upload video lên Cloud Storage qua Backend...")
                                    import urllib.parse
                                    parsed_url = urllib.parse.urlparse(args.api_url)
                                    base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
                                    upload_url = f"{base_url}/api/events/upload_clip"
                                    
                                    with open(dynamic_clip_path, 'rb') as f:
                                        files = {'file': (os.path.basename(dynamic_clip_path), f, 'video/mp4')}
                                        data = {'event_id': event_id}
                                        headers_up = {'X-Device-Key': args.device_key}
                                        r_up = requests.post(upload_url, headers=headers_up, files=files, data=data, timeout=60)
                                        
                                        if r_up.status_code in [200, 201]:
                                            clip_url = r_up.json().get('clip_url')
                                            print(f"{GREEN}✅ Upload thành công lên Supabase: {clip_url}{RESET}")
                                        else:
                                            print(f"{RED}❌ Upload thất bại (Lỗi {r_up.status_code}): {r_up.text}{RESET}")
                                except Exception as e:
                                    print(f"{RED}❌ Lỗi khi upload video: {e}{RESET}")

                            post_fall_buffer = []
                    else:
                        pre_fall_buffer.append(annotated_frame)


        finally:
            # Proper release to prevent video file corruption
            cap.release()
            

        # Nếu chạy hết video mà không có cú ngã nào được kích hoạt gửi API (đối với luồng upload video demo)
        if not is_imou and not fall_dispatched and args.upload_token:
            print(f"\n🟢 {GREEN}No fall detected. Sending fallback SAFE status to backend...{RESET}")
            event_id = f"EVT-{int(time.time())}-{secrets.token_hex(4).upper()}"
            headers = {
                'Content-Type': 'application/json',
                'X-Upload-Token': args.upload_token
            }
            payload = {
                "event_id": event_id,
                "event_type": "safe",
                "severity": "LOW",
                "confidence": 1.0,
                "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                "room": args.room,
                "model_ver": "v1.0.0",
                "clip_url": args.video_url
            }
            
            print(f"📤 Dispatching SAFE status API request to: {args.api_url}")
            try:
                r = requests.post(args.api_url, headers=headers, json=payload, timeout=12)
                print(f"📥 BACKEND RESPONSE (STATUS CODE: {r.status_code}) -> {r.text}")
            except Exception as e:
                print(f"{RED}❌ Failed to connect fallback status to backend:{RESET} {e}")

        # Nếu không phải live camera Imou, thoát hẳn script sau khi xong video
        if not is_imou:
            print(f"\n🟢 {GREEN}Video finished. Processing complete.{RESET}\n")
            break
        else:
            print(f"⏳ Đang nghỉ 2 giây trước khi reconnect lại HLS stream...")
            time.sleep(2)


def main():
    parser = argparse.ArgumentParser(description="SilentGuard AI — Edge Device Passive Fall Detection Pipeline Demo")
    
    # Target file options
    parser.add_argument("--video-url", type=str, default="", help="Signed video URL for Demo Flow")
    parser.add_argument("--upload-token", type=str, default="", help="Authentication upload token (vid_xxx)")
    
    # Classic flow options
    parser.add_argument("--input", type=str, default="mobile/assets/videos/videoplayback.mp4", 
                        help="Path to local input video (defaults to mobile/assets/videos/videoplayback.mp4)")
    parser.add_argument("--device-key", type=str, default="", help="X-Device-Key for Classic flow authentication")
    parser.add_argument("--camera-id", type=str, default="",
                        help="Camera ID to stream live frames to Backend WebSocket Relay. Leave empty to disable relay.")
    
    # General configurations
    parser.add_argument("--output", type=str, default="clips/test-household/demo.mp4", 
                        help="Output path to save the processed video (defaults to clips/test-household/demo.mp4)")
    parser.add_argument("--room", type=str, default="bedroom", help="The room where camera is placed (default: bedroom)")
    parser.add_argument("--api-url", type=str, default="https://c2-app-128-production-e0f9.up.railway.app/api/events/detect",
                        help="SilentGuard API endpoint (default: production backend)")

    args = parser.parse_args()

    # Start WebSocket relay publisher thread only when --camera-id is supplied.
    # If camera_id is empty (all existing call sites), nothing changes.
    global ws_backend_url, ws_camera_id
    ws_backend_url = args.api_url
    ws_camera_id = args.camera_id
    if ws_camera_id:
        t = threading.Thread(target=websocket_publisher, daemon=True, name="ws-relay-publisher")
        t.start()
        print(f"[WebSocket] Relay publisher thread started for camera '{ws_camera_id}'.")

    process_video_stream(args)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{GRAY}Process interrupted by user. Exiting safely.{RESET}\n")
        sys.exit(0)
