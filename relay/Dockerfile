# World Monitor relay (AIS vessel stream, market/RSS relay, in-process seed
# loops), from the pinned upstream release commit. Upstream's Dockerfile.relay
# copies a hand-picked subset of scripts/; we keep all of scripts/, shared/ and
# data/ so a version bump can't miss a newly needed file.
FROM node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3 AS source
# World Monitor v2.11.8 = commit de602d000d9e10e7da651884bb589d2ad55f3593
ARG WM_COMMIT=de602d000d9e10e7da651884bb589d2ad55f3593
RUN mkdir /src && cd /src \
 && wget -q -O- "https://codeload.github.com/koala73/worldmonitor/tar.gz/$WM_COMMIT" | tar xz --strip-components=1 \
 && node scripts/generate-inventory-facts.mjs

FROM node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3
RUN apk add --no-cache curl
WORKDIR /app
COPY --from=source /src/scripts/package.json /src/scripts/package-lock.json ./scripts/
RUN npm ci --prefix scripts --omit=dev --omit=optional --ignore-scripts
COPY --from=source /src/scripts/ ./scripts/
COPY --from=source /src/shared/ ./shared/
COPY --from=source /src/data/ ./data/
# Fixed settings: listen on IPv6 + IPv4 (Railway private network), and allow
# the plain-HTTP redis-rest proxy on the private network.
ENV RELAY_BIND_HOST=:: \
    UPSTASH_ALLOW_INSECURE_HTTP=true \
    MARKET_YAHOO_REFRESH_INTERVAL_MS=900000 \
    PORT=3004
EXPOSE 3004
CMD ["node", "scripts/ais-relay.cjs"]
