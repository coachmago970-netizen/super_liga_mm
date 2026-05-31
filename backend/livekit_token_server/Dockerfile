FROM node:20-alpine AS base

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build
RUN npm prune --omit=dev

ENV NODE_ENV=production
EXPOSE 8080

CMD ["npm", "start"]
