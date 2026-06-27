# SilentGuard Database Schema (Supabase)

Tài liệu này mô tả sơ đồ cơ sở dữ liệu quan hệ (Entity-Relationship Diagram) của dự án SilentGuard.

## 1. Entity-Relationship Diagram (ERD)

Sơ đồ dưới đây được vẽ bằng MermaidJS, thể hiện cấu trúc các bảng và mối quan hệ giữa chúng.

```mermaid
erDiagram
    users {
        uuid id PK
        string firebase_uid UK
        string email
        string full_name
        string phone
        string role
        uuid active_household_id FK
        string fcm_token
        timestamp created_at
    }

    households {
        uuid id PK
        string name
        string elderly_name
        string address
        uuid owner_user_id FK
        timestamp created_at
    }

    household_members {
        uuid id PK
        uuid household_id FK
        uuid user_id FK
        string role "owner|member"
        timestamp joined_at
    }

    household_invites {
        uuid id PK
        uuid household_id FK
        string code UK
        uuid created_by FK
        timestamp expires_at
        timestamp used_at
        uuid used_by FK
    }

    household_invite_requests {
        uuid id PK
        uuid household_id FK
        uuid invited_by FK
        uuid invitee_id FK
        string status "pending|accepted|declined"
        timestamp created_at
        timestamp responded_at
    }

    contacts {
        uuid id PK
        uuid household_id FK
        uuid user_id FK
        int priority_order
        timestamp created_at
    }

    cameras {
        uuid id PK
        uuid household_id FK
        string name
        string room
        int fps
        string serial_number UK
        string device_api_key_hash
        string status "online|offline|unknown"
        timestamp last_heartbeat
        timestamp created_at
        timestamp deleted_at
    }

    events {
        uuid id PK
        string event_id UK
        uuid household_id FK
        uuid camera_id FK
        string source "camera|video_upload"
        string event_type
        string severity "LOW|MEDIUM|HIGH|CRITICAL"
        float confidence
        timestamp timestamp
        int duration_sec
        string room
        string clip_path
        string status
        string model_ver
        string llm_message
        timestamp created_at
    }

    event_feedback {
        uuid id PK
        uuid event_id FK
        uuid submitted_by FK
        boolean is_correct
        string notes
        timestamp created_at
    }

    video_uploads {
        uuid id PK
        uuid household_id FK
        uuid uploaded_by FK
        string storage_path
        string video_url
        string upload_token UK
        string status "pending|processed|failed"
        uuid event_id FK
        timestamp created_at
    }

    %% Quan hệ (Relationships)
    users ||--o{ households : "owns (owner_user_id)"
    users }|--|| households : "active_household_id"
    households ||--o{ household_members : "has"
    users ||--o{ household_members : "belongs to"
    
    households ||--o{ contacts : "has emergency contacts"
    users ||--o{ contacts : "is emergency contact"

    households ||--o{ cameras : "has"
    
    households ||--o{ events : "has"
    cameras ||--o{ events : "records"
    
    events ||--o{ event_feedback : "receives"
    users ||--o{ event_feedback : "submits"
    
    households ||--o{ video_uploads : "has"
    users ||--o{ video_uploads : "uploads"
    events ||--o| video_uploads : "generated from"

    households ||--o{ household_invites : "generates"
    users ||--o{ household_invites : "created by / used by"

    households ||--o{ household_invite_requests : "receives"
    users ||--o{ household_invite_requests : "invited_by / invitee"
```

## 2. Ghi chú Ràng buộc Cơ sở dữ liệu (Constraints)
- **Unique Constraints (UK):**
  - `users.firebase_uid`: Không cho phép 2 tài khoản trùng UID Firebase.
  - `cameras.serial_number`: Đảm bảo không có 2 camera dùng chung 1 số Serial phần cứng.
  - `household_invites.code`: Mã mời gia đình là duy nhất.
  - `events.event_id`: Tránh ghi nhận trùng lặp cùng 1 sự kiện từ AI server.
  - `video_uploads.upload_token`: Token tạm thời sinh ra ngẫu nhiên cho mỗi video.
  - `event_feedback(event_id, submitted_by)`: Composite Unique Key để đảm bảo 1 người chỉ được phản hồi 1 lần cho 1 sự kiện.
- **Cascading & Security:**
  - `events` có khóa ngoại trỏ về `households` và `cameras` để đảm bảo khi xóa gia đình, các sự kiện có thể được cascade.
  - Tầng mã nguồn sử dụng cơ chế **Optimistic Locking** (ví dụ với bảng `household_invites`) để chặn các lỗ hổng Race Condition khi truy xuất dữ liệu đồng thời.
