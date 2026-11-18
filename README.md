[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/world-monitor?utm_medium=integration&utm_source=button&utm_campaign=worldmonitor)

# World Monitor on Railway

One-click Railway template for [World Monitor](https://github.com/koala73/worldmonitor) (AGPL-3.0), a real-time global intelligence dashboard: AI-summarised news, conflicts, earthquakes, fires, markets, shipping and infrastructure on one map.

**Version:** World Monitor **v2.11.8** (upstream commit `de602d000d9e10e7da651884bb589d2ad55f3593`), built on upstream's own pinned base image `node:24-alpine@sha256:feb76650b7195319268c59cb2d419c732d6c499b13bf5296f16ab59eb1f0a4f3`.

Upstream publishes no release-tagged image of the self-hosted stack (`ghcr.io/koala73/worldmonitor:<version>` is only the front end that proxies to worldmonitor.app's cloud API, and the self-hosted images only carry `main` and `sha-*` tags). So each service here downloads the source at that fixed commit from GitHub and builds it with upstream's own Dockerfile steps.

## What it deploys

| Service | Folder | What it does |
|---|---|---|
| `worldmonitor` | `app/` | nginx + the Node API sidecar (`LOCAL_API_MODE=docker`). The only public service. Health check `/healthz`. |
| `relay` | `relay/` | AIS vessel stream, market and RSS relay, in-process data loops. Private. Health check `/health`. |
| `redis-rest` | `redis-rest/` | Upstash-compatible REST proxy in front of Redis, bearer-token protected. Private. |
| `seeders` | `seeders/` | Runs upstream's `scripts/seed-*.mjs` every 30 minutes (upstream runs them from a host cron). Private. |
| `Redis` | Railway Redis | All data, on a Railway volume. |

## Variables

Nothing to fill in. All secrets are generated per deploy:

- `WM_SESSION_SECRET` (worldmonitor): signs anonymous browser sessions.
- `RELAY_SHARED_SECRET` (relay; referenced by worldmonitor): authenticates the app to the relay.
- `SRH_TOKEN` (redis-rest; referenced by the others): bearer token for the Redis REST proxy.
- Redis password: Railway Redis's own.

Optional API keys unlock more layers. Add them yourself as service variables: `OPENROUTER_API_KEY` or `LLM_API_URL`/`LLM_API_KEY`/`LLM_MODEL` (AI summaries), `AISSTREAM_API_KEY` (live ships, on `relay` and `worldmonitor`), `FINNHUB_API_KEY`, `FRED_API_KEY`, `EIA_API_KEY`, `NASA_FIRMS_API_KEY`, `ACLED_ACCESS_TOKEN` (on `seeders` and `worldmonitor`). See upstream's [SELF_HOSTING.md](https://github.com/koala73/worldmonitor/blob/v2.11.8/SELF_HOSTING.md).

## Railway-specific changes (small, guarded)

- nginx also listens on `[::]:8080`, and the relay and REST proxy bind `::`, so the services reach each other over Railway's IPv6 private network.
- `/healthz` on the app proxies to upstream's `/api/sidecar-health`, because Railway rejects `-` in health check paths.
- The build lifts upstream's 10-day age limit on the release's frozen SEO "live pulse" snapshot. Without it, a pinned release stops building 10 days after it was cut.
- Each `sed` is guarded by a `grep`, so a version bump fails the build loudly if upstream moves the line.

## Updates

All four app services build from this repo's `main`. When we bump the pinned World Monitor commit here, Railway shows deployers an "update available" notice, and they choose when to apply it. Read `CHANGELOG.md` first: breaking changes are listed first. Data lives in Redis on its volume and survives updates and redeploys.
