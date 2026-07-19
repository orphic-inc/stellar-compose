# CLAUDE.md — stellar-compose

Docker Compose orchestration for the Stellar platform. Ties together stellar-api, stellar-ui, and a Postgres database. This file is the agent guide; the human operator runbook is [README.md](README.md).

## Submodule architecture

```
stellar-compose/
  api/   → git submodule → orphic-inc/stellar-api  (pinned SHA)
  ui/    → git submodule → orphic-inc/stellar-ui   (pinned SHA)
  docker-compose.yml
  .env.api   .env.ui   .env.db          (gitignored; created from the .example templates)
  .env.api.example   .env.ui.example   .env.db.example
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

Submodules are pinned to exact SHAs; the recorded SHA in `.gitmodules` and the index is what matters. The submodule pin only affects the `build:` (local-build) path — a **pulled** deploy uses the `image:` tag, not the submodule. When you do bump the api submodule, pin a **current** commit (post the self-migrating entrypoint, stellar-api #276) — an old pin regresses local builds to manual migrations.

## Images: pin a semver, don't ship `:latest`

CI in each service repo publishes images on push to `main` (`:latest`) and on version tags (`:<semver>`). **Production pins a specific semver in `docker-compose.yml` — never `:latest`** ([stellar-api ADR-0027](https://github.com/orphic-inc/stellar-api/blob/main/docs/adr/0027-publish-vs-deploy-boundary.md)): a pin is a reproducible, revertible deploy; `:latest` is not.

| Use | image line |
|---|---|
| Production / staging | `image: ghcr.io/orphic-inc/stellar-api:0.8.0` (pinned semver) |
| Local build from submodule source | comment `image:`, uncomment `build: ./api` |
| Throwaway "track main" (never prod) | `:latest` |

Deploy/upgrade = bump the pin and `docker compose pull && up -d`; roll back = revert the pin. The api container self-migrates on boot (#276).

## Compose for local dev — when to use it

You usually don't need compose for day-to-day development:

- **Developing api only**: run `npm run dev` in `stellar-api`. No compose.
- **Developing ui only**: run `npm start` in `stellar-ui` (proxies `/api` → `localhost:8080`). No compose.
- **Integration / E2E testing**: use compose to spin up the full stack against real images before a release.
- **Production deploys**: the only context where you're running the published images.

## Environment files

| File | Purpose |
|---|---|
| `.env.api` | stellar-api env vars (mirror `api/.env.default`) |
| `.env.ui` | stellar-ui env vars (copy from `ui/.env.example`) |
| `.env.db` | Postgres credentials (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`) |

`.env.api` must set at minimum `STELLAR_PSQL_URI`, `STELLAR_AUTH_JWT_SECRET`, `STELLAR_HTTP_CORS_ORIGIN`. The full variable reference is [api `docs/README.md`](https://github.com/orphic-inc/stellar-api/blob/main/docs/README.md#environment-reference) (and `api/.env.default`).

Only the `.example` templates are tracked; the real `.env*` files are gitignored, so this public repo cannot carry a live secret. Create them with `cp .env.api.example .env.api` (and the same for `.env`, `.env.ui`, `.env.db`), then fill in real values locally. When you add a variable, add it to the matching `.example` with a `changeme` placeholder.

## Commands

```bash
docker compose up --build -d   # build from submodule source and start
docker compose up -d           # start using pulled/cached images
docker compose logs -f api     # tail api logs
docker compose exec api sh     # shell into the api container
docker compose exec api npm run db:seed   # seed default ranks/forums (first run — see README)
docker compose down            # stop and remove containers (data volume persists)
docker compose down -v         # also wipe the db-data volume
```

## Cross-repo considerations

Changes in stellar-api that alter response shapes, route paths, or the OpenAPI spec require a matching update in stellar-ui before compose produces a coherent stack. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full cross-repo checklist.
