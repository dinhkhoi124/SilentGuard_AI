// @lovable.dev/vite-tanstack-config already includes the following — do NOT add them manually
// or the app will break with duplicate plugins:
//   - tanstackStart, viteReact, tailwindcss, tsConfigPaths, nitro (build-only using cloudflare as a default target),
//     componentTagger (dev-only), VITE_* env injection, @ path alias, React/TanStack dedupe,
//     error logger plugins, and sandbox detection (port/host/strictPort).
// You can pass additional config via defineConfig({ vite: { ... }, etc... }) if needed.
import { defineConfig } from "@lovable.dev/vite-tanstack-config";

export default defineConfig({
  nitro: {
    preset: "node-server",
    routeRules: {
      "/api/**": { proxy: "https://c2-app-128-production-e0f9.up.railway.app/api/**" },
      "/downloads/**/*.ipa": { headers: { "Content-Type": "application/octet-stream", "Content-Disposition": "attachment" } }
    }
  },
  tanstackStart: {
    // Redirect TanStack Start's bundled server entry to src/server.ts (our SSR error wrapper).
    // nitro/vite builds from this
    server: { entry: "server" },
  },
  vite: {
    server: {
      proxy: {
        "/api": {
          target: "https://c2-app-128-production-e0f9.up.railway.app/",
          changeOrigin: true,
          secure: false,
        },
      },
    },
  },
});
