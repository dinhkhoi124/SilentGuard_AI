import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, Volume2, VolumeX } from "lucide-react";
import { useState, useRef, useEffect, lazy, Suspense } from "react";
import { ClientOnly } from "@/components/ClientOnly";
import { AnimatePresence, motion } from "framer-motion";
import logoAsset from "@/assets/logo.png";

const Flipbook = lazy(() => import("@/components/Flipbook").then((m) => ({ default: m.Flipbook })));

export const Route = createFileRoute("/brochure")({
  head: () => ({
    meta: [
      { title: "Tài liệu giới thiệu — SilentGuard" },
      {
        name: "description",
        content: "Khám phá chi tiết giải pháp an toàn thụ động SilentGuard qua tài liệu giới thiệu trực quan.",
      },
    ],
  }),
  component: BrochurePage,
});

function BrochurePage() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [showHint, setShowHint] = useState(true);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.volume = 0.3;
    }
  }, []);

  const toggleMusic = () => {
    if (audioRef.current) {
      if (isPlaying) {
        audioRef.current.pause();
      } else {
        audioRef.current.play().catch((err) => {
          console.error("Audio play error:", err);
          alert("Không thể phát nhạc. Vui lòng kiểm tra lại loa hoặc trình duyệt của bạn.");
        });
      }
      setIsPlaying(!isPlaying);
    }
  };

  return (
    <main className="min-h-screen bg-surface-2 flex flex-col relative overflow-hidden">
      {/* Hidden Audio Element */}
      <audio ref={audioRef} src="/boosicmox.wav" loop preload="auto" />
      <style>{`
        @keyframes waveMove {
          0% { transform: translateX(0) scaleY(1); }
          50% { transform: translateX(-25%) scaleY(1.1); }
          100% { transform: translateX(-50%) scaleY(1); }
        }
        .animate-wave {
          animation: waveMove 15s ease-in-out infinite alternate;
        }
        @keyframes floatBubble {
          0% { transform: translateY(110vh) scale(0.5) translateX(0); opacity: 0; }
          10% { opacity: 1; }
          50% { transform: translateY(50vh) scale(1) translateX(20px); opacity: 0.8; }
          90% { opacity: 1; }
          100% { transform: translateY(-10vh) scale(1.2) translateX(-20px); opacity: 0; }
        }
        .bubble {
          position: absolute;
          border-radius: 50%;
          animation: floatBubble 15s infinite linear;
          backdrop-filter: blur(2px);
          
          /* Hiệu ứng bong bóng xà phòng / cầu vồng nhẹ */
          background: radial-gradient(
            circle at 30% 30%, 
            rgba(255, 255, 255, 0.2) 0%, 
            rgba(255, 192, 203, 0.15) 20%, 
            rgba(135, 206, 235, 0.15) 40%, 
            rgba(255, 255, 224, 0.1) 60%, 
            rgba(255, 255, 255, 0) 100%
          );
          box-shadow: 
            inset 0 0 10px rgba(255, 255, 255, 0.6),
            inset 10px 0 20px rgba(255, 0, 255, 0.2), 
            inset -10px 0 20px rgba(0, 255, 255, 0.2), 
            inset 0 -10px 20px rgba(255, 255, 0, 0.15), 
            0 4px 12px rgba(0, 0, 0, 0.05);
          border: 1px solid rgba(255, 255, 255, 0.5);
        }
        /* Điểm sáng mặt trời chói ở góc trên trái bong bóng */
        .bubble::after {
          content: "";
          position: absolute;
          top: 15%;
          left: 15%;
          width: 30%;
          height: 20%;
          border-radius: 50%;
          background: radial-gradient(ellipse at center, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0) 70%);
          transform: rotate(-45deg);
        }
      `}</style>
      
      {/* Soft glowing orbs */}
      <div className="absolute top-[-20%] left-[-10%] w-[50vw] h-[50vw] rounded-full bg-brand/5 blur-3xl pointer-events-none z-0"></div>
      <div className="absolute bottom-[-20%] right-[-10%] w-[50vw] h-[50vw] rounded-full bg-brand/5 blur-3xl pointer-events-none z-0"></div>

      {/* Animated bubbles with rainbow soap effect */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden z-0">
        <div className="bubble size-16 left-[10%] [animation-duration:12s] [animation-delay:0s]"></div>
        <div className="bubble size-24 left-[30%] [animation-duration:18s] [animation-delay:2s]"></div>
        <div className="bubble size-10 left-[60%] [animation-duration:10s] [animation-delay:5s]"></div>
        <div className="bubble size-32 left-[80%] [animation-duration:22s] [animation-delay:1s]"></div>
        <div className="bubble size-20 left-[45%] [animation-duration:15s] [animation-delay:7s]"></div>
        <div className="bubble size-12 left-[90%] [animation-duration:14s] [animation-delay:3s]"></div>
        <div className="bubble size-28 left-[20%] [animation-duration:20s] [animation-delay:8s]"></div>
        <div className="bubble size-14 left-[70%] [animation-duration:16s] [animation-delay:4s]"></div>
      </div>
      
      {/* Background waves */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden z-0 flex items-center">
        <svg className="absolute w-[200%] h-[40vh] opacity-[0.03] animate-wave text-brand" preserveAspectRatio="none" viewBox="0 0 1440 320" style={{ top: '30%' }}>
          <path fill="currentColor" fillOpacity="1" d="M0,160L48,165.3C96,171,192,181,288,160C384,139,480,85,576,96C672,107,768,181,864,213.3C960,245,1056,235,1152,208C1248,181,1344,139,1392,117.3L1440,96L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z"></path>
        </svg>
        <svg className="absolute w-[200%] h-[40vh] opacity-[0.04] animate-wave text-brand" preserveAspectRatio="none" viewBox="0 0 1440 320" style={{ top: '40%', animationDuration: '20s', animationDirection: 'alternate-reverse' }}>
          <path fill="currentColor" fillOpacity="1" d="M0,128L60,144C120,160,240,192,360,192C480,192,600,160,720,154.7C840,149,960,171,1080,192C1200,213,1320,235,1380,245.3L1440,256L1440,320L1380,320C1320,320,1200,320,1080,320C960,320,840,320,720,320C600,320,480,320,360,320C240,320,120,320,60,320L0,320Z"></path>
        </svg>
      </div>
      
      {/* Navbar tối giản */}
      <nav className="border-b border-border bg-background/90 backdrop-blur-xl relative z-20">
        <div className="mx-auto flex h-14 w-full items-center justify-between px-4 sm:px-6">
          <Link
            to="/"
            className="flex items-center gap-2 text-sm font-medium text-ink-soft hover:text-brand transition-colors"
          >
            <ArrowLeft className="size-4" />
            <span>Quay lại trang chủ</span>
          </Link>
          <div className="flex items-center gap-4">
            <button 
              onClick={toggleMusic}
              className={`flex items-center justify-center size-9 rounded-full border transition-all shadow-sm ${isPlaying ? 'bg-brand text-white border-brand shadow-glow' : 'bg-white/50 border-brand/10 text-brand hover:bg-white hover:scale-105'}`}
              title={isPlaying ? "Tắt nhạc nền" : "Bật nhạc nền"}
            >
              {isPlaying ? <Volume2 className="size-4" /> : <VolumeX className="size-4" />}
            </button>
            
            <div className="hidden sm:flex items-center gap-3 border-l border-border pl-4">
              <img src={logoAsset} alt="SilentGuard Logo" className="h-6 opacity-90" />
              <div className="text-sm font-medium text-ink">
                Tài liệu giới thiệu SilentGuard
              </div>
            </div>
          </div>
        </div>
      </nav>

      {/* Vùng hiển thị toàn màn hình cho sách lật */}
      <div className="flex-1 flex flex-col relative py-6 sm:py-12 px-2 sm:px-8 overflow-hidden z-10" onClick={() => setShowHint(false)}>
        <ClientOnly fallback={<div className="flex-1 flex items-center justify-center animate-pulse text-ink-soft">Đang tải tài liệu...</div>}>
          <Suspense fallback={<div className="flex-1 flex items-center justify-center animate-pulse text-ink-soft">Đang khởi tạo sách...</div>}>
            <Flipbook pdfUrl="/brochure.pdf" />
            
            {/* Helper Text */}
            <AnimatePresence>
              {showHint && (
                <motion.div
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  className="absolute bottom-[10%] sm:bottom-12 left-1/2 -translate-x-1/2 z-30 pointer-events-none"
                >
                  <div className="animate-bounce flex items-center gap-2 bg-white/70 backdrop-blur-xl px-5 py-2.5 rounded-full shadow-soft border border-white/50 text-brand font-medium text-sm tracking-wide">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="lucide lucide-mouse-pointer-click size-4 shrink-0"><path d="M14 4.1 12 6"/><path d="m5.1 8-2.9-.8"/><path d="m6 12-2.8 3"/><path d="M7.2 2.2 8 5.1"/><path d="M9.037 9.69a.498.498 0 0 1 .653-.653l11 4.5a.5.5 0 0 1-.074.949l-4.349 1.041a1 1 0 0 0-.74.739l-1.04 4.35a.5.5 0 0 1-.95.074z"/></svg>
                    <span>Kéo lật góc trang sách để đọc thêm thông tin</span>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </Suspense>
        </ClientOnly>
      </div>
    </main>
  );
}
