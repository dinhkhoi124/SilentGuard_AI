import type { FastifyPluginAsync } from "fastify";
import { prisma } from "../db";

const alertsRouter: FastifyPluginAsync = async (fastify) => {
  // GET /api/alerts — active alerts (high-confidence, pending events)
  fastify.get<{
    Querystring: { limit?: string };
  }>("/alerts", async (req) => {
    const limit = Math.min(50, Math.max(1, Number(req.query.limit) || 10));

    const alerts = await prisma.event.findMany({
      where: {
        status: { in: ["pending", "uncertain"] },
        confidence: { gte: 0.4 },
      },
      orderBy: [{ confidence: "desc" }, { timestamp: "desc" }],
      take: limit,
      include: { review: true },
    });

    return { total: alerts.length, items: alerts };
  });

  // GET /api/alerts/count — badge count for UI
  fastify.get("/alerts/count", async () => {
    const count = await prisma.event.count({
      where: {
        status: { in: ["pending", "uncertain"] },
        confidence: { gte: 0.4 },
      },
    });
    return { count };
  });
};

export default alertsRouter;
