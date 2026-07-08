# Landing Page Guide

Nguồn doc này được tổng hợp từ branch `origin/landing_page`.

## Kết luận nhanh

Landing page nằm trong `landing_page/`. Đây là app TanStack Start + Vite + React, không phải Next.js. App dùng file-based routing trong `landing_page/src/routes`, có SSR output `.output/server/index.mjs`, và có Dockerfile để build/chạy Node server.

## Thư mục chính

```text
landing_page/
  package.json
  vite.config.ts
  Dockerfile
  src/
    router.tsx
    routeTree.gen.ts
    start.ts
    server.ts
    routes/
      __root.tsx
      index.tsx
      demo.tsx
      brochure.tsx
      faq.tsx
      privacy.tsx
      README.md
    components/
      Hero3D.tsx
      Flipbook.tsx
      ClientOnly.tsx
      ui/
    assets/
  public/
    brochure.pdf
    downloads/
      app-arm64-v8a-release.apk
      app-armeabi-v7a-release.apk
      app-x86_64-release.apk
      SilentGuard.ipa or Runner.ipa, tùy branch/commit
      fall/*.mp4
```

## Framework và routing

`src/routes/README.md` ghi rõ:

- TanStack Start dùng file-based routing;
- mỗi file `.tsx` trong `src/routes` là một route;
- không tạo `src/pages/`, `src/routes/_app/index.tsx`, hoặc `app/layout.tsx`;
- root layout duy nhất là `src/routes/__root.tsx`;
- `routeTree.gen.ts` là auto-generated, không sửa tay.

Router được tạo trong `src/router.tsx` bằng:

```text
createRouter({
  routeTree,
  context: { queryClient },
  scrollRestoration: true,
  defaultPreloadStaleTime: 0
})
```

## Scripts

Theo `landing_page/package.json`:

```powershell
cd landing_page
npm install
npm run dev
npm run build
npm run preview
npm run start
npm run lint
npm run format
```

Scripts thực tế:

```json
{
  "dev": "vite dev",
  "build": "vite build",
  "build:dev": "vite build --mode development",
  "preview": "vite preview",
  "start": "node .output/server/index.mjs",
  "lint": "eslint .",
  "format": "prettier --write ."
}
```

## Nội dung/chức năng chính

Trang `/` trong `src/routes/index.tsx` gồm các section:

- nav SilentGuard;
- hero với `Hero3D`;
- giới thiệu brochure;
- cách hoạt động;
- tính năng camera AI;
- product/gallery;
- CTA mở trang demo;
- stories;
- FAQ;
- contact;
- app download cho Android/iOS;
- footer.

Route thấy trong branch:

```text
/          # landing page
/demo      # thử AI/demo
/brochure  # flipbook/brochure
/faq
/privacy
```

## API proxy

`landing_page/vite.config.ts` cấu hình proxy đến backend Railway:

```text
/api/** -> https://c2-app-128-production-e0f9.up.railway.app/api/**
```

Trong dev server Vite:

```text
/api -> https://c2-app-128-production-e0f9.up.railway.app/
```

Ngoài ra route rule cho `.ipa` đặt header download:

```text
/downloads/**/*.ipa
```

## Docker

`landing_page/Dockerfile`:

```text
FROM node:22-alpine
WORKDIR /app
COPY landing_page/package*.json ./
RUN npm install --include=dev
COPY landing_page/ ./
RUN npm run build
EXPOSE 3000
ENV PORT=3000
ENV HOST=0.0.0.0
CMD ["node", ".output/server/index.mjs"]
```

Build từ repository root:

```powershell
docker build -f landing_page/Dockerfile -t silentguard-landing .
docker run --rm -p 3000:3000 silentguard-landing
```

## Lưu ý khi merge

- Landing page có nhiều binary asset trong `public/downloads` và `src/assets`; cần cẩn thận khi conflict/merge để không mất APK/IPA/video demo.
- `src/routes/index.tsx` có nhiều nội dung marketing và download instruction; khi sửa nên test cả desktop và mobile.
- Tên file IPA trong branch có dấu hiệu khác nhau giữa commit (`Runner.ipa` và `SilentGuard.ipa`). Khi merge cần kiểm tra link download trong UI khớp với file thực sự còn lại trong `public/downloads`.
