FROM node:20-bookworm-slim
WORKDIR /app
COPY applications/frontend/package*.json ./
RUN npm ci --omit=dev
COPY applications/frontend/server.js ./server.js
COPY applications/frontend/views ./views
COPY applications/frontend/public ./public
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
CMD ["node", "server.js"]
