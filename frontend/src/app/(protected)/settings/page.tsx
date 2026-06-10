"use client";

import React, { useState } from "react";
import { Sliders, Bell, Shield, Save, CheckCircle } from "lucide-react";
import MainLayout from "@/components/layout/MainLayout";

interface Notifications {
  emailAlerts: boolean;
  smsAlerts: boolean;
  pushAlerts: boolean;
}

const notifItems: { key: keyof Notifications; label: string; desc: string }[] =
  [
    {
      key: "emailAlerts",
      label: "Email Alerts",
      desc: "Gửi email khi có alert mới được tạo",
    },
    {
      key: "smsAlerts",
      label: "SMS Alerts",
      desc: "Gửi SMS cho các alert có confidence cao",
    },
    {
      key: "pushAlerts",
      label: "Push Notifications",
      desc: "Thông báo trình duyệt real-time",
    },
  ];

export default function SettingsPage() {
  const [threshold, setThreshold] = useState(70);
  const [notifications, setNotifications] = useState<Notifications>({
    emailAlerts: true,
    smsAlerts: false,
    pushAlerts: true,
  });
  const [saved, setSaved] = useState(false);

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  };

  const toggleNotif = (key: keyof Notifications) => {
    setNotifications((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const thresholdColor =
    threshold >= 80
      ? "text-red-600 bg-red-50"
      : threshold >= 60
        ? "text-orange-500 bg-orange-50"
        : "text-gray-500 bg-gray-50";

  return (
    <MainLayout title="Cài đặt">
      <div className="max-w-2xl space-y-5">
        {/* Confidence Threshold */}
        <section className="bg-white rounded-xl border border-gray-200 shadow-sm p-6">
          <div className="flex items-center gap-2 mb-1">
            <Sliders className="w-4 h-4 text-blue-600" />
            <h2 className="font-semibold text-gray-800 text-sm">
              Ngưỡng Confidence
            </h2>
          </div>
          <p className="text-xs text-gray-500 mb-5">
            Chỉ tạo alert khi AI confidence vượt ngưỡng này. Tăng ngưỡng để giảm
            false positive.
          </p>

          <div className="flex items-center gap-4">
            <input
              type="range"
              min={40}
              max={95}
              step={5}
              value={threshold}
              onChange={(e) => setThreshold(Number(e.target.value))}
              className="flex-1 accent-blue-600 cursor-pointer"
            />
            <div
              className={`w-16 text-center font-bold text-lg rounded-lg py-1.5 flex-shrink-0 ${thresholdColor}`}
            >
              {threshold}%
            </div>
          </div>

          <div className="flex justify-between text-xs text-gray-400 mt-1.5 px-0.5">
            <span>40% — nhiều alert hơn</span>
            <span>95% — ít alert hơn</span>
          </div>
        </section>

        {/* Notifications */}
        <section className="bg-white rounded-xl border border-gray-200 shadow-sm p-6">
          <div className="flex items-center gap-2 mb-5">
            <Bell className="w-4 h-4 text-blue-600" />
            <h2 className="font-semibold text-gray-800 text-sm">Thông báo</h2>
          </div>

          <div className="space-y-5">
            {notifItems.map(({ key, label, desc }) => (
              <div
                key={key}
                className="flex items-center justify-between gap-4"
              >
                <div>
                  <p className="text-sm font-medium text-gray-800">{label}</p>
                  <p className="text-xs text-gray-500 mt-0.5">{desc}</p>
                </div>
                {/* Toggle switch */}
                <button
                  type="button"
                  role="switch"
                  aria-checked={notifications[key]}
                  onClick={() => toggleNotif(key)}
                  className={[
                    "relative w-11 h-6 rounded-full transition-colors duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-400 flex-shrink-0",
                    notifications[key] ? "bg-blue-600" : "bg-gray-200",
                  ].join(" ")}
                >
                  <span
                    className={[
                      "absolute top-1 w-4 h-4 bg-white rounded-full shadow transition-transform duration-200",
                      notifications[key] ? "translate-x-6" : "translate-x-1",
                    ].join(" ")}
                  />
                </button>
              </div>
            ))}
          </div>
        </section>

        {/* System Info */}
        <section className="bg-white rounded-xl border border-gray-200 shadow-sm p-6">
          <div className="flex items-center gap-2 mb-5">
            <Shield className="w-4 h-4 text-blue-600" />
            <h2 className="font-semibold text-gray-800 text-sm">
              Thông tin hệ thống
            </h2>
          </div>

          <dl className="grid grid-cols-2 gap-x-8 gap-y-3 text-sm">
            {[
              { label: "Phiên bản AI", value: "SafeWatch v2.1.0" },
              { label: "Model", value: "YOLOv8-SafeWatch" },
              { label: "Số xe giám sát", value: "6 / 8" },
              { label: "Uptime", value: "99.7%", green: true },
              { label: "Cập nhật cuối", value: "2024-12-01" },
              { label: "Môi trường", value: "Demo" },
            ].map(({ label, value, green }) => (
              <React.Fragment key={label}>
                <dt className="text-gray-500">{label}</dt>
                <dd
                  className={`font-semibold ${green ? "text-green-600" : "text-gray-800"}`}
                >
                  {value}
                </dd>
              </React.Fragment>
            ))}
          </dl>
        </section>

        {/* Save */}
        <div className="flex justify-end pb-2">
          <button
            onClick={handleSave}
            className={[
              "flex items-center gap-2 px-6 py-2.5 rounded-lg text-sm font-semibold transition-all duration-200",
              saved
                ? "bg-green-600 text-white"
                : "bg-blue-600 hover:bg-blue-700 text-white",
            ].join(" ")}
          >
            {saved ? (
              <>
                <CheckCircle className="w-4 h-4" /> Đã lưu!
              </>
            ) : (
              <>
                <Save className="w-4 h-4" /> Lưu cài đặt
              </>
            )}
          </button>
        </div>
      </div>
    </MainLayout>
  );
}
