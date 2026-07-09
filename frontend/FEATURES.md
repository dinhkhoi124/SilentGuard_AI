# 📋 FEATURES — VinBus SafeWatch UI

> Tài liệu mô tả toàn bộ tính năng giao diện, cách sử dụng từng màn hình,
> và quy tắc phân quyền theo từng role.

---

## 🚀 Cách chạy

```bash
# Từ thư mục team-128/frontend/
npm install       # lần đầu
npm run dev       # http://localhost:3000
```

Truy cập `http://localhost:3000` → tự động chuyển sang `/login`.

---

## 🔐 Đăng nhập & Phân quyền

### Màn hình Login (`/login`)

Chọn 1 trong 3 tài khoản demo rồi nhấn **Đăng nhập**:

| Tài khoản | Role | Chuyển đến |
|---|---|---|
| **Admin VinBus** | `admin` | `/dashboard` |
| **Nguyễn Thị Lan** | `operator` | `/dashboard` |
| **Trần Văn Tài** | `driver` | `/driver` |

- Phiên đăng nhập được lưu trong **localStorage** → refresh trang không mất session.
- Nhấn icon **đăng xuất** ở góc dưới sidebar để về trang login.

### Bảng phân quyền RBAC

| Màn hình / Tính năng | Admin | Operator | Driver |
|---|:---:|:---:|:---:|
| Dashboard (tổng quan) | ✅ | ✅ | ❌ |
| Danh sách Alerts | ✅ | ✅ | ❌ |
| Xem chi tiết Alert | ✅ | ✅ | ❌ |
| **Confirm / Reject / Escalate** | ✅ | ✅ | ❌ |
| Fleet (danh sách xe) | ✅ | ✅ | ❌ |
| Event Log | ✅ | ✅ | ❌ |
| Quản lý User | ✅ | ❌ | ❌ |
| Cài đặt hệ thống | ✅ | ❌ | ❌ |
| Sidebar: Alerts badge "3" | ✅ | ✅ | ❌ |
| Giao diện nhận cảnh báo (`/driver`) | ❌ | ❌ | ✅ |

> Sidebar tự động ẩn/hiện các mục theo role đang đăng nhập.

---

## 📺 Chi tiết từng màn hình

---

### 1. Dashboard (`/dashboard`)

**Ai xem được:** Admin, Operator

**Mô tả:** Tổng quan hoạt động an toàn toàn bộ fleet trong ngày/tuần/tháng.

#### Cách dùng:
1. Nhấn nút **Hôm nay / Tuần / Tháng** ở góc trên để đổi kỳ thống kê.
   - Tiêu đề trang tự động đổi theo ("Tổng quan hôm nay" / "tuần này"...).
2. Đọc 4 **Metric Cards**:

   | Card | Ý nghĩa |
   |---|---|
   | **Tổng alert** `42` | Tổng số alert được tạo trong kỳ, delta so với kỳ trước |
   | **Confirmed** `30` | Số alert operator đã xác nhận là thật, kèm tỉ lệ % |
   | **Rejected** `10` | Số alert bị từ chối (false positive), kèm tỉ lệ % |
   | **Pending** `2` ⚠️ | Alert chưa xử lý — nền cam nổi bật, cần xử lý ngay |

3. **Biểu đồ cột** "Alert theo ngày — Fall vs Fight":
   - Cột **xanh** = Fall (té ngã), cột **đỏ** = Fight (xô xát).
   - Hover vào cột để xem số liệu chính xác.

4. **Top xe sự cố**: Danh sách xe có nhiều sự cố nhất, hiển thị thanh tiến độ đỏ theo tỉ lệ.

---

### 2. Danh sách Alerts (`/alerts`)

**Ai xem được:** Admin, Operator

**Mô tả:** Toàn bộ alert từ hệ thống AI, lọc và sắp xếp nhanh.

#### Cách dùng:
1. **Filter tabs** ở đầu trang:

   | Tab | Hiển thị |
   |---|---|
   | `Tất cả` | Toàn bộ alerts |
   | `Pending (N)` | Chỉ alert chưa xử lý — có badge đỏ đếm số lượng |
   | `Fight` | Chỉ sự kiện xô xát |
   | `Fall` | Chỉ sự kiện té ngã |

2. **Mỗi card alert** hiển thị:
   - `EVT-XXXX` — mã sự kiện (font mono)
   - Badge loại: **Fight** (đỏ) / **Fall** (cam)
   - Badge trạng thái: **Pending** (vàng nhấp nháy) / **Confirmed** (xanh) / **Rejected** (xám)
   - Xe, tuyến, camera, mô tả AI
   - Thời gian, % confidence, MTTD
   - Viền trái màu đỏ = Fight, cam = Fall

3. **Nhấn vào card** → chuyển sang trang chi tiết Alert để xem xét.

4. **Chỉ số Live** (góc trên phải): chấm xanh nhấp nháy + "Live" — hệ thống đang theo dõi real-time.

---

### 3. Chi tiết Alert & Human Review (`/alerts/[id]`)

**Ai xem được:** Admin, Operator  
**Ai được Confirm/Reject:** Admin, Operator (không có cho Driver)

**Mô tả:** Màn hình quan trọng nhất — xem clip đã ẩn danh và đưa ra quyết định.

#### Cách dùng:

**A. Thanh tiến trình (Timeline) — 5 bước:**
```
AI detect ✅ → Anonymize ✅ → Operator review 🔵 → Confirm/Reject → Driver notified
```
- Bước xanh lá = đã hoàn thành
- Bước xanh dương nhấp nháy = đang ở bước này
- Bước xám = chưa tới

**B. Khung video (panel trái):**
- Nền đen với **2 hình skeleton** hoạt ảnh (không lưu mặt/danh tính)
  - Fight: 2 nhân vật đối nhau, có đường va chạm màu đỏ
  - Fall: 1 nhân vật đứng + 1 ngã ngang
- Badge xanh **"✓ privacy layer active"** — xác nhận đã ẩn danh
- Scanline animation mô phỏng camera feed
- Bên dưới: 2 card nhỏ — **Hành động AI phát hiện** và **Vị trí trên xe**

**C. Panel thông tin (panel phải):**
- **CONFIDENCE AI**: số lớn màu xanh + nhãn đánh giá
  - `≥ 80%` → "Cao · [Loại] pattern rõ" (xanh)
  - `40–79%` → "Trung bình · Operator cần xem clip" (cam)
  - `< 40%` → "Thấp · Khả năng false positive cao" (đỏ)
- **Xe & Tuyến**: mã xe + tuyến + trạng thái đang chạy
- **MTTD**: thời gian từ lúc xảy ra đến khi phát hiện
  - `≤ 30s` → "✓ Trong ngưỡng" (xanh)
  - `> 30s` → "⚠ Vượt ngưỡng" (đỏ)

**D. Quyết định (chỉ hiện khi Pending + role Admin/Operator):**

| Nút | Tác dụng |
|---|---|
| **✓ Confirm** | Xác nhận là sự cố thật → cập nhật trạng thái Confirmed, hiện toast xanh |
| **✗ Reject** | Từ chối (false positive) → cập nhật Rejected, hiện toast |
| **↑ Escalate** | Chuyển lên cấp trên xử lý → hiện toast thông báo |
| Textarea | Ghi chú kèm theo (tùy chọn) — nội dung gửi cùng với quyết định |

> ⚠️ Khi alert đã là Confirmed/Rejected: hiện panel "Thông tin duyệt" (operator, thời gian, ghi chú).

---

### 4. Fleet (`/fleet`)

**Ai xem được:** Admin, Operator

**Mô tả:** Tổng quan trạng thái real-time của toàn bộ đội xe.

#### Cách dùng:
- Đọc **summary bar** ở đầu: số xe online / offline / có alert chưa xử lý
- **Grid 4 cột** các card xe:
  - 🟢 Online: viền xanh, icon CheckCircle xanh
  - ⚫ Offline: nền xám, icon WifiOff
  - ⚠️ **Viền vàng** + icon cảnh báo = xe đang có **Pending alert** chưa xử lý
  - Số sự cố theo màu: đỏ (>5), cam (1–5), xám (0)
- **Demo xe lỗi**: `BUS-055`, `BUS-099` đang ở trạng thái Offline

---

### 5. Event Log (`/event-log`)

**Ai xem được:** Admin, Operator

**Mô tả:** Lịch sử đầy đủ tất cả sự kiện — có thể lọc và sắp xếp.

#### Cách dùng:
1. **Filter loại** (góc trên phải): `Tất cả` / `Fall` / `Fight`
2. **Sắp xếp** bằng cách nhấn tiêu đề cột có icon `↕`:
   - **Conf.** — sắp xếp theo confidence (cao → thấp)
   - **Thời gian** — sắp xếp theo thời gian (mới → cũ)
   - **MTTD** — sắp xếp theo thời gian phát hiện (nhanh → chậm)
3. Nhấn **mã EVT-XXXX** (màu xanh) → đến trang chi tiết Alert tương ứng
4. Cột **Reviewer**: tên operator đã duyệt (hoặc `—` nếu chưa duyệt)

---

### 6. Quản lý User (`/users`)

**Ai xem được:** Admin (Operator/Driver thấy màn hình "Không có quyền")

**Mô tả:** Danh sách toàn bộ tài khoản trong hệ thống.

| Cột | Nội dung |
|---|---|
| Người dùng | Avatar chữ cái đầu + tên đầy đủ |
| Vai trò | Badge màu: 🟣 Admin / 🔵 Operator / 🟢 Driver |
| Ca làm việc | Hành chính / Ca đêm / ... |
| ID | Mã số hệ thống (font mono) |
| Hành động | Nút "Chỉnh sửa" (disabled trong demo) |

> Nút **"+ Thêm user"** ở góc trên phải hiện disabled trong bản demo.

---

### 7. Cài đặt (`/settings`)

**Ai xem được:** Admin

**Mô tả:** Điều chỉnh ngưỡng AI và cấu hình thông báo.

#### Cách dùng:
1. **Ngưỡng Confidence** — kéo thanh trượt từ 40% → 95%:
   - `≥ 80%` → hiển thị đỏ (nhiều alert ít hơn, ít false positive)
   - `60–79%` → cam
   - `< 60%` → xám (nhiều alert hơn, có thể nhiều false positive)
2. **Toggle thông báo**:
   - Email Alerts — gửi email khi có alert mới
   - SMS Alerts — SMS cho alert confidence cao
   - Push Notifications — thông báo trình duyệt real-time
3. Nhấn **"Lưu cài đặt"** → nút chuyển sang xanh lá "✓ Đã lưu!" trong 2.5 giây
4. **Thông tin hệ thống** (readonly): phiên bản AI, model, uptime, môi trường

---

### 8. 4 Paths — Luồng xử lý Alert (`/4paths`)

**Ai xem được:** Admin, Operator

**Mô tả:** Sơ đồ 4 luồng mà mỗi alert có thể đi qua trong hệ thống.

| Path | Màu | Luồng | Khi nào |
|---|---|---|---|
| **1. AI Detection Pipeline** | Xanh dương | Camera → AI → Alert tự động | Mọi alert đều qua bước này |
| **2. High-Confidence Path** | Đỏ | Alert ưu tiên → SMS/Push → Review ngay → Driver | Confidence ≥ 80% |
| **3. Operator Review Path** | Xanh lá | Pending → Xem footage → Confirm/Reject → Đóng case | Mọi alert cần xét duyệt |
| **4. False-Positive Path** | Xám | Low-conf → Review thủ công → Rejected → Feedback AI | Confidence < 60%, sai |

- Mỗi card có **4 bước dạng flow** với icon và mũi tên nối
- Bên dưới: **Thống kê tuần** — tổng số theo từng loại kết quả

---

### 9. Driver View (`/driver`)

**Ai xem được:** Driver (role `driver`)

**Mô tả:** Giao diện tối giản dành riêng cho tài xế — chỉ nhận cảnh báo.

#### Hai trạng thái:
- **🟢 An toàn**: Icon checkmark xanh, "Không có cảnh báo", đồng hồ HH:MM:SS cập nhật mỗi giây
- **🔴 Có cảnh báo**: Card đỏ lớn với:
  - "⚠ CẢNH BÁO AN TOÀN" in đậm
  - Thông tin xe + tuyến + thời gian
  - Nút **"Xác nhận đã nhận"** → flash xanh rồi reset

> Nút demo ở cuối trang để toggle giữa 2 trạng thái khi demo.  
> Admin/Operator vào `/driver` sẽ bị redirect về `/dashboard`.

---

## 🎨 Quy ước màu sắc trong toàn app

| Màu | Ý nghĩa |
|---|---|
| 🔵 Xanh dương | Confirmed, active state, nav item đang chọn, confidence cao-trung |
| 🟠 Cam / Vàng | Pending, cần xử lý, low confidence (40–79%), Fall event |
| 🔴 Đỏ | Fight event, confidence rất cao (≥80%, cần chú ý), offline/lỗi |
| 🟢 Xanh lá | Trạng thái tốt: online, đã xác nhận, MTTD trong ngưỡng, an toàn |
| ⚫ Xám | Rejected, offline, dữ liệu không có, disabled |

---

## 🗂️ Cấu trúc file

```
src/
├── lib/
│   ├── types.ts          — Tất cả TypeScript interface (User, Alert, ...)
│   └── mock-data.ts      — Dữ liệu mẫu (5 alerts, 3 users, chart data, 8 buses)
├── contexts/
│   └── AuthContext.tsx   — login(), logout(), useAuth() hook, localStorage sync
├── components/
│   ├── layout/
│   │   ├── Sidebar.tsx       — Nav + RBAC filter + user info + logout
│   │   ├── Header.tsx        — Title + live clock + avatar
│   │   └── MainLayout.tsx    — Sidebar + Header + scrollable main content
│   ├── dashboard/
│   │   ├── MetricCard.tsx        — Card số liệu (có variant highlight)
│   │   ├── AlertBarChart.tsx     — Recharts bar chart Fall/Fight
│   │   └── TopBusesList.tsx      — Danh sách xe + thanh tiến độ
│   └── alerts/
│       ├── AlertTable.tsx        — Filter tabs + danh sách alert
│       ├── AlertDetail.tsx       — Timeline + skeleton SVG + actions
│       ├── EventTypeBadge.tsx    — Badge Fight/Fall
│       └── AlertStatusBadge.tsx  — Badge Pending/Confirmed/Rejected
└── app/
    ├── page.tsx                  — Redirect theo auth state
    ├── login/page.tsx            — Chọn tài khoản demo
    ├── driver/page.tsx           — Giao diện tài xế
    └── (protected)/              — Route group được bảo vệ bởi auth
        ├── layout.tsx            — Auth guard: redirect /login nếu chưa đăng nhập
        ├── dashboard/page.tsx
        ├── alerts/page.tsx
        ├── alerts/[id]/page.tsx
        ├── fleet/page.tsx
        ├── event-log/page.tsx
        ├── users/page.tsx
        ├── settings/page.tsx
        └── 4paths/page.tsx
```

---

## ⚡ Dữ liệu mẫu có sẵn

### Alerts (5 bản ghi)

| ID | Xe | Loại | Confidence | Trạng thái |
|---|---|---|---|---|
| EVT-0042 | BUS-102 | Fight | 92% | **Pending** |
| EVT-0041 | BUS-047 | Fall | 78% | **Pending** |
| EVT-0040 | BUS-213 | Fight | 88% | Confirmed |
| EVT-0039 | BUS-088 | Fall | 55% | Rejected |
| EVT-0038 | BUS-102 | Fall | 85% | Confirmed |

### Fleet (8 xe)

| Xe | Tuyến | Trạng thái | Ghi chú |
|---|---|---|---|
| BUS-102 | 32 | Online | 8 sự cố |
| BUS-047 | 15 | Online | 6 sự cố |
| BUS-213 | 09 | Online | 4 sự cố |
| BUS-088 | 27 | Online | 3 sự cố |
| BUS-174 | 18 | Online | 2 sự cố |
| BUS-301 | 22 | Online | 0 sự cố |
| BUS-055 | 04 | **Offline** | — |
| BUS-099 | 11 | **Offline** | — |

---

## 🔧 Mở rộng / Tuỳ chỉnh

### Thêm alert mới
Mở `src/lib/mock-data.ts`, thêm object vào mảng `mockAlerts`:
```ts
{
  id: 'EVT-0043',
  busId: 'BUS-174',
  route: 'Tuyến 18',
  eventType: 'Fall',        // 'Fall' | 'Fight'
  confidence: 73,
  timestamp: '23:15:00',
  status: 'pending',        // 'pending' | 'confirmed' | 'rejected'
  mttd: 27,
  camera: 'Camera 2',
  description: 'Mô tả sự kiện...',
}
```

### Thêm user
Mở `src/lib/mock-data.ts`, thêm vào `mockUsers`:
```ts
{ id: '4', name: 'Lê Thị Hoa', role: 'operator', avatar: 'LH', shift: 'Ca sáng' }
```

### Thêm xe vào Fleet
Mở `src/app/(protected)/fleet/page.tsx`, thêm vào mảng `fleetData`.

### Đổi ngưỡng dashboard
Mở `src/lib/mock-data.ts`, sửa object `mockDashboardStats`.
