export type Role = 'admin' | 'operator' | 'driver'
export type EventType = 'Fall' | 'Fight'
export type AlertStatus = 'pending' | 'confirmed' | 'rejected'
export type FilterPeriod = 'today' | 'week' | 'month'
export type AlertFilter = 'all' | 'pending' | 'fight' | 'fall'

export interface User {
  id: string
  name: string
  role: Role
  avatar: string   // 2-letter initials
  shift: string
}

export interface Alert {
  id: string
  busId: string
  route: string
  eventType: EventType
  confidence: number
  timestamp: string
  status: AlertStatus
  mttd: number
  camera: string
  description: string
  reviewNote?: string
  reviewedBy?: string
  reviewedAt?: string
}

export interface DayData {
  date: string
  fall: number
  fight: number
}

export interface BusIncident {
  busId: string
  count: number
}

export interface DashboardStats {
  totalAlerts: number
  confirmed: number
  rejected: number
  pending: number
  changeFromYesterday: number
  alertsByDay: DayData[]
  topBuses: BusIncident[]
}
