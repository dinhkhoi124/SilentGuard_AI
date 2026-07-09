"use client";

import React, { useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  Bus,
  Shield,
  AlertTriangle,
  CheckCircle,
  Clock,
  MapPin,
  LogOut,
} from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import { mockAlerts } from "@/lib/mock-data";

const DRIVER_BUS = "BUS-102";

export default function DriverPage() {
  const { user, isLoading, logout } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !user) {
      router.push("/login");
    }
  }, [isLoading, user, router]);

  // Loading state
  if (isLoading || !user) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-blue-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const busAlerts = mockAlerts.filter((a) => a.busId === DRIVER_BUS);
  const pendingAlerts = busAlerts.filter((a) => a.status === "pending");
  const hasPending = pendingAlerts.length > 0;

  return (
    <div className="min-h-screen bg-gray-900 text-white flex flex-col">
      {/* ── Top bar ── */}
      <header className="bg-gray-800 border-b border-gray-700 px-5 py-3 flex items-center justify-between gap-4">
        {/* Brand */}
        <div className="flex items-center gap-2">
          <div className="bg-blue-600 p-1.5 rounded-md flex-shrink-0">
            <Shield className="w-4 h-4 text-white" />
          </div>
          <span className="font-bold text-sm hidden sm:block">
            VinBus SafeWatch
          </span>
        </div>

        {/* Bus + shift */}
        <div className="flex items-center gap-4 text-sm">
          <div className="flex items-center gap-1.5 text-gray-400">
            <Bus className="w-4 h-4" />
            <span className="font-mono font-semibold text-white">
              {DRIVER_BUS}
            </span>
          </div>
          <div className="flex items-center gap-1.5 text-gray-400">
            <Clock className="w-3.5 h-3.5" />
            <span>{user.shift}</span>
          </div>
        </div>

        {/* User + logout */}
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 bg-gray-700 rounded-full px-3 py-1.5">
            <div className="w-6 h-6 rounded-full bg-blue-600 flex items-center justify-center text-xs font-bold flex-shrink-0">
              {user.avatar}
            </div>
            <span className="text-sm text-gray-200 hidden sm:block">
              {user.name}
            </span>
          </div>
          <button
            onClick={logout}
            title="Đăng xuất"
            className="p-1.5 text-gray-400 hover:text-red-400 transition-colors rounded-md hover:bg-gray-700"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </header>

      {/* ── Main ── */}
      <main className="flex-1 p-5 max-w-2xl mx-auto w-full">
        {/* Status banner */}
        <div
          className={[
            "rounded-xl p-5 mb-6 flex items-center gap-4",
            hasPending
              ? "bg-red-900/50 border border-red-500/50"
              : "bg-green-900/50 border border-green-500/50",
          ].join(" ")}
        >
          <div
            className={[
              "w-14 h-14 rounded-full flex items-center justify-center flex-shrink-0",
              hasPending ? "bg-red-500/20" : "bg-green-500/20",
            ].join(" ")}
          >
            {hasPending ? (
              <AlertTriangle className="w-7 h-7 text-red-400" />
            ) : (
              <CheckCircle className="w-7 h-7 text-green-400" />
            )}
          </div>
          <div>
            <p
              className={`font-bold text-lg ${hasPending ? "text-red-300" : "text-green-300"}`}
            >
              {hasPending
                ? `${pendingAlerts.length} CẢNH BÁO ĐANG CHỜ`
                : "An toàn — Không có sự cố"}
            </p>
            <p className="text-sm text-gray-400 mt-0.5">
              {hasPending
                ? "Có sự cố trên xe, vui lòng kiểm tra hành khách ngay"
                : "Không có cảnh báo nào hiện tại · tiếp tục lái xe an toàn"}
            </p>
          </div>
        </div>

        {/* Alert list */}
        {busAlerts.length > 0 ? (
          <>
            <h2 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
              Sự kiện ghi nhận trên {DRIVER_BUS}
            </h2>

            <div className="flex flex-col gap-3">
              {busAlerts.map((alert) => (
                <div
                  key={alert.id}
                  className={[
                    "rounded-xl border p-4",
                    alert.status === "pending"
                      ? "bg-gray-800 border-red-500/60"
                      : "bg-gray-800/60 border-gray-700",
                  ].join(" ")}
                >
                  <div className="flex items-start justify-between gap-3">
                    {/* Left: info */}
                    <div className="flex-1 min-w-0">
                      {/* Badges */}
                      <div className="flex items-center gap-2 mb-2 flex-wrap">
                        <span className="font-mono text-xs text-gray-400">
                          {alert.id}
                        </span>
                        <span
                          className={[
                            "text-xs font-bold px-2 py-0.5 rounded-full border",
                            alert.eventType === "Fight"
                              ? "bg-red-900/60 text-red-300 border-red-700"
                              : "bg-orange-900/60 text-orange-300 border-orange-700",
                          ].join(" ")}
                        >
                          {alert.eventType}
                        </span>
                        <span
                          className={[
                            "text-xs font-semibold px-2 py-0.5 rounded-full border",
                            alert.status === "pending"
                              ? "bg-amber-900/60 text-amber-300 border-amber-700"
                              : alert.status === "confirmed"
                                ? "bg-green-900/60 text-green-300 border-green-700"
                                : "bg-gray-700 text-gray-400 border-gray-600",
                          ].join(" ")}
                        >
                          {alert.status === "pending"
                            ? "Chờ xử lý"
                            : alert.status === "confirmed"
                              ? "Đã xác nhận"
                              : "Đã từ chối"}
                        </span>
                      </div>

                      {/* Description */}
                      <p className="text-sm text-gray-300 mb-2 leading-relaxed">
                        {alert.description}
                      </p>

                      {/* Meta */}
                      <div className="flex items-center gap-4 text-xs text-gray-500 flex-wrap">
                        <span className="flex items-center gap-1">
                          <MapPin className="w-3 h-3" />
                          {alert.route}
                        </span>
                        <span className="flex items-center gap-1">
                          <Clock className="w-3 h-3" />
                          {alert.timestamp}
                        </span>
                        <span>{alert.camera}</span>
                      </div>
                    </div>

                    {/* Right: confidence */}
                    <div className="text-right flex-shrink-0">
                      <p
                        className={[
                          "text-2xl font-bold leading-none",
                          alert.confidence >= 80
                            ? "text-red-400"
                            : alert.confidence >= 60
                              ? "text-orange-400"
                              : "text-gray-400",
                        ].join(" ")}
                      >
                        {alert.confidence}%
                      </p>
                      <p className="text-xs text-gray-500 mt-0.5">conf.</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </>
        ) : (
          <div className="text-center py-16 text-gray-600">
            <Bus className="w-12 h-12 mx-auto mb-3 opacity-20" />
            <p className="text-sm">Không có sự kiện nào được ghi nhận</p>
          </div>
        )}
      </main>
    </div>
  );
}
