# syntax=docker/dockerfile:1.7
FROM node:22-alpine AS build
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
RUN corepack enable
WORKDIR /workspace
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json eslint.config.mjs .npmrc ./
COPY services/api/package.json services/api/package.json
COPY packages/api-types/package.json packages/api-types/package.json
RUN pnpm install --frozen-lockfile
COPY services/api services/api
COPY packages/api-types packages/api-types
RUN pnpm --filter @pakt/api build
RUN pnpm --filter @pakt/api deploy --prod /opt/pakt-api

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
USER node
COPY --from=build --chown=node:node /opt/pakt-api ./
EXPOSE 4000
CMD ["node", "dist/server.js"]
