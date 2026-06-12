import 'dotenv/config'
import { prisma } from './db'

const BUSES = ['BUS-101', 'BUS-102', 'BUS-103', 'BUS-047', 'BUS-213', 'BUS-088', 'BUS-174']
const ROUTES: Record<string, string> = {
  'BUS-101': '32', 'BUS-102': '32', 'BUS-103': '15',
  'BUS-047': '15', 'BUS-213': '09', 'BUS-088': '27', 'BUS-174': '18',
}

function randomBetween(min: number, max: number) {
  return Math.random() * (max - min) + min
}

function randomTimestamp(daysBack: number) {
  const ms = Date.now() - randomBetween(0, daysBack * 24 * 60 * 60 * 1000)
  return new Date(ms)
}

async function seed() {
  console.log('🌱 Seeding database...')

  // ── Users ──────────────────────────────────────────────────────────
  const users = [
    { email: 'admin@vinbus.vn',    name: 'Admin VinBus',      role: 'admin' },
    { email: 'operator@vinbus.vn', name: 'Nguyễn Thị Lan',    role: 'operator' },
    { email: 'driver@vinbus.vn',   name: 'Trần Văn Tài',      role: 'driver', busId: 'BUS-102' },
  ]
  for (const u of users) {
    await prisma.user.upsert({ where: { email: u.email }, update: {}, create: u })
  }
  console.log(`  ✓ ${users.length} users`)

  // ── Events ─────────────────────────────────────────────────────────
  let created = 0
  for (let i = 0; i < 80; i++) {
    const bus = BUSES[Math.floor(Math.random() * BUSES.length)]
    const confidence = Math.round(randomBetween(0.28, 0.97) * 100) / 100
    const eventType = Math.random() > 0.45 ? 'fight' : 'fall'
    const timestamp = randomTimestamp(7)

    // Confidence zones (ADR-004)
    let status: string
    if (confidence < 0.4) {
      status = 'ignored'
    } else if (confidence < 0.7) {
      status = 'uncertain'
    } else {
      // alert đỏ: phần lớn đã được review
      const r = Math.random()
      status = r < 0.55 ? 'confirmed' : r < 0.75 ? 'rejected' : 'pending'
    }

    const event = await prisma.event.create({
      data: {
        busId: bus,
        routeId: ROUTES[bus],
        eventType,
        confidence,
        timestamp,
        status,
        aiModelVersion: 'mock-v0.1',
      },
    })

    // Tạo review cho event đã xử lý
    if (status === 'confirmed' || status === 'rejected') {
      await prisma.review.create({
        data: {
          eventId: event.id,
          reviewerId: 'operator@vinbus.vn',
          action: status === 'confirmed' ? 'confirm' : 'reject',
          learningSignal: true,
          reviewedAt: new Date(timestamp.getTime() + randomBetween(30000, 120000)),
        },
      })
    }
    created++
  }
  console.log(`  ✓ ${created} events (với reviews)`)
  console.log('\n✅ Seed hoàn thành!')

  await prisma.$disconnect()
}

seed().catch((e) => {
  console.error(e)
  process.exit(1)
})
