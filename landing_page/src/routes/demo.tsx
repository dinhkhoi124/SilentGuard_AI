import { createFileRoute, Link } from "@tanstack/react-router";
import { useServerFn } from "@tanstack/react-start";
import { useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { AlertTriangle, CheckCircle2, Film, Loader2, Upload, ArrowLeft, Sparkles } from "lucide-react";

import { analyzeFallVideo, type FallDetectionResult } from "@/lib/fall-detection.functions";

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

async function extractFrames(file: File, count: number): Promise<string[]> {
  const url = URL.createObjectURL(file);
  const video = document.createElement("video");
  video.src = url;
  video.muted = true;
  video.playsInline = true;
  video.preload = "auto";
  video.crossOrigin = "anonymous";

  await new Promise<void>((resolve, reject) => {
    video.onloadedmetadata = () => resolve();
    video.onerror = () => reject(new Error("Không đọc được video. Hãy thử định dạng MP4/WebM."));
  });

  const duration = isFinite(video.duration) && video.duration > 0 ? video.duration : 1;
  const width = 480;
  const ratio = video.videoHeight / (video.videoWidth || 1);
  const height = Math.round(width * (ratio || 0.5625));

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Trình duyệt không hỗ trợ canvas.");

  const frames: string[] = [];
  for (let i = 0; i < count; i++) {
    const t = (duration * (i + 0.5)) / count;
    await new Promise<void>((resolve, reject) => {
      const onSeeked = () => {
        video.removeEventListener("seeked", onSeeked);
        try {
          ctx.drawImage(video, 0, 0, width, height);
          frames.push(canvas.toDataURL("image/jpeg", 0.75));
          resolve();
        } catch (e) {
          reject(e as Error);
        }
      };
      video.addEventListener("seeked", onSeeked, { once: true });
      video.currentTime = Math.min(t, Math.max(0, duration - 0.05));
    });
  }
  URL.revokeObjectURL(url);
  return frames;
}

function DemoPage() {
  const analyze = useServerFn(analyzeFallVideo);
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [status, setStatus] = useState<"idle" | "extracting" | "analyzing">("idle");
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<FallDetectionResult | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  function selectFile(f: File | null) {
    setResult(null);
    setError(null);
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
    setFile(f);
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(URL.createObjectURL(f));
  }

  async function runAnalysis() {
    if (!file) return;
    setError(null);
    setResult(null);
    try {
      setStatus("extracting");
      const frames = await extractFrames(file, FRAME_COUNT);
      setStatus("analyzing");
      const r = await analyze({ data: { frames } });
      setResult(r);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Có lỗi xảy ra.");
    } finally {
      setStatus("idle");
    }
  }

  const busy = status !== "idle";

  return (
    <main className="min-h-screen bg-background text-foreground">
      <nav className="sticky top-0 z-50 border-b border-border bg-background/70 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-6">
          <Link to="/" className="flex items-center gap-2 text-sm text-ink-soft hover:text-brand">
            <ArrowLeft className="size-4" /> Về trang chủ
          </Link>
          <div className="flex items-center gap-2">
            <span className="grid size-5 place-items-center rounded-full bg-brand">
              <span className="size-1.5 rounded-full bg-brand-foreground" />
            </span>
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
            Hệ thống trích 8 khung hình từ video của bạn và phân tích bằng cùng mô hình thị giác
            mà SilentGuard sử dụng trong sản phẩm.
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
                  <div className="text-xs">hoặc bấm để chọn · MP4, WebM, MOV · tối đa {MAX_MB}MB</div>
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
                  {status === "extracting"
                    ? "Đang trích khung hình…"
                    : status === "analyzing"
                      ? "AI đang phân tích…"
                      : "Phân tích bằng AI"}
                </button>
              </div>
            </div>

            {error && (
              <div className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-700 ring-1 ring-red-200">
                {error}
              </div>
            )}
          </div>

          {/* Result */}
          <div className="rounded-3xl bg-surface p-6 ring-1 ring-border shadow-soft">
            <h2 className="mb-4 text-sm font-semibold uppercase tracking-widest text-ink-soft">
              Kết quả phân tích
            </h2>
            <AnimatePresence mode="wait">
              {!result && !busy && (
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
                  {status === "extracting"
                    ? "Đang trích 8 khung hình từ video…"
                    : "Mô hình thị giác đang phân tích chuyển động…"}
                </motion.div>
              )}

              {result && !busy && <ResultCard key="result" r={result} />}
            </AnimatePresence>
          </div>
        </div>

        <p className="mx-auto mt-12 max-w-[60ch] text-center text-xs text-ink-soft">
          Lưu ý: Demo này gửi 8 khung hình tĩnh trích từ video lên dịch vụ AI để phân tích — không
          phải dòng video trực tiếp như trong sản phẩm thật. Độ chính xác có thể khác với hệ thống
          camera SilentGuard.
        </p>
      </section>
    </main>
  );
}

function ResultCard({ r }: { r: FallDetectionResult }) {
  const positive = r.fallDetected;
  const sevColor =
    r.severity === "high"
      ? "bg-red-100 text-red-700 ring-red-200"
      : r.severity === "medium"
        ? "bg-orange-100 text-orange-700 ring-orange-200"
        : r.severity === "low"
          ? "bg-amber-100 text-amber-700 ring-amber-200"
          : "bg-emerald-100 text-emerald-700 ring-emerald-200";

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
          positive
            ? "bg-red-50 text-red-800 ring-red-200"
            : "bg-emerald-50 text-emerald-800 ring-emerald-200"
        }`}
      >
        {positive ? (
          <AlertTriangle className="size-6 shrink-0" />
        ) : (
          <CheckCircle2 className="size-6 shrink-0" />
        )}
        <div>
          <div className="text-xs font-semibold uppercase tracking-widest opacity-70">
            {positive ? "Phát hiện té ngã" : "Không phát hiện té ngã"}
          </div>
          <div className="text-lg font-semibold">
            Độ tin cậy {(r.confidence * 100).toFixed(0)}%
          </div>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        <span className={`rounded-full px-3 py-1 text-xs font-medium ring-1 ${sevColor}`}>
          Mức độ: {labelSeverity(r.severity)}
        </span>
        <span className="rounded-full bg-surface-2 px-3 py-1 text-xs text-ink-soft ring-1 ring-border">
          {r.timestampHint}
        </span>
      </div>

      <div>
        <h4 className="mb-1 text-xs font-semibold uppercase tracking-widest text-ink-soft">
          Mô tả
        </h4>
        <p className="text-sm leading-relaxed">{r.description}</p>
      </div>

      <div>
        <h4 className="mb-1 text-xs font-semibold uppercase tracking-widest text-ink-soft">
          Khuyến nghị
        </h4>
        <p className="text-sm leading-relaxed">{r.recommendation}</p>
      </div>
    </motion.div>
  );
}

function labelSeverity(s: FallDetectionResult["severity"]) {
  return { none: "Không có", low: "Nhẹ", medium: "Trung bình", high: "Nghiêm trọng" }[s];
}
