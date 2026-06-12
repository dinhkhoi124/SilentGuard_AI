'use client'

import { useState, useEffect } from 'react'
import { Clock } from 'lucide-react'
import { useAuth } from '@/contexts/AuthContext'

interface HeaderProps {
  title: string
}

function formatTime(date: Date): string {
  return date.toLocaleTimeString('vi-VN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })
}

export default function Header({ title }: HeaderProps) {
  const { user } = useAuth()
  const [currentTime, setCurrentTime] = useState<string>('')

  // Hydration-safe clock — initialise only on client
  useEffect(() => {
    setCurrentTime(formatTime(new Date()))

    // Update every 60 seconds, aligned to the next full minute
    const now = new Date()
    const msUntilNextMinute = (60 - now.getSeconds()) * 1000 - now.getMilliseconds()

    const initialTimeout = setTimeout(() => {
      setCurrentTime(formatTime(new Date()))
      const interval = setInterval(() => {
        setCurrentTime(formatTime(new Date()))
      }, 60_000)
      return () => clearInterval(interval)
    }, msUntilNextMinute)

    return () => clearTimeout(initialTimeout)
  }, [])

  return (
    <header className="h-14 bg-white border-b border-gray-200 px-6 flex items-center justify-between flex-shrink-0">
      {/* ── Left: page title ── */}
      <h1 className="font-semibold text-gray-800 text-base">{title}</h1>

      {/* ── Right: shift info + avatar ── */}
      <div className="flex items-center gap-4">
        {user && (
          <>
            {/* Shift + clock */}
            <div className="flex items-center gap-1.5 text-sm text-gray-500">
              <Clock className="w-3.5 h-3.5" />
              <span>{user.shift}</span>
              {currentTime && (
                <>
                  <span className="text-gray-300">·</span>
                  <span className="font-medium text-gray-700 tabular-nums">{currentTime}</span>
                </>
              )}
            </div>

            {/* Avatar */}
            <div className="w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-xs font-bold select-none">
              {user.avatar}
            </div>
          </>
        )}
      </div>
    </header>
  )
}
