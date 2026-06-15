'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  Bus,
  LayoutDashboard,
  Bell,
  FileText,
  Users,
  Settings,
  LogOut,
  Shield,
} from 'lucide-react'
import { useAuth } from '@/contexts/AuthContext'
import type { Role } from '@/lib/types'

// ── nav item definition ───────────────────────────────────────────────────────
interface NavItem {
  href: string
  label: string
  icon: React.ReactNode
  roles: Role[]
  badge?: string
}

const NAV_ITEMS: NavItem[] = [
  {
    href: '/dashboard',
    label: 'Dashboard',
    icon: <LayoutDashboard className="w-4 h-4" />,
    roles: ['admin', 'operator', 'driver'],
  },
  {
    href: '/alerts',
    label: 'Alerts',
    icon: <Bell className="w-4 h-4" />,
    roles: ['admin', 'operator', 'driver'],
    badge: '3',
  },
  {
    href: '/fleet',
    label: 'Fleet',
    icon: <Bus className="w-4 h-4" />,
    roles: ['admin', 'operator'],
  },
  {
    href: '/event-log',
    label: 'Event Log',
    icon: <FileText className="w-4 h-4" />,
    roles: ['admin', 'operator'],
  },
  {
    href: '/users',
    label: 'Quản lý user',
    icon: <Users className="w-4 h-4" />,
    roles: ['admin'],
  },
  {
    href: '/settings',
    label: 'Cài đặt',
    icon: <Settings className="w-4 h-4" />,
    roles: ['admin'],
  },
]

// ── role badge styling ────────────────────────────────────────────────────────
const roleBadgeClass: Record<Role, string> = {
  admin: 'bg-purple-100 text-purple-700',
  operator: 'bg-blue-100 text-blue-700',
  driver: 'bg-green-100 text-green-700',
}

const roleLabel: Record<Role, string> = {
  admin: 'Admin',
  operator: 'Operator',
  driver: 'Driver',
}

// ── component ─────────────────────────────────────────────────────────────────
export default function Sidebar() {
  const { user, logout } = useAuth()
  const pathname = usePathname()

  if (!user) return null

  const visibleItems = NAV_ITEMS.filter((item) => item.roles.includes(user.role))

  // badge is only meaningful for admin / operator
  const showBadge = (item: NavItem) =>
    item.badge !== undefined && (user.role === 'admin' || user.role === 'operator')

  return (
    <aside className="w-60 bg-white border-r border-gray-200 h-screen flex flex-col flex-shrink-0">

      {/* ── Logo ── */}
      <div className="flex items-center gap-2 p-4 border-b border-gray-200">
        <div className="bg-blue-600 text-white p-1.5 rounded-md flex-shrink-0">
          <Shield className="w-4 h-4" />
        </div>
        <span className="font-bold text-gray-800 text-sm leading-tight">VinBus SafeWatch</span>
      </div>

      {/* ── Nav items ── */}
      <nav className="flex-1 p-4 overflow-y-auto">
        <ul className="flex flex-col gap-1">
          {visibleItems.map((item) => {
            const isActive = pathname === item.href || pathname.startsWith(item.href + '/')
            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={[
                    'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors duration-100',
                    isActive
                      ? 'bg-blue-600 text-white'
                      : 'text-gray-600 hover:bg-gray-100',
                  ].join(' ')}
                >
                  {item.icon}
                  <span className="flex-1">{item.label}</span>

                  {/* Alert badge */}
                  {showBadge(item) && (
                    <span
                      className={[
                        'text-xs font-bold px-1.5 py-0.5 rounded-full min-w-[20px] text-center',
                        isActive
                          ? 'bg-white text-blue-600'
                          : 'bg-red-500 text-white',
                      ].join(' ')}
                    >
                      {item.badge}
                    </span>
                  )}
                </Link>
              </li>
            )
          })}
        </ul>
      </nav>

      {/* ── User info ── */}
      <div className="border-t border-gray-200 p-4">
        <div className="flex items-center gap-3">
          {/* Avatar */}
          <div className="w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">
            {user.avatar}
          </div>

          {/* Name + role */}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-gray-800 truncate">{user.name}</p>
            <span
              className={`text-xs font-medium px-1.5 py-0.5 rounded-full ${roleBadgeClass[user.role]}`}
            >
              {roleLabel[user.role]}
            </span>
          </div>

          {/* Logout */}
          <button
            type="button"
            onClick={logout}
            title="Đăng xuất"
            className="text-gray-400 hover:text-red-500 transition-colors duration-150 flex-shrink-0"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  )
}
