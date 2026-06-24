# ---- Base Stage ----
FROM node:22-alpine AS base
WORKDIR /app
COPY landing_page/package*.json ./

# ---- Dependencies Stage ----
FROM base AS dependencies
RUN npm install

# ---- Build Stage ----
FROM dependencies AS builder
COPY landing_page/ ./
RUN npm run build

# ---- Production Stage ----
FROM node:22-alpine AS runner
WORKDIR /app
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

EXPOSE 3000
ENV PORT=3000
ENV HOST=0.0.0.0
ENV PATH="/app/node_modules/.bin:$PATH"

CMD ["vinxi", "start", "--port", "3000", "--host", "0.0.0.0"]
