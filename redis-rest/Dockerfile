# Upstash-compatible REST proxy in front of Redis, from the pinned upstream
# release commit (upstream docker/Dockerfile.redis-rest, with redis@4 pinned).
ARG NODE_IMAGE=node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3

FROM ${NODE_IMAGE} AS source
# World Monitor v2.11.8 = commit de602d000d9e10e7da651884bb589d2ad55f3593
ARG WM_COMMIT=de602d000d9e10e7da651884bb589d2ad55f3593
RUN apk add --no-cache git \
 && git init -q /src && cd /src \
 && git fetch -q --depth 1 https://github.com/koala73/worldmonitor.git "$WM_COMMIT" \
 && git checkout -q FETCH_HEAD && rm -r .git

FROM ${NODE_IMAGE}
WORKDIR /app
RUN npm init -y >/dev/null && npm install --no-audit --no-fund redis@4.7.1
COPY --from=source /src/docker/redis-rest-proxy.mjs .
# Listen on IPv6 + IPv4 so Railway's private network reaches it.
ENV SRH_BIND_HOST=:: \
    PORT=8079
EXPOSE 8079
CMD ["node", "redis-rest-proxy.mjs"]
