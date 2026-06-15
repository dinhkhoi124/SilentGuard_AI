"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import {
  ArrowLeft,
  Camera,
  Clock,
  Bus,
  MapPin,
  Shield,
  CheckCircle,
  XCircle,
  AlertTriangle,
} from "lucide-react";
import MainLayout from "@/components/layout/MainLayout";
import EventTypeBadge from "@/components/alerts/EventTypeBadge";
import AlertStatusBadge from "@/components/alerts/AlertStatusBadge";
import { mockAlerts } from "@/lib/mock-data";
import { useAuth } from "@/contexts/AuthContext";
import type { AlertStatus } from "@/lib/types";

interface PageProps {
  params: { id: string };
}

export default function AlertDetailPage({ params }: PageProps) {
  const router = useRouter();
  const { user } = useAuth();

  const alert = mockAlerts.find((a) => a.id === params.id);

  const [status, setStatus] = useState<AlertStatus>(alert?.status ?? "pending");
  const [reviewNote, setReviewNote] = useState(alert?.reviewNote ?? "");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(
    alert ? alert.status !== "pending" : false,
  );

  // ── Not found ───────────────────────────────────────────────────────────────
  if (!alert) {
    return (
      <MainLayout title="Alert Not Found">
        <div className="flex flex-col items-center justify-center py-24 text-gray-400">
          <AlertTriangle className="w-12 h-12 mb-3" />
          <p className="text-lg font-semibold text-gray-600">
            Alert không tồn tại
          </p>
          <p className="text-sm mt-1 mb-5">
            ID <span className="font-mono">{params.id}</span> không có trong hệ
            thống.
          </p>
          <button
            onClick={() => router.back()}
            className="text-blue-600 text-sm hover:underline"
          >
            ← Quay lại
          </button>
        </div>
      </MainLayout>
    );
  }

  // Operators and admins can review pending alerts
  const canReview =
    (user?.role === "admin" || user?.role === "operator") && !submitted;

  const handleReview = async (action: "confirmed" | "rejected") => {
    setIsSubmitting(true);
    await new Promise((r) => setTimeout(r, 600));
    setStatus(action);
    setSubmitted(true);
    setIsSubmitting(false);
  };

  const confidenceColor =
    alert.confidence >= 80
      ? "text-red-600"
      : alert.confidence >= 60
        ? "text-orange-500"
        : "text-gray-500";

  const confidenceBarColor =
    alert.confidence >= 80
      ? "bg-red-400"
      : alert.confidence >= 60
        ? "bg-orange-400"
        : "bg-gray-400";

  return (
    <MainLayout title={`Alert ${alert.id}`}>
      {/* ── Back + heading ── */}
      <div className="mb-6">
        <button
          onClick={() => router.back()}
          className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-blue-600 transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" />
          Quay lại danh sách
        </button>

        <div className="flex items-center gap-3 flex-wrap">
          <h2 className="font-mono font-bold text-gray-800 text-lg">
            {alert.id}
          </h2>
          <EventTypeBadge type={alert.eventType} size="md" />
          <AlertStatusBadge status={status} size="md" />
          {status === "pending" && (
            <span className="inline-flex items-center gap-1.5 text-xs text-amber-600 font-semibold bg-amber-50 border border-amber-200 rounded-full px-2.5 py-0.5">
              <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse" />
              Chờ xử lý
            </span>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {/* ── Left column ── */}
        <div className="flex flex-col gap-5">
          {/* Camera feed placeholder */}
          <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
            <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100">
              <div className="flex items-center gap-2 text-sm font-semibold text-gray-700">
                <Camera className="w-4 h-4 text-blue-600" />
                {alert.camera}
              </div>
              <span className="text-xs text-gray-400 font-mono">
                {alert.busId} · {alert.route}
              </span>
            </div>

            {/* Mock video frame */}
            <div className="relative bg-gray-900 aspect-video flex items-center justify-center select-none">
              {/* Scanline overlay */}
              <div
                className="absolute inset-0 opacity-[0.07] pointer-events-none"
                style={{
                  backgroundImage:
                    "repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(255,255,255,0.5) 2px, rgba(255,255,255,0.5) 4px)",
                }}
              />

              {/* Timestamp + REC */}
              <div className="absolute top-3 left-3 text-green-400 font-mono text-xs">
                ● REC {alert.timestamp}
              </div>
              <div className="absolute top-3 right-3 text-green-400 font-mono text-xs">
                {alert.busId}
              </div>

              {/* Placeholder icon */}
              <div className="text-center text-gray-600">
                <Camera className="w-10 h-10 mx-auto mb-2 opacity-20" />
                <p className="text-xs opacity-30">Camera feed — demo</p>
              </div>

              {/* Detection bounding box */}
              <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                <div className="border-2 border-red-400 rounded w-28 h-40 opacity-70 relative">
                  <span className="absolute -top-5 left-0 text-red-400 text-xs font-mono bg-gray-900/80 px-1 whitespace-nowrap">
                    {alert.eventType} {alert.confidence}%
                  </span>
                </div>
              </div>

              {/* Bottom bar */}
              <div className="absolute bottom-3 left-3 right-3 flex justify-between text-gray-500 text-xs font-mono">
                <span>FRAME 0042</span>
                <span>1920×1080</span>
              </div>
            </div>
          </div>

          {/* Metadata */}
          <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-5">
            <h3 className="font-semibold text-gray-800 text-sm mb-4">
              Chi tiết sự kiện
            </h3>

            <dl className="space-y-3 text-sm">
              {[
                { Icon: Bus, label: "Bus", value: alert.busId },
                { Icon: MapPin, label: "Tuyến", value: alert.route },
                {
                  Icon: Clock,
                  label: "Thời gian",
                  value: alert.timestamp,
                  mono: true,
                },
                {
                  Icon: Shield,
                  label: "Confidence",
                  value: `${alert.confidence}%`,
                  bold: true,
                },
                { Icon: Camera, label: "Camera", value: alert.camera },
              ].map(({ Icon, label, value, mono, bold }) => (
                <div key={label} className="flex items-center gap-3">
                  <Icon className="w-4 h-4 text-gray-400 flex-shrink-0" />
                  <span className="text-gray-500 w-24 flex-shrink-0">
                    {label}
                  </span>
                  <span
                    className={[
                      bold
                        ? confidenceColor + " font-bold"
                        : "text-gray-800 font-semibold",
                      mono ? "font-mono" : "",
                    ].join(" ")}
                  >
                    {value}
                  </span>
                </div>
              ))}
              <div className="flex items-center gap-3">
                <Clock className="w-4 h-4 text-gray-400 flex-shrink-0" />
                <span className="text-gray-500 w-24 flex-shrink-0">MTTD</span>
                <span className="text-gray-800 font-semibold">
                  {alert.mttd}s
                </span>
              </div>
            </dl>

            <div className="mt-4 pt-4 border-t border-gray-100">
              <p className="text-xs font-semibold text-gray-500 mb-1.5">
                Mô tả
              </p>
              <p className="text-sm text-gray-700 leading-relaxed">
                {alert.description}
              </p>
            </div>
          </div>
        </div>

        {/* ── Right column ── */}
        <div className="flex flex-col gap-5">
          {/* Review panel (pending + reviewer roles) */}
          {canReview ? (
            <div className="bg-white rounded-xl border border-amber-200 shadow-sm p-5">
              <div className="flex items-center gap-2 mb-4">
                <AlertTriangle className="w-4 h-4 text-amber-500" />
                <h3 className="font-semibold text-gray-800 text-sm">
                  Xem xét & Xử lý
                </h3>
              </div>

              <label className="block text-xs font-semibold text-gray-600 mb-1.5">
                Ghi chú (tuỳ chọn)
              </label>
              <textarea
                value={reviewNote}
                onChange={(e) => setReviewNote(e.target.value)}
                placeholder="Nhập nhận xét về sự kiện này..."
                rows={4}
                className="w-full text-sm border border-gray-200 rounded-lg px-3 py-2 resize-none focus:outline-none focus:ring-2 focus:ring-blue-300 focus:border-blue-400 text-gray-700 placeholder-gray-400 mb-4"
              />

              <div className="flex gap-3">
                <button
                  onClick={() => handleReview("confirmed")}
                  disabled={isSubmitting}
                  className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-green-600 hover:bg-green-700 text-white text-sm font-semibold rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <CheckCircle className="w-4 h-4" />
                  Xác nhận
                </button>
                <button
                  onClick={() => handleReview("rejected")}
                  disabled={isSubmitting}
                  className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-white hover:bg-red-50 border-2 border-red-300 hover:border-red-400 text-red-600 text-sm font-semibold rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <XCircle className="w-4 h-4" />
                  Từ chối
                </button>
              </div>

              {isSubmitting && (
                <p className="text-center text-xs text-gray-400 mt-3 animate-pulse">
                  Đang xử lý...
                </p>
              )}
            </div>
          ) : (
            /* Already-reviewed result card */
            <div
              className={[
                "bg-white rounded-xl border shadow-sm p-5",
                status === "confirmed" ? "border-green-200" : "border-gray-200",
              ].join(" ")}
            >
              <div className="flex items-center gap-2 mb-4">
                {status === "confirmed" ? (
                  <CheckCircle className="w-4 h-4 text-green-500" />
                ) : (
                  <XCircle className="w-4 h-4 text-gray-400" />
                )}
                <h3 className="font-semibold text-gray-800 text-sm">
                  {status === "confirmed" ? "Đã xác nhận" : "Đã từ chối"}
                </h3>
              </div>

              <dl className="text-sm space-y-3">
                {alert.reviewedBy && (
                  <>
                    <div className="flex items-center gap-3">
                      <dt className="text-gray-500 w-28 flex-shrink-0">
                        Xem xét bởi
                      </dt>
                      <dd className="font-semibold text-gray-800">
                        {alert.reviewedBy}
                      </dd>
                    </div>
                  </>
                )}
                {alert.reviewedAt && (
                  <div className="flex items-center gap-3">
                    <dt className="text-gray-500 w-28 flex-shrink-0">Lúc</dt>
                    <dd className="font-mono font-semibold text-gray-800">
                      {alert.reviewedAt}
                    </dd>
                  </div>
                )}
                {(reviewNote || alert.reviewNote) && (
                  <div>
                    <dt className="text-xs font-semibold text-gray-500 mb-1.5">
                      Ghi chú
                    </dt>
                    <dd className="text-gray-700 bg-gray-50 rounded-lg p-3 text-sm leading-relaxed">
                      {reviewNote || alert.reviewNote}
                    </dd>
                  </div>
                )}
              </dl>
            </div>
          )}

          {/* Confidence visualiser */}
          <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-5">
            <h3 className="font-semibold text-gray-800 text-sm mb-4">
              AI Confidence Score
            </h3>

            <div className="flex items-end gap-3 mb-3">
              <span
                className={`text-4xl font-bold leading-none ${confidenceColor}`}
              >
                {alert.confidence}%
              </span>
              <span className="text-sm text-gray-400 mb-0.5">
                {alert.confidence >= 80
                  ? "Độ tin cậy cao"
                  : alert.confidence >= 60
                    ? "Độ tin cậy trung bình"
                    : "Độ tin cậy thấp"}
              </span>
            </div>

            <div className="w-full bg-gray-100 rounded-full h-3 overflow-hidden">
              <div
                className={`h-3 rounded-full transition-all duration-700 ${confidenceBarColor}`}
                style={{ width: `${alert.confidence}%` }}
              />
            </div>
            <div className="flex justify-between mt-1.5 text-xs text-gray-400">
              <span>0%</span>
              <span>50%</span>
              <span>100%</span>
            </div>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}
