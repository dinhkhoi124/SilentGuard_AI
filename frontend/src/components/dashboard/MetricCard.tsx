'use client'

import React from 'react'

interface MetricCardProps {
  title: string
  value: number | string
  subtitle: string
  highlight?: boolean
}

export default function MetricCard({
  title,
  value,
  subtitle,
  highlight = false,
}: MetricCardProps) {
  return (
    <div
      className={`rounded-xl p-5 shadow-sm border ${
        highlight
          ? 'bg-amber-50 border-amber-200'
          : 'bg-white border-gray-200'
      }`}
    >
      <p className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">
        {title}
      </p>
      <p
        className={`text-3xl font-bold leading-none mb-1 ${
          highlight ? 'text-orange-500' : 'text-gray-900'
        }`}
      >
        {value}
      </p>
      <p className="text-sm text-gray-500">{subtitle}</p>
    </div>
  )
}
