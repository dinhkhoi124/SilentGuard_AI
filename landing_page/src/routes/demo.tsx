import { createFileRoute, Link } from "@tanstack/react-router";
import { useServerFn } from "@tanstack/react-start";
import { useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { AlertTriangle, CheckCircle2, Film, Loader2, Upload, ArrowLeft, Sparkles, Download } from "lucide-react";
import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth, signInWithEmailAndPassword } from "firebase/auth";

import logoAsset from "@/assets/logo.png";

import { analyzeFallVideo, type FallDetectionResult } from "@/lib/fall-detection.functions";

// Firebase Configuration using the project credentials from environment variables
const firebaseConfig = {
  apiKey: "AIzaSyCfhqgVNzm0p15W31Rb4ZzC_POKN5SxMDc",
  authDomain: "silentguard-8d104.firebaseapp.com",
  projectId: "silentguard-8d104",
  storageBucket: "silentguard-8d104.appspot.com",
  messagingSenderId: "107588222654260172638",
  appId: "1:107588222654260172638:web:3294d8a7840fd7739f7ce"
};

// Initialize Firebase App
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApp();

const DEMO_EMAIL = "demo@silentguard.ai";
const DEMO_PASSWORD = "Demo@2026";
const DEMO_HOUSEHOLD_ID = "d5494e06-b7ac-43f8-810a-22102079aade";

async function getDemoToken() {
  const auth = getAuth(app);
  const userCredential = await signInWithEmailAndPassword(auth, DEMO_EMAIL, DEMO_PASSWORD);
  const token = await userCredential.user.getIdToken(true); // force refresh to get a fresh token each time
  return token;
}

export const Route = createFileRoute("/demo")({
  head: () => ({
    meta: [
      { title: "Demo phát hiện té ngã — SilentGuard" },
      {
        name: "description",
        content:
          "Tải lên một đoạn video ngắn để trải nghiệm khả năng phát hiện té ngã bằng AI của SilentGuard.",
      },
    ],
  }),
  component: DemoPage,
});

const FRAME_COUNT = 8;
const MAX_MB = 50;

function DemoPage() {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [status, setStatus] = useState<"idle" | "authenticating" | "uploading" | "polling" | "done">("idle");
  const [error, setError] = useState<string | null>(null);
  const [uploadToken, setUploadToken] = useState<string | null>(null);
  const [eventResult, setEventResult] = useState<{
    event_type: string | null;
    severity: string | null;
    confidence: number | null;
    llm_message: string | null;
    room: string | null;
  } | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const resultRef = useRef<HTMLDivElement>(null);

  function selectFile(f: File | null) {
    setEventResult(null);
    setUploadToken(null);
    setError(null);
    setStatus("idle");
    if (!f) {
      setFile(null);
      setPreviewUrl(null);
      return;
    }
    if (!f.type.startsWith("video/")) {
      setError("Vui lòng chọn tệp video (MP4, WebM, MOV).");
      return;
    }
    if (f.size > MAX_MB * 1024 * 1024) {
      setError(`Video tối đa ${MAX_MB}MB.`);
      return;
    }

    // Check video duration (max 1 minute / 60 seconds)
    const video = document.createElement("video");
    video.preload = "metadata";
    video.onloadedmetadata = function () {
      window.URL.revokeObjectURL(video.src);
      if (video.duration > 60) {
        setError("Độ dài video tối đa là 1 phút (60 giây). Vui lòng chọn video ngắn hơn.");
        setFile(null);
        setPreviewUrl(null);
      } else {
        setFile(f);
        if (previewUrl) URL.revokeObjectURL(previewUrl);
        setPreviewUrl(URL.createObjectURL(f));
      }
    };
    video.onerror = function () {
      setError("Không thể đọc thông tin video. Vui lòng thử lại với video khác.");
      setFile(null);
      setPreviewUrl(null);
    };
    video.src = URL.createObjectURL(f);
  }

  async function runAnalysis() {
    if (!file) return;
    setError(null);
    setEventResult(null);
    setUploadToken(null);
    
    try {
      setStatus("authenticating");
      const token = await getDemoToken();

      setStatus("uploading");
      
      // Step 1: Xin link upload trực tiếp
      const reqUploadRes = await fetch("https://c2-app-128-production.up.railway.app/api/events/request-upload-url", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`
        },
        body: JSON.stringify({
          household_id: DEMO_HOUSEHOLD_ID,
          filename: `${Date.now()}_${file.name}`,
          content_type: file.type || "video/mp4"
        }),
      });

      if (!reqUploadRes.ok) {
        const errJson = await reqUploadRes.json().catch(() => ({}));
        throw new Error(errJson.detail?.error?.message || errJson.detail || "Không thể khởi tạo phiên upload.");
      }

      const { upload_url, upload_token } = await reqUploadRes.json();
      
      // Step 2: Upload trực tiếp lên Supabase Storage
      const putRes = await fetch(upload_url, {
        method: "PUT",
        headers: {
          "Content-Type": file.type || "video/mp4"
        },
        body: file
      });
      
      if (!putRes.ok) {
        throw new Error("Lỗi khi tải video lên hệ thống lưu trữ.");
      }
      
      // Step 3: Gọi backend báo đã upload xong để trigger AI
      const triggerRes = await fetch("https://c2-app-128-production.up.railway.app/api/events/trigger-ai", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`
        },
        body: JSON.stringify({
          upload_token
        })
      });
      
      if (!triggerRes.ok) {
        const errJson = await triggerRes.json().catch(() => ({}));
        throw new Error(errJson.detail?.error?.message || errJson.detail || "Không thể bắt đầu luồng phân tích AI.");
      }

      setUploadToken(upload_token);
      setStatus("polling");

      const startTime = Date.now();

      // Polling function every 3 seconds
      const pollInterval = setInterval(async () => {
        try {
          // Timeout after 120 seconds
          if (Date.now() - startTime > 120 * 1000) {
            clearInterval(pollInterval);
            setError("Quá thời gian phân tích (120 giây). Vui lòng thử lại.");
            setStatus("idle");
            return;
          }

          const statusRes = await fetch(`https://c2-app-128-production.up.railway.app/api/events/upload-status/${upload_token}`);
          if (!statusRes.ok) {
            clearInterval(pollInterval);
            throw new Error("Không thể kiểm tra trạng thái video.");
          }

          const statusData = await statusRes.json();
          if (statusData.status === "processed") {
            clearInterval(pollInterval);
            setEventResult({
              event_type: statusData.event?.event_type || null,
              severity: statusData.event?.severity || null,
              confidence: statusData.event?.confidence || null,
              llm_message: statusData.event?.llm_message || null,
              room: statusData.event?.room || null,
            });
            setStatus("done");
            
            // Auto scroll down to results container smoothly on mobile
            setTimeout(() => {
              resultRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
            }, 100);
          } else if (statusData.status === "failed") {
            clearInterval(pollInterval);
            setError("Phân tích thất bại, vui lòng thử lại.");
            setStatus("idle");
          }
        } catch (e) {
          clearInterval(pollInterval);
          setError(e instanceof Error ? e.message : "Có lỗi xảy ra khi xử lý.");
          setStatus("idle");
        }
      }, 3000);

    } catch (e) {
      setError(e instanceof Error ? e.message : "Có lỗi xảy ra.");
      setStatus("idle");
    }
  }

  const busy = status === "authenticating" || status === "uploading" || status === "polling";

  return (
    <main className="min-h-screen bg-background text-foreground">
      <nav className="sticky top-0 z-50 border-b border-border bg-background/70 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-6">
          <Link to="/" className="flex items-center gap-2 text-sm text-ink-soft hover:text-brand">
            <ArrowLeft className="size-4" /> Về trang chủ
          </Link>
          <div className="flex items-center gap-2">
            <img
              src={logoAsset}
              alt="SilentGuard"
              width={24}
              height={24}
              className="size-6 object-cover rounded-full mix-blend-multiply"
            />
            <span className="font-semibold tracking-tight">SilentGuard · Demo</span>
          </div>
        </div>
      </nav>

      <section className="mx-auto max-w-5xl px-6 py-16">
        <div className="mb-12 text-center">
          <span className="mb-4 inline-flex items-center gap-2 rounded-full bg-brand-light px-3 py-1 text-xs font-semibold uppercase tracking-wider text-brand">
            <Sparkles className="size-3.5" /> Trải nghiệm AI
          </span>
          <h1 className="text-balance text-3xl font-semibold lg:text-5xl">
            Tải video lên — AI sẽ cho biết có té ngã hay không
          </h1>
          <p className="mx-auto mt-4 max-w-[52ch] text-pretty text-ink-soft">
            Tải lên video của bạn (độ dài tối đa 1 phút). Hệ thống sẽ xử lý và gửi thông báo cảnh báo chi tiết từ mô hình AI.
          </p>
        </div>

        <div className="grid gap-8 lg:grid-cols-[1.1fr_1fr]">
          {/* Upload area */}
          <div className="rounded-3xl bg-surface p-6 ring-1 ring-border shadow-soft">
            <label
              htmlFor="video-input"
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => {
                e.preventDefault();
                selectFile(e.dataTransfer.files?.[0] ?? null);
              }}
              className="group flex aspect-video w-full cursor-pointer flex-col items-center justify-center rounded-2xl border-2 border-dashed border-border bg-surface-2 text-center transition-colors hover:border-brand hover:bg-brand-light/40"
            >
              {previewUrl ? (
                <video
                  src={previewUrl}
                  controls
                  className="aspect-video h-full w-full rounded-2xl object-cover"
                />
              ) : (
                <div className="flex flex-col items-center gap-3 p-6 text-ink-soft">
                  <div className="grid size-14 place-items-center rounded-full bg-brand-light text-brand transition-transform group-hover:scale-110">
                    <Upload className="size-6" />
                  </div>
                  <div className="font-medium text-ink">Kéo thả video vào đây</div>
                  <div className="text-xs">hoặc bấm để chọn · MP4, WebM, MOV · tối đa 1 phút ({MAX_MB}MB)</div>
                </div>
              )}
            </label>
            <input
              ref={inputRef}
              id="video-input"
              type="file"
              accept="video/*"
              className="hidden"
              onChange={(e) => selectFile(e.target.files?.[0] ?? null)}
            />

            <div className="mt-6 flex flex-wrap items-center justify-between gap-3">
              <div className="flex items-center gap-2 text-xs text-ink-soft">
                <Film className="size-4" />
                {file ? `${file.name} · ${(file.size / 1024 / 1024).toFixed(1)} MB` : "Chưa chọn video"}
              </div>
              <div className="flex gap-2">
                {file && (
                  <button
                    onClick={() => {
                      selectFile(null);
                      if (inputRef.current) inputRef.current.value = "";
                    }}
                    disabled={busy}
                    className="rounded-full bg-surface-2 px-4 py-2 text-sm ring-1 ring-border hover:bg-surface disabled:opacity-50"
                  >
                    Xoá
                  </button>
                )}
                <button
                  onClick={runAnalysis}
                  disabled={!file || busy}
                  className="inline-flex items-center gap-2 rounded-full bg-brand px-5 py-2 text-sm font-medium text-brand-foreground shadow-soft ring-1 ring-brand transition-all hover:shadow-glow disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {busy && <Loader2 className="size-4 animate-spin" />}
                  {status === "authenticating"
                    ? "Đang xác thực tài khoản demo…"
                    : status === "uploading"
                      ? "Đang tải video lên…"
                      : status === "polling"
                        ? "AI đang xử lý video…"
                        : "Phân tích bằng AI"}
                </button>
              </div>
            </div>

            {error && (
              <div className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-700 ring-1 ring-red-200">
                {error}
              </div>
            )}

            {/* Test Video Fall samples */}
            <div className="mt-8 border-t border-border pt-6">
              <h3 className="mb-3 text-xs font-semibold uppercase tracking-widest text-ink-soft">
                Video mẫu để kiểm thử nhanh
              </h3>
              <p className="mb-4 text-xs text-ink-soft">
                Nếu chưa có sẵn video, bạn có thể tải về các video mẫu ngã thật dưới đây để tải lên hệ thống kiểm tra:
              </p>
              <div className="grid grid-cols-2 gap-2 max-h-48 overflow-y-auto pr-2 custom-scrollbar">
                {[
                  "20240912_101331.mp4",
                  "20240912_101427.mp4",
                  "20240912_101520.mp4",
                  "20240912_101626.mp4",
                  "20240912_101723.mp4",
                  "20240912_101943.mp4",
                  "20240912_102048.mp4",
                  "20240912_102146.mp4",
                  "20240912_102330.mp4",
                  "20240912_102649.mp4"
                ].map((videoName, i) => (
                  <a
                    key={videoName}
                    href={`/downloads/fall/${videoName}`}
                    download
                    className="flex items-center justify-between rounded-xl bg-surface-2 p-2.5 text-xs font-medium text-ink border border-border hover:bg-brand-light/35 hover:border-brand/30 transition-all text-left"
                  >
                    <span className="truncate pr-2">Video ngã mẫu {i + 1}</span>
                    <Download className="size-3.5 shrink-0 text-brand-glow" />
                  </a>
                ))}
              </div>
            </div>
          </div>

          {/* Result */}
          <div ref={resultRef} className="rounded-3xl bg-surface p-6 ring-1 ring-border shadow-soft scroll-mt-20">
            <h2 className="mb-4 text-sm font-semibold uppercase tracking-widest text-ink-soft">
              Kết quả phân tích từ AI
            </h2>
            <AnimatePresence mode="wait">
              {!eventResult && !busy && (
                <motion.div
                  key="empty"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="flex h-72 flex-col items-center justify-center text-center text-sm text-ink-soft"
                >
                  <div className="mb-3 grid size-12 place-items-center rounded-full bg-surface-2">
                    <Film className="size-5" />
                  </div>
                  Tải lên một video và bấm "Phân tích" để xem kết quả.
                </motion.div>
              )}

              {busy && (
                <motion.div
                  key="loading"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="flex h-72 flex-col items-center justify-center gap-3 text-sm text-ink-soft"
                >
                  <Loader2 className="size-6 animate-spin text-brand" />
                  {status === "authenticating"
                    ? "Đang xác thực thông tin đăng nhập..."
                    : status === "uploading"
                      ? "Đang tải tệp video lên hệ thống lưu trữ…"
                      : "Hệ thống AI đang quét và phân tích té ngã…"}
                </motion.div>
              )}

              {eventResult && !busy && <ResultCard key="result" r={eventResult} />}
            </AnimatePresence>
          </div>
        </div>

        <p className="mx-auto mt-12 max-w-[60ch] text-center text-xs text-ink-soft">
          Lưu ý: Demo này gửi video của bạn lên dịch vụ phân tích AI để tự động phát hiện các sự cố té ngã theo thời gian thực.
        </p>
      </section>
    </main>
  );
}

function ResultCard({ r }: { r: { event_type: string | null; severity: string | null; confidence: number | null; llm_message: string | null; room: string | null } }) {
  const isFall = r.event_type === "fall";
                 
  const sevColor =
    r.severity?.toUpperCase() === "HIGH" || r.severity?.toUpperCase() === "CRITICAL"
      ? "bg-red-100 text-red-700 ring-red-200"
      : r.severity?.toUpperCase() === "MEDIUM"
        ? "bg-orange-100 text-orange-700 ring-orange-200"
        : "bg-emerald-100 text-emerald-700 ring-emerald-200";

  // Clean the AI message: strip room details ("trong bedroom", "trong phòng khách", etc) and duration_sec ("bất động hơn X giây")
  let cleanMessage = r.llm_message || "Không có phản hồi chi tiết từ AI.";
  if (r.llm_message) {
    // Remove "trong <room>" or "trong phòng <room>"
    cleanMessage = cleanMessage.replace(/trong\s+[a-zA-Z0-9_À-ỹ\s]+(?=\slúc)/i, "");
    // Remove "Người thân bất động hơn X giây. " or "Người thân bất động hơn X giây" or "Người thân chưa đứng dậy sau X giây. "
    cleanMessage = cleanMessage.replace(/(Người thân bất động hơn|Người thân chưa đứng dậy sau)\s+\d+\s+giây\.?\s*/i, "");

    // Dynamically convert UTC time string in message (e.g. "lúc 04:08") to Vietnam Local Time (GMT+7)
    const timeMatch = cleanMessage.match(/lúc\s+(\d{2}):(\d{2})/i);
    if (timeMatch) {
      const utcHours = parseInt(timeMatch[1], 10);
      const utcMinutes = parseInt(timeMatch[2], 10);
      
      // Add 7 hours for Vietnam (GMT+7) timezone conversion
      let localHours = (utcHours + 7) % 24;
      const formattedHours = String(localHours).padStart(2, '0');
      const formattedMinutes = String(utcMinutes).padStart(2, '0');
      
      cleanMessage = cleanMessage.replace(/lúc\s+\d{2}:\d{2}/i, `lúc ${formattedHours}:${formattedMinutes}`);
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
      className="space-y-5"
    >
      <div
        className={`flex items-center gap-3 rounded-2xl p-4 ring-1 ${
          isFall
            ? "bg-red-50 text-red-800 ring-red-200"
            : "bg-emerald-50 text-emerald-800 ring-emerald-200"
        }`}
      >
        {isFall ? (
          <AlertTriangle className="size-6 shrink-0" />
        ) : (
          <CheckCircle2 className="size-6 shrink-0" />
        )}
        <div>
          <div className="text-xs font-semibold uppercase tracking-widest opacity-70">
            {isFall ? "Phát hiện té ngã" : "An toàn / Bình thường (Không té ngã)"}
          </div>
          <div className="text-lg font-semibold">
            Độ tin cậy {r.confidence ? `${(r.confidence * 100).toFixed(0)}%` : "N/A"}
          </div>
        </div>
      </div>

      <div className="flex flex-wrap gap-2 animate-fade-in">
        <span className={`rounded-full px-3 py-1 text-xs font-medium ring-1 ${sevColor}`}>
          Mức độ nghiêm trọng: {r.severity || "Không xác định"}
        </span>
      </div>

      <div className={`rounded-xl border p-4 ${
        isFall 
          ? "border-red-200 bg-red-50/50" 
          : "border-emerald-200 bg-emerald-50/50"
      }`}>
        <h4 className={`mb-1 text-xs font-semibold uppercase tracking-widest ${
          isFall ? "text-red-800" : "text-emerald-800"
        }`}>
          {isFall ? "Cảnh báo chi tiết từ AI" : "Thông tin chi tiết từ AI"}
        </h4>
        <p className={`text-sm leading-relaxed ${
          isFall ? "text-red-900" : "text-emerald-900"
        }`}>{cleanMessage}</p>
      </div>
    </motion.div>
  );
}

