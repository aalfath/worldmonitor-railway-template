#!/bin/sh
# Runs upstream's run-seeders.sh, then sleeps, forever.
set -u
: "${UPSTASH_REDIS_REST_URL:?UPSTASH_REDIS_REST_URL is required}"
: "${UPSTASH_REDIS_REST_TOKEN:?UPSTASH_REDIS_REST_TOKEN is required}"
INTERVAL="${SEED_INTERVAL_SECONDS:-1800}"

# Wait for the redis-rest proxy (401 without the token, 200 with it).
i=0
until node -e "fetch(process.env.UPSTASH_REDIS_REST_URL+'/ping',{headers:{Authorization:'Bearer '+process.env.UPSTASH_REDIS_REST_TOKEN}}).then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"; do
  i=$((i + 1))
  [ "$i" -ge 60 ] && { echo "[seeders] redis-rest still unreachable, running anyway"; break; }
  sleep 5
done

cycle=0
while true; do
  cycle=$((cycle + 1))
  echo "[seeders] cycle $cycle started $(date -u +%FT%TZ)"
  sh /app/scripts/run-seeders.sh
  echo "[seeders] cycle $cycle finished $(date -u +%FT%TZ); next in ${INTERVAL}s"
  sleep "$INTERVAL"
done
