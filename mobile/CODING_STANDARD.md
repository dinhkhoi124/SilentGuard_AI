# QUY CHUẨN PHÁT TRIỂN ỨNG DỤNG (Dự án: C2-App-128)

Tài liệu này định nghĩa hệ thống thiết kế (Design System) trực quan trích xuất từ UI/UX thiết kế và các quy tắc viết code bắt buộc đối với mọi thành viên. Mục tiêu: Code sạch, giao diện đồng bộ, không xung đột.

---

## 1. Hệ Thống Định Danh Giao Diện (Design Tokens)

Tất cả các thuộc tính giao diện phải được gọi tập trung từ thư mục `core/theme/`. Tuyệt đối không tự ý điền mã màu HEX ngẫu nhiên hoặc kích thước chữ tự do.

### 1.1 Quản lý Màu sắc (`AppColors`)
Dựa trên thiết kế UI thực tế, hệ thống màu sắc quy định như sau:
* **Primary Color (Màu chủ đạo):** `Color(0xFF3661F6)` (Màu xanh dương tươi của nút bấm, tab active, dấu chấm thông báo).
* **Background Color:** `Color(0xFFF8F9FA)` (Màu nền xám nhạt toàn app, tạo chiều sâu cho các card trắng).
* **Surface Color:** `Color(0xFFFFFFFF)` (Màu trắng tinh của các khối Card thiết bị, hàng cài đặt, background thông báo).
* **Text Main:** `Color(0xFF111111)` (Màu đen sẫm cho tiêu đề lớn, tên thiết bị, tên người dùng).
* **Text Secondary:** `Color(0xFF757575)` (Màu xám cho mô tả, email, thời gian, phụ đề).
* **Status Colors:**
  * Live/Alert: `Color(0xFFE53935)` (Màu chấm đỏ Live trên camera).
  * Success: `Color(0xFF4CAF50)` (Màu xanh lá tích chọn thành công).

### 1.2 Quản lý Kích thước bo góc & Khoảng cách (`AppDimens`)
App có ngôn ngữ thiết kế bo góc rất mạnh (Heavily Rounded Style):
* **Bo góc nút bấm/Tab (Pill Style):** `BorderRadius.circular(30.0)` hoặc `StadiumBorder()`.
* **Bo góc Card/Khung ảnh:** `BorderRadius.circular(16.0)` đến `20.0`.
* **Khoảng cách chuẩn (Padding/Margin):**
  * `AppDimens.paddingSmall = 8.0` (Khoảng cách icon với chữ).
  * `AppDimens.paddingMedium = 16.0` (Khoảng cách lề chuẩn của các Card).
  * `AppDimens.paddingLarge = 24.0` (Khoảng cách lề lớn trái/phải của màn hình Home/Cài đặt).

### 1.3 Quy chuẩn Font chữ (`AppTextStyles`)
* **Screen Title:** Font Bold, size 20-22, màu `TextMain` (Ví dụ: "My Home", "Notification", "Add Device").
* **Card Title / Item Name:** Font Bold/Medium, size 16, màu `TextMain` (Ví dụ: "Smart V1 CCTV", "Home Management").
* **Body / Subtitle:** Font Regular, size 14, màu `TextSecondary` (Ví dụ: "andrew.insley@yourdomain.com").
* **Caption / Small Text:** Font Regular, size 12, màu `TextSecondary` (Ví dụ: Thời gian "09:41 AM", trạng thái Wi-Fi).

---

## 2. Quy Chuẩn Các Thành Phần Dùng Chung (Reusable Widgets)

Để tránh việc mỗi người tự vẽ lại một giao diện giống nhau, các màn hình phải sử dụng chung các custom widget được đóng gói sẵn trong thư mục `shared/widgets/`:

### 2.1 Nút bấm dạng nhộng (`AppPillButton`)
* **Mô tả:** Xuất hiện ở nút "Add Device", các tag lọc "Living Room", "Bedroom", "Popular".
* **Quy chuẩn:** Chiều cao cố định, chữ bo tròn hoàn toàn. Trạng thái Active sẽ có nền Xanh chữ Trắng, trạng thái Inactive có nền Xám nhạt chữ Đen.

### 2.2 Thanh chuyển Tab đôi (`AppSegmentedControl`)
* **Mô tả:** Xuất hiện ở màn hình Add Device ("Nearby Devices" / "Add Manual") và màn hình Notification ("General" / "Smart Home").
* **Quy chuẩn:** Sử dụng một Widget bọc ngoài, chia đều khoảng cách 50/50, có hiệu ứng chuyển màu nền mượt mà khi người dùng tap chọn.

### 2.3 Khung dòng cài đặt (`SettingRowTile`)
* **Mô tả:** Xuất hiện ở toàn bộ màn hình Account/Settings.
* **Cấu trúc:** `Leading Icon` (màu đen) + `Title Text` (màu đen sẫm) + `Trailing Arrow Icon` (chevron_right màu xám). 
* **Lưu ý:** Phần dưới cùng của màn hình nếu có nút "Logout" thì icon và chữ phải chuyển sang màu đỏ `Color(0xFFE53935)`.

### 2.4 Dòng thông báo chuẩn (`NotificationTile`)
* **Mô tả:** Xuất hiện ở màn hình Notification.
* **Cấu trúc:** `Left Circle Avatar` (chứa icon phân loại) + `Column` (Title bold + Body text regular + Time caption) + `Blue Unread Dot` (nếu chưa đọc) + `Trailing Arrow`.

---

## 3. Quy Tắc Viết Code (Vibe Code Rules)

* **Ưu tiên từ khóa `const`:** Mọi Widget không thay đổi dữ liệu khi runtime bắt buộc phải khai báo `const` để tiết kiệm tài nguyên CPU của thiết bị.
* **Layout thích ứng (Responsive):** Khi chia Grid cho danh sách Camera (Màn hình Cameras 8), bắt buộc dùng `SliverGrid` hoặc `GridView.builder` với tỉ lệ `childAspectRatio` hợp lý để không bị lỗi tràn viền (Overflow) trên các màn hình điện thoại kích thước nhỏ.
* **Tách biệt Logic và Giao diện:** * File UI chỉ chứa các Widget hiển thị, không tính toán logic.
  * Các sự kiện như bấm nút bật/tắt camera (Switch bật tắt ở màn hình Grid), bấm chuyển tab... bắt buộc phải gửi Event sang **BLoC**, sau đó hứng State trả về để cập nhật lại UI.

---
