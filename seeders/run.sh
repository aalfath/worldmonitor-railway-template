#!/bin/sh
# World Monitor seeders for Railway.
# Upstream self-hosting runs scripts/seed-*.mjs from the host on a cron.
# Railway has no host, so this loop does it inside the project: each cycle
# runs every standalone seeder (live layers such as earthquakes, fires,
# markets, news) and then every seed bundle (slow reference data; each bundle
# skips sections that are still fresh), SEED_PARALLEL at a time, then sleeps
# SEED_INTERVAL_SECONDS. Seeders that need an API key you haven't set skip.
set -u
: "${UPSTASH_REDIS_REST_URL:?UPSTASH_REDIS_REST_URL is required}"
: "${UPSTASH_REDIS_REST_TOKEN:?UPSTASH_REDIS_REST_TOKEN is required}"
INTERVAL="${SEED_INTERVAL_SECONDS:-1800}"
PAR="${SEED_PARALLEL:-4}"
CAP="${SEED_TIMEOUT:-300}"
cd /app/scripts

# Seeders that a bundle already runs are left to the bundle.
in_bundles="$(grep -ho "script: *'seed-[^']*\.mjs'" seed-bundle-*.mjs | sed "s/.*'\(seed-[^']*\.mjs\)'/\1/" | sort -u)"
standalone=""; bundles=""
for f in seed-*.mjs; do
  case "$f" in
    seed-bundle-*) bundles="$bundles $f" ;;
    *) echo "$in_bundles" | grep -qx "$f" || standalone="$standalone $f" ;;
  esac
done

cat > /tmp/seed-one.sh <<'ONE'
#!/bin/sh
f="$1"; cap="$2"; log="/tmp/$f.log"
case "$f" in
  seed-bundle-*) node "$f" > "$log" 2>&1 ;;   # bundles bound each section themselves
  *) timeout -s KILL "$cap" node "$f" > "$log" 2>&1 ;;
esac
rc=$?
last="$(grep -v '^[[:space:]]*$' "$log" | tail -n 1 | cut -c1-160)"
if [ "$rc" -eq 0 ]; then echo "[seeders] $f: ok ($last)"
elif [ "$rc" -eq 137 ]; then echo "[seeders] $f: killed after ${cap}s"
else echo "[seeders] $f: failed rc=$rc ($last)"; fi
ONE
chmod +x /tmp/seed-one.sh

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
  echo "[seeders] cycle $cycle: $(echo $standalone | wc -w) seeders + $(echo $bundles | wc -w) bundles, $PAR at a time"
  # shellcheck disable=SC2086
  printf '%s\n' $standalone $bundles | xargs -P "$PAR" -I{} /tmp/seed-one.sh {} "$CAP"
  echo "[seeders] cycle $cycle done $(date -u +%FT%TZ); next in ${INTERVAL}s"
  sleep "$INTERVAL"
done
