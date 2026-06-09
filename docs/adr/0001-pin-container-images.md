---
status: accepted
date: 2026-06-09
---

# Pin all container images; never run floating tags in the fleet

## Context

`stellar-api`'s Dockerfile built `FROM node:lts-alpine` — a floating tag. With no
change on our side, that tag advanced to **Alpine 3.23** (OpenSSL 3 only). Prisma
5.3.1 misdetects libssl on Alpine 3.21+ and falls back to its `openssl-1.1.x`
engine, which needs `libssl.so.1.1` — absent on 3.23. The API crash-looped. CI
stayed green the whole time, because `validate.yml` only runs `docker compose
config` (spec validation) — it never builds or boots. The break was invisible
until a human ran the stack.

## Decision

Every image in the fleet is pinned to an explicit, reproducible reference — no
`:latest`, no distro-floating base tags. Pins are kept fresh by an automated bump
bot, not by drift.

- `api`: base image pinned to `node:24-alpine3.23` (orphic-inc/stellar-api#100).
- `ui` (`…stellar-ui:latest`) and `db` (`postgres:16-alpine`, whose `-alpine`
  suffix floats the distro): pin — tracked in #8.
- Automated bump PRs (Renovate, Docker + npm) — tracked in #9.
- A build + boot + migrate CI smoke test, to catch the class of break that
  config-only validation misses — tracked in #7.

## Consequences

A floating tag trades reproducibility for silent, unscheduled change: the same
commit builds differently tomorrow, and a distro/engine break arrives with no
diff to blame. Pinning makes the runtime an explicit, reviewable input. The
cost — pins go stale — is paid down by the bump bot, which turns "drift
discovered by crash" into "drift proposed as a reviewable PR" gated by a CI boot.

The non-obvious trap this ADR exists to prevent: a future reader sees
`node:24-alpine3.23` and "tidies" it back to `node:lts-alpine`. **Don't** — that
is the exact change that caused the outage. Bump a pin deliberately, via a bump
PR, with CI booting the stack.
