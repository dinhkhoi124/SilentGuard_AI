# AI Core Guide

Nguồn doc này được tổng hợp từ branch `origin/feature/AI`.

## Kết luận nhanh

AI branch có hai luồng chạy riêng:

1. Edge worker V2 trong `src/edge/silentguard`, chạy bằng `python -m silentguard.worker`. Đây là runtime có cấu trúc package, đọc config YAML/env, đọc stream/fallback video, detect fall, publish frame, và gửi event lên backend.
2. AI inference server trong `src/ai_server.py`, chạy FastAPI bằng `uvicorn src.ai_server:app`. Server này quản lý hàng đợi FCFS cho video upload và có API start/stop stream động.

Ngoài ra branch còn có notebook trong `src/edge_ai/`, model artifact `yolov8n-pose.pt`, `models/fall_lgb_model.txt`, và script legacy `src/edge/AI-Core/ver9.py`.

## Thư mục chính

```text
src/
  ai_server.py                         # FastAPI AI inference server
  edge/
    README.md                          # hướng dẫn Edge AI V2
    requirements-edge.txt
    showcase.yaml                      # config mẫu
    silentguard/
      __main__.py
      worker.py                        # main edge runtime
      engine.py                        # YOLO pose + tracking + fall FSM
      features.py
      state_machine.py
      stream.py
      sender.py
      publisher.py
      tracking.py
      evaluate.py
      config.py
    AI-Core/ver9.py                    # script legacy/hybrid FSM + LightGBM
src/edge_ai/                           # notebooks nghiên cứu/thử nghiệm
models/fall_lgb_model.txt
yolov8n-pose.pt
Dockerfile.ai
```

## Edge worker V2

Pipeline theo `src/edge/README.md`:

```text
latest-frame capture
-> YOLOv8 Pose + ByteTrack
-> normalized features
-> per-track fall state machine
-> one incident
-> async backend sender
```

Chạy video local/dry-run từ repository root:

```powershell
$env:PYTHONPATH="src/edge"
python -m silentguard.worker --config src/edge/showcase.yaml --source mobile/assets/videos/videoplayback.mp4 --dry-run
```

Health endpoints mặc định:

```text
GET /health  # liveness của model/process
GET /ready   # chỉ ready khi stream có frame mới
```

Port mặc định theo config là `8080`.

## Config edge worker

`src/edge/showcase.yaml` có các nhóm:

```text
model:
  path: yolov8n-pose.pt
  image_size: 416
  device: cpu
  tracker: bytetrack.yaml
  pose_confidence: 0.40
  single_person_mode: true

fall:
  descending_velocity_bh_s: 0.60
  lying_torso_angle_deg: 50.0
  transition_limit_sec: 2.0
  lying_confirmation_sec: 1.0
  lying_gap_tolerance_sec: 0.35
  recovery_angle_deg: 30.0
  recovery_upright_sec: 3.0
  track_expiry_sec: 5.0

stream:
  url: ""
  url_endpoint: /api/cameras/{camera_id}/stream-url
  camera_id: ""
  fallback_video: ""
  refresh_margin_sec: 300
  reconnect_max_sec: 15
  buffer_size: 1

backend:
  base_url: https://c2-app-128-production-e0f9.up.railway.app
  event_path: /api/events/detect
  device_key: ""
  auth_token: ""
  request_timeout_sec: 10
  retry_delays_sec: [1, 2, 4, 8]

runtime:
  dry_run: true
  room: showcase
  model_version: fall-engine-v2-showcase
  source_name: imou_rtmp
  health_port: 8080
  stale_frame_sec: 30
  diagnostics_path: reports/latest_run.json
```

`src/edge/silentguard/config.py` cho phép override bằng env:

```text
MODEL_PATH
MODEL_IMAGE_SIZE
MODEL_DEVICE
STREAM_URL
STREAM_URL_ENDPOINT
CAMERA_ID
FALLBACK_VIDEO
BACKEND_URL
DEVICE_KEY
BACKEND_AUTH_TOKEN
FALL_DRY_RUN
ROOM
PORT
PUBLISH_ENABLED
PUBLISH_JPEG_QUALITY
```

Railway env theo README edge:

```text
CAMERA_ID
STREAM_URL_ENDPOINT=/api/cameras/{camera_id}/stream-url
BACKEND_URL
DEVICE_KEY
FALL_DRY_RUN=true
MODEL_IMAGE_SIZE=416
MODEL_DEVICE=cpu
PORT=8080
```

## Core class edge

`PoseFallEngine` trong `src/edge/silentguard/engine.py`:

- load `YOLO(config.model.path)`;
- ưu tiên `model.track(..., tracker=bytetrack.yaml)` nếu package `lap` khả dụng;
- fallback sang `model.predict(...)` + `IoUTracker`;
- extract pose bằng `PoseFeatureExtractor`;
- chạy `FallStateMachine`;
- nếu `single_person_mode=true`, chỉ giữ người có bounding box lớn nhất và gán `track_id=1`;
- trả về incidents, diagnostics, annotated result.

`EdgeWorker` trong `worker.py`:

- start health server;
- start `EventSender`;
- start `FramePublisher`;
- resolve stream URL hoặc fallback;
- đọc frame mới nhất bằng `LatestFrameCapture`;
- publish annotated frame lên backend relay;
- gửi incident payload qua `EventSender`.

`EventSender` trong `sender.py`:

- non-blocking queue size 100;
- dry-run thì log payload;
- khi publish thật, POST đến `BACKEND_URL + event_path`;
- header có thể gồm `X-Device-Key` và `Authorization: Bearer ...`;
- retry theo `retry_delays_sec`.

## Evaluation

Theo `src/edge/README.md`, tạo manifest từ `evaluation_manifest.example.csv`, thay bằng 10 fall và 30 normal clips, rồi chạy:

```powershell
$env:PYTHONPATH="src/edge"
python -m silentguard.evaluate --config src/edge/showcase.yaml --manifest src/edge/evaluation_manifest.csv --cache src/edge/reports/observations.json --report src/edge/reports/evaluation.json --sweep
```

Sau lần đầu có thể thêm `--reuse-cache`.

## AI inference server

`src/ai_server.py` là FastAPI app:

```text
GET  /health
GET  /api/debug/logs
POST /api/streams/start
POST /api/streams/stop?device_sn=...
POST /analyze
```

Core behavior:

- lifespan tạo `analyze_lock`, start live camera monitor nếu có env, và start FCFS upload worker;
- live monitor đọc env `IMOU_DEVICE_SN`, `DEVICE_API_KEY`, `BACKEND_API_URL`;
- luồng video upload vào `/analyze` được đưa vào `asyncio.Queue`;
- `run_inference_background` spawn `src/edge/AI-Core/ver9.py`;
- nếu không thấy HIGH/CRITICAL alert trong output, server gửi fallback payload `normal` hoặc `error` về backend bằng header `X-Upload-Token`.

Chạy local:

```powershell
pip install -r requirements.txt
pip install ultralytics opencv-python-headless
uvicorn src.ai_server:app --host 0.0.0.0 --port 8080
```

Dockerfile `Dockerfile.ai` cũng chạy:

```text
uvicorn src.ai_server:app --host 0.0.0.0 --port 8080
```

## Giới hạn và cảnh báo

- `confidence` gửi backend trong edge worker là fall rule score, không phải YOLO person confidence.
- Edge README ghi showcase giới hạn camera ngang/hơi cao, một người trong vùng chính; top-down, multi-camera và fine-tune pose không nằm trong showcase.
- Chỉ nên set `FALL_DRY_RUN=false` sau khi `/api/events/detect` đã được test idempotent.
- `src/edge_ai/*.ipynb` là notebook nghiên cứu, không phải runtime production.
