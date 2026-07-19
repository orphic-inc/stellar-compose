# Runbook — deploying Stellar on a live box (VPS / self-hosted)

This is the operator path from a bare host to a Stellar instance facing the internet, plus the readiness checks that decide whether it *should* face the internet. Run the checklist in section 3 on every deploy, not only the first — most of it is cheap, and the items that bite are the ones that look already-handled.

The companion document is stellar-ui's `docs/runbooks/e2e-stack-pass.md`, which verifies that a given image pair works at all. That one answers "does this build function"; this one answers "should this box be public". A green e2e pass is a precondition here, not a substitute.

## What the stack does for you

Understanding these three saves you from running steps that are already automatic:

- **Schema migration is automatic.** The api image's entrypoint runs `prisma migrate deploy` before starting the server (stellar-api #276). You never migrate by hand.
- **Baseline seeding is automatic.** The same entrypoint then runs `node dist/scripts/seed.js`, planting user ranks, forums, Golden Rules, the System user, and the stylesheet fixtures. It is idempotent — a no-op on an already-seeded database, safe on every boot. `set -e` means a failure in either step exits the container non-zero rather than serving against a schema-behind or unseeded database.
- **The API is 503-walled until install.** Every `/api/*` route returns 503 until the one-time install stamps `installedAt` (stellar-api ADR-0022). The boot seed deliberately does not stamp it — creating the first SysOp is an operator decision, not a side effect of starting a container.

## 0. Decide two things before touching the box

Both are hard to change later and both have bitten a real deploy.

**The hostname.** It goes into `STELLAR_SITE_URL` and `STELLAR_HTTP_CORS_ORIGIN`, and into the TLS certificate. A wrong CORS origin means the browser blocks the UI's own API calls — the site loads and then does nothing, which reads as a mysterious app bug rather than a config error.

**Whether you have SMTP.** With `STELLAR_SMTP_HOST` unset, `sendInviteEmail` and password recovery both no-op with a logged warning; the request still returns success. Combined with the closed-by-default registration posture, that means a box with no SMTP can onboard nobody and reset nobody's password. That is a legitimate configuration for a single-operator instance, but it should be a decision rather than a discovery.

## 1. Prepare the host

Docker and the compose plugin installed, a DNS A record pointing at the box, and ports 80 and 443 reachable.

Clone this repo, then create the four env files from their templates:

```bash
cp .env.example .env
cp .env.api.example .env.api
cp .env.db.example .env.db
cp .env.ui.example .env.ui
```

Set, at minimum:

| File | Variable | Value |
|---|---|---|
| `.env.db` | `POSTGRES_PASSWORD` | a real generated password, never the template placeholder |
| `.env.api` | `STELLAR_AUTH_JWT_SECRET` | 64 chars — `openssl rand -hex 32` |
| `.env.api` | `STELLAR_SITE_URL` | `https://yourdomain` |
| `.env.api` | `STELLAR_HTTP_CORS_ORIGIN` | `https://yourdomain` |
| `.env.api` | `STELLAR_SMTP_*` | your mail credentials, or knowingly leave unset per section 0 |

Leave the `KORIN_*` keys blank unless you are running the IRC sidecar. The integration is inert without them (stellar-api ADR-0013) — blank is a supported configuration, not a broken one.

These four files are gitignored. Keep it that way; they hold live secrets.

## 2. TLS before install, not after

Do this before the first `up -d`. Installing over plaintext means your SysOp password crosses the wire in the clear, and that credential is the one that matters most on the box.

1. Obtain certificates. `certbot certonly --standalone` is simplest while nothing is bound to port 80 yet.
2. Place `cert.pem`, `privkey.pem`, and `chain.pem` in `./volumes/proxy-certs`.
3. In `docker-compose.yml`, comment the default config mount and uncomment the `proxy-tls.nginx.conf` mount.

Then bring the stack up:

```bash
docker compose pull > /tmp/pull.log 2>&1; echo "EXIT:$?"
docker compose up -d > /tmp/up.log 2>&1; echo "EXIT:$?"
docker compose ps
```

> Do not chain `&&` off a piped command when the exit status matters — `cmd | tail` returns tail's status, so a failure vanishes silently. Redirect to a log, echo the status, then read the log.

Watch the api come up and confirm both automatic steps ran:

```bash
docker compose logs -f api
```

You want `prisma migrate deploy` applying migrations, then the seed, then the server start. A benign warning about the obsolete compose `version:` key is expected (#18).

Create the first admin — the only manual first-run step:

```bash
curl -X POST https://<your-host>/api/install \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","email":"admin@example.com","password":"<strong-password>"}'
```

Expect 201. Put that password in a password manager before you do anything else.

## 3. Readiness checklist

Record a result for each. An honest "not exercised" is worth more than an optimistic pass.

**3.1 No database exposure.** `docker compose ps` must show published ports only for `ui` (80, 443). `db` and `api` publish nothing; they are reachable only on the internal network. Postgres bound to a host port is a **blocker** on a public box.

**3.2 Secrets are real.** `POSTGRES_PASSWORD` is not the template placeholder (`grep -c 'changeme' .env.db` returns 0) and `STELLAR_AUTH_JWT_SECRET` is 64 chars. Check length, never print the value. A placeholder JWT secret on a public box means anyone can forge auth tokens. An automated preflight for this is tracked in #37.

**3.3 Site identity is the real domain.** `STELLAR_SITE_URL` and `STELLAR_HTTP_CORS_ORIGIN` are the live hostname — not `localhost`, and not a plausible-looking placeholder like `example.org`. `GET /api/install` surfaces problems here as `configWarnings`; an empty-ish list is the goal.

**3.4 Registration posture is deliberate.** `GET /api/install` reports `registrationStatus`. A fresh instance is `closed` by default (stellar-api 0.8.0) and `setupChecklist` carries a `registration-closed` item reminding you to open it at launch. Move to `invite` or `open` when you actually want people, not before.

**3.5 TLS is serving.** Port 443 responds with your certificate and port 80 redirects. If you deferred section 2, this is where it comes due.

**3.6 Data survives a restart.** The one people skip:

```bash
docker compose down > /tmp/down.log 2>&1; echo "EXIT:$?"
docker compose up -d > /tmp/up2.log 2>&1; echo "EXIT:$?"
sleep 20
curl -s https://<your-host>/api/install | jq '.installed'
```

Expect `true` — the SysOp survived, proving the volume persists and `migrate deploy` is idempotent against a populated database. `false` means the box would lose everything on reboot. **Blocker.**

**3.7 Restart policy.** `api`, `ui`, and `db` all declare `restart: always`, so the stack self-heals on host reboot.

**3.8 Images are pinned.** `docker-compose.yml` pins explicit semver tags, never `:latest` (stellar-api ADR-0027 — a pin is revertible, `:latest` is not). Record the exact tags; a readiness verdict is only valid for the pair you tested.

**3.9 Backups exist and leave the host.** The database lives in the bind mount `./volumes/db-data`. Take a dump and copy it off-box:

```bash
docker compose exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > stellar-$(date +%F).sql
```

Restore is `psql` into a fresh, empty database. There is no automation behind this today; a scheduled job is yours to add. For a pre-alpha box "manual, unscheduled" is a defensible answer, but a lost volume with no backup is unrecoverable.

## 4. Upgrading

Deploys and rollbacks are both tracked commits, which is the point of pinning (ADR-0027).

- **Upgrade** — bump the pinned tags, `docker compose pull && docker compose up -d`. The api self-migrates forward on boot.
- **Roll back** — revert the pin, pull and up again.

Take a backup first, and do not skip intermediate releases across a known destructive migration. Stellar uses expand-then-contract: a migration that drops or rewrites a column ships one release *after* the code that stopped needing the old shape, so skipping the middle release skips the half that made the drop safe.

Running more than one api replica through a migration is not yet safe — the entrypoint races if replicas start simultaneously against an unmigrated database (#10). Single-replica deploys are unaffected.

## 5. When to stop

Hand back rather than improvising if the database will not start or its volume mount path is wrong, if `installed` comes back `false` after a restart cycle, or if any readiness item in section 3 fails in a way that needs a code change. Config problems are operator-fixable in place; an application defect found at this stage is a release decision, not a deploy step.
