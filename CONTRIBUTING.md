# Contributing to Stellar Compose

Compose is the orchestration layer — it pins submodule SHAs, manages environment files, and defines the production service topology. Most active development happens in stellar-api and stellar-ui; compose changes are typically submodule bumps, environment additions, or nginx/TLS config changes.

---

## Workflow 1 — Daily development (no compose needed)

Run services independently:

```bash
# Terminal 1 — API (localhost:8080)
cd ~/git/stellar-api && npm run dev

# Terminal 2 — UI (localhost:9000, proxies /api → :8080)
cd ~/git/stellar-ui && npm run dev
```

Compose is not involved. This is the default for feature work.

---

## Workflow 2 — Cross-repo feature (API shape changes)

When a stellar-api PR adds, removes, or renames a field in any response, or adds a new route that stellar-ui will consume:

1. **In stellar-api**: implement the change, then export the updated spec.
   ```bash
   npm run openapi:export   # writes openapi.json to repo root
   ```
   Commit `openapi.json` in the same PR. CI enforces freshness — a stale spec fails the build.

2. **In stellar-ui**: regenerate types from the new spec.
   ```bash
   # stellar-api must be a sibling directory:  ../stellar-api/openapi.json
   npm run api:generate
   # → runs openapi:export in stellar-api, then writes src/types/api.ts
   npx tsc --noEmit          # verify no type regressions
   ```
   Commit `src/types/api.ts` in the UI PR. Link the API PR in the description.

3. **In stellar-compose** (after both PRs land on `main`): bump the submodule pins.
   ```bash
   git submodule update --remote api
   git submodule update --remote ui
   git add api ui
   git commit -m "chore: bump api + ui submodules post <feature-name>"
   ```

Order matters: API merges first, UI types regenerate against the merged spec, then compose pins both together.

---

## Workflow 3 — Release

1. In stellar-api, cut a version tag on `main`:
   ```bash
   git tag v0.5.4 && git push origin v0.5.4
   ```
   CI publishes `ghcr.io/orphic-inc/stellar-api:0.5.4` and updates `:latest`.

2. Repeat for stellar-ui:
   ```bash
   git tag v0.5.4 && git push origin v0.5.4
   ```

3. In stellar-compose, update `docker-compose.yml` image tags to the new version, bump submodule pins to the tagged commits, and tag compose itself:
   ```bash
   # Edit docker-compose.yml: image: ghcr.io/orphic-inc/stellar-api:0.5.4 etc.
   git add docker-compose.yml api ui
   git commit -m "chore: release v0.5.4"
   git tag v0.5.4 && git push origin v0.5.4
   ```

---

## Branch strategy

All three repos are trunk-only: feature branches are cut from `main` and merged back via PR. Releases are cut as version tags on `main`. Compose pins its submodules to exact SHAs and tracks `main`.

| Branch / tag | Purpose | Image tag |
|---|---|---|
| `main` | trunk — production | `:latest` |
| `v0.5.x` tag | pinned release | `:0.5.x` (semver) |

---

## ADR/PRD in-flight features

When multiple feature branches are active simultaneously (e.g. music model remodel, stylesheet scoring, CRS foundation), each may change API shapes independently. To avoid cascading type drift in stellar-ui:

- Each feature branch in stellar-api should export `openapi.json` as part of its PR. Do not skip this step even for "internal" changes — CI will catch it anyway.
- Regenerate `src/types/api.ts` in stellar-ui against the feature branch spec before merging the UI side.
- Do not merge an API-touching PR to `main` without the corresponding UI types PR ready to follow immediately (same day). Long gaps cause other devs to hit type errors on `main`.
- If two API feature branches both touch the same response shape, coordinate merge order and regenerate types once after the second lands.

---

## Submitting pull requests

- Compose PRs that change `docker-compose.yml` must include a description of which service changed and why.
- Submodule bump PRs should reference the API/UI PR(s) they incorporate.
- Environment variable additions must be reflected in `.env.default` (api) or documented in this file and CLAUDE.md.
