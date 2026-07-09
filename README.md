# Stellar Compose

The deployment and orchestration repo for **Stellar** — the Docker Compose stack that ties the API, UI, and database together. This is the operator's home: stand up, operate, upgrade, and back up a Stellar instance from here.

## The Stellar constellation

Stellar is four repositories developed together:

| Repo | Role |
| --- | --- |
| [stellar-api](https://github.com/orphic-inc/stellar-api) | Node/Express/Prisma REST API — the platform backend. Self-migrating container. |
| [stellar-ui](https://github.com/orphic-inc/stellar-ui) | React SPA frontend + the nginx proxy that fronts the stack. |
| **stellar-compose** (this repo) | The Compose stack + operator runbook — deployment, image pinning, upgrades. |
| [korin.pink](https://github.com/obrien-k/korin-pink) | **Optional** external IRC-metrics sidecar. The app runs fine without it. |

The publish/deploy boundary is defined in [stellar-api ADR-0027](https://github.com/orphic-inc/stellar-api/blob/main/docs/adr/0027-publish-vs-deploy-boundary.md): the api/ui pipelines end at a versioned GHCR image publish; **this repo owns deployment** — it pins which published image tags run, and promotion/rollback is a pin change here.

## Quick Start (local build)

Prerequisites: **Docker** and **Git**.

```bash
git clone https://github.com/orphic-inc/stellar-compose stellar
cd stellar
git submodule update --init --recursive
```

Edit `.env.api`, `.env.ui`, and `.env.db` — replace the `changeme` placeholders (see the [API](https://github.com/orphic-inc/stellar-api) and [UI](https://github.com/orphic-inc/stellar-ui) docs for the keys). At minimum set `STELLAR_AUTH_JWT_SECRET` (32+ chars) and the database credentials. Then build and start:

```bash
docker compose up --build -d
```

This builds the API and UI from the submodules. For a **pulled-image** deployment (production), see [Deploying a release](#deploying-a-release) below.

## First-run setup (required)

A fresh instance is **not usable until two one-time steps are done**:

1. **Schema** — applied automatically. The api container self-migrates on boot: its entrypoint runs `prisma migrate deploy` before starting (stellar-api #276), so you never run migrations by hand.
2. **Seed defaults** — **not automatic yet.** The entrypoint applies migrations but does **not** plant the default user ranks, forums, Golden Rules, System user, or stylesheet fixtures. Until they exist the app can't assign ranks or show forums. Seed them once against the running database:

   ```bash
   docker compose exec api npm run db:seed
   ```

   > Wiring an idempotent seed into first boot is a tracked follow-up (see [Known rough edges](#known-rough-edges)); until then this is a manual step on a new instance.

3. **Create the first admin** — the API is 503-walled on `/api/*` until the one-time install mints the first SysOp (stellar-api ADR-0022). Open the site and complete the install form, or POST directly:

   ```bash
   curl -X POST https://<your-host>/api/install \
     -H 'Content-Type: application/json' \
     -d '{"username":"admin","email":"admin@example.com","password":"<strong-password>"}'
   ```

## Deploying a release

Production runs **pulled, pinned images** — not local builds and not `:latest`. In `docker-compose.yml`, each service has an `image:` line pinned to a published semver and a commented `build:` line:

```yaml
image: ghcr.io/orphic-inc/stellar-api:0.6.9
# build: ./api
```

- **Deploy / upgrade** — bump the pinned tag to the target version and `docker compose pull && docker compose up -d`. The api container self-migrates the schema forward on boot.
- **Roll back** — revert the pin to the previous tag and `pull && up -d` again. Because the pin is tracked in git, a deploy and its rollback are both reviewable commits (ADR-0027).
- **Never pin `:latest` in production** — it makes deploys non-reproducible and rollbacks impossible.

Published tags live at `ghcr.io/orphic-inc/stellar-api` and `ghcr.io/orphic-inc/stellar-ui`. (Version parity between api and ui is a work in progress — pin each to its own latest published tag.)

> **Destructive migrations — read before a major upgrade.** The api self-migrates on boot with `prisma migrate deploy`. Stellar uses an **expand → contract** discipline (stellar-api ADR-0027): a migration that drops or rewrites columns ships one release *after* the code that stopped needing the old shape. Do not skip intermediate releases across a known destructive migration, and take a backup first (below). Running more than one api replica through a destructive migration is not yet safe — see [Known rough edges](#known-rough-edges).

## Backup & restore

The database lives in a Docker volume mounted into the `db` service. Back it up with `pg_dump` before any upgrade and on a schedule:

```bash
# Backup
docker compose exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > stellar-$(date +%F).sql

# Restore (into a fresh, empty database)
docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < stellar-YYYY-MM-DD.sql
```

Store backups off-host. A destructive migration or a lost volume with no backup is unrecoverable.

## TLS

To serve HTTPS, provide the proxy container with certificates (from [Let's Encrypt](https://letsencrypt.org/) or a commercial issuer):

1. Place `cert.pem` (domain cert), `privkey.pem` (private key), and `chain.pem` (CA chain) in `./volumes/proxy-certs`.
2. Uncomment the `proxy-tls.nginx.conf` volume mapping and comment the default config mapping in `docker-compose.yml`.

## The korin.pink IRC sidecar (optional)

Stellar runs fully without IRC. The korin integration is inert until you set its keys in `.env.api` (`KORIN_API_URL`, `KORIN_PULL_KEY`, `STELLAR_SERVICE_KEY`); leave them blank to run without it. See [stellar-api ADR-0013](https://github.com/orphic-inc/stellar-api/blob/main/docs/adr/0013-korin-pink-irc-integration.md).

## Known rough edges

- **Seeding is a manual first-run step** (above) — an idempotent seed-on-first-boot is not yet wired into the entrypoint.
- **Multi-replica migration safety** — the self-migrating entrypoint races if more than one api replica starts simultaneously against an unmigrated database ([issue #10](https://github.com/orphic-inc/stellar-compose/issues/10)). Single-replica deploys are unaffected.
- **Boot smoke test** — CI validates `docker compose config` but does not yet build-and-boot the stack ([issue #7](https://github.com/orphic-inc/stellar-compose/issues/7)); that gap is how the malformed image references (fixed in this pass) went unnoticed.
