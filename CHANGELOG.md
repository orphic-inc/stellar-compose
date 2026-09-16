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

## [0.9.5] — 2026-09-16

Stack: **api 0.9.5 + ui 0.9.5**

### Changed

- Both service pins move to **0.9.5**, and the `api` and `ui` submodules to the
  matching release tags. This releases the hold from
  [#49](https://github.com/orphic-inc/stellar-compose/issues/49), which kept the
  api at `0.9.4` because api `0.9.5` made `reason` required on
  `POST /ratio-policy/{userId}/override` while the pinned ui `0.9.3` still sent
  `status` alone. stellar-ui `0.9.5` carries that fix
  ([stellar-ui#332](https://github.com/orphic-inc/stellar-ui/issues/332)).

  The pairing check from `CONTRIBUTING.md` was run against the real tag before
  pinning: ui `v0.9.5` vendors api contract **0.9.5**, equal to the api pin, so
  the pair is sound and there is no diff to weigh.

  stellar-ui has no `0.9.4`. Its patch moved two so that both pins name the same
  release and this commit is a stack version — an unequal pair is left untagged
  here rather than given an invented number, and stellar-ui's ADR-0004 makes its
  patch digit that repo's own cadence, so the skip costs nothing there.

- **Recorded late:** `f4ec15b` moved the stack off **0.8.2** — the api pin to
  `0.9.4`, the ui pin to `0.9.3`, and both submodules to match. That deploy
  reached this file only now, found while preparing this release. It is noted
  under 0.9.5 because that is when it was written down, not when it happened;
  the pair it created was unequal, so it was never a tagged stack version and
  gets no section of its own. Nothing here gates a pin change on a CHANGELOG
  entry, which is why it was missed —
  [#51](https://github.com/orphic-inc/stellar-compose/issues/51) tracks that.

### Added

- `CONTRIBUTING.md`'s release workflow has a pairing check to run before
  pinning ([#49](https://github.com/orphic-inc/stellar-compose/issues/49)).
  Renovate's grouped pin PR takes each repo's newest tag independently, so it
  can pair an api with a ui that has not caught up to its contract. The step
  reads which api contract the ui tag vendors and names the diffs that must hold
  the api pin back.
- `.env.api.example` lists the api's 0.9.x settings, commented out at their
  defaults: `STELLAR_IRC_GUIDE_URL`, `STELLAR_TRUST_PROXY_HOPS`, and the
  inactivity, invite handout, invite expiry and ratio policy job dials. Both
  `*_MODE` switches ship `off`. Nothing changes for an existing `.env.api`.

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
