import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";
import { ArrowLeft, Check, Lock, ShieldCheck, X } from "lucide-react";
import logoAsset from "@/assets/logo.png";

export const Route = createFileRoute("/privacy")({
  head: () => ({
    meta: [
      { title: "Chính sách Quyền riêng tư — SilentGuard" },
      {
        name: "description",
        content:
          "Cam kết quyền riêng tư của SilentGuard: video thô không bao giờ rời khỏi thiết bị trong nhà, không nhận diện khuôn mặt, không bán dữ liệu.",
      },
      { property: "og:title", content: "Chính sách Quyền riêng tư — SilentGuard" },
      {
        property: "og:description",
        content: "An toàn không đánh đổi quyền riêng tư.",
      },
    ],
  }),
  component: PrivacyPage,
});

type Lang = "vi" | "en";

function PrivacyPage() {
  const [lang, setLang] = useState<Lang>("vi");
  const t = lang === "vi" ? VI : EN;

  return (
    <main className="min-h-screen bg-background text-foreground">
      <nav className="sticky top-0 z-50 border-b border-border bg-background/70 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-4xl items-center justify-between px-6">
          <Link to="/" className="flex items-center gap-2 text-sm text-ink-soft hover:text-brand">
            <ArrowLeft className="size-4" /> {lang === "vi" ? "Về trang chủ" : "Back to home"}
          </Link>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-1.5">
              <img
                src={logoAsset}
                alt="SilentGuard"
                width={24}
                height={24}
                className="size-6 object-cover rounded-full mix-blend-multiply"
              />
              <span className="font-semibold text-sm tracking-tight">SilentGuard</span>
            </div>
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
        </div>
      </nav>

      <article className="mx-auto max-w-3xl px-6 py-16">
        <header className="mb-12">
          <span className="mb-4 inline-flex items-center gap-2 rounded-full bg-brand-light px-3 py-1 text-xs font-semibold uppercase tracking-wider text-brand">
            <ShieldCheck className="size-3.5" /> {t.badge}
          </span>
          <h1 className="text-balance text-4xl font-semibold leading-tight lg:text-5xl">{t.title}</h1>
          <p className="mt-4 text-sm text-ink-soft">
            SilentGuard AI · {lang === "vi" ? "Phiên bản" : "Version"} 1.0 ·{" "}
            {lang === "vi" ? "Tháng 6/2026" : "June 2026"}
          </p>
        </header>

        {/* Core commitment */}
        <section className="mb-12 rounded-3xl bg-surface p-8 ring-1 ring-border shadow-soft">
          <div className="mb-4 flex items-center gap-3">
            <div className="grid size-10 place-items-center rounded-2xl bg-brand-light text-brand">
              <Lock className="size-5" />
            </div>
            <h2 className="text-xl font-semibold">{t.s1.title}</h2>
          </div>
          <p className="mb-5 text-pretty leading-relaxed text-ink-soft">{t.s1.intro}</p>
          <ul className="space-y-2 text-sm">
            {t.s1.bullets.map((b) => (
              <li key={b} className="flex gap-3">
                <Check className="mt-0.5 size-4 shrink-0 text-brand" />
                <span>{b}</span>
              </li>
            ))}
          </ul>
        </section>

        {/* Data collected */}
        <Section title={t.s2.title}>
          <SubHeading>{t.s2.sub1}</SubHeading>
          <DataTable headers={t.s2.head1} rows={t.s2.rows1} />
          <SubHeading className="mt-8">{t.s2.sub2}</SubHeading>
          <DataTable headers={t.s2.head2} rows={t.s2.rows2} />
          <SubHeading className="mt-8">{t.s2.sub3}</SubHeading>
          <p className="text-sm leading-relaxed text-ink-soft">{t.s2.account}</p>
        </Section>

        {/* What we don't collect */}
        <Section title={t.s3.title}>
          <ul className="grid gap-3 sm:grid-cols-2">
            {t.s3.items.map((i) => (
              <li
                key={i}
                className="flex items-start gap-3 rounded-xl bg-surface-2 p-4 text-sm ring-1 ring-border"
              >
                <span className="mt-0.5 grid size-5 shrink-0 place-items-center rounded-full bg-red-100 text-red-600">
                  <X className="size-3" />
                </span>
                <span>{i}</span>
              </li>
            ))}
          </ul>
        </Section>

        {/* Protection */}
        <Section title={t.s4.title}>
          {t.s4.blocks.map((b) => (
            <div key={b.h} className="mb-5 last:mb-0">
              <h4 className="mb-1 font-medium">{b.h}</h4>
              <p className="text-sm leading-relaxed text-ink-soft">{b.body}</p>
            </div>
          ))}
        </Section>

        {/* Sharing */}
        <Section title={t.s5.title}>
          <p className="mb-4 text-pretty leading-relaxed text-ink-soft">{t.s5.intro}</p>
          <ul className="space-y-3 text-sm">
            {t.s5.items.map((i) => (
              <li key={i.h} className="rounded-xl bg-surface-2 p-4 ring-1 ring-border">
                <div className="font-medium">{i.h}</div>
                <div className="mt-1 text-ink-soft">{i.body}</div>
              </li>
            ))}
          </ul>
        </Section>

        {/* Rights */}
        <Section title={t.s6.title}>
          <ul className="space-y-2 text-sm">
            {t.s6.items.map((i) => (
              <li key={i.h} className="flex gap-3">
                <Check className="mt-0.5 size-4 shrink-0 text-brand" />
                <span>
                  <span className="font-medium">{i.h}:</span> <span className="text-ink-soft">{i.body}</span>
                </span>
              </li>
            ))}
          </ul>
          <p className="mt-5 text-sm text-ink-soft">
            {t.s6.contact}{" "}
            <a href="mailto:privacy@silentguard.ai" className="font-medium text-brand hover:underline">
              privacy@silentguard.ai
            </a>
          </p>
        </Section>

        <Section title={t.s7.title}>
          <p className="text-pretty leading-relaxed text-ink-soft">{t.s7.body}</p>
        </Section>

        <Section title={t.s8.title}>
          <ul className="space-y-2 text-sm text-ink-soft">
            {t.s8.items.map((i) => (
              <li key={i} className="flex gap-3">
                <span className="mt-2 size-1.5 shrink-0 rounded-full bg-brand" />
                {i}
              </li>
            ))}
          </ul>
        </Section>

        <Section title={t.s9.title}>
          <p className="text-pretty leading-relaxed text-ink-soft">{t.s9.body}</p>
        </Section>

        <Section title={t.s10.title}>
          <div className="rounded-2xl bg-surface p-6 ring-1 ring-border">
            <p className="text-sm">
              <span className="text-ink-soft">Email:</span>{" "}
              <a href="mailto:privacy@silentguard.ai" className="font-medium text-brand hover:underline">
                privacy@silentguard.ai
              </a>
            </p>
            <p className="mt-2 text-sm">
              <span className="text-ink-soft">{lang === "vi" ? "Địa chỉ" : "Address"}:</span>{" "}
              <span className="italic text-ink-soft">{t.s10.address}</span>
            </p>
          </div>
        </Section>

        <footer className="mt-16 border-t border-border pt-8 text-center text-xs text-ink-soft">
          © 2026 SilentGuard · {lang === "vi" ? "Bảo vệ bằng sự thấu hiểu" : "Protection through empathy"}
        </footer>
      </article>
    </main>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-12">
      <h2 className="mb-5 border-l-2 border-brand pl-4 text-2xl font-semibold">{title}</h2>
      {children}
    </section>
  );
}

function SubHeading({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <h3 className={`mb-3 text-sm font-semibold uppercase tracking-widest text-ink-soft ${className}`}>
      {children}
    </h3>
  );
}

function DataTable({ headers, rows }: { headers: string[]; rows: string[][] }) {
  return (
    <div className="overflow-hidden rounded-2xl bg-surface ring-1 ring-border">
      <table className="w-full text-left text-sm">
        <thead className="bg-surface-2 text-xs uppercase tracking-wider text-ink-soft">
          <tr>
            {headers.map((h) => (
              <th key={h} className="px-4 py-3 font-medium">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} className="border-t border-border align-top">
              {r.map((c, j) => (
                <td key={j} className={`px-4 py-3 ${j === 0 ? "font-medium" : "text-ink-soft"}`}>
                  {c}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ---------------- Vietnamese ----------------
const VI = {
  badge: "Cam kết quyền riêng tư",
  title: "Chính sách Quyền riêng tư",
  s1: {
    title: "Cam kết cốt lõi",
    intro:
      "SilentGuard được xây dựng trên nguyên tắc: an toàn không đánh đổi quyền riêng tư. Chúng tôi tin rằng gia đình có thể bảo vệ người thân mà không cần giám sát danh tính hay lưu trữ hình ảnh không cần thiết.",
    bullets: [
      "Video thô không bao giờ rời khỏi thiết bị trong nhà bạn",
      "Chúng tôi không nhận diện, lưu trữ, hay xử lý khuôn mặt",
      "Chúng tôi không bao giờ bán dữ liệu của bạn cho bất kỳ bên thứ ba nào",
      "Bạn có thể yêu cầu xóa toàn bộ dữ liệu bất cứ lúc nào",
    ],
  },
  s2: {
    title: "Dữ liệu chúng tôi thu thập",
    sub1: "2.1 Dữ liệu xử lý tại thiết bị (không gửi ra ngoài)",
    head1: ["Loại dữ liệu", "Mục đích", "Lưu trữ"],
    rows1: [
      ["Video thô từ camera", "Phân tích AI để phát hiện té ngã", "Chỉ trong RAM, xóa ngay sau khi xử lý"],
      ["Skeleton/keypoints cơ thể", "Phân loại mức độ sự kiện", "Không lưu trữ"],
      ["Frame hình ảnh", "Tạo clip sự kiện", "Xóa sau khi encode xong"],
    ],
    sub2: "2.2 Dữ liệu gửi lên cloud (chỉ khi có sự kiện)",
    head2: ["Loại dữ liệu", "Mục đích", "Thời gian lưu"],
    rows2: [
      ["Clip video 20 giây (mặt đã blur)", "Để gia đình xem lại sự kiện", "30 ngày, sau đó tự động xóa"],
      ["Metadata sự kiện (thời gian, mức độ, phòng)", "Lịch sử & dashboard", "90 ngày"],
      ["Log hệ thống (uptime, lỗi)", "Hỗ trợ kỹ thuật", "30 ngày"],
    ],
    sub3: "2.3 Dữ liệu tài khoản",
    account:
      "Khi đăng ký, chúng tôi thu thập: tên, email, số điện thoại, và thông tin liên hệ khẩn cấp bạn cung cấp. Dữ liệu này được mã hóa và chỉ dùng để vận hành dịch vụ.",
  },
  s3: {
    title: "Dữ liệu chúng tôi KHÔNG thu thập",
    items: [
      "Không nhận diện khuôn mặt hay danh tính",
      "Không ghi hình liên tục 24/7",
      "Không thu thập âm thanh",
      "Không lưu video thô lên cloud",
      "Không theo dõi vị trí GPS",
      "Không chia sẻ dữ liệu với công ty quảng cáo",
    ],
  },
  s4: {
    title: "Cách dữ liệu được bảo vệ",
    blocks: [
      {
        h: "Tại thiết bị trong nhà",
        body: "Video thô chỉ tồn tại trong bộ nhớ RAM trong quá trình xử lý và bị xóa ngay sau đó. Thiết bị sử dụng mã hóa khi truyền dữ liệu ra ngoài.",
      },
      {
        h: "Trên đường truyền",
        body: "Toàn bộ dữ liệu gửi giữa thiết bị và cloud được mã hóa bằng TLS 1.3. Clip video được mã hóa thêm trước khi upload.",
      },
      {
        h: "Trên cloud",
        body: "Dữ liệu lưu trữ được mã hóa AES-256. Chỉ tài khoản gia đình được ủy quyền mới có thể truy cập clip và log.",
      },
    ],
  },
  s5: {
    title: "Chia sẻ dữ liệu",
    intro: "Chúng tôi không bán, cho thuê, hay trao đổi dữ liệu cá nhân của bạn. Chúng tôi chỉ chia sẻ dữ liệu trong các trường hợp:",
    items: [
      { h: "Thành viên gia đình được ủy quyền", body: "Các liên hệ bạn tự thêm vào tài khoản." },
      {
        h: "Nhà cung cấp hạ tầng kỹ thuật",
        body: "Chỉ dữ liệu cần thiết để vận hành (lưu trữ, push notification), ràng buộc bởi hợp đồng bảo mật.",
      },
      {
        h: "Yêu cầu pháp lý",
        body: "Khi có lệnh của cơ quan có thẩm quyền theo quy định pháp luật Việt Nam.",
      },
    ],
  },
  s6: {
    title: "Quyền của bạn",
    items: [
      { h: "Truy cập", body: "Xem toàn bộ dữ liệu chúng tôi lưu về bạn." },
      { h: "Chỉnh sửa", body: "Cập nhật thông tin tài khoản bất cứ lúc nào." },
      { h: "Xóa", body: "Yêu cầu xóa toàn bộ dữ liệu — thực hiện trong 30 ngày làm việc." },
      { h: "Hạn chế xử lý", body: "Tạm dừng dịch vụ mà không mất dữ liệu." },
      { h: "Xuất dữ liệu", body: "Nhận bản sao dữ liệu của bạn theo định dạng có thể đọc được." },
    ],
    contact: "Để thực hiện các quyền trên, liên hệ:",
  },
  s7: {
    title: "Dữ liệu của người cao tuổi",
    body: "Người cao tuổi được giám sát không cần tạo tài khoản và không cần tương tác với hệ thống. Chúng tôi không lưu trữ thông tin cá nhân của họ ngoài dữ liệu sự kiện ẩn danh. Gia đình chịu trách nhiệm thông báo và lấy sự đồng ý của người được giám sát trước khi lắp đặt.",
  },
  s8: {
    title: "Lưu giữ và xóa dữ liệu",
    items: [
      "Clip video: xóa ngay lập tức",
      "Metadata sự kiện: xóa trong 7 ngày",
      "Thông tin tài khoản: xóa trong 30 ngày",
      "Backup hệ thống: xóa hoàn toàn trong 90 ngày",
    ],
  },
  s9: {
    title: "Thay đổi chính sách",
    body: "Khi chính sách này thay đổi, chúng tôi sẽ thông báo qua email và trong ứng dụng ít nhất 30 ngày trước khi có hiệu lực. Việc tiếp tục sử dụng dịch vụ sau thời điểm đó được hiểu là đồng ý với chính sách mới.",
  },
  s10: {
    title: "Liên hệ",
    address: "(cập nhật khi có địa chỉ pháp lý chính thức)",
  },
};

// ---------------- English ----------------
const EN = {
  badge: "Our privacy commitment",
  title: "Privacy Policy",
  s1: {
    title: "Our Core Commitment",
    intro:
      "SilentGuard is built on a single principle: safety should never come at the cost of privacy. We believe families can protect their loved ones without surveilling their identity or storing unnecessary footage.",
    bullets: [
      "Raw video never leaves the home device",
      "We do not identify, store, or process anyone's face",
      "We will never sell your data to any third party",
      "You can request full data deletion at any time",
    ],
  },
  s2: {
    title: "Data We Collect",
    sub1: "2.1 On-device data (never transmitted)",
    head1: ["Data type", "Purpose", "Storage"],
    rows1: [
      ["Raw camera footage", "AI analysis for fall detection", "RAM only, deleted immediately after processing"],
      ["Body skeleton / keypoints", "Event severity classification", "Not stored"],
      ["Video frames", "Event clip generation", "Deleted after encoding"],
    ],
    sub2: "2.2 Cloud data (only on detected events)",
    head2: ["Data type", "Purpose", "Retention"],
    rows2: [
      ["20-second video clip (face blurred)", "Family review of the event", "30 days, then automatically deleted"],
      ["Event metadata (time, severity, room)", "History & dashboard", "90 days"],
      ["System logs (uptime, errors)", "Technical support", "30 days"],
    ],
    sub3: "2.3 Account data",
    account:
      "At registration, we collect: name, email, phone number, and any emergency contacts you provide. This data is encrypted and used solely to operate the service.",
  },
  s3: {
    title: "Data We Do NOT Collect",
    items: [
      "No facial recognition or identity tracking",
      "No continuous 24/7 recording",
      "No audio recording",
      "No raw video uploaded to cloud",
      "No GPS location tracking",
      "No data shared with advertising companies",
    ],
  },
  s4: {
    title: "How Data Is Protected",
    blocks: [
      {
        h: "On the home device",
        body: "Raw video exists only in RAM during processing and is deleted immediately afterward. The device uses encrypted channels for all outbound data.",
      },
      {
        h: "In transit",
        body: "All data transmitted between the home device and cloud is encrypted with TLS 1.3. Video clips are additionally encrypted before upload.",
      },
      {
        h: "In the cloud",
        body: "Stored data is encrypted with AES-256. Only authorized family accounts can access clips and logs.",
      },
    ],
  },
  s5: {
    title: "Data Sharing",
    intro: "We do not sell, rent, or trade your personal data. We share data only in the following cases:",
    items: [
      { h: "Authorized family members", body: "Contacts you add to your account." },
      {
        h: "Infrastructure providers",
        body: "Only the minimum data required to operate the service (storage, push notifications), bound by data processing agreements.",
      },
      { h: "Legal requirements", body: "When required by a lawful order from competent authorities." },
    ],
  },
  s6: {
    title: "Your Rights",
    items: [
      { h: "Access", body: "View all data we hold about you." },
      { h: "Correct", body: "Update your account information at any time." },
      { h: "Delete", body: "Request full data deletion — completed within 30 business days." },
      { h: "Restrict", body: "Pause the service without losing your data." },
      { h: "Export", body: "Receive a copy of your data in a readable format." },
    ],
    contact: "To exercise these rights, contact:",
  },
  s7: {
    title: "Data Relating to the Elderly Person",
    body: "The elderly person being monitored does not need to create an account or interact with the system. We do not store their personal information beyond anonymized event data. The family member is responsible for informing and obtaining the consent of the monitored person before installation.",
  },
  s8: {
    title: "Data Retention & Deletion",
    items: [
      "Video clips: deleted immediately",
      "Event metadata: deleted within 7 days",
      "Account information: deleted within 30 days",
      "System backups: fully purged within 90 days",
    ],
  },
  s9: {
    title: "Policy Changes",
    body: "When this policy changes, we will notify you by email and in-app at least 30 days before the change takes effect. Continued use of the service after that date constitutes acceptance of the updated policy.",
  },
  s10: {
    title: "Contact",
    address: "(to be updated with official registered address)",
  },
};
