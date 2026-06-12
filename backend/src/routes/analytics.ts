import type { FastifyPluginAsync } from 'fastify'
import { prisma } from '../db'

const analyticsRouter: FastifyPluginAsync = async (fastify) => {

  // ── GET /api/dashboard/summary ──────────────────────────────────────
  fastify.get('/dashboard/summary', async (_request, reply) => {
    const [total, confirmed, rejected, pending, uncertain] = await Promise.all([
      prisma.event.count({ where: { status: { not: 'ignored' } } }),
      prisma.event.count({ where: { status: 'confirmed' } }),
      prisma.event.count({ where: { status: 'rejected' } }),
      prisma.event.count({ where: { status: 'pending' } }),
      prisma.event.count({ where: { status: 'uncertain' } }),
    ])

    // Top buses — lấy 200 event gần nhất để tổng hợp
    const recentEvents = await prisma.event.findMany({
      where: { status: { not: 'ignored' } },
      select: { busId: true, eventType: true, status: true, timestamp: true },
      orderBy: { timestamp: 'desc' },
      take: 200,
    })

    // Top buses
    const busCounts: Record<string, number> = {}
    for (const e of recentEvents) {
      busCounts[e.busId] = (busCounts[e.busId] ?? 0) + 1
    }
    const topBuses = Object.entries(busCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([busId, count]) => ({ busId, count }))

    // By type
    const byType = {
      fall: recentEvents.filter((e) => e.eventType === 'fall').length,
      fight: recentEvents.filter((e) => e.eventType === 'fight').length,
    }

    const falseAlarmRate =
      total > 0 ? Math.round((rejected / total) * 100) / 100 : 0

    return reply.send({
      total_alerts: total,
      confirmed,
      rejected,
      pending,
      uncertain,
      false_alarm_rate: falseAlarmRate,
      top_buses: topBuses,
      by_type: byType,
    })
  })

  // ── GET /api/analytics/timeseries ──────────────────────────────────
  fastify.get('/analytics/timeseries', async (request, reply) => {
    const { from, to } = request.query as Record<string, string>

    const fromDate = from
      ? new Date(from)
      : new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    const toDate = to ? new Date(to) : new Date()

    const events = await prisma.event.findMany({
      where: {
        timestamp: { gte: fromDate, lte: toDate },
        status: { not: 'ignored' },
      },
      select: { timestamp: true, eventType: true },
      orderBy: { timestamp: 'asc' },
    })

    // Group by day (YYYY-MM-DD)
    const groups: Record<string, { fall: number; fight: number }> = {}
    for (const e of events) {
      const key = e.timestamp.toISOString().slice(0, 10)
      if (!groups[key]) groups[key] = { fall: 0, fight: 0 }
      if (e.eventType === 'fall') groups[key].fall++
      else groups[key].fight++
    }

    const series = Object.entries(groups)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, counts]) => ({
        date,
        fall: counts.fall,
        fight: counts.fight,
        total: counts.fall + counts.fight,
      }))

    return reply.send({ series, from: fromDate, to: toDate })
  })

  // ── GET /api/analytics/buses ────────────────────────────────────────
  fastify.get('/analytics/buses', async (request, reply) => {
    const { from, to, route_id } = request.query as Record<string, string>

    const fromDate = from
      ? new Date(from)
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
    const toDate = to ? new Date(to) : new Date()

    const where: Record<string, unknown> = {
      timestamp: { gte: fromDate, lte: toDate },
      status: { not: 'ignored' },
    }
    if (route_id) where.routeId = route_id

    const events = await prisma.event.findMany({
      where,
      select: { busId: true, routeId: true, eventType: true, status: true },
    })

    const buses: Record<
      string,
      { routeId: string | null; fall: number; fight: number; confirmed: number; total: number }
    > = {}

    for (const e of events) {
      if (!buses[e.busId]) {
        buses[e.busId] = { routeId: e.routeId, fall: 0, fight: 0, confirmed: 0, total: 0 }
      }
      buses[e.busId].total++
      if (e.eventType === 'fall') buses[e.busId].fall++
      else buses[e.busId].fight++
      if (e.status === 'confirmed') buses[e.busId].confirmed++
    }

    const result = Object.entries(buses)
      .sort((a, b) => b[1].total - a[1].total)
      .map(([busId, s]) => ({
        busId,
        routeId: s.routeId,
        fall: s.fall,
        fight: s.fight,
        total: s.total,
        confirm_rate:
          s.total > 0 ? Math.round((s.confirmed / s.total) * 100) / 100 : 0,
      }))

    return reply.send({ buses: result, from: fromDate, to: toDate })
  })
}

export default analyticsRouter
