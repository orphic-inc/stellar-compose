# Stellar Compose

This is a Docker compose file which ties together the API and UI for Stellar.

## Quick Start

Make sure you have the following installed and working:

- Docker
- Git

The following commands will set up a new development environment using Docker.

    git clone https://github.com/orphic-inc/stellar-compose stellar
    cd stellar
    git submodule update --init --recursive

Now, edit `.env.api` and replace all relevant configuration. Refer to [API](https://github.com/orphic-inc/stellar-api) documentation on the keys and values. Then, edit `.env.ui` and do the same with the [UI](https://github.com/orphic-inc/stellar-api) documentation. Finally, run the following to start Stellar:

    docker compose up --build -d

## TLS

In order to provide an HTTPS endpoint, you must provide the proxy container with certificates. These can come from [LetsEncrypt](https://letsencrypt.org/) or a commercial certificate issuer.

1. Place the following files in `./volumes/proxy-certs`

    * `cert.pem` - Your domain certificate
    * `privkey.pem` - Private key used to generate the certificate
    * `chain.pem` - Intermediate and Root CA certificate chain

2. Uncomment the `proxy-tls.nginx.conf` volume mapping and comment the default config mapping in `docker-compose.yml`.

## Docker Images

If you would prefer to use a tagged image, comment/uncomment `build` and `image` lines in `docker-compose.yml` to switch between locally built and remotely downloaded images. The `latest` tag represents the `main` branch of each repo, and tagged versions are available by their version number, e.g. `v1.0.0`.
