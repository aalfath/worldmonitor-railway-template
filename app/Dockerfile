# World Monitor web app (nginx + API sidecar), built from the pinned upstream
# release commit. Mirrors upstream's root Dockerfile at that commit.
# Upstream publishes no release-tagged image of the self-hosted stack
# (ghcr.io/koala73/worldmonitor:<version> is the cloud-proxy frontend only),
# so we build from source at a fixed commit.
FROM node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3 AS source
# World Monitor v2.11.8 = commit de602d000d9e10e7da651884bb589d2ad55f3593
ARG WM_COMMIT=de602d000d9e10e7da651884bb589d2ad55f3593
RUN mkdir /src && cd /src \
 && wget -q -O- "https://codeload.github.com/koala73/worldmonitor/tar.gz/$WM_COMMIT" | tar xz --strip-components=1

FROM node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3 AS builder
WORKDIR /app
ENV npm_config_install_links=true
COPY --from=source /src/ ./
RUN npm ci --ignore-scripts
RUN npm run build:crawlable-corpus && npm run build:sitemap
RUN node scripts/generate-inventory-facts.mjs
RUN node docker/build-handlers.mjs
RUN npm run build:pro
RUN npx tsc && npx vite build
RUN test -s dist/pro/index.html && test -s dist/pro/welcome.html

FROM node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3 AS runtime-deps
WORKDIR /app
COPY --from=source /src/docker/runtime-package.json ./package.json
COPY --from=source /src/docker/runtime-package-lock.json ./package-lock.json
RUN npm ci --omit=dev --omit=optional --ignore-scripts

FROM node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3 AS final
RUN apk add --no-cache nginx supervisor gettext && \
    mkdir -p /tmp/nginx-client-body /tmp/nginx-proxy /tmp/nginx-fastcgi \
             /tmp/nginx-uwsgi /tmp/nginx-scgi /var/log/supervisor && \
    addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/src-tauri/sidecar/local-api-server.mjs ./local-api-server.mjs
COPY --from=builder /app/src-tauri/sidecar/package.json ./package.json
COPY --from=builder /app/shared/llm-health-providers.js ./shared/llm-health-providers.js
COPY --from=builder /app/shared/desktop-key-access.js ./shared/desktop-key-access.js
COPY --from=builder /app/shared/selfhost-relay-paths.js ./shared/selfhost-relay-paths.js
ENV LOCAL_API_RESOURCE_DIR=/app
COPY --from=runtime-deps /app/node_modules ./node_modules
COPY --from=builder /app/api ./api
COPY --from=builder /app/data ./data
COPY --from=builder /app/dist /usr/share/nginx/html
COPY --from=source /src/docker/nginx.conf /etc/nginx/nginx.conf.template
COPY --from=source /src/docker/supervisord.conf /etc/supervisor/conf.d/worldmonitor.conf
COPY --from=source /src/docker/entrypoint.sh /app/entrypoint.sh
COPY --from=source /src/docker/render-nginx-realip.mjs /app/render-nginx-realip.mjs
COPY --from=source /src/docker/validate-session-secret.mjs /app/validate-session-secret.mjs
# Railway wrapper: also listen on IPv6 so the other services can reach the app
# over Railway's private network (the build fails if upstream moves the line).
RUN grep -q '^    listen 8080;$' /etc/nginx/nginx.conf.template \
 && sed -i 's/^    listen 8080;$/    listen 8080;\n    listen [::]:8080;/' /etc/nginx/nginx.conf.template \
 && grep -q 'listen \[::\]:8080;' /etc/nginx/nginx.conf.template \
 && chmod +x /app/entrypoint.sh \
 && chown -R appuser:appgroup /app /tmp/nginx-client-body /tmp/nginx-proxy \
    /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi /var/log/supervisor \
    /var/lib/nginx /var/log/nginx
# Fixed settings for a Railway install (always served over HTTPS, no cloud fallback).
ENV LOCAL_API_MODE=docker \
    LOCAL_API_PORT=46123 \
    LOCAL_API_CLOUD_FALLBACK=false \
    WORLDMONITOR_PUBLIC_HTTPS=1
USER appuser
EXPOSE 8080
CMD ["/app/entrypoint.sh"]
