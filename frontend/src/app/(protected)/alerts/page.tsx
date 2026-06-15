"use client";

import React, { useState, useMemo } from "react";
import Link from "next/link";
import { BellRing, ChevronRight, Clock } from "lucide-react";
import MainLayout from "@/components/layout/MainLayout";
import EventTypeBadge from "@/components/alerts/EventTypeBadge";
import AlertStatusBadge from "@/components/alerts/AlertStatusBadge";
import { mockAlerts } from "@/lib/mock-data";
import { getConfidenceStyle } from "@/lib/utils";
import type { AlertFilter } from "@/lib/types";

const filterLabels: Record<AlertFilter, string> = {
  all: "Tất cả",
  pending: "Pending",
  fight: "Fight",
  fall: "Fall",
};

export default function AlertsPage() {
  const [activeFilter, setActiveFilter] = useState<AlertFilter>("all");

  const pendingCount = mockAlerts.filter((a) => a.status === "pending").length;

  const filtered = useMemo(() => {
    return mockAlerts.filter((a) => {
      if (activeFilter === "pending") return a.status === "pending";
      if (activeFilter === "fight") return a.eventType === "Fight";
      if (activeFilter === "fall") return a.eventType === "Fall";
      return true;
    });
  }, [activeFilter]);

  return (
    <MainLayout title="Alerts">
      {/* Top row */}
      <div className="flex items-center justify-between mb-5">
        <div className="flex items-center gap-2 text-sm text-gray-500">
          <BellRing className="w-4 h-4 text-blue-600" />
          <span>
            <span className="font-semibold text-amber-600">{pendingCount}</span>{" "}
            alert đang chờ xử lý
          </span>
        </div>
        {/* Live pulse */}
        <div className="flex items-center gap-1.5 text-xs text-green-600 font-semibold">
          <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
          Live
        </div>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-2 mb-5 flex-wrap">
        {(Object.keys(filterLabels) as AlertFilter[]).map((f) => (
          <button
            key={f}
            onClick={() => setActiveFilter(f)}
            className={[
              "px-4 py-1.5 rounded-lg text-sm font-medium border transition-colors",
              activeFilter === f
                ? "bg-blue-600 text-white border-blue-600"
                : "bg-white text-gray-500 border-gray-200 hover:border-gray-300 hover:text-gray-700",
            ].join(" ")}
          >
            {filterLabels[f]}
            {f === "pending" && pendingCount > 0 && (
              <span
                className={[
                  "ml-1.5 text-xs font-bold px-1.5 py-0.5 rounded-full",
                  activeFilter === f
                    ? "bg-white text-blue-600"
                    : "bg-red-500 text-white",
                ].join(" ")}
              >
                {pendingCount}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Alert cards */}
      <div className="flex flex-col gap-3">
        {filtered.length === 0 ? (
          <div className="text-center py-16 text-gray-400 text-sm">
            Không có alert nào
          </div>
        ) : (
          filtered.map((alert) => (
            <Link
              key={alert.id}
              href={`/alerts/${alert.id}`}
              className="block bg-white rounded-xl border border-gray-200 shadow-sm hover:shadow-md hover:border-blue-200 transition-all duration-150 p-4"
            >
              <div className="flex items-start gap-4">
                {/* Coloured left stripe */}
                <div
                  className={[
                    "w-1 self-stretch rounded-full flex-shrink-0",
                    alert.eventType === "Fight"
                      ? "bg-red-400"
                      : "bg-orange-400",
                  ].join(" ")}
                />

                {/* Main info */}
                <div className="flex-1 min-w-0">
                  {/* Badges row */}
                  <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                    <span className="font-mono text-xs font-semibold text-gray-400">
                      {alert.id}
                    </span>
                    <EventTypeBadge type={alert.eventType} />
                    <AlertStatusBadge status={alert.status} />
                    {alert.status === "pending" && (
                      <span className="w-2 h-2 rounded-full bg-amber-400 animate-pulse" />
                    )}
                  </div>

                  {/* Bus / route */}
                  <div className="flex items-center gap-2 mb-1 flex-wrap text-sm">
                    <span className="font-semibold text-gray-800">
                      {alert.busId}
                    </span>
                    <span className="text-gray-300">·</span>
                    <span className="text-gray-600">{alert.route}</span>
                    <span className="text-gray-300">·</span>
                    <span className="text-gray-400">{alert.camera}</span>
                  </div>

                  {/* Description */}
                  <p className="text-sm text-gray-500 truncate">
                    {alert.description}
                  </p>
                </div>

                {/* Right meta */}
                <div className="flex flex-col items-end gap-1.5 flex-shrink-0">
                  <div className="flex items-center gap-1 text-xs text-gray-400">
                    <Clock className="w-3 h-3" />
                    {alert.timestamp}
                  </div>
                  <span
                    className={`text-xs font-bold ${getConfidenceStyle(alert.confidence).text}`}
                  >
                    {alert.confidence}% conf.
                  </span>
                  <span className="text-xs text-gray-400">
                    MTTD {alert.mttd}s
                  </span>
                  <ChevronRight className="w-4 h-4 text-gray-300 mt-0.5" />
                </div>
              </div>
            </Link>
          ))
        )}
      </div>
    </MainLayout>
  );
}
