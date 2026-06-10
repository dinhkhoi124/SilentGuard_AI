# VinBus SafeWatch — Frontend

Giao diện dashboard giám sát an toàn hành khách xe buýt, xây dựng bằng **Next.js 14 + Tailwind CSS**.

## Cài đặt & Chạy

```bash
# Trong thư mục team-128/frontend/
npm install
npm run dev       # dev server: http://localhost:3000
npm run build     # production build
npm run start     # chạy production build
```

## Tài khoản demo

| Tài khoản | Role | Quyền |
|---|---|---|
| Admin VinBus | `admin` | Toàn quyền: dashboard, alerts, fleet, event log, quản lý user, cài đặt |
| Nguyễn Thị Lan | `operator` | Dashboard, alerts (confirm/reject), fleet, event log |
| Trần Văn Tài | `driver` | Chỉ nhận cảnh báo (giao diện riêng tại `/driver`) |

## Các màn hình

| Route | Màn hình |
|---|---|
| `/login` | Chọn tài khoản đăng nhập |
| `/dashboard` | Tổng quan fleet (metrics + chart + top buses) |
| `/alerts` | Danh sách alerts (filter Pending/Fight/Fall) |
| `/alerts/[id]` | Chi tiết alert + Human Review (Confirm/Reject/Escalate) |
| `/fleet` | Danh sách xe + trạng thái online/offline |
| `/event-log` | Lịch sử toàn bộ sự kiện + tìm kiếm |
| `/users` | Quản lý user (Admin only) |
| `/settings` | Cài đặt ngưỡng AI + thông báo (Admin only) |
| `/4paths` | 4 tình huống xử lý hệ thống |
| `/driver` | Giao diện riêng cho tài xế |

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Styling**: Tailwind CSS v3
- **Charts**: Recharts
- **Icons**: Lucide React
- **Auth**: React Context + localStorage (demo)
- **Language**: TypeScript
