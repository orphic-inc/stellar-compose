# CLAUDE.md — stellar-compose

Docker Compose orchestration for the Stellar platform. Ties together stellar-api, stellar-ui, and a Postgres database as git submodules.

## Submodule architecture

```
stellar-compose/
  api/   → git submodule → orphic-inc/stellar-api  (pinned SHA)
  ui/    → git submodule → orphic-inc/stellar-ui   (pinned SHA)
  docker-compose.yml
  .env.api   .env.ui   .env.db
```

After cloning, initialize submodules:

```bash
git submodule update --init --recursive
```

To pull the latest upstream commit for a submodule:

```bash
git submodule update --remote api   # or ui
git add api                         # records the new SHA
git commit -m "chore: bump api submodule to <short-sha>"
```

Compose pins submodules to exact SHAs — `heads/main` in the status output just means "was checked out from main at time of last pin." The recorded SHA in `.gitmodules` and the index is what matters.

## Branch → Docker image mapping

The repos are trunk-only. CI in each service repo publishes images on push to `main` and on version tags:

| Branch / tag | Image tag |
|---|---|
| `main` | `:latest` |
| `v0.5.3` | `:0.5.3` |

`docker-compose.yml` defaults to `:latest`. To pin a release, edit the `image:` lines to a version tag, or comment/uncomment the `build:` lines to build from local submodule source instead of pulling a published image.

## Compose for local dev — when to use it

You usually don't need compose for day-to-day development:

- **Developing api only**: run `npm run dev` in `stellar-api`. No compose.
- **Developing ui only**: run `npm run dev` in `stellar-ui` (proxies /api to localhost:8080). No compose.
- **Integration / E2E testing**: use compose to spin up the full stack against real images before a release.
- **Production deploys**: the only context where you're running the published images.

## Environment files

| File | Purpose |
|---|---|
| `.env.api` | stellar-api env vars (copy from `api/.env.default`) |
| `.env.ui` | stellar-ui env vars (copy from `ui/.env.example` if present) |
| `.env.db` | Postgres credentials (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`) |

`.env.api` must contain at minimum `STELLAR_PSQL_URI`, `STELLAR_AUTH_JWT_SECRET`, `STELLAR_HTTP_CORS_ORIGIN`. See `api/CLAUDE.md` for the full variable table.

## Commands

```bash
docker compose up --build -d   # build from submodule source and start
docker compose up -d           # start using cached / pulled images
docker compose logs -f api     # tail api logs
docker compose exec api sh     # shell into api container
docker compose down            # stop and remove containers (data volume persists)
docker compose down -v         # also wipe the db-data volume
```

## Cross-repo considerations

Changes in stellar-api that alter response shapes, route paths, or the OpenAPI spec require a matching update in stellar-ui before compose produces a coherent stack. See CONTRIBUTING.md for the full cross-repo checklist.
