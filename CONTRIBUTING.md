# Contributing to Stellar Compose

Compose is the orchestration layer — it pins submodule SHAs, manages environment files, and defines the production service topology. Most active development happens in stellar-api and stellar-ui; compose changes are typically submodule bumps, environment additions, image-pin updates, or nginx/TLS config changes.

---

## Workflow 1 — Daily development (no compose needed)

Run services independently:

```bash
# Terminal 1 — API (localhost:8080)
cd ../stellar-api && npm run dev

# Terminal 2 — UI (localhost:9000, proxies /api → :8080)
cd ../stellar-ui && npm start
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

2. **In stellar-ui**: regenerate types from the new spec with `api:sync` (which pulls the fresh spec from the sibling `../stellar-api`; plain `api:generate` only reruns codegen over the already-vendored spec and won't pick up the change).
   ```bash
   # stellar-api must be a sibling directory:  ../stellar-api
   npm run api:sync
   npx tsc --noEmit          # verify no type regressions
   ```
   Commit `src/types/api.ts` (and `src/types/openapi.json`) in the UI PR. Link the API PR.

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

1. In stellar-api, cut a version tag on `main` — CI publishes `ghcr.io/orphic-inc/stellar-api:<semver>` and refreshes `:latest`.
2. Repeat for stellar-ui.
3. In stellar-compose, point the `image:` pins at the new **semver** (not `:latest`), bump the submodule pins to the tagged commits, and tag compose itself:
   ```bash
   # Edit docker-compose.yml:  image: ghcr.io/orphic-inc/stellar-api:0.6.9  etc.
   git add docker-compose.yml api ui
   git commit -m "chore: release 0.6.9"
   git tag v0.6.9 && git push origin v0.6.9
   ```

Production always runs a pinned semver, never `:latest` — a pin is a reproducible, revertible deploy ([stellar-api ADR-0027](https://github.com/orphic-inc/stellar-api/blob/main/docs/adr/0027-publish-vs-deploy-boundary.md)).

---

## Branch strategy

All three repos are trunk-only: feature branches are cut from `main` and merged back via PR. Releases are cut as version tags on `main`. Compose pins its submodules to exact SHAs and its images to semver tags.

| Branch / tag | Purpose | Image pin |
|---|---|---|
| `main` | trunk / development | `:latest` (convenience only, not prod) |
| `v0.6.x` tag | pinned release | `:0.6.x` (semver — what production runs) |

---

## Coordinating API-shape changes across in-flight branches

When multiple stellar-api feature branches change response shapes simultaneously, avoid cascading type drift in stellar-ui:

- Each API branch exports `openapi.json` as part of its PR — do not skip it even for "internal" changes; CI catches it anyway.
- Regenerate `src/types/api.ts` in stellar-ui (`npm run api:sync`) against the merged spec before merging the UI side.
- Don't merge an API-touching PR to `main` without the corresponding UI types PR ready to follow promptly — long gaps leave other devs hitting type errors on `main`.
- If two API branches touch the same shape, coordinate merge order and regenerate types once after the second lands.

---

## Submitting pull requests

- Compose PRs that change `docker-compose.yml` must describe which service changed and why.
- Submodule-bump and image-pin PRs should reference the API/UI PR(s) or release they incorporate.
- Environment variable additions must mirror `api/.env.default` (or `ui/.env.example`), be added to the matching `.env.*.example` template with a `changeme` placeholder, and be documented here and in `CLAUDE.md`.
- Never commit a real secret. Only `.env.*.example` templates are tracked; the real `.env*` files are gitignored, so live values stay in your local copies and cannot reach this public repo.
