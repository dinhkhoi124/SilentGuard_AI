'use client'

import React from 'react'
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  Legend,
} from 'recharts'
import type { DayData } from '@/lib/types'

interface AlertBarChartProps {
  data: DayData[]
}

export default function AlertBarChart({ data }: AlertBarChartProps) {
  return (
    <ResponsiveContainer width="100%" height={200}>
      <BarChart
        data={data}
        margin={{ top: 4, right: 4, left: 0, bottom: 0 }}
        barCategoryGap="30%"
        barGap={2}
      >
        <XAxis
          dataKey="date"
          tick={{ fontSize: 12, fill: '#6b7280' }}
          axisLine={false}
          tickLine={false}
        />
        <YAxis hide />
        <Tooltip
          contentStyle={{
            backgroundColor: '#fff',
            border: '1px solid #e5e7eb',
            borderRadius: '8px',
            fontSize: '12px',
          }}
          cursor={{ fill: 'rgba(0,0,0,0.04)' }}
        />
        <Legend
          verticalAlign="bottom"
          height={28}
          iconType="square"
          iconSize={10}
          wrapperStyle={{ fontSize: '12px', paddingTop: '8px' }}
          formatter={(value: string) =>
            value === 'fall' ? 'Fall' : 'Fight'
          }
        />
        <Bar dataKey="fall" name="fall" fill="#3b82f6" radius={[3, 3, 0, 0]} />
        <Bar dataKey="fight" name="fight" fill="#ef4444" radius={[3, 3, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  )
}
