import type { FastifyPluginAsync } from "fastify";
import { prisma } from "../db";
import { getIO } from "../socket";

const eventsRouter: FastifyPluginAsync = async (fastify) => {
  // GET /api/events — list with pagination & filters
  fastify.get<{
    Querystring: {
      page?: string;
      limit?: string;
      status?: string;
      eventType?: string;
      busId?: string;
    };
  }>("/events", async (req) => {
    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = {};
    if (req.query.status) where.status = req.query.status;
    if (req.query.eventType) where.eventType = req.query.eventType;
    if (req.query.busId) where.busId = req.query.busId;

    const [total, items] = await Promise.all([
      prisma.event.count({ where }),
      prisma.event.findMany({
        where,
        orderBy: { timestamp: "desc" },
        skip,
        take: limit,
        include: { review: true },
      }),
    ]);

    return { total, page, limit, items };
  });

  // GET /api/events/:id
  fastify.get<{ Params: { id: string } }>("/events/:id", async (req, reply) => {
    const event = await prisma.event.findUnique({
      where: { id: req.params.id },
      include: { review: true },
    });
    if (!event) return reply.code(404).send({ error: "Event not found" });
    return event;
  });

  // POST /api/events — ingest a new AI event
  fastify.post<{
    Body: {
      busId: string;
      routeId?: string;
      driverId?: string;
      eventType: string;
      confidence: number;
      timestamp: string;
      clipUrl?: string;
      aiModelVersion?: string;
      locationLat?: number;
      locationLng?: number;
    };
  }>("/events", async (req, reply) => {
    const {
      busId,
      routeId,
      driverId,
      eventType,
      confidence,
      timestamp,
      clipUrl,
      aiModelVersion,
      locationLat,
      locationLng,
    } = req.body;

    if (!busId || !eventType || confidence == null || !timestamp) {
      return reply
        .code(400)
        .send({
          error:
            "Missing required fields: busId, eventType, confidence, timestamp",
        });
    }

    // Auto-status based on confidence zones (ADR-004)
    let status = "pending";
    if (confidence < 0.4) status = "ignored";
    else if (confidence < 0.7) status = "uncertain";

    const event = await prisma.event.create({
      data: {
        busId,
        routeId,
        driverId,
        eventType,
        confidence,
        timestamp: new Date(timestamp),
        clipUrl,
        status,
        aiModelVersion,
        locationLat,
        locationLng,
      },
    });

    // Broadcast to all connected clients
    try {
      getIO().emit("new_event", event);
    } catch {
      // Socket.io not yet initialized (startup race) — safe to ignore
    }

    return reply.code(201).send(event);
  });

  // PATCH /api/events/:id/review — operator reviews an event
  fastify.patch<{
    Params: { id: string };
    Body: {
      reviewerId: string;
      action: "confirm" | "reject" | "escalate";
      note?: string;
      learningSignal?: boolean;
      videoTimestamp?: number;
    };
  }>("/events/:id/review", async (req, reply) => {
    const { reviewerId, action, note, learningSignal, videoTimestamp } =
      req.body;

    if (!reviewerId || !action) {
      return reply
        .code(400)
        .send({ error: "Missing required fields: reviewerId, action" });
    }

    const event = await prisma.event.findUnique({
      where: { id: req.params.id },
    });
    if (!event) return reply.code(404).send({ error: "Event not found" });

    const newStatus =
      action === "confirm"
        ? "confirmed"
        : action === "reject"
          ? "rejected"
          : "escalated";

    const [updatedEvent, review] = await prisma.$transaction([
      prisma.event.update({
        where: { id: req.params.id },
        data: { status: newStatus },
      }),
      prisma.review.upsert({
        where: { eventId: req.params.id },
        create: {
          eventId: req.params.id,
          reviewerId,
          action,
          note,
          learningSignal: learningSignal ?? true,
          videoTimestamp,
        },
        update: {
          reviewerId,
          action,
          note,
          learningSignal: learningSignal ?? true,
          videoTimestamp,
          reviewedAt: new Date(),
        },
      }),
    ]);

    try {
      getIO().emit("event_reviewed", { event: updatedEvent, review });
    } catch {
      // safe to ignore
    }

    return { event: updatedEvent, review };
  });
};

export default eventsRouter;
