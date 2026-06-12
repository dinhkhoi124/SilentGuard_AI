import { Server } from 'socket.io'
import type { Server as HttpServer } from 'http'

let io: Server

export function initSocket(httpServer: HttpServer): Server {
  io = new Server(httpServer, {
    cors: {
      origin: process.env.FRONTEND_URL || 'http://localhost:3000',
      methods: ['GET', 'POST'],
    },
  })

  io.on('connection', (socket) => {
    console.log(`[Socket.io] connected  → ${socket.id}`)
    socket.on('disconnect', () =>
      console.log(`[Socket.io] disconnected → ${socket.id}`)
    )
  })

  console.log('[Socket.io] initialized')
  return io
}

export function getIO(): Server {
  if (!io) throw new Error('[Socket.io] not initialized — call initSocket first')
  return io
}
