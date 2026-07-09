"use client";

import React from "react";
import { Users, Shield, Eye, Truck } from "lucide-react";
import MainLayout from "@/components/layout/MainLayout";
import { mockUsers } from "@/lib/mock-data";
import type { Role } from "@/lib/types";

const roleConfig: Record<
  Role,
  { label: string; Icon: React.ElementType; cls: string }
> = {
  admin: {
    label: "Admin",
    Icon: Shield,
    cls: "bg-purple-100 text-purple-700 border-purple-200",
  },
  operator: {
    label: "Operator",
    Icon: Eye,
    cls: "bg-blue-100 text-blue-700 border-blue-200",
  },
  driver: {
    label: "Driver",
    Icon: Truck,
    cls: "bg-green-100 text-green-700 border-green-200",
  },
};

export default function UsersPage() {
  return (
    <MainLayout title="Quản lý User">
      {/* Header */}
      <div className="flex items-center justify-between mb-5">
        <div className="flex items-center gap-2 text-sm text-gray-500">
          <Users className="w-4 h-4 text-blue-600" />
          <span>{mockUsers.length} người dùng</span>
        </div>
        <button
          disabled
          title="Tính năng demo"
          className="px-4 py-2 text-sm font-semibold bg-blue-600 text-white rounded-lg opacity-40 cursor-not-allowed"
        >
          + Thêm user
        </button>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50 text-xs font-semibold text-gray-500 uppercase tracking-wider">
              <th className="text-left px-5 py-3">Người dùng</th>
              <th className="text-left px-5 py-3">Vai trò</th>
              <th className="text-left px-5 py-3">Ca làm việc</th>
              <th className="text-left px-5 py-3">ID</th>
              <th className="text-right px-5 py-3">Hành động</th>
            </tr>
          </thead>
          <tbody>
            {mockUsers.map((user, i) => {
              const { label, Icon, cls } = roleConfig[user.role];
              return (
                <tr
                  key={user.id}
                  className={[
                    "hover:bg-gray-50 transition-colors border-b border-gray-50",
                    i % 2 === 1 ? "bg-gray-50/40" : "",
                  ].join(" ")}
                >
                  {/* Name + avatar */}
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">
                        {user.avatar}
                      </div>
                      <span className="font-medium text-gray-800">
                        {user.name}
                      </span>
                    </div>
                  </td>

                  {/* Role badge */}
                  <td className="px-5 py-4">
                    <span
                      className={`inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1 rounded-full border ${cls}`}
                    >
                      <Icon className="w-3 h-3" />
                      {label}
                    </span>
                  </td>

                  {/* Shift */}
                  <td className="px-5 py-4 text-gray-600">{user.shift}</td>

                  {/* ID */}
                  <td className="px-5 py-4 font-mono text-xs text-gray-400">
                    #{user.id}
                  </td>

                  {/* Actions */}
                  <td className="px-5 py-4 text-right">
                    <button
                      disabled
                      title="Tính năng demo"
                      className="text-xs text-gray-400 cursor-not-allowed"
                    >
                      Chỉnh sửa
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <p className="text-xs text-gray-400 mt-4 text-center">
        Chế độ demo — chỉnh sửa user không khả dụng
      </p>
    </MainLayout>
  );
}
