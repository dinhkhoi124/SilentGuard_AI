'use client'

import React, { useState } from 'react'
import { AlertTriangle } from 'lucide-react'
import type { Alert, AlertFilter, Role } from '@/lib/types'

interface AlertTableProps {
  alerts: Alert[]
  onView: (id: string) => void
  userRole: Role
}

const statusBadge: Record<string, string> = {
  pending: 'bg-amber-100 text-amber-700',
  confirmed: 'bg-green-100 text-green-700',
  rejected: 'bg-gray-100 text-gray-600',
}

const rowBorder: Record<string, string> = {
  pending: 'border-l-4 border-l-orange-400',
  confirmed: 'border-l-4 border-l-green-400',
  rejected: 'border-l-4 border-l-gray-300',
}

function ConfidenceBar({ value }: { value: number }) {
  const color =
    value >= 80
      ? 'bg-blue-500'
      : value >= 40
      ? 'bg-amber-400'
      : 'bg-red-500'

  return (
    <div className="flex items-center gap-2">
      <div className="w-20 bg-gray-100 rounded-full h-1.5 overflow-hidden flex-shrink-0">
        <div
          className={`${color} h-1.5 rounded-full`}
          style={{ width: `${value}%` }}
        />
      </div>
      <span className="text-xs text-gray-600 font-medium">{value}%</span>
    </div>
  )
}

export default function AlertTable({ alerts, onView, userRole }: AlertTableProps) {
  const [activeFilter, setActiveFilter] = useState<AlertFilter>('all')

  const pendingCount = alerts.filter((a) => a.status === 'pending').length

  const filtered = alerts.filter((a) => {
    if (activeFilter === 'all') return true
    if (activeFilter === 'pending') return a.status === 'pending'
    if (activeFilter === 'fight') return a.eventType === 'Fight'
    if (activeFilter === 'fall') return a.eventType === 'Fall'
    return true
  })

  const tabs: { key: AlertFilter; label: string }[] = [
    { key: 'all', label: 'Tất cả' },
    { key: 'pending', label: `Pending (${pendingCount})` },
    { key: 'fight', label: 'Fight' },
    { key: 'fall', label: 'Fall' },
  ]

  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
      {/* Filter Tabs */}
      <div className="flex items-center gap-1 px-4 pt-4 pb-0 border-b border-gray-100">
        {tabs.map((tab) => {
          const isActive = activeFilter === tab.key
          const isPendingTab = tab.key === 'pending'
          return (
            <button
              key={tab.key}
              onClick={() => setActiveFilter(tab.key)}
              className={`px-4 py-2 text-sm font-medium rounded-t-lg border-b-2 transition-colors ${
                isActive
                  ? isPendingTab
                    ? 'border-b-orange-400 text-orange-600 bg-orange-50'
                    : 'border-b-blue-500 text-blue-600 bg-blue-50'
                  : 'border-b-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {tab.label}
            </button>
          )
        })}
      </div>

      {/* Table */}
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 border-b border-gray-100">
              <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                Thời gian
              </th>
              <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                Xe
              </th>
              <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                Loại
              </th>
              <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                Confidence
              </th>
              <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                Trạng thái
              </th>
              <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                Hành động
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-gray-400 text-sm">
                  Không có alert nào
                </td>
              </tr>
            ) : (
              filtered.map((alert) => (
                <tr
                  key={alert.id}
                  className={`${rowBorder[alert.status]} hover:bg-gray-50 transition-colors`}
                >
                  {/* Time */}
                  <td className="px-4 py-3 text-gray-700 font-mono text-xs">
                    <div className="font-semibold text-gray-900">{alert.timestamp}</div>
                    <div className="text-gray-400 text-xs">{alert.id}</div>
                  </td>

                  {/* Bus */}
                  <td className="px-4 py-3">
                    <div className="font-semibold text-gray-900">{alert.busId}</div>
                    <div className="text-xs text-gray-400">{alert.route}</div>
                  </td>

                  {/* Type */}
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex items-center text-xs font-semibold px-2 py-0.5 rounded ${
                        alert.eventType === 'Fight'
                          ? 'text-red-600 bg-red-50'
                          : 'text-blue-600 bg-blue-50'
                      }`}
                    >
                      {alert.eventType}
                    </span>
                  </td>

                  {/* Confidence */}
                  <td className="px-4 py-3">
                    <ConfidenceBar value={alert.confidence} />
                  </td>

                  {/* Status */}
                  <td className="px-4 py-3">
                    <span
                      className={`inline-block text-xs font-semibold px-2.5 py-1 rounded-full ${statusBadge[alert.status]}`}
                    >
                      {alert.status}
                    </span>
                  </td>

                  {/* Action */}
                  <td className="px-4 py-3">
                    {userRole !== 'driver' && (
                      <>
                        {alert.status === 'pending' ? (
                          <button
                            onClick={() => onView(alert.id)}
                            className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white text-xs font-medium rounded-lg transition-colors"
                          >
                            Xem
                          </button>
                        ) : (
                          <button
                            onClick={() => onView(alert.id)}
                            className="px-3 py-1.5 border border-gray-300 hover:border-gray-400 text-gray-600 hover:text-gray-800 text-xs font-medium rounded-lg transition-colors"
                          >
                            Xem log
                          </button>
                        )}
                      </>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Footer Note */}
      <div className="px-4 py-3 border-t border-gray-100 bg-amber-50 flex items-start gap-2">
        <AlertTriangle size={14} className="text-amber-500 mt-0.5 flex-shrink-0" />
        <p className="text-xs text-amber-700">
          Alert confidence 40–70%: AI không chắc chắn — Operator cần xem kỹ clip trước khi quyết định
        </p>
      </div>
    </div>
  )
}
