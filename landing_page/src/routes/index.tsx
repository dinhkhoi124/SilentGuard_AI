import { createFileRoute, Link } from "@tanstack/react-router";
import { motion, useScroll, useTransform, useReducedMotion } from "framer-motion";
import { useRef, useState } from "react";
import { Activity, Bell, Camera, ChevronDown, Eye, EyeOff, Moon, PlayCircle, ShieldCheck, Sparkles, Users, Wifi } from "lucide-react";

import { ClientOnly } from "@/components/ClientOnly";
import { Hero3D } from "@/components/Hero3D";
import lifestyleImg from "@/assets/lifestyle.jpg";
import appScreenImg from "@/assets/app-screen.jpg";
import logoAsset from "@/assets/silentguard-logo.png.asset.json";

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
            src={logoAsset.url}
            alt="SilentGuard"
            width={28}
            height={28}
            className="size-7 object-contain"
          />
          <span className="font-semibold tracking-tight">SilentGuard</span>
        </a>
        <div className="hidden items-center gap-8 text-sm text-ink-soft md:flex">
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

      <div className="mx-auto max-w-6xl px-6 py-20 lg:py-32">
        <div className="grid items-center gap-16 lg:grid-cols-[1.05fr_0.95fr]">
          <motion.div style={{ y, scale, opacity }} className="relative">
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
              className="mt-12 grid max-w-md grid-cols-3 gap-4 text-sm"
            >
              {[
                { k: "<3s", v: "Phát hiện" },
                { k: "99.4%", v: "Độ chính xác" },
                { k: "24/7", v: "Quan sát liên tục" },
              ].map((s) => (
                <div key={s.v}>
                  <div className="text-2xl font-semibold text-brand">{s.k}</div>
                  <div className="text-xs text-ink-soft">{s.v}</div>
                </div>
              ))}
            </motion.div>
          </motion.div>

          {/* 3D Scene */}
          <div className="relative">
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

function Contact() {
  const [submitted, setSubmitted] = useState(false);
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
                setSubmitted(true);
              }}
              className="space-y-4 rounded-2xl bg-surface-2 p-6 ring-1 ring-border md:p-8"
            >
              {submitted ? (
                <div className="flex flex-col items-center gap-3 py-10 text-center">
                  <div className="grid size-12 place-items-center rounded-full bg-brand-light text-brand">
                    <ShieldCheck className="size-6" />
                  </div>
                  <p className="font-semibold">Cảm ơn bạn đã đăng ký!</p>
                  <p className="text-sm text-ink-soft">
                    Chúng tôi sẽ liên hệ trong vòng 24 giờ.
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
                      placeholder="Nguyễn Văn A"
                      className="w-full rounded-xl bg-surface px-4 py-3 text-sm ring-1 ring-border outline-none transition-all focus:ring-brand"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-xs font-medium uppercase tracking-wider text-ink-soft">
                      Số điện thoại
                    </label>
                    <input
                      required
                      type="tel"
                      placeholder="09xx xxx xxx"
                      className="w-full rounded-xl bg-surface px-4 py-3 text-sm ring-1 ring-border outline-none transition-all focus:ring-brand"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-xs font-medium uppercase tracking-wider text-ink-soft">
                      Thành phố
                    </label>
                    <input
                      type="text"
                      placeholder="Hà Nội / TP. HCM / …"
                      className="w-full rounded-xl bg-surface px-4 py-3 text-sm ring-1 ring-border outline-none transition-all focus:ring-brand"
                    />
                  </div>
                  <button
                    type="submit"
                    className="mt-2 w-full rounded-full bg-brand px-6 py-3 text-sm font-medium text-brand-foreground shadow-soft ring-1 ring-brand transition-all hover:scale-[1.01] hover:shadow-glow"
                  >
                    Đăng ký nhận tư vấn
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
                <a
                  href="#"
                  className="inline-flex items-center gap-3 rounded-2xl bg-background px-5 py-3 text-ink ring-1 ring-white/10 transition-all hover:scale-[1.02]"
                >
                  <svg viewBox="0 0 24 24" className="size-6" fill="currentColor" aria-hidden>
                    <path d="M16.365 1.43c0 1.14-.42 2.22-1.16 3.04-.79.87-2.07 1.55-3.12 1.47-.13-1.09.43-2.24 1.13-3.02.78-.87 2.13-1.52 3.15-1.49zM20.5 17.05c-.55 1.27-.82 1.83-1.53 2.95-1 1.56-2.4 3.51-4.14 3.52-1.55.01-1.95-1.01-4.05-1-2.1.01-2.54 1.02-4.09 1.01-1.74-.01-3.07-1.77-4.07-3.33C-.04 16.69-.36 11.43 1.84 8.62c1.55-1.99 4-3.16 6.31-3.16 2.34 0 3.82 1.28 5.76 1.28 1.88 0 3.03-1.28 5.74-1.28 2.05.01 4.22 1.12 5.77 3.06-5.07 2.78-4.24 10.03.08 11.53z" />
                  </svg>
                  <div className="text-left leading-tight">
                    <div className="text-[10px] uppercase tracking-wider text-ink-soft">Tải về trên</div>
                    <div className="text-sm font-semibold">App Store</div>
                  </div>
                </a>
                <a
                  href="#"
                  className="inline-flex items-center gap-3 rounded-2xl bg-background px-5 py-3 text-ink ring-1 ring-white/10 transition-all hover:scale-[1.02]"
                >
                  <svg viewBox="0 0 24 24" className="size-6" aria-hidden>
                    <path fill="#34A853" d="M3.6 2.3c-.4.4-.6 1-.6 1.8v15.8c0 .8.2 1.4.6 1.8l11.6-11.6L3.6 2.3z" opacity=".0" />
                    <path fill="currentColor" d="M3.6 2.3c-.4.4-.6 1-.6 1.8v15.8c0 .8.2 1.4.6 1.8l9-9-9-10.4zM16.6 9.7L4.2 2.2c-.3-.2-.5-.2-.7-.1l9.1 10.4 4-2.8zM20.5 11.3l-3.9-2.3-4.2 3 4.2 3 3.9-2.3c1.1-.7 1.1-1.7 0-2.4zM3.5 21.9c.2.1.5.1.7-.1l12.4-7.5-4-3-9.1 10.6z" />
                  </svg>
                  <div className="text-left leading-tight">
                    <div className="text-[10px] uppercase tracking-wider text-ink-soft">Tải về trên</div>
                    <div className="text-sm font-semibold">Google Play</div>
                  </div>
                </a>
              </div>

              <div className="mt-8 flex flex-wrap items-center gap-6 text-xs text-background/60">
                <div className="flex items-center gap-2">
                  <span className="text-brand-glow">★★★★★</span>
                  <span>4.9 / 5 · 1.200+ đánh giá</span>
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
              <img src={logoAsset.url} alt="SilentGuard" width={24} height={24} className="size-6 object-contain" />
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
                <li>Hotline: 1900 68XX</li>
                <li>hello@silentguard.vn</li>
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

function Index() {
  return (
    <main className="min-h-screen bg-background text-foreground">
      <Nav />
      <Hero />
      <HowItWorks />
      <Features />
      <DemoCTA />
      <Stories />
      <FAQ />
      <Contact />
      <AppDownload />
      <Footer />
    </main>
  );
}
