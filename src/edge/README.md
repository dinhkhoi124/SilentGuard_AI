# SilentGuard Edge AI V2

Pipeline dùng chung cho video validation và Imou RTMP trên Railway:

```text
latest-frame capture -> YOLOv8 Pose + ByteTrack -> normalized features
-> per-track fall state machine -> one incident -> async backend sender
```

## Chạy video ở chế độ an toàn

Từ repository root:

```powershell
$env:PYTHONPATH="src/edge"
python -m silentguard.worker --config src/edge/showcase.yaml `
  --source mobile/assets/videos/videoplayback.mp4 --dry-run
```

Health endpoint mặc định: `http://localhost:8080/health`. `/health` là liveness của model/process; `/ready` chỉ trả 200 khi stream đang có frame mới. Mất RTMP tạm thời vì vậy không làm Railway restart trước khi reconnect.

## Evaluation

Sao chép `evaluation_manifest.example.csv`, thay bằng 10 fall và 30 normal clips, rồi chạy:

```powershell
$env:PYTHONPATH="src/edge"
python -m silentguard.evaluate `
  --config src/edge/showcase.yaml `
  --manifest src/edge/evaluation_manifest.csv `
  --cache src/edge/reports/observations.json `
  --report src/edge/reports/evaluation.json `
  --sweep
```

Sau lần đầu, thêm `--reuse-cache` để sweep threshold mà không chạy lại YOLO.

## Railway environment

Không commit giá trị secret. Cấu hình service bằng environment variables:

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

Chỉ chuyển `FALL_DRY_RUN=false` sau khi `/events/detect` được test idempotent.

Fallback nhanh có thể cấp `STREAM_URL` trực tiếp hoặc `FALLBACK_VIDEO` trong container/volume. Worker luôn ưu tiên `STREAM_URL`, sau đó backend stream endpoint, cuối cùng mới dùng file fallback.

## Giới hạn showcase

- Camera ngang hoặc hơi cao, một người trong vùng chính.
- Top-down, multi-camera và fine-tune pose nằm ngoài bản showcase.
- `confidence` gửi backend là fall rule score, không phải YOLO person confidence.
