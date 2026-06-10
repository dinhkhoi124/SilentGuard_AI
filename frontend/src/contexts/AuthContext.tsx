'use client'

import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
} from 'react'
import { useRouter } from 'next/navigation'
import type { User } from '@/lib/types'
import { mockUsers } from '@/lib/mock-data'

const STORAGE_KEY = 'vinbus_user_id'

interface AuthContextValue {
  user: User | null
  isLoading: boolean
  login: (userId: string) => void
  logout: () => void
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  // Restore session from localStorage on mount
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const savedId = localStorage.getItem(STORAGE_KEY)
      if (savedId) {
        const found = mockUsers.find((u) => u.id === savedId) ?? null
        setUser(found)
      }
    }
    setIsLoading(false)
  }, [])

  const login = useCallback((userId: string) => {
    const found = mockUsers.find((u) => u.id === userId) ?? null
    if (found) {
      if (typeof window !== 'undefined') {
        localStorage.setItem(STORAGE_KEY, found.id)
      }
      setUser(found)
    }
  }, [])

  const logout = useCallback(() => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem(STORAGE_KEY)
    }
    setUser(null)
    router.push('/login')
  }, [router])

  return (
    <AuthContext.Provider value={{ user, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext)
  if (ctx === undefined) {
    throw new Error('useAuth must be used inside <AuthProvider>')
  }
  return ctx
}
