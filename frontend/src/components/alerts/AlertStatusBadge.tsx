'use client'

import type { AlertStatus } from '@/lib/types'

const styles: Record<AlertStatus, { label: string; cls: string }> = {
  pending: {
    label: 'Pending',
    cls: 'bg-amber-100 text-amber-700 border border-amber-200',
  },
  confirmed: {
    label: 'Confirmed',
    cls: 'bg-green-100 text-green-700 border border-green-200',
  },
  rejected: {
    label: 'Rejected',
    cls: 'bg-gray-100 text-gray-500 border border-gray-200',
  },
}

interface AlertStatusBadgeProps {
  status: AlertStatus
  size?: 'sm' | 'md'
}

export default function AlertStatusBadge({ status, size = 'sm' }: AlertStatusBadgeProps) {
  const { label, cls } = styles[status]
  const sizeClass = size === 'md' ? 'text-sm px-3 py-1' : 'text-xs px-2 py-0.5'
  return (
    <span
      className={`inline-flex items-center font-semibold rounded-full ${sizeClass} ${cls}`}
    >
      {label}
    </span>
  )
}
