# World Monitor seeders: upstream's scripts/run-seeders.sh in a loop.
# Upstream runs the seed scripts from the host on a cron; Railway has no host,
# so this service runs them every SEED_INTERVAL_SECONDS and writes the data
# into Redis through the redis-rest proxy on the private network.
FROM node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3 AS source
# World Monitor v2.11.8 = commit de602d000d9e10e7da651884bb589d2ad55f3593
ARG WM_COMMIT=de602d000d9e10e7da651884bb589d2ad55f3593
RUN mkdir /src && cd /src \
 && wget -q -O- "https://codeload.github.com/koala73/worldmonitor/tar.gz/$WM_COMMIT" | tar xz --strip-components=1 \
 && node scripts/generate-inventory-facts.mjs

FROM node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3
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
    SEED_TIMEOUT=300 \
    SEED_PARALLEL=4
CMD ["/app/run.sh"]
