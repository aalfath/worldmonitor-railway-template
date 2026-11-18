# World Monitor seeders: upstream's scripts/run-seeders.sh in a loop.
# Upstream runs the seed scripts from the host on a cron; Railway has no host,
# so this service runs them every SEED_INTERVAL_SECONDS and writes the data
# into Redis through the redis-rest proxy on the private network.
ARG NODE_IMAGE=node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3

FROM ${NODE_IMAGE} AS source
# World Monitor v2.11.8 = commit de602d000d9e10e7da651884bb589d2ad55f3593
ARG WM_COMMIT=de602d000d9e10e7da651884bb589d2ad55f3593
RUN apk add --no-cache git \
 && git init -q /src && cd /src \
 && git fetch -q --depth 1 https://github.com/koala73/worldmonitor.git "$WM_COMMIT" \
 && git checkout -q FETCH_HEAD && rm -r .git \
 && node scripts/generate-inventory-facts.mjs

FROM ${NODE_IMAGE}
RUN apk add --no-cache coreutils curl
WORKDIR /app
COPY --from=source /src/scripts/package.json /src/scripts/package-lock.json ./scripts/
RUN npm ci --prefix scripts --omit=dev --omit=optional --ignore-scripts
COPY --from=source /src/scripts/ ./scripts/
COPY --from=source /src/shared/ ./shared/
COPY --from=source /src/server/ ./server/
COPY --from=source /src/data/ ./data/
COPY --from=source /src/api/ ./api/
COPY --from=source /src/src/ ./src/
COPY --from=source /src/tsconfig.json /src/tsconfig.api.json ./
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh
ENV NODE_OPTIONS="--dns-result-order=ipv4first" \
    SEED_INTERVAL_SECONDS=1800 \
    SEED_TIMEOUT=300
CMD ["/app/run.sh"]
