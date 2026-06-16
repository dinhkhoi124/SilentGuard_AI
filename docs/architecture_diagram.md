# SilentGuard AI — Sơ đồ Kiến trúc

> Tài liệu này chứa toàn bộ sơ đồ hệ thống SilentGuard AI dưới dạng Mermaid diagram.

---

## 1. System Overview — Tổng quan hệ thống

```mermaid
flowchart TB
    subgraph HOME["🏠 Nhà người cao tuổi"]
        CAM["📷 Camera IP\n(RTSP stream)"]
        EDGE["🖥️ Edge Device\n(RPi 5 / Jetson Nano)\nYOLOv8-Pose + OpenCV"]
        CAM -->|"Raw video\n(chỉ trong RAM)"| EDGE
    end

    subgraph CLOUD["☁️ Cloud Backend (Render / Railway)"]
        API["⚡ FastAPI Backend\nAlert Engine\nAuth Middleware"]
        DB[("🗄️ Supabase\nPostgreSQL + Storage\nBlurred clip")]
        API <-->|"Read / Write"| DB
    end

    subgraph EXTERNAL["🔌 External Services"]
        FCM["🔔 Firebase FCM\nPush Notification"]
        CLAUDE["🤖 Claude Sonnet\nLLM Alert Message\n& Daily Report"]
        CALL["📞 Auto-call\n(Twilio / VGTS)"]
    end

    subgraph MOBILE["📱 Mobile App (Flutter / React Native)"]
        APP["👨‍👩‍👧 Gia đình\nAlert List\nClip Player\nConfirm / Dismiss"]
    end

    EDGE -->|"POST /api/events/detect\n(metadata + clip URL)"| API
    API -->|"Trigger push"| FCM
    API -->|"Generate message"| CLAUDE
    CLAUDE -->|"Natural language alert"| API
    API -->|"HIGH / CRITICAL"| CALL
    FCM -->|"Push notification"| APP
    APP -->|"PATCH /api/alerts/:id/review"| API
```

---

## 2. Edge Device Pipeline — Luồng xử lý tại thiết bị biên

```mermaid
flowchart LR
    A["📷 Video Frame\n(RTSP / USB cam)"] --> B["🧠 YOLOv8-Pose\nKeypoint Detection\n17 điểm khung xương"]
    B --> C{"Pose\ndetected?"}
    C -->|Không| A
    C -->|Có| D["📐 Fall Classifier\nGóc thân người\nVận tốc chuyển động\nTỷ lệ bounding box"]
    D --> E{"Fall\ndetected?"}
    E -->|Không| A
    E -->|Có| F["⏱️ Severity Engine\nRule-based timer\nMotion score tracking"]
    F --> G["🔒 Anonymizer\nBlur mặt OpenCV\nChỉ giữ skeleton overlay"]
    G --> H["🎬 Clip Capture\nCircular buffer FFmpeg\nT-8s → T+2s = 10s clip"]
    H --> I["📤 POST /api/events/detect\nMetadata JSON\n+ Upload clip đã blur"]
```

---

## 3. Alert Flow — Luồng xử lý cảnh báo

```mermaid
sequenceDiagram
    participant E as 🖥️ Edge Device
    participant B as ⚡ FastAPI Backend
    participant S as 🗄️ Supabase
    participant C as 🤖 Claude LLM
    participant F as 🔔 Firebase FCM
    participant M as 📱 Mobile App
    participant U as 👨‍👩‍👧 Gia đình

    E->>B: POST /api/events/detect<br/>{severity, confidence, clip_url, timestamp}
    B->>S: INSERT events (severity double-check)
    B->>S: Upload blurred clip to Storage
    S-->>B: clip_url confirmed

    alt severity = MEDIUM / HIGH / CRITICAL
        B->>C: Generate alert message (VN)
        C-->>B: "Mẹ bạn có vẻ bị ngã tại phòng khách..."
        B->>F: Send push notification (FCM)
        F->>M: Push notification đến app
        M->>U: 🔔 Hiển thị alert + mở app
    end

    alt severity = HIGH / CRITICAL
        B->>B: Đợi 2 phút không phản hồi
        B->>B: Trigger auto-call (Twilio)
        Note over B: Gọi lần lượt emergency contacts
    end

    U->>M: Mở Alert Detail, xem clip blur
    M->>B: PATCH /api/alerts/:id/review<br/>{action: "confirm" | "dismiss"}
    B->>S: UPDATE alert_reviews (learning_signal)
    B->>B: Cancel auto-call nếu đang chờ

    alt action = "dismiss" (false positive)
        B->>S: Log learning_signal = false_positive
        Note over S: Dữ liệu dùng để retrain model
    end
```

---

## 4. Severity State Machine — Máy trạng thái mức độ nghiêm trọng

```mermaid
stateDiagram-v2
    [*] --> NORMAL : Hệ thống khởi động

    NORMAL --> FALL_DETECTED : YOLOv8 phát hiện tư thế ngã\n(confidence ≥ 50%)

    FALL_DETECTED --> NORMAL : Người tự đứng dậy\n(< 10 giây)

    FALL_DETECTED --> LOW : Bất động < 30s\nVÀ tự đứng lên sau đó
    FALL_DETECTED --> MEDIUM : Bất động 30s – 2 phút
    FALL_DETECTED --> HIGH : Bất động > 2 phút
    FALL_DETECTED --> CRITICAL : Bất động > 5 phút\nVÀ không phản hồi push

    LOW --> NORMAL : Log only, không push\nTự phục hồi
    MEDIUM --> NORMAL : Push notification\nGia đình confirm / dismiss
    HIGH --> NORMAL : Push + Auto-call lần 1\nGia đình confirm
    CRITICAL --> NORMAL : Alert toàn bộ contact\nGọi liên tục mỗi 60s

    MEDIUM --> HIGH : Tiếp tục bất động\nvượt quá 2 phút
    HIGH --> CRITICAL : Tiếp tục bất động\nvượt quá 5 phút + không reply
```

---

## 5. Data Flow & Privacy — Luồng dữ liệu và quyền riêng tư

```mermaid
flowchart TB
    subgraph EDGE_RAM["🔒 RAM của Edge Device (KHÔNG lưu ra disk)"]
        RAW["🎥 Raw Video Frame\n(mặt, thân người nguyên vẹn)"]
        PROC["⚙️ Xử lý YOLOv8\n+ Fall Classifier"]
        BLUR["🌫️ Blur mặt\n(OpenCV GaussianBlur)"]
        BUF["💾 Circular Buffer\n10 giây clip đã blur"]
        RAW --> PROC --> BLUR --> BUF
    end

    subgraph UPLOAD["📤 Chỉ dữ liệu này lên cloud"]
        META["📋 Metadata JSON\n{severity, confidence,\ntimestamp, device_id,\nduration_seconds}"]
        CLIP["🎬 Clip đã blur\n(mặt ẩn, chỉ thấy\nskeleton overlay)"]
    end

    subgraph CLOUD_STORE["☁️ Supabase Storage (encrypted)"]
        STORED["✅ Chỉ lưu:\n- Clip đã blur\n- Metadata sự kiện\n- Không raw video bao giờ"]
    end

    BUF -->|"Encode + Upload"| CLIP
    PROC -->|"Extract metadata"| META
    META --> CLOUD_STORE
    CLIP --> CLOUD_STORE
    CLOUD_STORE --> STORED

    style RAW fill:#ff6b6b,color:#fff
    style STORED fill:#51cf66,color:#fff
    style BUF fill:#ffd43b,color:#333
```

> ⚠️ **Cam kết privacy**: Raw video tuyệt đối không rời khỏi RAM của edge device.  
> Mọi dữ liệu lên cloud đã qua bước blur mặt. Clip tự xóa khỏi RAM sau khi upload xong.

---

## 6. DB Schema — Sơ đồ cơ sở dữ liệu (Supabase / PostgreSQL)

```mermaid
flowchart LR
    subgraph USERS["users"]
        U1["id (Firebase UID)"]
        U2["email"]
        U3["name"]
        U4["role"]
        U5["emergency_contacts (jsonb)"]
        U6["notification_settings (jsonb)"]
    end

    subgraph DEVICES["devices"]
        D1["id (uuid)"]
        D2["name"]
        D3["location"]
        D4["owner_id → users.id"]
        D5["status (online/offline)"]
        D6["last_seen (timestamp)"]
        D7["config_json (jsonb)"]
    end

    subgraph EVENTS["events"]
        E1["id (uuid)"]
        E2["device_id → devices.id"]
        E3["event_type (fall/anomaly)"]
        E4["severity (LOW/MED/HIGH/CRIT)"]
        E5["confidence (float 0–1)"]
        E6["timestamp"]
        E7["clip_url (Supabase Storage)"]
        E8["status (pending/reviewed)"]
        E9["ai_model_version"]
        E10["duration_seconds (float)"]
        E11["created_at"]
    end

    subgraph ALERT_REVIEWS["alert_reviews"]
        R1["id (uuid)"]
        R2["event_id → events.id"]
        R3["reviewer_id → users.id"]
        R4["action (confirm/dismiss/escalate)"]
        R5["note (text)"]
        R6["learning_signal (jsonb)"]
        R7["reviewed_at"]
    end

    USERS -->|"1 owns nhiều"| DEVICES
    DEVICES -->|"1 tạo nhiều"| EVENTS
    EVENTS -->|"1 có nhiều"| ALERT_REVIEWS
    USERS -->|"1 review nhiều"| ALERT_REVIEWS
```
