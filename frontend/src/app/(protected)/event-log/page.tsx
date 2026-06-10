"use client";

import React, { useState, useMemo } from "react";
import Link from "next/link";
import { ClipboardList, ArrowUpDown } from "lucide-react";
import MainLayout from "@/components/layout/MainLayout";
import EventTypeBadge from "@/components/alerts/EventTypeBadge";
import AlertStatusBadge from "@/components/alerts/AlertStatusBadge";
import { mockAlerts } from "@/lib/mock-data";
import type { EventType } from "@/lib/types";

type TypeFilter = "all" | EventType;
type SortKey = "timestamp" | "confidence" | "mttd";

export default function EventLogPage() {
  const [typeFilter, setTypeFilter] = useState<TypeFilter>("all");
  const [sortKey, setSortKey] = useState<SortKey>("timestamp");

  const data = useMemo(() => {
    let list = [...mockAlerts];
    if (typeFilter !== "all") {
      list = list.filter((a) => a.eventType === typeFilter);
    }
    list.sort((a, b) => {
      if (sortKey === "confidence") return b.confidence - a.confidence;
      if (sortKey === "mttd") return a.mttd - b.mttd;
      // Default: reverse-chronological by timestamp string
      return b.timestamp.localeCompare(a.timestamp);
    });
    return list;
  }, [typeFilter, sortKey]);

  const SortBtn = ({ label, sk }: { label: string; sk: SortKey }) => (
    <button
      onClick={() => setSortKey(sk)}
      className={[
        "flex items-center gap-1 transition-colors",
        sortKey === sk ? "text-blue-600" : "hover:text-blue-500",
      ].join(" ")}
    >
      {label}
      <ArrowUpDown className="w-3 h-3 flex-shrink-0" />
    </button>
  );

  return (
    <MainLayout title="Event Log">
      {/* Controls */}
      <div className="flex items-center justify-between mb-5 flex-wrap gap-3">
        <div className="flex items-center gap-2 text-sm text-gray-500">
          <ClipboardList className="w-4 h-4 text-blue-600" />
          <span>{data.length} sự kiện</span>
        </div>

        <div className="flex gap-2">
          {(["all", "Fall", "Fight"] as TypeFilter[]).map((f) => (
            <button
              key={f}
              onClick={() => setTypeFilter(f)}
              className={[
                "px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors",
                typeFilter === f
                  ? "bg-blue-600 text-white border-blue-600"
                  : "bg-white text-gray-500 border-gray-200 hover:border-gray-300",
              ].join(" ")}
            >
              {f === "all" ? "Tất cả" : f}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                <th className="text-left px-4 py-3">ID</th>
                <th className="text-left px-4 py-3">Bus / Tuyến</th>
                <th className="text-left px-4 py-3">Loại</th>
                <th className="text-left px-4 py-3">
                  <SortBtn label="Conf." sk="confidence" />
                </th>
                <th className="text-left px-4 py-3">
                  <SortBtn label="Thời gian" sk="timestamp" />
                </th>
                <th className="text-left px-4 py-3">
                  <SortBtn label="MTTD" sk="mttd" />
                </th>
                <th className="text-left px-4 py-3">Camera</th>
                <th className="text-left px-4 py-3">Trạng thái</th>
                <th className="text-left px-4 py-3">Reviewer</th>
              </tr>
            </thead>
            <tbody>
              {data.map((alert, i) => (
                <tr
                  key={alert.id}
                  className={[
                    "hover:bg-blue-50 transition-colors border-b border-gray-50",
                    i % 2 === 1 ? "bg-gray-50/40" : "bg-white",
                  ].join(" ")}
                >
                  <td className="px-4 py-3">
                    <Link
                      href={`/alerts/${alert.id}`}
                      className="font-mono text-xs text-blue-600 hover:underline font-semibold"
                    >
                      {alert.id}
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    <span className="font-semibold text-gray-800">
                      {alert.busId}
                    </span>
                    <span className="text-gray-400 mx-1.5">·</span>
                    <span className="text-gray-500 text-xs">{alert.route}</span>
                  </td>
                  <td className="px-4 py-3">
                    <EventTypeBadge type={alert.eventType} />
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={[
                        "font-bold text-xs",
                        alert.confidence >= 80
                          ? "text-red-600"
                          : alert.confidence >= 60
                            ? "text-orange-500"
                            : "text-gray-400",
                      ].join(" ")}
                    >
                      {alert.confidence}%
                    </span>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-600">
                    {alert.timestamp}
                  </td>
                  <td className="px-4 py-3 text-xs text-gray-600">
                    {alert.mttd}s
                  </td>
                  <td className="px-4 py-3 text-xs text-gray-500">
                    {alert.camera}
                  </td>
                  <td className="px-4 py-3">
                    <AlertStatusBadge status={alert.status} />
                  </td>
                  <td className="px-4 py-3 text-xs text-gray-500 font-mono">
                    {alert.reviewedBy ?? "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </MainLayout>
  );
}
