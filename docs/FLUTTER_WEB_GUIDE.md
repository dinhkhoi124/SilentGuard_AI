# Flutter Web Guide

Nguồn doc này được tổng hợp từ branch `origin/feature/flutter-web`.

## Kết luận nhanh

`origin/feature/flutter-web` là biến thể web của app Flutter trong `mobile/`, không phải landing page. Nó kế thừa phần lớn mobile app nhưng thêm:

- build/deploy Flutter Web bằng Docker + nginx;
- web push service và Firebase Messaging service worker;
- proxy `/api/` đến backend Railway;
- proxy `/imou-api/` đến Imou Cloud để tránh CORS;
- WebSocket viewer để nhận frame từ backend stream relay.

## Điểm khác với app mobile

So với branch app `origin/feature/app-improvements`, branch flutter-web có thêm/thay doi:

```text
mobile/Dockerfile
mobile/nginx.conf
mobile/nginx.conf.template
mobile/lib/core/services/web_push_service.dart
mobile/web/firebase-messaging-sw.js
mobile/lib/features/home/presentation/widgets/websocket_video_player.dart
mobile/pubspec.yaml thêm web_socket_channel
mobile/lib/core/config/app_config.dart: IMOU_API_BASE_URL default '/imou-api'
```

## Cách chạy dev

```powershell
cd mobile
flutter pub get
flutter run -d chrome
```

Nếu muốn trỏ backend local:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=IMOU_API_BASE_URL=/imou-api
```

Lưu ý: `/imou-api` cần reverse proxy khi chạy production/nginx. Nếu chạy dev trực tiếp bằng Chrome, cần cấu hình proxy riêng hoặc dùng URL Imou trực tiếp nếu CORS cho phép.

## Build web

```powershell
cd mobile
flutter pub get
flutter build web --release --no-tree-shake-icons
```

Output:

```text
mobile/build/web
```

## Docker deploy

`mobile/Dockerfile` có 2 stage:

1. `ghcr.io/cirruslabs/flutter:stable` build Flutter Web.
2. `nginx:alpine` serve `/usr/share/nginx/html`.

Build từ thư mục `mobile`:

```powershell
cd mobile
docker build -t silentguard-flutter-web .
docker run --rm -p 8080:8080 -e PORT=8080 silentguard-flutter-web
```

Dockerfile runtime tạo nginx config inline trong `CMD`, listen theo env `PORT`.

## Proxy production

Dockerfile inline nginx config:

```text
location /imou-api/ {
  proxy_pass https://openapi-sg.easy4ip.com/openapi/;
  proxy_ssl_server_name on;
  proxy_set_header Host openapi-sg.easy4ip.com;
}

location /api/ {
  proxy_pass https://c2-app-128-production-b968.up.railway.app/api/;
  proxy_ssl_server_name on;
  proxy_set_header Host c2-app-128-production-b968.up.railway.app;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_read_timeout 3600s;
  proxy_send_timeout 3600s;
}
```

Nó cũng set cache-control `no-store` cho:

```text
/index.html
/main.dart.js
/flutter_service_worker.js
```

và fallback SPA:

```text
try_files $uri $uri/ /index.html
```

File `mobile/nginx.conf` trong branch là config tối giản listen 80 và SPA fallback; Dockerfile runtime mới là config đầy đủ hơn cho proxy.

## Web push

`mobile/lib/core/services/web_push_service.dart`:

- chỉ chạy khi `kIsWeb`;
- request browser notification permission;
- đợi service worker ready tối đa 10s;
- lấy FCM token bằng VAPID key;
- POST token về backend:

```text
POST {backendBaseUrl}/api/users/device-token
Authorization: Bearer {firebaseIdToken}
Content-Type: application/json
```

Service worker `mobile/web/firebase-messaging-sw.js` import Firebase compat SDK `9.23.0`, init Firebase project `silentguard-8d104`, và hiện background notification với icon `/icons/Icon-192.png`.

## WebSocket camera viewer

`mobile/lib/features/home/presentation/widgets/websocket_video_player.dart` dùng `web_socket_channel`.

Luôn build URL từ `AppConfig.apiBaseUrl`:

```text
wss://{backend-host}/api/streams/{deviceId}/subscribe
```

Nếu base URL là `http`, protocol là `ws`.

Widget nhận frame dạng `Uint8List` hoặc `List<int>` và render bằng `Image.memory`. Có:

- ping mỗi 30s;
- reconnect sau 3s;
- stale frame watchdog 10s;
- giữ frame cũ bằng `gaplessPlayback`.

Backend cần expose websocket `/api/streams/{camera_id}/subscribe`, khớp với backend FastAPI branch.

## Biến compile-time quan trọng

`mobile/lib/core/config/app_config.dart` trong flutter-web:

```text
API_BASE_URL=https://c2-app-128-production-b968.up.railway.app
IMOU_API_BASE_URL=/imou-api
GOOGLE_SIGN_IN_SERVER_CLIENT_ID=...
IMOU_APP_ID=...
IMOU_APP_SECRET=...
```

Build với dart-define:

```powershell
flutter build web --release --no-tree-shake-icons --dart-define=API_BASE_URL=https://your-backend.example.com --dart-define=IMOU_API_BASE_URL=/imou-api
```

## Lưu ý khi merge

- `feature/flutter-web` sửa cùng thư mục `mobile/` với app chính, nên merge dễ gặp conflict với `feature/app-improvements`.
- Khác biệt quan trọng cần giữ: `web_socket_channel`, `web_push_service.dart`, `firebase-messaging-sw.js`, Docker/nginx proxy, và `IMOU_API_BASE_URL=/imou-api`.
- Nếu merge vào app mobile chung, cần đảm bảo code có nhánh `kIsWeb` dùng để native app vẫn dùng media_kit/Imou URL trực tiếp, còn web dùng websocket/proxy.
