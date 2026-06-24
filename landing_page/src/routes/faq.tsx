import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ArrowLeft, ChevronDown, HelpCircle, Package, Settings, ShieldCheck, Wrench } from "lucide-react";

export const Route = createFileRoute("/faq")({
  head: () => ({
    meta: [
      { title: "Câu hỏi thường gặp — SilentGuard" },
      {
        name: "description",
        content:
          "Mọi điều bạn muốn biết về SilentGuard: cách hệ thống phát hiện té ngã, quyền riêng tư, lắp đặt, và hỗ trợ.",
      },
      { property: "og:title", content: "Câu hỏi thường gặp — SilentGuard" },
      {
        property: "og:description",
        content: "Câu trả lời rõ ràng cho mọi câu hỏi về camera AI phát hiện té ngã.",
      },
    ],
  }),
  component: FAQPage,
});

type Lang = "vi" | "en";

function FAQPage() {
  const [lang, setLang] = useState<Lang>("vi");
  const groups = lang === "vi" ? GROUPS_VI : GROUPS_EN;
  const labels = lang === "vi"
    ? { back: "Về trang chủ", badge: "Hỗ trợ", title: "Câu hỏi thường gặp", subtitle: "Mọi điều bạn muốn biết — trước khi mua, sau khi lắp đặt và trong khi sử dụng.", more: "Vẫn còn thắc mắc?", contact: "Liên hệ đội hỗ trợ" }
    : { back: "Back to home", badge: "Support", title: "Frequently Asked Questions", subtitle: "Everything you'd want to know — before buying, after installation, and during everyday use.", more: "Still have questions?", contact: "Contact support" };

  return (
    <main className="min-h-screen bg-background text-foreground">
      <nav className="sticky top-0 z-50 border-b border-border bg-background/70 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-6">
          <Link to="/" className="flex items-center gap-2 text-sm text-ink-soft hover:text-brand">
            <ArrowLeft className="size-4" /> {labels.back}
          </Link>
          <div className="flex items-center gap-1 rounded-full bg-surface-2 p-1 text-xs font-medium ring-1 ring-border">
            {(["vi", "en"] as const).map((l) => (
              <button
                key={l}
                onClick={() => setLang(l)}
                className={`rounded-full px-3 py-1 transition-colors ${
                  lang === l ? "bg-brand text-brand-foreground" : "text-ink-soft hover:text-ink"
                }`}
              >
                {l === "vi" ? "Tiếng Việt" : "English"}
              </button>
            ))}
          </div>
        </div>
      </nav>

      <section className="mx-auto max-w-3xl px-6 py-16">
        <header className="mb-12 text-center">
          <span className="mb-4 inline-flex items-center gap-2 rounded-full bg-brand-light px-3 py-1 text-xs font-semibold uppercase tracking-wider text-brand">
            <HelpCircle className="size-3.5" /> {labels.badge}
          </span>
          <h1 className="text-balance text-4xl font-semibold leading-tight lg:text-5xl">{labels.title}</h1>
          <p className="mx-auto mt-4 max-w-[52ch] text-pretty text-ink-soft">{labels.subtitle}</p>
        </header>

        <div className="space-y-12">
          {groups.map((g) => (
            <FAQGroup key={g.title} group={g} />
          ))}
        </div>

        <div className="mt-16 rounded-3xl bg-surface p-8 text-center ring-1 ring-border shadow-soft">
          <h3 className="mb-2 text-xl font-semibold">{labels.more}</h3>
          <p className="mb-5 text-sm text-ink-soft">hello@silentguard.vn · 1900 68XX</p>
          <a
            href="mailto:hello@silentguard.vn"
            className="inline-flex items-center gap-2 rounded-full bg-brand px-6 py-3 text-sm font-medium text-brand-foreground shadow-soft ring-1 ring-brand transition-all hover:shadow-glow"
          >
            {labels.contact}
          </a>
        </div>
      </section>
    </main>
  );
}

type Item = { q: string; a: string };
type Group = { title: string; icon: React.ComponentType<{ className?: string }>; items: Item[] };

function FAQGroup({ group }: { group: Group }) {
  const [open, setOpen] = useState<number | null>(0);
  const Icon = group.icon;
  return (
    <div>
      <div className="mb-5 flex items-center gap-3">
        <div className="grid size-10 place-items-center rounded-2xl bg-brand-light text-brand">
          <Icon className="size-5" />
        </div>
        <h2 className="text-xl font-semibold">{group.title}</h2>
      </div>
      <div className="space-y-3">
        {group.items.map((it, i) => {
          const isOpen = open === i;
          return (
            <div key={it.q} className="overflow-hidden rounded-2xl bg-surface ring-1 ring-border">
              <button
                onClick={() => setOpen(isOpen ? null : i)}
                aria-expanded={isOpen}
                className="flex w-full items-center justify-between gap-4 px-6 py-5 text-left transition-colors hover:bg-surface-2"
              >
                <span className="font-medium">{it.q}</span>
                <ChevronDown
                  className={`size-5 shrink-0 text-ink-soft transition-transform ${isOpen ? "rotate-180 text-brand" : ""}`}
                />
              </button>
              <AnimatePresence initial={false}>
                {isOpen && (
                  <motion.div
                    key="body"
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: "auto", opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                    className="overflow-hidden"
                  >
                    <p className="px-6 pb-5 text-sm leading-relaxed text-ink-soft">{it.a}</p>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ---------------- Vietnamese ----------------
const GROUPS_VI: Group[] = [
  {
    title: "Về sản phẩm",
    icon: Package,
    items: [
      {
        q: "SilentGuard là gì?",
        a: "SilentGuard là hệ thống giám sát an toàn cho người cao tuổi sống một mình. Camera AI tự động phát hiện khi bố/mẹ bị ngã và gửi cảnh báo đến điện thoại của bạn trong vòng dưới 60 giây — không cần người cao tuổi đeo thiết bị hay làm bất cứ điều gì.",
      },
      {
        q: "Hệ thống hoạt động như thế nào?",
        a: "Camera ghi lại hình ảnh và xử lý AI ngay tại thiết bị trong nhà. Khi phát hiện té ngã, hệ thống phân loại mức độ nghiêm trọng, cắt clip 20 giây quanh sự kiện, rồi gửi thông báo kèm clip đến ứng dụng của bạn. Toàn bộ quá trình diễn ra tự động, không cần kết nối cloud để xử lý.",
      },
      {
        q: "Tại sao chọn camera thay vì smartwatch hay thiết bị đeo?",
        a: "Thiết bị đeo yêu cầu người cao tuổi nhớ đeo, nhớ sạc — tỉ lệ tuân thủ thực tế rất thấp ở nhóm 70 tuổi trở lên. Camera hoạt động hoàn toàn thụ động: lắp một lần, không cần bố/mẹ làm gì cả. Ngoài ra, chúng tôi đang nghiên cứu tích hợp thêm wearable như một lớp bảo vệ bổ sung cho những không gian camera không thể cover (ví dụ: phòng tắm).",
      },
    ],
  },
  {
    title: "Về tính năng",
    icon: Settings,
    items: [
      {
        q: "Hệ thống phát hiện những gì?",
        a: "MVP V1 tập trung vào phát hiện té ngã — nguyên nhân chấn thương hàng đầu ở người cao tuổi. Hệ thống phân loại 4 mức độ: nhẹ (tự đứng dậy), cần kiểm tra, khẩn cấp, và nguy cấp.",
      },
      {
        q: "Nếu bố/mẹ chỉ ngồi xuống đột ngột hoặc cúi người — hệ thống có báo nhầm không?",
        a: "Đây là thách thức kỹ thuật chúng tôi đang tích cực giải quyết. Hệ thống sử dụng nhiều tín hiệu — góc cơ thể, tốc độ chuyển động, thời gian bất động sau đó — để phân biệt té ngã thật với chuyển động bình thường. Mục tiêu là tỉ lệ báo nhầm dưới 15%.",
      },
      {
        q: "Clip gửi về có thấy mặt bố/mẹ không?",
        a: "Mặt được làm mờ tự động trước khi clip rời khỏi thiết bị trong nhà. Bạn sẽ thấy rõ tình huống xảy ra nhưng không nhận diện được khuôn mặt. Nếu bạn muốn tùy chỉnh mức độ này, chúng tôi sẽ có tùy chọn trong phiên bản tiếp theo.",
      },
      {
        q: "Hệ thống có gọi điện tự động không?",
        a: "Có — nếu bạn không phản hồi thông báo trong vòng 3 phút khi mức độ HIGH hoặc CRITICAL, hệ thống sẽ tự động gọi điện cho bạn. Nếu vẫn không liên lạc được, sẽ gọi tiếp cho các liên hệ khẩn cấp theo thứ tự bạn đã cài đặt.",
      },
      {
        q: "Camera có hoạt động ban đêm không?",
        a: "Có. Chúng tôi khuyến nghị sử dụng camera IP có hỗ trợ night vision — hầu hết các dòng camera phổ biến hiện nay đều có tính năng này.",
      },
    ],
  },
  {
    title: "Về lắp đặt & chi phí",
    icon: Wrench,
    items: [
      {
        q: "Cần lắp bao nhiêu camera?",
        a: "Tùy diện tích và layout nhà. Thông thường, một căn hộ cần 2–3 camera (phòng ngủ, phòng khách, bếp). Mỗi bộ camera cần một thiết bị xử lý AI đặt trong nhà (khoảng bằng một hộp wifi nhỏ).",
      },
      {
        q: "Chi phí lắp đặt là bao nhiêu?",
        a: "Chi phí phần cứng (camera + thiết bị xử lý) ước tính 3–5 triệu đồng tùy số phòng. Phí dịch vụ hàng tháng đang được xác định dựa trên phản hồi từ giai đoạn khảo sát. Đăng ký để được thông báo sớm nhất khi có giá chính thức.",
      },
      {
        q: "Tôi có cần thợ kỹ thuật đến lắp không?",
        a: "Chúng tôi cung cấp hướng dẫn lắp đặt tự làm (DIY) và hỗ trợ từ xa. Với những gia đình muốn được lắp trực tiếp, chúng tôi sẽ có dịch vụ lắp đặt tại nhà ở TP.HCM và Hà Nội trong giai đoạn ra mắt.",
      },
    ],
  },
  {
    title: "Về quyền riêng tư",
    icon: ShieldCheck,
    items: [
      {
        q: "Video có được lưu trên cloud không?",
        a: "Không. Video thô không bao giờ rời khỏi thiết bị trong nhà. Chỉ clip ngắn đã làm mờ mặt và metadata sự kiện mới được gửi lên cloud khi có sự cố.",
      },
      {
        q: "Hệ thống có nhận diện khuôn mặt không?",
        a: "Không. SilentGuard không nhận diện, lưu trữ, hay xử lý danh tính của bất kỳ ai. Hệ thống chỉ phân tích chuyển động và tư thế cơ thể.",
      },
      {
        q: "Dữ liệu của tôi có được bán cho bên thứ ba không?",
        a: "Không bao giờ. Xem thêm Chính sách Quyền riêng tư đầy đủ của chúng tôi.",
      },
    ],
  },
  {
    title: "Về hỗ trợ",
    icon: HelpCircle,
    items: [
      {
        q: "Nếu camera hoặc thiết bị gặp sự cố thì sao?",
        a: "Ứng dụng sẽ cảnh báo ngay nếu camera mất kết nối hoặc thiết bị ngừng hoạt động hơn 5 phút. Đội hỗ trợ kỹ thuật sẵn sàng qua chat và hotline trong giờ hành chính.",
      },
      {
        q: "SilentGuard có thay thế dịch vụ cấp cứu không?",
        a: "Không. SilentGuard giúp gia đình biết sớm hơn và phản ứng nhanh hơn — nhưng không thay thế việc gọi 115 hoặc đưa người thân đến cơ sở y tế khi cần. Việc tích hợp trực tiếp với dịch vụ cấp cứu đang được nghiên cứu cho các phiên bản sau.",
      },
    ],
  },
];

// ---------------- English ----------------
const GROUPS_EN: Group[] = [
  {
    title: "About the Product",
    icon: Package,
    items: [
      {
        q: "What is SilentGuard?",
        a: "SilentGuard is a safety monitoring system for elderly people living alone. An AI-powered camera automatically detects falls and sends an alert to your phone within 60 seconds — no wearable device required, no action needed from your loved one.",
      },
      {
        q: "How does it work?",
        a: "The camera captures footage and runs AI inference directly on a local device inside the home. When a fall is detected, the system classifies its severity, extracts a 20-second clip around the event, and pushes a notification with the clip to your app. The entire process is automatic and does not require cloud processing.",
      },
      {
        q: "Why camera instead of a smartwatch or wearable?",
        a: "Wearable devices require the elderly person to remember to wear them and keep them charged — compliance rates are very low in the 70+ age group. A camera works entirely passively: install once, and your loved one doesn't need to do anything. We are also researching wearable integration as a supplemental layer for spaces cameras can't cover, such as bathrooms.",
      },
    ],
  },
  {
    title: "About Features",
    icon: Settings,
    items: [
      {
        q: "What does the system detect?",
        a: "MVP V1 focuses on fall detection — the leading cause of injury in older adults. The system classifies events into 4 severity levels: minor (self-recovery), needs checking, urgent, and critical.",
      },
      {
        q: "Will it trigger false alarms if someone sits down quickly or bends over?",
        a: "Minimizing false positives is one of our core engineering challenges. The system uses multiple signals — body angle, movement speed, and post-event stillness duration — to distinguish real falls from normal movements. Our target is a false positive rate below 15%.",
      },
      {
        q: "Will the clip show my parent's face?",
        a: "Faces are automatically blurred before the clip leaves the home device. You'll see clearly what happened without being able to identify the person's face. Options for customizing this will be available in a future version.",
      },
      {
        q: "Does the system make automatic phone calls?",
        a: "Yes — if you don't respond to a HIGH or CRITICAL alert within 3 minutes, the system will automatically call you. If still unreachable, it will contact your emergency contacts in the order you've configured.",
      },
      {
        q: "Does it work at night?",
        a: "Yes. We recommend IP cameras with night vision support, which is standard on most modern consumer cameras.",
      },
    ],
  },
  {
    title: "Installation & Pricing",
    icon: Wrench,
    items: [
      {
        q: "How many cameras do I need?",
        a: "It depends on your home's layout. A typical apartment needs 2–3 cameras (bedroom, living room, kitchen), plus one AI processing unit installed in the home (roughly the size of a small router).",
      },
      {
        q: "How much does it cost?",
        a: "Hardware (cameras + processing unit) is estimated at 3–5 million VND depending on the number of rooms. Monthly service pricing is being finalized based on survey feedback. Sign up to be notified as soon as official pricing is available.",
      },
      {
        q: "Do I need a technician to install it?",
        a: "We provide DIY installation guides and remote support. For families who prefer on-site installation, we will offer home installation services in Ho Chi Minh City and Hanoi at launch.",
      },
    ],
  },
  {
    title: "Privacy",
    icon: ShieldCheck,
    items: [
      {
        q: "Is video stored in the cloud?",
        a: "No. Raw video never leaves the home device. Only short anonymized clips and event metadata are sent to the cloud when an incident is detected.",
      },
      {
        q: "Does the system use facial recognition?",
        a: "No. SilentGuard does not identify, store, or process anyone's identity. The system only analyzes movement and body posture.",
      },
      {
        q: "Is my data sold to third parties?",
        a: "Never. See our full Privacy Policy for details.",
      },
    ],
  },
  {
    title: "Support",
    icon: HelpCircle,
    items: [
      {
        q: "What happens if the camera or device malfunctions?",
        a: "The app will immediately alert you if a camera loses connection or the device stops responding for more than 5 minutes. Technical support is available via in-app chat and hotline during business hours.",
      },
      {
        q: "Does SilentGuard replace emergency services?",
        a: "No. SilentGuard helps your family know sooner and respond faster — but it does not replace calling emergency services or taking your loved one to a medical facility when needed. Direct integration with emergency services is being researched for future versions.",
      },
    ],
  },
];
