'use client'

import type { EventType } from '@/lib/types'

const styles: Record<EventType, { label: string; cls: string }> = {
  Fight: {
    label: 'Fight',
    cls: 'bg-red-100 text-red-700 border border-red-200',
  },
  Fall: {
    label: 'Fall',
    cls: 'bg-orange-100 text-orange-700 border border-orange-200',
  },
}

interface EventTypeBadgeProps {
  type: EventType
  size?: 'sm' | 'md'
}

export default function EventTypeBadge({ type, size = 'sm' }: EventTypeBadgeProps) {
  const { label, cls } = styles[type]
  const sizeClass = size === 'md' ? 'text-sm px-3 py-1' : 'text-xs px-2 py-0.5'
  return (
    <span
      className={`inline-flex items-center gap-1 font-semibold rounded-full ${sizeClass} ${cls}`}
    >
      {type === 'Fight' ? '⚔' : '↓'} {label}
    </span>
  )
}
