'use client'

import React from 'react'
import type { BusIncident } from '@/lib/types'

interface TopBusesListProps {
  buses: BusIncident[]
  maxCount: number
}

export default function TopBusesList({ buses, maxCount }: TopBusesListProps) {
  return (
    <div className="space-y-3">
      {buses.map((bus) => {
        const pct = maxCount > 0 ? (bus.count / maxCount) * 100 : 0
        return (
          <div key={bus.busId} className="flex items-center gap-3">
            <span className="text-sm font-medium text-gray-700 w-20 flex-shrink-0">
              {bus.busId}
            </span>
            <div className="flex-1 bg-gray-100 rounded-full h-2.5 overflow-hidden">
              <div
                className="bg-red-400 h-2.5 rounded-full transition-all duration-300"
                style={{ width: `${pct}%` }}
              />
            </div>
            <span className="text-sm font-semibold text-gray-700 w-6 text-right flex-shrink-0">
              {bus.count}
            </span>
          </div>
        )
      })}
    </div>
  )
}
