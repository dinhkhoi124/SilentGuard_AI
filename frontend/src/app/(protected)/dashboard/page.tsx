'use client'

import React, { useState } from 'react'
import MainLayout from '@/components/layout/MainLayout'
import MetricCard from '@/components/dashboard/MetricCard'
import AlertBarChart from '@/components/dashboard/AlertBarChart'
import TopBusesList from '@/components/dashboard/TopBusesList'
import { mockDashboardStats } from '@/lib/mock-data'
import type { FilterPeriod } from '@/lib/types'

const periodLabels: Record<FilterPeriod, string> = {
  today: 'Hôm nay',
  week: 'Tuần',
  month: 'Tháng',
}

const titleByPeriod: Record<FilterPeriod, string> = {
  today: 'Tổng quan hôm nay',
  week: 'Tổng quan tuần này',
  month: 'Tổng quan tháng này',
}

export default function DashboardPage() {
  const [selectedPeriod, setSelectedPeriod] = useState<FilterPeriod>('today')
  const stats = mockDashboardStats
  const maxBusCount = stats.topBuses[0]?.count ?? 1

  return (
    <MainLayout title="Dashboard">
      {/* Period Filter */}
      <div className="flex items-center gap-2 mb-5">
        {(['today', 'week', 'month'] as FilterPeriod[]).map((period) => (
          <button
            key={period}
            onClick={() => setSelectedPeriod(period)}
            className={`px-4 py-1.5 rounded-lg text-sm font-medium border transition-colors ${
              selectedPeriod === period
                ? 'border-blue-500 text-blue-600 bg-blue-50'
                : 'border-gray-200 text-gray-500 hover:border-gray-300 hover:text-gray-700 bg-white'
            }`}
          >
            {periodLabels[period]}
          </button>
        ))}
      </div>

      {/* Page title */}
      <h2 className="text-xl font-semibold text-gray-900 mb-5">
        {titleByPeriod[selectedPeriod]}
      </h2>

      {/* Metric Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <MetricCard
          title="Tổng alert"
          value={stats.totalAlerts}
          subtitle={`+${stats.changeFromYesterday} so với hôm qua`}
        />
        <MetricCard
          title="Confirmed"
          value={stats.confirmed}
          subtitle={`${Math.round((stats.confirmed / stats.totalAlerts) * 100)}%`}
        />
        <MetricCard
          title="Rejected"
          value={stats.rejected}
          subtitle={`${Math.round((stats.rejected / stats.totalAlerts) * 100)}%`}
        />
        <MetricCard
          title="Pending"
          value={stats.pending}
          subtitle="cần xử lý"
          highlight
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {/* Bar Chart */}
        <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-5">
          <h3 className="text-sm font-semibold text-gray-700 mb-4">
            Alert theo ngày — Fall vs Fight
          </h3>
          <AlertBarChart data={stats.alertsByDay} />
        </div>

        {/* Top Buses */}
        <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-5">
          <h3 className="text-sm font-semibold text-gray-700 mb-4">
            Top xe sự cố
          </h3>
          <TopBusesList buses={stats.topBuses} maxCount={maxBusCount} />
        </div>
      </div>
    </MainLayout>
  )
}
