import { createFileRoute, Link } from "@tanstack/react-router";
import { motion, useScroll, useTransform, useReducedMotion, AnimatePresence } from "framer-motion";
import { useRef, useState, useEffect } from "react";
import { Activity, Bell, Camera, ChevronDown, Eye, EyeOff, Loader2, Moon, PlayCircle, ShieldCheck, Sparkles, Users, Wifi, X, Download, ArrowUp, HelpCircle, Laptop, Smartphone, Key, Settings, Info, BookOpen, ArrowRight } from "lucide-react";
import { toast } from "sonner";

import { ClientOnly } from "@/components/ClientOnly";
import { Hero3D } from "@/components/Hero3D";
import lifestyleImg from "@/assets/lifestyle.jpg";
import appScreenImg from "@/assets/app-screen.jpg";
import downloadAndroidIcon from "@/assets/download-android.png";
import conceptCameraAiImg from "@/assets/concept_camera_ai.png";
import conceptMobileAppImg from "@/assets/concept_mobile_app.png";
import conceptFamilyCareImg from "@/assets/concept_family_care.png";
import logoAsset from "@/assets/logo.png";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "SilentGuard — Thiết bị phát hiện té ngã cho người cao tuổi" },
      {
        name: "description",
        content:
          "SilentGuard dùng AI phát hiện té ngã của người cao tuổi và gửi cảnh báo tức thì đến điện thoại con cái. An tâm dù bạn ở bất cứ đâu.",
      },
      { property: "og:title", content: "SilentGuard — An tâm cho cha mẹ" },
      {
        property: "og:description",
        content: "Phát hiện té ngã tức thì, kết nối gia đình bằng công nghệ AI.",
      },
    ],
  }),
  component: Index,
});

import type { Variants } from "framer-motion";

const EASE = [0.16, 1, 0.3, 1] as const;

const fadeUp: Variants = {
  hidden: { opacity: 0, y: 24 },
  show: { opacity: 1, y: 0, transition: { duration: 0.8, ease: EASE } },
};

function Section({
  children,
  className = "",
  id,
}: {
  children: React.ReactNode;
  className?: string;
  id?: string;
}) {
  return (
    <motion.section
      id={id}
      initial="hidden"
      whileInView="show"
      viewport={{ once: true, amount: 0.2 }}
      variants={{ show: { transition: { staggerChildren: 0.1 } } }}
      className={className}
    >
      {children}
    </motion.section>
  );
}

function Nav() {
  return (
    <nav className="sticky top-0 z-50 border-b border-border bg-background/70 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <a href="#top" className="flex items-center gap-2">
          <img
            src={logoAsset}
            alt="SilentGuard"
            width={28}
            height={28}
            className="size-7 object-cover rounded-full mix-blend-multiply"
          />
          <span className="font-semibold tracking-tight">SilentGuard</span>
        </a>
        <div className="hidden items-center gap-8 text-sm text-ink-soft md:flex">
          <a href="#intro" className="transition-colors hover:text-brand">Giới thiệu</a>
          <a href="#how" className="transition-colors hover:text-brand">Cách hoạt động</a>
          <a href="#features" className="transition-colors hover:text-brand">Tính năng</a>
          <Link to="/demo" className="transition-colors hover:text-brand">Thử AI</Link>
          <Link to="/faq" className="transition-colors hover:text-brand">Hỏi đáp</Link>
          <a href="#contact" className="transition-colors hover:text-brand">Liên hệ</a>
        </div>
        <Link
          to="/demo"
          className="rounded-full bg-brand px-4 py-2 text-sm font-medium text-brand-foreground shadow-soft ring-1 ring-brand transition-all hover:scale-[1.02] hover:shadow-glow"
        >
          Thử AI miễn phí
        </Link>
      </div>
    </nav>
  );
}

function Hero() {
  const ref = useRef<HTMLDivElement>(null);
  const prefersReduce = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end start"] });
  const y = useTransform(scrollYProgress, [0, 1], [0, prefersReduce ? 0 : 120]);
  const scale = useTransform(scrollYProgress, [0, 1], [1, prefersReduce ? 1 : 0.92]);
  const opacity = useTransform(scrollYProgress, [0, 1], [1, 0]);

  return (
    <section ref={ref} id="top" className="relative overflow-hidden border-b border-border">
      {/* Ambient gradient blobs */}
      <div
        aria-hidden
        className="pointer-events-none absolute -left-32 top-10 size-[420px] rounded-full opacity-60 blur-3xl"
        style={{ background: "radial-gradient(circle, color-mix(in oklab, var(--brand-light) 90%, transparent), transparent 70%)" }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -right-24 bottom-0 size-[360px] rounded-full opacity-50 blur-3xl"
        style={{ background: "radial-gradient(circle, color-mix(in oklab, var(--accent) 30%, transparent), transparent 70%)" }}
      />

      <div className="mx-auto max-w-6xl px-6 pt-10 pb-20 lg:pt-16 lg:pb-32">
        <div className="grid items-center gap-16 lg:grid-cols-[1.05fr_0.95fr]">
          <motion.div style={{ y, scale, opacity }} className="relative min-w-0">
            <motion.span
              variants={fadeUp}
              initial="hidden"
              animate="show"
              className="mb-6 inline-flex items-center gap-2 rounded-full bg-brand-light px-3 py-1 text-xs font-semibold uppercase tracking-wider text-brand"
            >
              <ShieldCheck className="size-3.5" /> An tâm cho cả gia đình
            </motion.span>

            <motion.h1
              variants={fadeUp}
              initial="hidden"
              animate="show"
              transition={{ delay: 0.05 }}
              className="mb-8 max-w-[18ch] text-balance text-4xl font-semibold leading-[1.05] tracking-tight lg:text-6xl"
            >
              Khoảng cách không còn là{" "}
              <span className="italic text-brand">nỗi lo</span> khi cha mẹ luôn được bảo vệ.
            </motion.h1>

            <motion.p
              variants={fadeUp}
              initial="hidden"
              animate="show"
              transition={{ delay: 0.15 }}
              className="mb-10 max-w-[48ch] text-pretty text-lg text-ink-soft"
            >
              SilentGuard dùng camera AI quan sát thầm lặng, phát hiện ngay khi có người té ngã
              và gửi cảnh báo trực tiếp đến app của bạn — không cần ai phải đeo gì cả.
            </motion.p>

            <motion.div
              variants={fadeUp}
              initial="hidden"
              animate="show"
              transition={{ delay: 0.25 }}
              className="flex flex-col gap-4 sm:flex-row"
            >
              <a
                href="#contact"
                className="inline-flex items-center justify-center gap-2 rounded-full bg-brand px-6 py-3 font-medium text-brand-foreground shadow-soft ring-1 ring-brand transition-all hover:shadow-glow"
              >
                <span className="grid size-4 place-items-center rounded-full bg-brand-foreground/20">
                  <span className="size-1.5 rounded-full bg-brand-foreground" />
                </span>
                Trải nghiệm ứng dụng
              </a>
              <a
                href="#how"
                className="inline-flex items-center justify-center rounded-full bg-surface px-6 py-3 font-medium text-ink ring-1 ring-border transition-colors hover:bg-surface-2"
              >
                Xem cách hoạt động
              </a>
            </motion.div>

            <motion.div
              variants={fadeUp}
              initial="hidden"
              animate="show"
              transition={{ delay: 0.4 }}
              className="mt-12 flex flex-wrap gap-x-8 gap-y-6 text-sm sm:max-w-md sm:justify-between"
            >
              {[
                { k: "<60s", v: "Phát hiện" },
                { k: "90%", v: "Độ chính xác" },
                { k: "24/7", v: "Quan sát liên tục" },
              ].map((s) => (
                <div key={s.v}>
                  <div className="text-3xl font-semibold text-brand tracking-tight">{s.k}</div>
                  <div className="text-xs sm:text-sm text-ink-soft mt-1">{s.v}</div>
                </div>
              ))}
            </motion.div>
          </motion.div>

          {/* 3D Scene */}
          <div className="relative min-w-0">
            <div className="relative aspect-square w-full overflow-hidden rounded-3xl bg-gradient-to-br from-brand-light via-surface to-surface-2 ring-1 ring-border shadow-glow">
              <ClientOnly
                fallback={
                  <div className="grid h-full w-full place-items-center text-xs uppercase tracking-widest text-ink-soft">
                    Loading 3D…
                  </div>
                }
              >
                <Hero3D />
              </ClientOnly>

              {/* Floating live alert card */}
              <motion.div
                initial={{ opacity: 0, y: 20, x: -20 }}
                animate={{ opacity: 1, y: 0, x: 0 }}
                transition={{ delay: 0.6, duration: 0.8, ease: EASE }}
                className="absolute bottom-6 left-6 max-w-[260px] rounded-2xl bg-surface/90 p-4 shadow-soft ring-1 ring-border backdrop-blur-md"
              >
                <div className="mb-2 flex items-center gap-2">
                  <span className="relative grid size-2 place-items-center rounded-full bg-brand">
                    <span className="absolute inset-0 animate-ping rounded-full bg-brand opacity-60" />
                  </span>
                  <span className="text-[10px] font-semibold uppercase tracking-wider text-brand">
                    Đang theo dõi
                  </span>
                </div>
                <p className="text-sm font-semibold">Mẹ — An toàn</p>
                <p className="mt-0.5 text-xs text-ink-soft">Camera phòng khách · 2 phút trước</p>
              </motion.div>

              {/* Floating phone */}
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.8, duration: 0.8 }}
                className="absolute -right-4 top-10 hidden w-36 rotate-6 overflow-hidden rounded-[1.5rem] bg-surface p-1.5 shadow-glow ring-1 ring-border sm:block lg:right-[-2rem] lg:w-44"
              >
                <img
                  src={appScreenImg}
                  alt="Giao diện ứng dụng SilentGuard"
                  width={400}
                  height={600}
                  className="aspect-[9/16] w-full rounded-[1.1rem] object-cover"
                  loading="eager"
                />
              </motion.div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

const STEPS = [
  {
    n: "01",
    title: "Lắp đặt camera",
    body: "Đặt camera SilentGuard tại phòng khách, phòng ngủ hoặc nhà tắm — cha mẹ không cần đeo hay mang theo bất cứ thứ gì.",
    icon: ShieldCheck,
  },
  {
    n: "02",
    title: "AI quan sát thầm lặng",
    body: "Mô hình thị giác máy phân tích chuyển động trực tiếp trên camera, phân biệt cú ngã thật với việc ngồi xuống hay cúi nhặt đồ.",
    icon: Activity,
  },
  {
    n: "03",
    title: "Thông báo tức thì",
    body: "Dưới 3 giây sau khi phát hiện ngã, ứng dụng gửi cảnh báo cùng ảnh hiện trường đến tất cả thành viên trong gia đình.",
    icon: Bell,
  },
];

function Introduction() {
  return (
    <Section id="intro" className="py-24">
      <div className="mx-auto max-w-4xl px-6">
        <motion.div 
          variants={fadeUp} 
          className="relative overflow-hidden rounded-3xl border border-border bg-surface-2 p-8 sm:p-12 text-center shadow-soft"
        >
          <div className="absolute top-0 right-0 -mr-16 -mt-16 opacity-5 pointer-events-none">
            <BookOpen className="size-64" />
          </div>
          
          <div className="mx-auto flex size-16 items-center justify-center rounded-full bg-brand/10 text-brand mb-6">
            <BookOpen className="size-8" />
          </div>
          <h2 className="text-balance text-2xl font-semibold sm:text-3xl lg:text-4xl">
            Tài liệu giới thiệu giải pháp
          </h2>
          <p className="mx-auto mt-4 max-w-[50ch] text-pretty text-ink-soft">
            Tìm hiểu chi tiết về cơ chế hoạt động, các tính năng cốt lõi và chính sách bảo mật của SilentGuard qua cuốn sách tương tác.
          </p>
          <div className="mt-8">
            <Link
              to="/brochure"
              className="inline-flex items-center gap-2 rounded-full bg-brand px-6 py-3 text-sm font-medium text-brand-foreground shadow-soft ring-1 ring-brand transition-all hover:scale-[1.02] hover:shadow-glow"
            >
              <span>📖 Đọc tài liệu giới thiệu</span>
              <ArrowRight className="size-4" />
            </Link>
          </div>
        </motion.div>
      </div>
    </Section>
  );
}

function HowItWorks() {
  return (
    <Section id="how" className="bg-surface-2 py-24">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div variants={fadeUp} className="mb-20 text-center">
          <h2 className="text-balance text-3xl font-semibold lg:text-4xl">
            Cơ chế hoạt động đơn giản
          </h2>
          <p className="mx-auto mt-4 max-w-[48ch] text-pretty text-ink-soft">
            Công nghệ hiện đại phục vụ cho tình yêu thương chân thành nhất.
          </p>
        </motion.div>

        <div className="grid gap-12 md:grid-cols-3">
          {STEPS.map((s, i) => (
            <motion.div
              key={s.n}
              variants={fadeUp}
              whileHover={{ y: -6 }}
              transition={{ type: "spring", stiffness: 200, damping: 18 }}
              className="group relative"
            >
              <div className="mb-6 flex items-center gap-3">
                <div className="relative grid size-12 place-items-center rounded-2xl bg-surface shadow-soft ring-1 ring-border transition-all group-hover:shadow-glow">
                  <s.icon className="size-5 text-brand" />
                </div>
                <span className="font-mono text-xs uppercase tracking-widest text-ink-soft">
                  Bước {s.n}
                </span>
              </div>
              <h3 className="mb-3 text-xl font-semibold">{s.title}</h3>
              <p className="text-pretty text-sm leading-relaxed text-ink-soft">{s.body}</p>
              {i < STEPS.length - 1 && (
                <div className="pointer-events-none absolute -right-6 top-6 hidden h-px w-12 bg-gradient-to-r from-brand/40 to-transparent md:block" />
              )}
            </motion.div>
          ))}
        </div>
      </div>
    </Section>
  );
}

const FEATURES = [
  { icon: Camera, title: "Phát hiện ngã bằng AI thị giác", body: "Mô hình AI nhận biết tư thế và chuyển động, phân biệt cú ngã thật với các hoạt động bình thường." },
  { icon: EyeOff, title: "Bảo vệ riêng tư", body: "Hình ảnh được xử lý ngay trên camera, không lưu trữ video liên tục. Chỉ gửi ảnh khi có sự cố." },
  { icon: Moon, title: "Hoạt động cả ban đêm", body: "Cảm biến hồng ngoại giúp camera quan sát rõ trong bóng tối — phù hợp cả khi cha mẹ đi vệ sinh đêm." },
  { icon: Bell, title: "Cảnh báo đa kênh", body: "Đẩy thông báo, gọi điện và nhắn tin đồng thời đến nhiều thành viên gia đình." },
  { icon: Users, title: "Nhiều người thân cùng theo dõi", body: "Anh chị em trong nhà cùng nhận cảnh báo trên một app, không ai bỏ lỡ thông tin quan trọng." },
  { icon: Wifi, title: "Cài đặt trong 5 phút", body: "Cắm điện, quét QR, kết nối Wi-Fi — không cần thợ kỹ thuật, không cần đi dây phức tạp." },
];

function Features() {
  return (
    <Section id="features" className="py-24">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid items-center gap-16 lg:grid-cols-2 lg:gap-24">
          <motion.div
            variants={fadeUp}
            className="relative order-2 lg:order-1"
          >
            <motion.div
              whileHover={{ rotateX: 4, rotateY: -6, scale: 1.02 }}
              transition={{ type: "spring", stiffness: 200, damping: 20 }}
              style={{ transformStyle: "preserve-3d", perspective: 1000 }}
              className="relative"
            >
              <img
                src={lifestyleImg}
                alt="Người cao tuổi đang đọc sách trong vườn"
                width={1280}
                height={896}
                loading="lazy"
                className="w-full rounded-2xl object-cover shadow-soft ring-1 ring-border"
              />
              <div className="absolute -bottom-5 -right-5 rounded-2xl bg-surface px-5 py-4 shadow-glow ring-1 ring-border">
                <div className="flex items-center gap-3">
                  <div className="relative grid size-10 place-items-center rounded-full bg-brand-light">
                    <Eye className="size-5 text-brand" />
                    <span className="absolute -right-0.5 -top-0.5 size-2 animate-pulse rounded-full bg-brand" />
                  </div>
                  <div>
                    <div className="text-xs text-ink-soft">Camera đang hoạt động</div>
                    <div className="font-mono text-sm font-semibold text-brand">Tất cả an toàn</div>
                  </div>
                </div>
              </div>
            </motion.div>
          </motion.div>

          <motion.div variants={fadeUp} className="order-1 lg:order-2">
            <h2 className="mb-8 text-balance text-3xl font-semibold leading-tight lg:text-4xl">
              Camera AI thiết kế dành riêng cho gia đình có người cao tuổi
            </h2>

            <div className="grid gap-6 sm:grid-cols-2">
              {FEATURES.map((f) => (
                <motion.div
                  key={f.title}
                  variants={fadeUp}
                  className="group flex gap-4"
                >
                  <div className="mt-1 grid size-9 shrink-0 place-items-center rounded-xl bg-brand-light text-brand transition-all group-hover:bg-brand group-hover:text-brand-foreground">
                    <f.icon className="size-4" />
                  </div>
                  <div>
                    <h4 className="mb-1 font-medium">{f.title}</h4>
                    <p className="text-sm text-ink-soft">{f.body}</p>
                  </div>
                </motion.div>
              ))}
            </div>
          </motion.div>
        </div>
      </div>
    </Section>
  );
}

const STORIES = [
  {
    quote:
      "Bố mẹ tôi không thích đeo đồng hồ thông minh — hay quên sạc, hay tháo ra. Camera SilentGuard lắp một lần là xong, tôi không phải nhắc nhở gì cả.",
    name: "Anh Minh Tuấn",
    city: "TP. Hồ Chí Minh",
  },
  {
    quote:
      "Có lần bố tôi trượt chân khi ra khỏi giường lúc nửa đêm, app báo trong 3 giây kèm theo ảnh hiện trường. Tôi gọi hàng xóm sang kịp lúc.",
    name: "Chị Thanh Huyền",
    city: "Hà Nội",
  },
];

function Stories() {
  return (
    <Section id="stories" className="bg-ink py-24 text-background">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div variants={fadeUp} className="mb-16 max-w-[44ch]">
          <span className="mb-4 inline-block text-xs font-semibold uppercase tracking-widest text-brand-glow">
            Câu chuyện thật
          </span>
          <h2 className="text-balance text-3xl font-medium leading-tight lg:text-4xl">
            Những kết nối yêu thương được giữ vững — kể cả khi cách xa.
          </h2>
        </motion.div>

        <div className="grid gap-8 md:grid-cols-2">
          {STORIES.map((s) => (
            <motion.figure
              key={s.name}
              variants={fadeUp}
              whileHover={{ y: -4 }}
              className="rounded-3xl bg-white/5 p-8 ring-1 ring-white/10 backdrop-blur"
            >
              <blockquote className="mb-8 text-lg italic leading-relaxed text-background/90">
                "{s.quote}"
              </blockquote>
              <figcaption className="flex items-center gap-3">
                <div className="size-10 rounded-full bg-gradient-to-br from-brand-glow to-brand" />
                <div>
                  <div className="text-sm font-medium">{s.name}</div>
                  <div className="text-xs text-background/60">{s.city}</div>
                </div>
              </figcaption>
            </motion.figure>
          ))}
        </div>
      </div>
    </Section>
  );
}

import useEmblaCarousel from "embla-carousel-react";

function ProductGallery() {
  const galleryImages = [
    { src: conceptMobileAppImg, alt: "Cảnh báo an toàn thông minh", title: "Ứng dụng di động", desc: "Giao diện trực quan, cảnh báo tức thì, cập nhật trạng thái mọi lúc." },
    { src: conceptFamilyCareImg, alt: "Bảo vệ gia đình bằng AI", title: "Giải pháp bảo vệ toàn diện", desc: "An tâm cho cha mẹ cao tuổi, kết nối con cái dù ở bất cứ đâu." },
    { src: conceptCameraAiImg, alt: "Công nghệ Camera AI hiện đại", title: "Thiết bị Camera AI", desc: "Thiết kế nhỏ gọn, hiện đại, lắp đặt linh hoạt ở mọi góc phòng." }
  ];

  // Nhân bản danh sách ảnh để đảm bảo Embla Carousel có đủ số lượng slide (ít nhất 6) để loop mượt mà
  const displayImages = [...galleryImages, ...galleryImages];

  const [emblaRef, emblaApi] = useEmblaCarousel({ 
    align: "center", 
    loop: true,
    skipSnaps: false
  });

  // Tự động chạy slider (Autoplay) mỗi 3 giây và tạm dừng khi người dùng tương tác
  useEffect(() => {
    if (!emblaApi) return;

    let intervalId: ReturnType<typeof setInterval>;

    const startAutoplay = () => {
      stopAutoplay();
      intervalId = setInterval(() => {
        if (emblaApi) emblaApi.scrollNext();
      }, 3000);
    };

    const stopAutoplay = () => {
      if (intervalId) clearInterval(intervalId);
    };

    startAutoplay();

    emblaApi.on("pointerDown", stopAutoplay);
    emblaApi.on("pointerUp", startAutoplay);

    return () => {
      stopAutoplay();
      if (emblaApi) {
        emblaApi.off("pointerDown", stopAutoplay);
        emblaApi.off("pointerUp", startAutoplay);
      }
    };
  }, [emblaApi]);

  return (
    <Section id="gallery" className="py-24 bg-surface-2 border-y border-border overflow-hidden">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div variants={fadeUp} className="mb-16 text-center">
          <span className="mb-4 inline-block text-xs font-semibold uppercase tracking-widest text-brand">
            Hình ảnh thực tế
          </span>
          <h2 className="text-balance text-3xl font-semibold leading-tight lg:text-4xl">
            Chi tiết sản phẩm SilentGuard
          </h2>
          <p className="mx-auto mt-4 max-w-[48ch] text-pretty text-ink-soft">
            Trực quan thiết bị camera AI và giao diện ứng dụng kết nối trực tiếp trong gia đình.
          </p>
        </motion.div>

        {/* Embla Carousel Viewport */}
        <div className="w-full overflow-hidden cursor-grab active:cursor-grabbing" ref={emblaRef}>
          <div className="flex touch-pan-y">
            {displayImages.map((img, i) => (
              <div 
                key={i} 
                className="flex-[0_0_85%] sm:flex-[0_0_45%] lg:flex-[0_0_30%] min-w-0 px-3"
              >
                <div
                  className="group h-full flex flex-col overflow-hidden rounded-3xl bg-surface border border-border shadow-soft transition-all duration-300 hover:-translate-y-1.5 hover:shadow-glow"
                >
                  <div className="relative w-full overflow-hidden aspect-[4/3] sm:aspect-[16/9] bg-surface-2 flex items-center justify-center">
                    <img
                      src={img.src}
                      alt={img.alt}
                      loading="lazy"
                      className="w-full h-full object-cover group-hover:scale-105 transition-all duration-700 pointer-events-none"
                    />
                  </div>
                  <div className="p-6 flex-1 flex flex-col justify-center">
                    <h3 className="mb-2 text-lg font-semibold text-ink">{img.title}</h3>
                    <p className="text-sm text-ink-soft leading-relaxed">{img.desc}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Section>
  );
}

function Contact() {
  const [submitted, setSubmitted] = useState(false);
  const [loading, setLoading] = useState(false);

  return (
    <Section id="contact" className="py-24">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          variants={fadeUp}
          className="relative overflow-hidden rounded-3xl bg-surface p-8 ring-1 ring-border md:p-16"
        >
          <div
            aria-hidden
            className="pointer-events-none absolute -right-20 -top-20 size-80 rounded-full opacity-40 blur-3xl"
            style={{ background: "radial-gradient(circle, var(--brand-light), transparent 70%)" }}
          />
          <div className="relative grid gap-12 md:grid-cols-[1.1fr_0.9fr] md:items-center">
            <div>
              <span className="mb-4 inline-block text-xs font-semibold uppercase tracking-widest text-brand">
                Đăng ký sớm
              </span>
              <h2 className="mb-6 text-balance text-3xl font-semibold leading-tight lg:text-4xl">
                Nhận tư vấn miễn phí & ưu tiên dùng thử SilentGuard tại nhà
              </h2>
              <p className="mb-8 max-w-[42ch] text-ink-soft">
                Đội ngũ của chúng tôi sẽ liên hệ trong 24 giờ để tư vấn vị trí lắp đặt camera
                phù hợp với không gian sống của gia đình bạn.
              </p>
              <ul className="space-y-3 text-sm text-ink">
                {[
                  "Khảo sát & tư vấn vị trí lắp đặt miễn phí",
                  "Ưu tiên nhận thiết bị trong đợt mở bán đầu tiên",
                  "Hỗ trợ cài đặt qua video call tận tình",
                ].map((b) => (
                  <li key={b} className="flex items-center gap-3">
                    <span className="size-1.5 rounded-full bg-brand shadow-[0_0_10px_var(--brand)]" />
                    {b}
                  </li>
                ))}
              </ul>
            </div>

            <form
              onSubmit={(e) => {
                e.preventDefault();
                setLoading(true);
                // Simulate an API call with 1.2s timeout
                setTimeout(() => {
                  setLoading(false);
                  setSubmitted(true);
                }, 1200);
              }}
              className="space-y-4 rounded-2xl bg-surface-2 p-6 ring-1 ring-border md:p-8"
            >
              {submitted ? (
                <div className="flex flex-col items-center gap-3 py-10 text-center">
                  <div className="grid size-12 place-items-center rounded-full bg-brand-light text-brand">
                    <ShieldCheck className="size-6" />
                  </div>
                  <p className="font-semibold text-lg text-emerald-800">Cảm ơn bạn đã đăng ký thành công!</p>
                  <p className="text-sm text-ink-soft">
                    Đội ngũ chăm sóc khách hàng SilentGuard sẽ chủ động liên hệ tới số điện thoại của bạn trong vòng 24 giờ để tư vấn chi tiết.
                  </p>
                </div>
              ) : (
                <>
                  <div className="space-y-1.5">
                    <label className="text-xs font-medium uppercase tracking-wider text-ink-soft">
                      Họ và tên
                    </label>
                    <input
                      required
                      type="text"
                      disabled={loading}
                      placeholder="Nguyễn Văn A"
                      className="w-full rounded-xl bg-surface px-4 py-3 text-sm ring-1 ring-border outline-none transition-all focus:ring-brand disabled:opacity-55"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-xs font-medium uppercase tracking-wider text-ink-soft">
                      Số điện thoại
                    </label>
                    <input
                      required
                      type="tel"
                      disabled={loading}
                      placeholder="09xx xxx xxx"
                      className="w-full rounded-xl bg-surface px-4 py-3 text-sm ring-1 ring-border outline-none transition-all focus:ring-brand disabled:opacity-55"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-xs font-medium uppercase tracking-wider text-ink-soft">
                      Thành phố
                    </label>
                    <input
                      type="text"
                      disabled={loading}
                      placeholder="Hà Nội / TP. HCM / …"
                      className="w-full rounded-xl bg-surface px-4 py-3 text-sm ring-1 ring-border outline-none transition-all focus:ring-brand disabled:opacity-55"
                    />
                  </div>
                  <button
                    type="submit"
                    disabled={loading}
                    className="mt-2 w-full rounded-full bg-brand px-6 py-3 text-sm font-medium text-brand-foreground shadow-soft ring-1 ring-brand transition-all hover:scale-[1.01] hover:shadow-glow disabled:cursor-not-allowed disabled:opacity-50 flex items-center justify-center gap-2"
                  >
                    {loading ? (
                      <>
                        <Loader2 className="size-4 animate-spin" />
                        Đang kết nối hệ thống...
                      </>
                    ) : (
                      "Đăng ký nhận tư vấn"
                    )}
                  </button>
                  <p className="text-center text-xs text-ink-soft">
                    Thông tin của bạn được bảo mật theo chính sách riêng tư.
                  </p>
                </>
              )}
            </form>
          </div>
        </motion.div>
      </div>
    </Section>
  );
}

function AppDownload() {
  const [isAndroidModalOpen, setIsAndroidModalOpen] = useState(false);
  const [isIosModalOpen, setIsIosModalOpen] = useState(false);

  return (
    <Section className="pb-24">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          variants={fadeUp}
          className="relative overflow-hidden rounded-3xl bg-ink p-8 text-background ring-1 ring-white/10 md:p-14"
        >
          <div
            aria-hidden
            className="pointer-events-none absolute -left-24 top-0 size-72 rounded-full bg-brand/30 blur-3xl"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute -right-16 -bottom-24 size-80 rounded-full bg-brand-glow/20 blur-3xl"
          />

          <div className="relative grid items-center gap-10 md:grid-cols-[1.1fr_0.9fr]">
            <div>
              <span className="mb-4 inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-wider text-brand-glow backdrop-blur">
                <Bell className="size-3.5" /> Ứng dụng SilentGuard
              </span>
              <h2 className="mb-4 text-balance text-3xl font-semibold leading-tight lg:text-4xl">
                Mang sự an tâm theo bạn — mọi lúc, mọi nơi.
              </h2>
              <p className="mb-8 max-w-[46ch] text-pretty text-background/75">
                Nhận cảnh báo tức thì, xem ảnh hiện trường, gọi hỗ trợ cho cha mẹ
                chỉ trong một chạm. Ứng dụng nhẹ, hoạt động ổn định cả khi mạng yếu.
              </p>

              <div className="flex flex-wrap gap-3">
                <button
                  type="button"
                  onClick={() => setIsIosModalOpen(true)}
                  className="inline-flex w-full sm:w-[200px] justify-center items-center gap-3 rounded-2xl bg-background px-5 py-3 text-ink ring-1 ring-white/10 transition-all hover:scale-[1.02] cursor-pointer"
                >
                  <svg viewBox="0 0 24 24" className="size-6 shrink-0" fill="currentColor" aria-hidden>
                    <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/>
                  </svg>
                  <div className="text-left leading-tight w-full flex flex-col items-start">
                    <div className="text-[10px] uppercase tracking-wider text-ink-soft">Tải về bản</div>
                    <div className="text-sm font-semibold">iOS (.IPA)</div>
                  </div>
                </button>
                <button
                  type="button"
                  onClick={() => setIsAndroidModalOpen(true)}
                  className="inline-flex w-full sm:w-[200px] justify-center items-center gap-3 rounded-2xl bg-background px-5 py-3 text-ink ring-1 ring-white/10 transition-all hover:scale-[1.02] cursor-pointer"
                >
                  <svg viewBox="0 0 28.99 31.99" className="size-6 shrink-0" aria-hidden>
                    <g fillRule="nonzero">
                      <path d="M13.54 15.28.12 29.34a3.66 3.66 0 0 0 5.33 2.16l15.1-8.6Z" fill="#ea4335" />
                      <path d="m27.11 12.89-6.53-3.74-7.35 6.45 7.38 7.28 6.48-3.7a3.54 3.54 0 0 0 1.5-4.79 3.62 3.62 0 0 0-1.5-1.5z" fill="#fbbc04" />
                      <path d="M.12 2.66a3.57 3.57 0 0 0-.12.92v24.84a3.57 3.57 0 0 0 .12.92L14 15.64Z" fill="#4285f4" />
                      <path d="m13.64 16 6.94-6.85L5.5.51A3.73 3.73 0 0 0 3.63 0 3.64 3.64 0 0 0 .12 2.65Z" fill="#34a853" />
                    </g>
                  </svg>
                  <div className="text-left leading-tight w-full flex flex-col items-start">
                    <div className="text-[10px] uppercase tracking-wider text-ink-soft">Tải về bản</div>
                    <div className="text-sm font-semibold">Android (.APK)</div>
                  </div>
                </button>
              </div>

              <div className="mt-8 flex flex-wrap items-center gap-6 text-xs text-background/60">
                <div className="flex items-center gap-2">
                  <ShieldCheck className="size-4 text-brand-glow" />
                  <span>Sản phẩm được các điều dưỡng tin dùng</span>
                </div>
                <div className="flex items-center gap-2">
                  <Wifi className="size-3.5 text-brand-glow" />
                  <span>Hoạt động cả khi mạng 3G</span>
                </div>
              </div>
            </div>

            <div className="relative flex justify-center md:justify-end">
              <motion.div
                whileHover={{ y: -4, rotate: -2 }}
                transition={{ type: "spring", stiffness: 200, damping: 18 }}
                className="relative w-52 overflow-hidden rounded-[2rem] bg-surface p-2 shadow-glow ring-1 ring-white/20 md:w-60"
              >
                <img
                  src={appScreenImg}
                  alt="Giao diện ứng dụng SilentGuard"
                  width={400}
                  height={600}
                  className="aspect-[9/16] w-full rounded-[1.6rem] object-cover"
                  loading="lazy"
                />
              </motion.div>
            </div>
          </div>
        </motion.div>
      </div>

      <AnimatePresence>
        {isAndroidModalOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-md"
            onClick={() => setIsAndroidModalOpen(false)}
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              transition={{ type: "spring", duration: 0.5 }}
              className="relative w-full max-w-2xl overflow-hidden rounded-3xl bg-ink text-background p-6 md:p-8 ring-1 ring-white/20 shadow-2xl"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Glow Effects */}
              <div className="pointer-events-none absolute -left-20 -top-20 size-60 rounded-full bg-brand/20 blur-3xl" />
              <div className="pointer-events-none absolute -right-20 -bottom-20 size-60 rounded-full bg-brand-glow/10 blur-3xl" />

              {/* Close Button */}
              <button
                type="button"
                onClick={() => setIsAndroidModalOpen(false)}
                className="absolute right-4 top-4 rounded-full p-2 text-background/60 hover:bg-white/10 hover:text-background transition-colors cursor-pointer"
              >
                <X className="size-5" />
              </button>

              <div className="relative">
                <div className="mb-6">
                  <span className="mb-2 inline-flex items-center gap-1.5 rounded-full bg-brand/20 px-3 py-1 text-xs font-semibold uppercase tracking-wider text-brand-glow">
                    Tải xuống APK
                  </span>
                  <h3 className="text-2xl font-bold">Chọn phiên bản Android phù hợp</h3>
                  <p className="text-sm text-background/60 mt-1">
                    Ứng dụng SilentGuard hỗ trợ các kiến trúc chip Android khác nhau để tối ưu hóa hiệu năng và tương thích tốt nhất.
                  </p>
                </div>

                <div className="space-y-4">
                  {/* Version 1: ARM64-v8a */}
                  <div className="relative overflow-hidden rounded-2xl bg-white/5 p-5 ring-1 ring-brand/35 hover:bg-white/10 transition-all">
                    <div className="absolute right-3 top-3">
                      <span className="rounded-full bg-brand px-2.5 py-0.5 text-[10px] font-semibold text-white uppercase tracking-wider shadow-[0_0_10px_var(--brand)]">
                        Khuyên dùng
                      </span>
                    </div>
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                      <div>
                        <h4 className="text-base font-semibold text-brand-glow flex items-center gap-2">
                          Cấu trúc ARM64-v8a (64-bit)
                        </h4>
                        <p className="text-xs text-background/70 mt-1 max-w-[48ch]">
                          <strong>Thiết bị phù hợp:</strong> Hầu hết điện thoại Android hiện nay (đời mới từ khoảng 2017 trở lại đây). Đây là bản phổ biến nhất chạy trên các máy tầm trung đến cao cấp.
                        </p>
                        <span className="inline-block mt-2 text-[11px] text-background/50 font-mono">
                          File: app-arm64-v8a-release.apk
                        </span>
                      </div>
                      <a
                        href="/downloads/app-arm64-v8a-release.apk"
                        download
                        className="flex items-center justify-center gap-2 rounded-xl bg-brand hover:bg-brand-glow text-white px-4 py-2.5 text-sm font-semibold transition-all self-start md:self-auto shadow-md"
                      >
                        <Download className="size-4" /> Tải xuống
                      </a>
                    </div>
                  </div>

                  {/* Version 2: ARMEABI-v7a */}
                  <div className="relative overflow-hidden rounded-2xl bg-white/5 p-5 ring-1 ring-white/10 hover:bg-white/10 transition-all">
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                      <div>
                        <h4 className="text-base font-semibold text-background flex items-center gap-2">
                          Cấu trúc ARMEABI-v7a (32-bit)
                        </h4>
                        <p className="text-xs text-background/70 mt-1 max-w-[48ch]">
                          <strong>Thiết bị phù hợp:</strong> Các dòng điện thoại Android đời cũ, máy cấu hình thấp, smartwatch, tivi. Bản này có thể tương thích ngược trên cả máy 64-bit.
                        </p>
                        <span className="inline-block mt-2 text-[11px] text-background/50 font-mono">
                          File: app-armeabi-v7a-release.apk
                        </span>
                      </div>
                      <a
                        href="/downloads/app-armeabi-v7a-release.apk"
                        download
                        className="flex items-center justify-center gap-2 rounded-xl bg-white/10 hover:bg-white/20 text-white px-4 py-2.5 text-sm font-semibold transition-all self-start md:self-auto"
                      >
                        <Download className="size-4" /> Tải xuống
                      </a>
                    </div>
                  </div>

                  {/* Version 3: x86_64 */}
                  <div className="relative overflow-hidden rounded-2xl bg-white/5 p-5 ring-1 ring-white/10 hover:bg-white/10 transition-all">
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                      <div>
                        <h4 className="text-base font-semibold text-background flex items-center gap-2">
                          Cấu trúc x86_64 (64-bit)
                        </h4>
                        <p className="text-xs text-background/70 mt-1 max-w-[48ch]">
                          <strong>Thiết bị phù hợp:</strong> Trình giả lập (Emulator) trên máy tính (như LDPlayer, Bluestacks, NoxPlayer hoặc Android Studio Emulator chạy trên chip Intel/AMD).
                        </p>
                        <span className="inline-block mt-2 text-[11px] text-background/50 font-mono">
                          File: app-x86_64-release.apk
                        </span>
                      </div>
                      <a
                        href="/downloads/app-x86_64-release.apk"
                        download
                        className="flex items-center justify-center gap-2 rounded-xl bg-white/10 hover:bg-white/20 text-white px-4 py-2.5 text-sm font-semibold transition-all self-start md:self-auto"
                      >
                        <Download className="size-4" /> Tải xuống
                      </a>
                    </div>
                  </div>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {isIosModalOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-md overflow-y-auto"
            onClick={() => setIsIosModalOpen(false)}
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              transition={{ type: "spring", duration: 0.5 }}
              className="relative w-full max-w-2xl my-8 overflow-hidden rounded-3xl bg-ink text-background p-6 md:p-8 ring-1 ring-white/20 shadow-2xl"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Glow Effects */}
              <div className="pointer-events-none absolute -left-20 -top-20 size-60 rounded-full bg-brand/20 blur-3xl" />
              <div className="pointer-events-none absolute -right-20 -bottom-20 size-60 rounded-full bg-brand-glow/10 blur-3xl" />

              {/* Close Button */}
              <button
                type="button"
                onClick={() => setIsIosModalOpen(false)}
                className="absolute right-4 top-4 rounded-full p-2 text-background/60 hover:bg-white/10 hover:text-background transition-colors cursor-pointer z-20 bg-white/5 border border-white/10"
              >
                <X className="size-5" />
              </button>

              <div className="relative pt-6">
                <div className="mb-6 pr-12">
                  <span className="mb-2 inline-flex items-center gap-1.5 rounded-full bg-brand/20 px-3 py-1 text-xs font-semibold uppercase tracking-wider text-brand-glow">
                    Hướng dẫn cài đặt
                  </span>
                  <h3 className="text-2xl font-bold">Cài đặt App iOS bằng Sideloadly</h3>
                  <p className="text-sm text-background/60 mt-1">
                    Hướng dẫn cách cài file .ipa lên iPhone/iPad cho mục đích thử nghiệm nội bộ và demo nhanh.
                  </p>
                </div>

                <div className="relative max-h-[60vh] overflow-y-auto pr-4 custom-scrollbar">

                <div className="space-y-6 text-sm text-background/90">
                  {/* Step 1 */}
                  <div className="flex gap-4">
                    <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-brand/20 text-brand-glow font-bold text-xs">
                      1
                    </div>
                    <div>
                      <h4 className="font-semibold text-white mb-1">Yêu cầu chuẩn bị</h4>
                      <ul className="list-disc pl-5 space-y-1 text-background/70">
                        <li>Một máy tính Windows hoặc macOS.</li>
                        <li>Một chiếc iPhone/iPad để cài đặt app.</li>
                        <li>Cáp USB kết nối thiết bị với máy tính.</li>
                        <li>
                          File ứng dụng dạng{" "}
                          <a
                            href="/downloads/Runner.ipa"
                            download
                            className="text-brand-glow hover:underline inline-flex items-center gap-0.5"
                          >
                            SilentGuard.ipa <Download className="size-3" />
                          </a>
                        </li>
                      </ul>
                    </div>
                  </div>

                  {/* Step 2 */}
                  <div className="flex gap-4">
                    <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-brand/20 text-brand-glow font-bold text-xs">
                      2
                    </div>
                    <div>
                      <h4 className="font-semibold text-white mb-1">Cài đặt công cụ cần thiết</h4>
                      <p className="text-background/70 mb-2">
                        Nếu dùng hệ điều hành Windows, bạn cần tải và cài đặt trước 3 công cụ sau (chỉ cần mở ứng dụng Sideloadly để sử dụng):
                      </p>
                      <div className="flex flex-wrap gap-2">
                        <a
                          href="https://sideloadly.io/"
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1.5 rounded-lg bg-white/10 hover:bg-white/20 px-3 py-1.5 text-xs text-white transition-colors"
                        >
                          <Laptop className="size-3.5" /> Tải Sideloadly
                        </a>
                      </div>
                    </div>
                  </div>

                  {/* Step 3 */}
                  <div className="flex gap-4">
                    <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-brand/20 text-brand-glow font-bold text-xs">
                      3
                    </div>
                    <div>
                      <h4 className="font-semibold text-white mb-1">Chuẩn bị iPhone</h4>
                      <p className="text-background/70">
                        Kết nối iPhone với máy tính bằng cáp USB. Nếu điện thoại hiển thị thông báo <strong>"Trust This Computer?" (Tin cậy máy tính này?)</strong>, hãy chọn <strong>"Trust" (Tin cậy)</strong> và nhập passcode của máy.
                      </p>
                    </div>
                  </div>

                  {/* Step 4 */}
                  <div className="flex gap-4">
                    <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-brand/20 text-brand-glow font-bold text-xs">
                      4
                    </div>
                    <div>
                      <h4 className="font-semibold text-white mb-1">Cài đặt bằng Sideloadly</h4>
                      <ul className="list-decimal pl-5 space-y-1 text-background/70">
                        <li>Mở phần mềm <strong>Sideloadly</strong> trên máy tính.</li>
                        <li>Ở mục <strong>Device</strong>: Chọn chính xác iPhone của bạn đang kết nối.</li>
                        <li>Ở mục <strong>IPA</strong>: Kéo thả file <code>SilentGuard.ipa</code> đã tải vào hoặc click vào icon để chọn file.</li>
                        <li>Ở mục <strong>Apple Account</strong>: Nhập tài khoản Apple ID của bạn để thực hiện ký số.</li>
                        <li>Click nút <strong>Start</strong>. Phần mềm sẽ yêu cầu bạn nhập mật khẩu Apple ID để tiến hành cài đặt.</li>
                      </ul>
                    </div>
                  </div>

                  {/* Step 5 */}
                  <div className="flex gap-4">
                    <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-brand/20 text-brand-glow font-bold text-xs">
                      5
                    </div>
                    <div>
                      <h4 className="font-semibold text-white mb-1">Cấu hình Tin cậy (Trust Developer) trên iPhone</h4>
                      <p className="text-background/70 mb-3">
                        Sau khi cài đặt xong, nếu mở app báo lỗi <strong>"Untrusted Developer"</strong>, hãy thao tác trên iPhone:
                      </p>
                      <div className="rounded-xl bg-white/5 p-4 border border-white/10 space-y-2 text-xs text-background/80">
                        <div className="flex items-center gap-2">
                          <Settings className="size-4 text-brand-glow" />
                          <span>Cài đặt (Settings) &rarr; Cài đặt chung (General) &rarr; Quản lý VPN & Thiết bị (VPN & Device Management)</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Key className="size-4 text-brand-glow" />
                          <span>Chọn tài khoản Apple ID của bạn &rarr; Chọn <strong>Trust (Tin cậy)</strong></span>
                        </div>
                        <div className="mt-2 pt-2 border-t border-white/10 flex items-start gap-2 text-brand-glow">
                          <Info className="size-4 shrink-0 mt-0.5" />
                          <span>
                            <strong>Lưu ý iOS 16+:</strong> Nếu ứng dụng yêu cầu Bật chế độ nhà phát triển (Developer Mode), hãy vào <strong>Cài đặt &rarr; Quyền riêng tư & Bảo mật &rarr; Chế độ nhà phát triển</strong>, gạt Bật và khởi động lại iPhone.
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div> {/* Đóng space-y-6 */}
              </div> {/* Đóng custom-scrollbar scroll area */}
            </div> {/* Đóng relative-pt-6 */}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </Section>
  );
}

function DemoCTA() {
  return (
    <Section className="py-24">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          variants={fadeUp}
          className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-brand to-brand-glow p-10 text-brand-foreground shadow-glow md:p-16"
        >
          <div
            aria-hidden
            className="pointer-events-none absolute -right-20 -top-20 size-80 rounded-full bg-white/20 blur-3xl"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute -bottom-24 -left-20 size-80 rounded-full bg-black/10 blur-3xl"
          />
          <div className="relative flex flex-col items-start gap-10 md:flex-row md:items-center md:justify-between">
            <div className="max-w-[42ch]">
              <span className="mb-4 inline-flex items-center gap-2 rounded-full bg-white/15 px-3 py-1 text-xs font-semibold uppercase tracking-wider backdrop-blur">
                <Sparkles className="size-3.5" /> Trải nghiệm AI ngay
              </span>
              <h2 className="text-balance text-3xl font-semibold leading-tight lg:text-4xl">
                Tải video lên — xem AI phát hiện té ngã trong vài giây
              </h2>
              <p className="mt-4 text-pretty text-brand-foreground/85">
                Trải nghiệm cùng mô hình thị giác mà SilentGuard dùng trong sản phẩm thật. Không
                cần đăng ký, không lưu trữ video của bạn.
              </p>
            </div>
            <Link
              to="/demo"
              className="inline-flex items-center gap-3 rounded-full bg-brand-foreground px-7 py-4 text-base font-medium text-brand shadow-soft transition-all hover:scale-[1.02]"
            >
              <PlayCircle className="size-5" /> Mở trang demo
            </Link>
          </div>
        </motion.div>
      </div>
    </Section>
  );
}

const FAQS = [
  {
    q: "Camera có lưu trữ hình ảnh trong nhà không?",
    a: "Không. SilentGuard xử lý hình ảnh trực tiếp trên camera và chỉ gửi ảnh tĩnh hiện trường khi phát hiện sự cố. Chúng tôi không quay video liên tục về máy chủ.",
  },
  {
    q: "AI có nhầm khi người thân ngồi xuống hoặc nằm xuống không?",
    a: "Mô hình được huấn luyện để phân biệt cú ngã thật (mất thăng bằng đột ngột + nằm bất động) với các hành động bình thường như ngồi xuống ghế, nằm nghỉ hay cúi nhặt đồ.",
  },
  {
    q: "Nếu mất điện hoặc mất Wi-Fi thì sao?",
    a: "Camera có pin dự phòng 4 giờ và hỗ trợ kết nối 4G qua eSIM (tuỳ chọn). Khi kết nối phục hồi, các cảnh báo sẽ được gửi lại tự động.",
  },
  {
    q: "Bao nhiêu người trong gia đình cùng nhận được cảnh báo?",
    a: "Không giới hạn. Anh chị em, con cháu, người giúp việc đều có thể cùng cài app và nhận cảnh báo đồng thời qua đẩy thông báo, gọi điện và SMS.",
  },
  {
    q: "Có cần thợ kỹ thuật đến lắp đặt không?",
    a: "Không. Bạn chỉ cần cắm điện, quét mã QR trên camera và làm theo hướng dẫn 5 bước trong app. Chúng tôi cũng hỗ trợ cài đặt qua video call miễn phí.",
  },
];

function FAQ() {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <Section id="faq" className="bg-surface-2 py-24">
      <div className="mx-auto max-w-3xl px-6">
        <motion.div variants={fadeUp} className="mb-12 text-center">
          <span className="mb-4 inline-block text-xs font-semibold uppercase tracking-widest text-brand">
            Hỏi đáp
          </span>
          <h2 className="text-balance text-3xl font-semibold lg:text-4xl">
            Mọi điều bạn muốn hỏi trước khi đặt mua
          </h2>
        </motion.div>

        <div className="space-y-3">
          {FAQS.map((f, i) => {
            const isOpen = open === i;
            return (
              <motion.div
                key={f.q}
                variants={fadeUp}
                className="overflow-hidden rounded-2xl bg-surface ring-1 ring-border"
              >
                <button
                  onClick={() => setOpen(isOpen ? null : i)}
                  className="flex w-full items-center justify-between gap-4 px-6 py-5 text-left"
                  aria-expanded={isOpen}
                >
                  <span className="font-medium">{f.q}</span>
                  <ChevronDown
                    className={`size-5 shrink-0 text-ink-soft transition-transform ${isOpen ? "rotate-180 text-brand" : ""}`}
                  />
                </button>
                <motion.div
                  initial={false}
                  animate={{ height: isOpen ? "auto" : 0, opacity: isOpen ? 1 : 0 }}
                  transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                  className="overflow-hidden"
                >
                  <p className="px-6 pb-5 text-sm leading-relaxed text-ink-soft">{f.a}</p>
                </motion.div>
              </motion.div>
            );
          })}
        </div>
      </div>
    </Section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-border py-12">
      <div className="mx-auto max-w-6xl px-6">
        <div className="flex flex-col items-start justify-between gap-12 md:flex-row">
          <div>
            <div className="mb-6 flex items-center gap-2">
              <img src={logoAsset} alt="SilentGuard" width={24} height={24} className="size-6 object-cover rounded-full mix-blend-multiply" />
              <span className="font-semibold tracking-tight">SilentGuard</span>
            </div>
            <p className="max-w-[32ch] text-sm text-ink-soft">
              Giải pháp công nghệ hỗ trợ chăm sóc sức khỏe người cao tuổi tại Việt Nam.
            </p>
          </div>
          <div className="flex gap-16">
            <div className="space-y-4">
              <h5 className="text-xs font-semibold uppercase tracking-widest text-ink-soft">
                Liên hệ
              </h5>
              <ul className="space-y-2 text-sm text-ink">
                <li>Hotline: 0347838309</li>
                <li>vinhv304@gmail.com</li>
              </ul>
            </div>
            <div className="space-y-4">
              <h5 className="text-xs font-semibold uppercase tracking-widest text-ink-soft">
                Pháp lý
              </h5>
              <ul className="space-y-2 text-sm text-ink">
                <li><Link to="/privacy" className="hover:text-brand">Bảo mật</Link></li>
                <li><Link to="/faq" className="hover:text-brand">Hỏi đáp</Link></li>
              </ul>
            </div>
          </div>
        </div>
        <div className="mt-12 border-t border-border pt-8">
          <p className="text-xs text-ink-soft">© 2026 SilentGuard. Bảo vệ bằng sự thấu hiểu.</p>
        </div>
      </div>
    </footer>
  );
}

function BackToTop() {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const toggleVisibility = () => {
      if (window.scrollY > 400) {
        setIsVisible(true);
      } else {
        setIsVisible(false);
      }
    };

    window.addEventListener("scroll", toggleVisibility);
    return () => window.removeEventListener("scroll", toggleVisibility);
  }, []);

  const scrollToTop = () => {
    window.scrollTo({
      top: 0,
      behavior: "smooth",
    });
  };

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.button
          initial={{ opacity: 0, scale: 0.8, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.8, y: 20 }}
          onClick={scrollToTop}
          className="fixed bottom-6 right-6 z-40 flex size-12 cursor-pointer items-center justify-center rounded-full bg-brand text-white shadow-glow ring-1 ring-white/10 transition-all hover:bg-brand-glow hover:scale-110 active:scale-95"
          aria-label="Cuộn về đầu trang"
        >
          <ArrowUp className="size-5" />
        </motion.button>
      )}
    </AnimatePresence>
  );
}

function Index() {
  return (
    <main className="min-h-screen bg-background text-foreground">
      <Nav />
      <Hero />
      <Introduction />
      <HowItWorks />
      <Features />
      <ProductGallery />
      <DemoCTA />
      <Stories />
      <FAQ />
      <Contact />
      <AppDownload />
      <Footer />
      <BackToTop />
    </main>
  );
}
