FROM node:22-alpine
WORKDIR /app
COPY landing_page/package*.json ./
RUN npm install --include=dev
COPY landing_page/ ./
RUN npm run build
EXPOSE 3000
ENV PORT=3000
ENV HOST=0.0.0.0
CMD ["node", "dist/server/server.js"]
