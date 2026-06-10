"use client";

import React from "react";
import { Bus, AlertTriangle, CheckCircle, WifiOff } from "lucide-react";
import MainLayout from "@/components/layout/MainLayout";
import { mockAlerts } from "@/lib/mock-data";

type BusStatus = "online" | "offline";

interface BusEntry {
  busId: string;
  route: string;
  status: BusStatus;
  driver: string;
  incidents: number;
}

const fleetData: BusEntry[] = [
  {
    busId: "BUS-102",
    route: "Tuyến 32",
    status: "online",
    driver: "TV",
    incidents: 8,
  },
  {
    busId: "BUS-047",
    route: "Tuyến 15",
    status: "online",
    driver: "ND",
    incidents: 6,
  },
  {
    busId: "BUS-213",
    route: "Tuyến 09",
    status: "online",
    driver: "LV",
    incidents: 4,
  },
  {
    busId: "BUS-088",
    route: "Tuyến 27",
    status: "online",
    driver: "PT",
    incidents: 3,
  },
  {
    busId: "BUS-174",
    route: "Tuyến 18",
    status: "online",
    driver: "HM",
    incidents: 2,
  },
  {
    busId: "BUS-301",
    route: "Tuyến 22",
    status: "online",
    driver: "QN",
    incidents: 0,
  },
  {
    busId: "BUS-055",
    route: "Tuyến 04",
    status: "offline",
    driver: "—",
    incidents: 1,
  },
  {
    busId: "BUS-099",
    route: "Tuyến 11",
    status: "offline",
    driver: "—",
    incidents: 0,
  },
];

const statusCfg = {
  online: {
    label: "Online",
    Icon: CheckCircle,
    textCls: "text-green-600",
    borderCls: "border-green-100",
    bgCls: "bg-green-50",
    dotCls: "bg-green-500",
  },
  offline: {
    label: "Offline",
    Icon: WifiOff,
    textCls: "text-gray-400",
    borderCls: "border-gray-200",
    bgCls: "bg-gray-50",
    dotCls: "bg-gray-300",
  },
};

export default function FleetPage() {
  const pendingBuses = new Set(
    mockAlerts.filter((a) => a.status === "pending").map((a) => a.busId),
  );
  const onlineCount = fleetData.filter((b) => b.status === "online").length;

  return (
    <MainLayout title="Fleet">
      {/* Summary */}
      <div className="flex items-center gap-6 mb-6 flex-wrap">
        <div className="flex items-center gap-2">
          <span className="w-2.5 h-2.5 rounded-full bg-green-500 animate-pulse" />
          <span className="text-sm text-gray-600 font-medium">
            {onlineCount} xe đang hoạt động
          </span>
        </div>
        <div className="flex items-center gap-2">
          <span className="w-2.5 h-2.5 rounded-full bg-gray-300" />
          <span className="text-sm text-gray-600 font-medium">
            {fleetData.length - onlineCount} xe offline
          </span>
        </div>
        {pendingBuses.size > 0 && (
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 rounded-full bg-amber-400 animate-pulse" />
            <span className="text-sm text-amber-600 font-medium">
              {pendingBuses.size} xe có alert chưa xử lý
            </span>
          </div>
        )}
      </div>

      {/* Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {fleetData.map((bus) => {
          const cfg = statusCfg[bus.status];
          const hasPending = pendingBuses.has(bus.busId);
          const { Icon } = cfg;

          return (
            <div
              key={bus.busId}
              className={[
                "relative bg-white rounded-xl border shadow-sm p-5 transition-all duration-150 hover:shadow-md",
                hasPending ? "border-amber-300" : "border-gray-200",
              ].join(" ")}
            >
              {/* Pending indicator */}
              {hasPending && (
                <div className="absolute top-3 right-3">
                  <AlertTriangle className="w-4 h-4 text-amber-500" />
                </div>
              )}

              {/* Bus icon */}
              <div
                className={`w-10 h-10 rounded-lg border flex items-center justify-center mb-3 ${cfg.bgCls} ${cfg.borderCls}`}
              >
                <Bus className={`w-5 h-5 ${cfg.textCls}`} />
              </div>

              <p className="font-bold text-gray-800 text-sm mb-0.5">
                {bus.busId}
              </p>
              <p className="text-xs text-gray-500 mb-3">{bus.route}</p>

              {/* Status */}
              <div className="flex items-center gap-1.5 mb-3">
                <Icon className={`w-3.5 h-3.5 ${cfg.textCls}`} />
                <span className={`text-xs font-medium ${cfg.textCls}`}>
                  {cfg.label}
                </span>
              </div>

              {/* Footer stats */}
              <div className="flex items-center justify-between text-xs border-t border-gray-100 pt-3">
                <span className="text-gray-500">
                  Tài xế:{" "}
                  <span className="font-semibold text-gray-700">
                    {bus.driver}
                  </span>
                </span>
                <span
                  className={`font-bold ${
                    bus.incidents > 5
                      ? "text-red-500"
                      : bus.incidents > 0
                        ? "text-orange-400"
                        : "text-gray-300"
                  }`}
                >
                  {bus.incidents} sự cố
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </MainLayout>
  );
}
