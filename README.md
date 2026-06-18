# Stellar Compose

Docker Compose orchestration for the Stellar platform — ties together [stellar-api](https://github.com/orphic-inc/stellar-api) and [stellar-ui](https://github.com/orphic-inc/stellar-ui) as git submodules with a Postgres database.

For day-to-day feature development you don't need compose — run api and ui independently. Compose is for integration testing and production deploys. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full cross-repo workflow.

## Quick Start

    git clone https://github.com/orphic-inc/stellar-compose stellar
    cd stellar
    git submodule update --init --recursive

Copy and fill in the three environment files:

    cp api/.env.default .env.api   # stellar-api config — see api/CLAUDE.md for variables
    cp api/.env.default .env.ui    # stellar-ui config (STELLAR_API_URL, etc.)
    # create .env.db with POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB

Then start the stack:

    docker compose up --build -d

## TLS

To serve HTTPS, provide certificates in `./volumes/proxy-certs`:

- `cert.pem` — domain certificate
- `privkey.pem` — private key
- `chain.pem` — intermediate + root CA chain

Then swap the nginx config in `docker-compose.yml`: comment `proxy.nginx.conf`, uncomment `proxy-tls.nginx.conf`.

## Docker Images

Published images are hosted on GHCR. The repos are trunk-only — images are published from `main` and from version tags:

| Image tag | Source |
|---|---|
| `:latest` | `main` (latest commit) |
| `:0.5.3` | tag `v0.5.3` |

`docker-compose.yml` uses `:latest` by default. To pin a release, edit the `image:` lines to a version tag, or comment/uncomment the `build:` lines to build from local submodule source instead of pulling a published image.
