# Architecture Decision Records — VinBus SafeWatch AI

> Ghi lại các quyết định kiến trúc quan trọng của dự án.
> Đọc mỗi ADR trong 3–5 phút. Cập nhật khi quyết định thay đổi.

---

## Mục lục

| Mã | Tiêu đề | Trạng thái |
|----|---------|------------|
| ADR-001 | Chọn YOLOv8-Pose + LSTM cho AI Detection | Accepted |
| ADR-002 | Chọn SQLite cho Development, PostgreSQL cho Production | Accepted |
| ADR-003 | Chọn WebSocket (Socket.io) thay vì Polling cho Alert Realtime | Accepted |
| ADR-004 | Chọn 3-zone Confidence thay vì Single Threshold | Accepted |
| ADR-005 | Không dùng VLM (GPT-4V / Gemini Vision) cho realtime inference | Accepted |
| ADR-006 | Chọn Render.com cho Production Deployment | Accepted |
| ADR-007 | Tách AI Service (Python) và Backend (Node.js) thành 2 service riêng | Accepted |
| ADR-008 | Kiến trúc Analytics — PostgreSQL thuần cho MVP, TimescaleDB khi scale | Accepted |

---

## ADR-001: Chọn YOLOv8-Pose + LSTM cho AI Detection

**Ngày:** 2024-11-15
**Trạng thái:** Accepted

### Bối cảnh

Cần chọn kiến trúc AI để phát hiện té ngã và xô xát từ video stream camera trên xe buýt trong điều kiện realtime. KPI bắt buộc: MTTD < 30s, Precision ≥ 85%, Recall ≥ 80%.

### Các lựa chọn

1. **Rule-based detection** — Dùng threshold trên velocity/acceleration của bounding box. Đơn giản nhưng false positive rất cao, không phân biệt được "ngã" và "cúi lấy đồ".
2. **YOLOv8-Pose + LSTM** — Extract skeleton keypoints theo frame, LSTM phân tích chuỗi chuyển động theo thời gian để classify action.
3. **VLM (GPT-4V / Gemini Vision)** — Gửi frame lên cloud API để phân tích. Accuracy cao nhưng latency 5–15s/query, không đạt MTTD < 30s.
4. **VideoMAE / TimeSformer** — Transformer-based video understanding, accuracy tốt hơn LSTM nhưng nặng hơn nhiều, khó deploy trên edge device.

### Quyết định

Lựa chọn 2: **YOLOv8-Pose + LSTM**.

### Lý do

- YOLOv8-Pose chạy ~30ms/frame trên GPU mid-range — đủ để đảm bảo MTTD < 30s.
- Output skeleton của YOLOv8-Pose đồng thời giải quyết luôn Privacy Layer (US-04, US-19) — không cần module riêng.
- Toàn bộ pipeline chạy local, không gửi dữ liệu lên cloud — tuân thủ privacy constraint.
- Pretrained trên COCO, có thể fine-tune với dataset nhỏ (100–200 clip staged).
- LSTM đủ nhẹ để deploy trên edge device trên xe.

### Hệ quả

- Cần thu thập và label staged data đúng góc camera xe buýt (overhead 45–60°) vì COCO dataset khác điều kiện thực tế.
- Nếu sau này cần accuracy cao hơn, có thể nâng lên VideoMAE mà không cần thay đổi phần còn lại của pipeline (chỉ thay classifier).
- Phải test với camera thật của VinBus trước Sprint 2 — đây là riskiest assumption của toàn bộ dự án.

---

## ADR-002: Chọn SQLite cho Development, PostgreSQL cho Production

**Ngày:** 2024-11-15
**Trạng thái:** Accepted

### Bối cảnh

Backend cần lưu event log, alert, review history, và learning signal. Cần chọn database phù hợp cho cả môi trường development và production.

### Các lựa chọn

1. **SQLite cho cả dev và prod** — Đơn giản, không cần setup. Nhưng không hỗ trợ concurrent writes, không scale khi có 50+ xe gửi event đồng thời.
2. **PostgreSQL cho cả dev và prod** — Mạnh, production-ready. Nhưng mỗi developer phải cài PostgreSQL local, tốn thời gian setup.
3. **SQLite cho dev, PostgreSQL cho prod** — Linh hoạt, developer không cần cài PostgreSQL, chỉ đổi `DATABASE_URL` khi deploy.

### Quyết định

Lựa chọn 3: **SQLite cho development, PostgreSQL (Supabase) cho production**.

### Lý do

- Developer không cần cài PostgreSQL local — giảm thời gian onboarding thành viên mới.
- Prisma ORM abstract database differences, code gần như giống nhau giữa hai môi trường.
- Supabase free tier đủ cho MVP, có thể upgrade khi cần.
- Chỉ cần đổi `DATABASE_URL` trong `.env` khi deploy.

### Hệ quả

- Cần test migration scripts trên cả SQLite và PostgreSQL để đảm bảo compatibility.
- Một số feature của PostgreSQL (ví dụ: `jsonb`, array types) không dùng được nếu muốn giữ compatibility với SQLite — tránh dùng các type này trong schema.
- Khi có time-series analytics nâng cao, cân nhắc thêm TimescaleDB extension trên PostgreSQL (không cần thay đổi SQLite dev).

---

## ADR-003: Chọn WebSocket (Socket.io) thay vì Polling cho Alert Realtime

**Ngày:** 2024-11-15
**Trạng thái:** Accepted

### Bối cảnh

Alert từ AI service phải xuất hiện trên dashboard operator trong vòng < 30 giây (MTTD KPI). Cần cơ chế push alert từ server xuống browser realtime.

### Các lựa chọn

1. **Short polling** — Frontend gọi `GET /alerts` mỗi 5–10 giây. Đơn giản nhưng thêm 5–10s delay vào MTTD, tốn băng thông.
2. **Long polling** — Giữ connection mở đến khi có data mới. Phức tạp hơn polling, vẫn có overhead.
3. **WebSocket (Socket.io)** — Kết nối hai chiều, server push ngay khi có alert. Latency < 1s.
4. **Server-Sent Events (SSE)** — Server push một chiều, nhẹ hơn WebSocket. Không cần hai chiều nhưng không hỗ trợ tốt trên một số proxy/load balancer.

### Quyết định

Lựa chọn 3: **Socket.io (WebSocket)**.

### Lý do

- Push alert ngay khi `POST /events/detect` được gọi — latency < 1s, đảm bảo MTTD < 30s không bị ảnh hưởng bởi network layer.
- Socket.io có fallback tự động về polling nếu WebSocket không khả dụng — robust hơn native WebSocket.
- Dễ broadcast tới tất cả operator đang online cùng lúc (`io.emit`).
- Hỗ trợ room — sau này có thể push alert chỉ tới operator phụ trách tuyến cụ thể.

### Hệ quả

- Cần handle reconnection khi operator mất mạng tạm thời — Socket.io hỗ trợ sẵn nhưng cần test kỹ.
- Nếu scale lên nhiều server (horizontal scaling), cần thêm Redis adapter cho Socket.io để đồng bộ event giữa các instance.
- Browser tab inactive có thể throttle WebSocket — cần test MTTD thực tế trong điều kiện tab bị minimize.

---

## ADR-004: Chọn 3-zone Confidence thay vì Single Threshold

**Ngày:** 2024-11-15
**Trạng thái:** Accepted

### Bối cảnh

Cần quyết định cách xử lý confidence score từ AI model. Nếu threshold quá thấp → false positive nhiều → operator mất tin tưởng. Nếu threshold quá cao → bỏ sót sự cố thật → mục tiêu safety thất bại.

### Các lựa chọn

1. **Single threshold (ví dụ: 0.7)** — Đơn giản. Dưới ngưỡng bỏ qua, trên ngưỡng tạo alert. Không phân biệt được mức độ chắc chắn.
2. **Hai ngưỡng (uncertain + alert)** — Phân biệt "có thể có sự cố" và "chắc chắn có sự cố". Operator xử lý khác nhau.
3. **Ba vùng (ignore + uncertain + alert)** — Bổ sung thêm vùng "bỏ qua nhưng vẫn log" để thu thập data mà không làm phiền operator.

### Quyết định

Lựa chọn 3: **Ba vùng confidence: 0–40% (bỏ qua), 40–70% (uncertain), 70%+ (alert đỏ)**.

### Lý do

- Vùng "bỏ qua" (0–40%) vẫn được log nội bộ → dùng để phân tích model drift và retrain, không bỏ phí data.
- Vùng "uncertain" (40–70%) có UX khác — không có âm thanh, không interrupt — giảm alert fatigue.
- Operator chỉ bị interrupt bởi alert đỏ (70%+) → precision thực tế cao hơn với single threshold thấp.
- Threshold không cố định — được calibrate lại sau 2–4 tuần dựa trên Confirm/Reject ratio của operator.

### Hệ quả

- Cần track alert fatigue rate (Reject / tổng alert) để biết khi nào cần điều chỉnh threshold.
- Precision KPI (≥ 85%) chỉ tính trên vùng alert đỏ (70%+), không tính vùng uncertain — cần làm rõ khi báo cáo metric.
- Escalate tự động sau 2 phút nếu operator chưa action trên alert đỏ.

---

## ADR-005: Không dùng VLM cho Realtime Inference

**Ngày:** 2024-11-15
**Trạng thái:** Accepted

### Bối cảnh

VLM (Vision-Language Model) như GPT-4V, Gemini Vision có khả năng phân tích hình ảnh và sinh ngôn ngữ tự nhiên. Có ý kiến đề xuất dùng VLM để detect sự cố thay vì train model riêng.

### Các lựa chọn

1. **VLM cho realtime inference** — Gửi frame lên cloud API, nhận phân tích bằng ngôn ngữ tự nhiên. Không cần train model.
2. **CV thuần (YOLOv8 + LSTM)** — Train model riêng, chạy local, latency thấp.
3. **CV detect + VLM phân tích** — CV chạy realtime để detect, VLM chạy async để enrich context cho operator.

### Quyết định

Lựa chọn 2 cho core pipeline. Lựa chọn 3 có thể xem xét ở **post-MVP** nếu cần.

### Lý do

- VLM latency 5–15s/query — không thể đảm bảo MTTD < 30s với 50+ xe đồng thời.
- Chi phí API VLM rất cao khi scale (mỗi frame inference = 1 API call × 50 xe × 30fps).
- Gửi frame video lên cloud vi phạm privacy constraint — hành khách không đồng ý dữ liệu hình ảnh ra ngoài.
- Không cần ngôn ngữ tự nhiên để classify "fall" hay "fight" — bài toán này là structured classification, không cần LLM.

### Hệ quả

- Cần thu thập và label training data — tốn effort hơn so với dùng VLM out-of-the-box.
- Post-MVP: có thể dùng LLM nhỏ (Llama 3.1 8B, self-hosted) để enrich metadata cho operator sau khi CV đã detect — không gửi frame, chỉ gửi metadata text.

---

## ADR-006: Chọn Render.com cho Production Deployment

**Ngày:** 2024-11-15
**Trạng thái:** Accepted

### Bối cảnh

Cần deploy toàn bộ hệ thống (Node.js backend + Python AI service) lên môi trường production có URL truy cập được — đây là một trong các tiêu chí Definition of Done.

### Các lựa chọn

1. **Vercel** — Tốt cho Next.js frontend, nhưng không hỗ trợ tốt long-running process (AI service cần chạy liên tục).
2. **Railway** — Hỗ trợ nhiều service, dễ setup. Nhưng free tier giới hạn, có thể gặp cold start.
3. **Render.com** — Hỗ trợ Web Service + Background Worker, free tier đủ cho MVP, không có cold start nếu dùng paid tier.
4. **AWS / GCP** — Mạnh nhất nhưng setup phức tạp, không phù hợp với timeline dự án.

### Quyết định

Lựa chọn 3: **Render.com**.

### Lý do

- Hỗ trợ deploy cả Node.js (Web Service) và Python (Background Worker) trên cùng một platform.
- Kết nối trực tiếp với GitHub repo — CI/CD tự động khi push lên main branch.
- Free tier đủ cho demo và staging. Upgrade đơn giản khi cần production thật.
- Hỗ trợ environment variables, không cần quản lý secrets phức tạp.

### Hệ quả

- Free tier trên Render có sleep sau 15 phút không có request — cần upgrade lên paid tier ($7/tháng) trước khi demo với stakeholder.
- AI service (Python + GPU) không thể chạy trên Render free tier — cần chạy local hoặc dùng Colab/Modal.run cho demo. Đây là giới hạn cần làm rõ với stakeholder trước.
- Supabase (PostgreSQL) là external service, không phụ thuộc vào Render — an toàn.

---

## ADR-007: Tách AI Service (Python) và Backend (Node.js) thành 2 Service Riêng

**Ngày:** 2024-11-15
**Trạng thái:** Accepted

### Bối cảnh

Cần quyết định architecture: gộp AI detection vào cùng backend, hay tách thành service riêng biệt giao tiếp qua API.

### Các lựa chọn

1. **Monolith** — Tích hợp Python AI vào Node.js backend qua child process hoặc Python shell. Đơn giản nhưng tightly coupled, khó scale và khó thay thế model.
2. **Microservice — tách hoàn toàn** — AI service (Python/FastAPI) và Backend (Node.js/Express) là 2 service độc lập, giao tiếp qua REST API.
3. **Serverless AI** — Mỗi inference là một function call độc lập. Tốt cho scale nhưng không phù hợp với video stream liên tục.

### Quyết định

Lựa chọn 2: **Tách AI Service (Python/FastAPI) và Backend (Node.js) thành 2 service riêng**.

### Lý do

- Retrain model mới không cần đụng vào backend — chỉ deploy lại AI service.
- Thêm tính năng dashboard hoặc notification không ảnh hưởng gì đến AI pipeline.
- AI service cần GPU, backend không cần — có thể deploy trên infrastructure khác nhau.
- Contract giữa hai service là `POST /api/events/detect` — rõ ràng, dễ test độc lập.
- Mock AI script (Python) trong tuần đầu tiên có thể giả lập đúng interface mà không cần model thật.

### Hệ quả

- Cần quản lý 2 service riêng — thêm complexity về deployment và monitoring.
- Nếu AI service down, backend vẫn chạy bình thường — operator vẫn dùng được Manual Trigger.
- Cần authentication giữa AI service và backend (ít nhất là whitelist IP hoặc API key nội bộ) để tránh external abuse.
- Network latency giữa 2 service thêm vào MTTD — cần deploy cùng region.

---

*Cập nhật ADR khi có quyết định mới hoặc khi quyết định cũ thay đổi. Ghi rõ "Superseded by ADR-XXX" và tạo ADR mới.*

---

## ADR-008: Kiến trúc Analytics — PostgreSQL thuần cho MVP, TimescaleDB khi scale

**Ngày:** 2024-11-15
**Trạng thái:** Accepted

### Bối cảnh

Analytics (US-03, US-05 trong PRD) là tính năng cốt lõi ngang tầm với alert, không phải tính năng phụ. Operator cần xem thống kê theo ngày/tuần/tháng, filter theo tuyến, top xe sự cố, và xuất Excel. Cần quyết định cách lưu trữ và query data thống kê này.

### Các lựa chọn

1. **Tính toán realtime từ bảng Event mỗi lần query** — Đơn giản, không cần infrastructure thêm. Có thể chậm khi data lớn (hàng triệu events).
2. **Pre-aggregate vào bảng riêng (materialized view / summary table)** — Query nhanh hơn nhưng cần job chạy định kỳ để cập nhật, thêm complexity.
3. **TimescaleDB ngay từ đầu** — Extension của PostgreSQL chuyên cho time-series, query cực nhanh. Nhưng overkill cho MVP với <50 xe.
4. **PostgreSQL thuần cho MVP, migrate sang TimescaleDB khi cần** — Dùng window functions và index tốt để query đủ nhanh ở quy mô MVP, chỉ nâng cấp khi có vấn đề về performance thực tế.

### Quyết định

Lựa chọn 4: **PostgreSQL thuần với index tốt cho MVP. TimescaleDB khi data vượt 1 triệu rows hoặc query > 2s.**

### Lý do

- Ở quy mô MVP (50 xe × ~10 events/ngày × 365 ngày = ~180K rows/năm), PostgreSQL với index đúng query dưới 100ms — không cần TimescaleDB.
- Schema `Event` đã có `timestamp`, `busId`, `routeId`, `eventType` — đủ để GROUP BY và filter mọi chiều thống kê cần thiết.
- Tránh over-engineering: TimescaleDB cần setup riêng, không chạy được trên Supabase free tier.
- Nếu sau này cần migrate sang TimescaleDB, chỉ cần chạy `SELECT create_hypertable('Event', 'timestamp')` — không cần đổi schema hay application code.

### Index cần tạo ngay từ đầu

```sql
-- Các query thống kê đều filter theo timestamp + eventType + busId
CREATE INDEX idx_event_timestamp ON "Event"(timestamp DESC);
CREATE INDEX idx_event_type_time ON "Event"(event_type, timestamp DESC);
CREATE INDEX idx_event_bus_time  ON "Event"(bus_id, timestamp DESC);
CREATE INDEX idx_event_route     ON "Event"(route_id, timestamp DESC);
```

### API Analytics cần implement

```
GET /api/dashboard/summary                          -- tổng quan, load khi đăng nhập
GET /api/analytics/timeseries?from&to&group_by=day  -- chart theo ngày/tuần/tháng
GET /api/analytics/buses?from&to&route_id           -- top xe, filter theo tuyến
GET /api/analytics/export?from&to&format=xlsx       -- xuất Excel
```

### Hệ quả

- Analytics query phải chạy song song với alert trong sprint đầu — không phải tính năng để sau.
- Seed data khi demo phải đa dạng: nhiều `busId`, `routeId`, `eventType`, `timestamp` trải đều trong ít nhất 7 ngày — chart trông rỗng nếu data không đủ.
- Export Excel dùng `ExcelJS` phía backend (Node.js) thay vì SheetJS phía frontend — tránh load toàn bộ data lên browser trước khi export.
- Khi số xe tăng lên >200 hoặc query dashboard > 2s liên tục, bật TimescaleDB — không cần đổi application code nếu index đã đúng.
