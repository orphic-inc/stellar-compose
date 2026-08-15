# Changelog

All notable changes to this repository are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

**What a version means here.** stellar-compose ships no artifact of its own — it
pins one. A version is the **stack** it deploys: `v0.8.2` is the commit where
`docker-compose.yml` pins `stellar-api:0.8.2` and `stellar-ui:0.8.2` together. A
pin bump *is* the deploy, and reverting it is the rollback
([ADR-0027](https://github.com/orphic-inc/stellar-api/blob/main/docs/adr/0027-publish-vs-deploy-boundary.md)),
so the tag marks the commit an operator deploys rather than a release artifact.

Tags for 0.6.9 through 0.8.2 were applied retroactively on 2026-08-15. Only
commits where **both** service pins name the same release are tagged; the window
between 0.6.9 and 0.8.0 ran api 0.7.0 against ui 0.6.9, which is not a stack
version and is deliberately left untagged rather than given an invented number.

## [Unreleased]

Nothing pending. The last change was the 0.8.2 pin.

## [0.8.2] — 2026-08-14

Stack: **api 0.8.2 + ui 0.8.2**

### Added

- Live-box deploy and readiness runbook (`docs/runbooks/live-box-deploy.md`) — the
  operator half of the 0.8.1 readiness pass, covering the two decisions that are
  expensive to change later (the hostname behind `STELLAR_HTTP_CORS_ORIGIN`, and
  whether SMTP exists at all), plus upgrade and rollback.
- Renovate now tracks the `api` and `ui` submodule pointers against their release
  tags, grouped with the image pins so a release moves both in one PR. Nothing had
  been keeping them current; they had drifted 14 and 13 commits behind the v0.8.1
  tags whose images were pinned.

### Changed

- Pinned the last floating image: `postgres:18-alpine` → `postgres:18.6-alpine3.24`.
  The `-alpine` suffix floats the distro underneath the tag, the drift class that
  advanced the api base to Alpine 3.23 and crash-looped its Prisma engine
  (ADR-0001). Verified identical per-platform digests, so nothing that runs changed.
- Realigned both submodule pointers onto the v0.8.1 tags before adopting tag
  tracking.

### Removed

- The `sync-upstream` workflow, which added this repository as its own `upstream`
  and rebased `main` onto itself nightly. It could never have acted — `main`
  disallows force pushes — and its presence gave forks a shared file to diverge on,
  which broke a downstream fork's sync for two months.

## [0.8.1] — 2026-07-18

Stack: **api 0.8.1 + ui 0.8.1**

### Changed

- Only `.env.*.example` templates are tracked; the real env files are gitignored,
  so this public repository cannot carry a live secret.
- `validate` creates the env files from those templates before running
  `docker compose config`, which also keeps CI honest about the documented setup
  path working.

## [0.8.0] — 2026-07-18

Stack: **api 0.8.0 + ui 0.8.0**

### Added

- Renovate, configured so that image pins open a PR and never automerge — bumping a
  release pin is a deploy decision, not a dependency update (ADR-0027).

### Fixed

- The db volume mounts at `/var/lib/postgresql` for Postgres 18, which moved the
  data directory; the previous path silently produced an empty database.
- nginx no longer strips the `/api/` prefix on `proxy_pass`, which had broken every
  API call from the UI.

### Changed

- Postgres 16 → 18.
- Submodule pointers bumped to match the pinned image tags.

## [0.6.9] — 2026-07-09

Stack: **api 0.6.9 + ui 0.6.9** — the first commit where both pins name the same
release.

### Added

- ADR-0001: pin all container images, no floating tags.
- Operator runbook, agent guide (`CLAUDE.md`), and contributor guide.
- `validate` workflow — YAML parse plus `docker compose config`.

### Changed

- Migrated the database service to PostgreSQL and made ports consistent.

[Unreleased]: https://github.com/orphic-inc/stellar-compose/compare/v0.8.2...HEAD
[0.8.2]: https://github.com/orphic-inc/stellar-compose/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/orphic-inc/stellar-compose/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/orphic-inc/stellar-compose/compare/v0.6.9...v0.8.0
[0.6.9]: https://github.com/orphic-inc/stellar-compose/releases/tag/v0.6.9
