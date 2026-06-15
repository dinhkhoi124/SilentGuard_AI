import 'dotenv/config'
import Fastify from 'fastify'
import cors from '@fastify/cors'
import { initSocket } from './socket'
import eventsRouter from './routes/events'
import alertsRouter from './routes/alerts'
import analyticsRouter from './routes/analytics'

const fastify = Fastify({ logger: process.env.NODE_ENV !== 'production' })

async function bootstrap() {
  // CORS
  await fastify.register(cors, {
    origin: process.env.FRONTEND_URL || 'http://localhost:3000',
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  })

  // Routes
  await fastify.register(eventsRouter, { prefix: '/api' })
  await fastify.register(alertsRouter, { prefix: '/api' })
  await fastify.register(analyticsRouter, { prefix: '/api' })

  // Health check
  fastify.get('/health', async () => ({
    status: 'ok',
    ts: new Date().toISOString(),
    env: process.env.NODE_ENV,
  }))

  const PORT = Number(process.env.PORT) || 3001

  await fastify.listen({ port: PORT, host: '0.0.0.0' })

  // Attach Socket.io AFTER fastify is listening
  initSocket(fastify.server)

  console.log(`\n🚀 Backend running → http://localhost:${PORT}`)
  console.log(`📡 Socket.io ready`)
  console.log(`🔍 Health check → http://localhost:${PORT}/health\n`)
}

bootstrap().catch((err) => {
  console.error(err)
  process.exit(1)
})
