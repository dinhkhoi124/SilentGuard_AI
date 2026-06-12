"use client";

import React from "react";
import {
  GitFork,
  Camera,
  BellRing,
  Shield,
  Truck,
  ArrowRight,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Cpu,
} from "lucide-react";
import MainLayout from "@/components/layout/MainLayout";

interface FlowStep {
  Icon: React.ElementType;
  title: string;
  desc: string;
  iconCls: string;
}

interface FlowPath {
  id: number;
  name: string;
  subtitle: string;
  headerCls: string;
  headingCls: string;
  steps: FlowStep[];
}

const paths: FlowPath[] = [
  {
    id: 1,
    name: "AI Detection Pipeline",
    subtitle: "Camera → AI model → Alert tạo tự động",
    headerCls: "bg-blue-50 border-blue-100",
    headingCls: "text-blue-700",
    steps: [
      {
        Icon: Camera,
        title: "Camera capture",
        desc: "Ghi hình 1080p liên tục",
        iconCls: "bg-blue-100 text-blue-600",
      },
      {
        Icon: Cpu,
        title: "AI Inference",
        desc: "YOLOv8 phân tích frame",
        iconCls: "bg-blue-100 text-blue-600",
      },
      {
        Icon: AlertTriangle,
        title: "Event detected",
        desc: "Vượt ngưỡng confidence",
        iconCls: "bg-blue-100 text-blue-600",
      },
      {
        Icon: BellRing,
        title: "Alert created",
        desc: "Lưu log & gửi thông báo",
        iconCls: "bg-blue-100 text-blue-600",
      },
    ],
  },
  {
    id: 2,
    name: "High-Confidence Path",
    subtitle: "Confidence ≥ 80% — ưu tiên xử lý ngay",
    headerCls: "bg-red-50 border-red-100",
    headingCls: "text-red-700",
    steps: [
      {
        Icon: AlertTriangle,
        title: "Alert ưu tiên",
        desc: "Conf ≥ 80%",
        iconCls: "bg-red-100 text-red-600",
      },
      {
        Icon: BellRing,
        title: "Urgent notify",
        desc: "SMS + Push tức thì",
        iconCls: "bg-red-100 text-red-600",
      },
      {
        Icon: Shield,
        title: "Operator review",
        desc: "Xem xét ngay lập tức",
        iconCls: "bg-red-100 text-red-600",
      },
      {
        Icon: Truck,
        title: "Driver notified",
        desc: "Cảnh báo trên cabin",
        iconCls: "bg-red-100 text-red-600",
      },
    ],
  },
  {
    id: 3,
    name: "Operator Review Path",
    subtitle: "Operator xem lại footage và xác nhận",
    headerCls: "bg-green-50 border-green-100",
    headingCls: "text-green-700",
    steps: [
      {
        Icon: BellRing,
        title: "Pending alert",
        desc: "Chờ xem xét",
        iconCls: "bg-green-100 text-green-600",
      },
      {
        Icon: Camera,
        title: "Review footage",
        desc: "Xem lại camera feed",
        iconCls: "bg-green-100 text-green-600",
      },
      {
        Icon: CheckCircle,
        title: "Confirm / Reject",
        desc: "Quyết định cuối cùng",
        iconCls: "bg-green-100 text-green-600",
      },
      {
        Icon: Shield,
        title: "Case closed",
        desc: "Ghi log & lưu trữ",
        iconCls: "bg-green-100 text-green-600",
      },
    ],
  },
  {
    id: 4,
    name: "False-Positive Path",
    subtitle: "Phát hiện sai — phản hồi cải thiện model",
    headerCls: "bg-gray-50 border-gray-100",
    headingCls: "text-gray-600",
    steps: [
      {
        Icon: AlertTriangle,
        title: "Low-conf alert",
        desc: "Conf < 60%",
        iconCls: "bg-gray-100 text-gray-500",
      },
      {
        Icon: Camera,
        title: "Manual review",
        desc: "Kiểm tra thủ công",
        iconCls: "bg-gray-100 text-gray-500",
      },
      {
        Icon: XCircle,
        title: "Rejected",
        desc: "Đánh dấu false positive",
        iconCls: "bg-gray-100 text-gray-500",
      },
      {
        Icon: Cpu,
        title: "Model feedback",
        desc: "Dữ liệu cải thiện AI",
        iconCls: "bg-gray-100 text-gray-500",
      },
    ],
  },
];

const weekStats = [
  { label: "AI Detected", value: 42, colorCls: "text-blue-600" },
  { label: "High Priority", value: 18, colorCls: "text-red-600" },
  { label: "Confirmed", value: 30, colorCls: "text-green-600" },
  { label: "False Positive", value: 10, colorCls: "text-gray-400" },
];

export default function FourPathsPage() {
  return (
    <MainLayout title="4 Paths">
      {/* Intro */}
      <div className="mb-6">
        <div className="flex items-center gap-2 mb-1">
          <GitFork className="w-5 h-5 text-blue-600" />
          <h2 className="text-lg font-semibold text-gray-800">
            4 Luồng xử lý Alert
          </h2>
        </div>
        <p className="text-sm text-gray-500">
          Mỗi alert đi qua một trong bốn luồng tuỳ theo confidence và loại sự
          kiện.
        </p>
      </div>

      {/* Path cards */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5 mb-6">
        {paths.map((path) => (
          <div
            key={path.id}
            className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden"
          >
            {/* Card header */}
            <div className={`border-b px-5 py-4 ${path.headerCls}`}>
              <p
                className={`text-xs font-bold mb-0.5 ${path.headingCls} opacity-70`}
              >
                Path {path.id}
              </p>
              <h3 className={`font-bold text-sm ${path.headingCls}`}>
                {path.name}
              </h3>
              <p className="text-xs text-gray-500 mt-0.5">{path.subtitle}</p>
            </div>

            {/* Steps row */}
            <div className="p-5">
              <div className="flex items-start">
                {path.steps.map((step, idx) => {
                  const { Icon } = step;
                  return (
                    <React.Fragment key={idx}>
                      <div className="flex flex-col items-center flex-1 min-w-0">
                        {/* Icon circle */}
                        <div
                          className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${step.iconCls}`}
                        >
                          <Icon className="w-4 h-4" />
                        </div>
                        <p className="text-xs font-semibold text-gray-700 text-center mt-2 leading-tight px-1">
                          {step.title}
                        </p>
                        <p className="text-xs text-gray-400 text-center mt-0.5 leading-tight px-1">
                          {step.desc}
                        </p>
                      </div>

                      {/* Arrow connector */}
                      {idx < path.steps.length - 1 && (
                        <div className="flex items-start pt-4 flex-shrink-0">
                          <ArrowRight className="w-3.5 h-3.5 text-gray-300" />
                        </div>
                      )}
                    </React.Fragment>
                  );
                })}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Weekly stats */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-5">
        <h3 className="font-semibold text-gray-800 text-sm mb-5">
          Thống kê theo luồng — tuần này
        </h3>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {weekStats.map(({ label, value, colorCls }) => (
            <div key={label} className="text-center">
              <p className={`text-3xl font-bold ${colorCls}`}>{value}</p>
              <p className="text-xs text-gray-500 mt-1">{label}</p>
            </div>
          ))}
        </div>
      </div>
    </MainLayout>
  );
}
