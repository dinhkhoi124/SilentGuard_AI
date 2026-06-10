'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Bus, Shield, Eye, Truck, CheckCircle } from 'lucide-react'
import { useAuth } from '@/contexts/AuthContext'
import { mockUsers } from '@/lib/mock-data'
import type { User } from '@/lib/types'

// ── role meta ────────────────────────────────────────────────────────────────
const roleMeta: Record<
  string,
  { icon: React.ReactNode; badge: string; badgeClass: string; description: string }
> = {
  '1': {
    icon: <Shield className="w-6 h-6 text-purple-600" />,
    badge: 'Admin',
    badgeClass: 'bg-purple-100 text-purple-700',
    description: 'Toàn quyền hệ thống',
  },
  '2': {
    icon: <Eye className="w-6 h-6 text-blue-600" />,
    badge: 'Operator',
    badgeClass: 'bg-blue-100 text-blue-700',
    description: 'Xác nhận & xử lý alert, Ca đêm',
  },
  '3': {
    icon: <Truck className="w-6 h-6 text-green-600" />,
    badge: 'Driver',
    badgeClass: 'bg-green-100 text-green-700',
    description: 'Nhận cảnh báo từ hệ thống, Ca đêm',
  },
}

// ── component ─────────────────────────────────────────────────────────────────
export default function LoginPage() {
  const router = useRouter()
  const { login } = useAuth()
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [isLoggingIn, setIsLoggingIn] = useState(false)

  const handleLogin = async () => {
    if (!selectedId) return
    setIsLoggingIn(true)

    login(selectedId)

    const selectedUser = mockUsers.find((u) => u.id === selectedId)
    if (selectedUser?.role === 'driver') {
      router.push('/driver')
    } else {
      router.push('/dashboard')
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md bg-white shadow-lg rounded-xl p-8">

        {/* ── Logo ── */}
        <div className="flex flex-col items-center mb-8">
          <div className="flex items-center gap-2 mb-2">
            <div className="bg-blue-600 text-white p-2 rounded-lg">
              <Bus className="w-6 h-6" />
            </div>
            <span className="text-xl font-bold text-gray-800">VinBus SafeWatch</span>
          </div>
          <p className="text-sm text-gray-500">Hệ thống giám sát an toàn hành khách</p>
        </div>

        {/* ── Account selector ── */}
        <div className="mb-6">
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
            Chọn tài khoản demo
          </p>

          <div className="flex flex-col gap-3">
            {mockUsers.map((user: User) => {
              const meta = roleMeta[user.id]
              const isSelected = selectedId === user.id

              return (
                <button
                  key={user.id}
                  type="button"
                  onClick={() => setSelectedId(user.id)}
                  className={[
                    'flex items-center gap-3 w-full text-left rounded-lg p-4 border-2 cursor-pointer transition-all duration-150',
                    isSelected
                      ? 'border-blue-500 bg-blue-50'
                      : 'border-gray-200 bg-white hover:border-blue-400 hover:bg-gray-50',
                  ].join(' ')}
                >
                  {/* Icon */}
                  <div className="flex-shrink-0">{meta.icon}</div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-0.5">
                      <span className="font-semibold text-gray-800 text-sm">{user.name}</span>
                      <span
                        className={`text-xs font-medium px-2 py-0.5 rounded-full ${meta.badgeClass}`}
                      >
                        {meta.badge}
                      </span>
                    </div>
                    <p className="text-xs text-gray-500 truncate">{meta.description}</p>
                  </div>

                  {/* Selected indicator */}
                  {isSelected && (
                    <CheckCircle className="w-5 h-5 text-blue-500 flex-shrink-0" />
                  )}
                </button>
              )
            })}
          </div>
        </div>

        {/* ── Login button ── */}
        <button
          type="button"
          onClick={handleLogin}
          disabled={!selectedId || isLoggingIn}
          className={[
            'w-full py-2.5 rounded-lg font-semibold text-sm transition-all duration-150',
            selectedId && !isLoggingIn
              ? 'bg-blue-600 hover:bg-blue-700 text-white cursor-pointer'
              : 'bg-gray-200 text-gray-400 cursor-not-allowed',
          ].join(' ')}
        >
          {isLoggingIn ? 'Đang đăng nhập…' : 'Đăng nhập'}
        </button>
      </div>
    </div>
  )
}
