# Logseq Sync Worker

[![Build Image](https://github.com/yshalsager/logseq-selfhost/actions/workflows/build-selfhost-sync-worker-image.yml/badge.svg)](https://github.com/yshalsager/logseq-selfhost/actions/workflows/build-selfhost-sync-worker-image.yml)
[![ghcr.io tag](https://ghcr-badge.egpl.dev/yshalsager/logseq-selfhost-sync-worker/latest_tag?ignore=latest,buildcache*,sha256*&trim=major&label=GitHub%20Registry&color=steelblue)](https://github.com/yshalsager/logseq-selfhost/pkgs/container/logseq-selfhost-sync-worker)
[![ghcr.io size](https://ghcr-badge.egpl.dev/yshalsager/logseq-selfhost-sync-worker/size?tag=latest&label=Image%20size&color=steelblue)](https://github.com/yshalsager/logseq-selfhost/pkgs/container/logseq-selfhost-sync-worker)
[![License](https://img.shields.io/github/license/yshalsager/logseq-selfhost.svg)](https://github.com/yshalsager/logseq-selfhost/blob/master/LICENSE)

This image runs Logseq's `deps/db-sync` Cloudflare Worker locally through Wrangler. It provides the normal sync protocol plus semantic REST, OpenAPI, and MCP endpoints.

The Docker-on-VPS implementation is based on [rien7's `sync-worker-mcp` work](https://github.com/rien7/logseq-selfhost/tree/feat/sync-worker-mcp).

It is an alternative sync backend, not a sidecar for `images/sync`. Its D1, Durable Object, and R2 emulation state is stored under `/data/wrangler` and is incompatible with the Node adapter's SQLite/filesystem volume.

Semantic REST and MCP access require a non-E2EE graph and Cognito tokens with `logseq/read` or `logseq/write` scopes.

## Upstream URLs

- [Logseq repository](https://github.com/logseq/logseq)
- [`deps/db-sync` README](https://github.com/logseq/logseq/blob/master/deps/db-sync/README.md)
- [Semantic REST and MCP APIs](https://github.com/logseq/logseq/pull/12896)

## Configure

Docker Compose reads variables from the shell or an optional `.env` beside `docker-compose.yml`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `GHCR_OWNER` | `yshalsager` | GHCR namespace |
| `IMAGE_TAG` | `latest` | Image tag |
| `SYNC_WORKER_PORT` | `8789` | Host port |
| `COGNITO_ISSUER` | Logseq Cognito | JWT issuer |
| `COGNITO_CLIENT_ID` | Logseq client | Primary JWT audience |
| `COGNITO_JWKS_URL` | Logseq Cognito | JWT verification keys |
| `COGNITO_CLIENT_IDS` | empty | Additional comma-separated audiences |
| `OPENAI_APPS_CHALLENGE` | empty | Optional ChatGPT app verification token |
| `DB_SYNC_ADMIN_TOKEN` | empty | Optional operator endpoint token |

## Deploy

```bash
docker compose -f images/sync-worker/docker-compose.yml pull
docker compose -f images/sync-worker/docker-compose.yml up -d
```

Put an HTTPS reverse proxy in front of the mapped port. The main integration endpoints are:

```text
MCP:      https://sync.example.com/mcp
OpenAPI:  https://sync.example.com/openapi.json
Docs:     https://sync.example.com/api-docs
```

Run one replica only because all Worker state is local to the Docker volume.

## Build and publish

Workflow: `.github/workflows/build-selfhost-sync-worker-image.yml`

- Manual dispatch accepts optional `logseq_ref` and `image_tag` values.
- The fallback build runs Saturdays at 04:00 UTC.
- Pushes to `master` build when image inputs change.
- Published image: `ghcr.io/<GHCR_OWNER>/ls-containerized-sync-worker:<tag>`.

## Smoke test

```bash
IMAGE=ghcr.io/<GHCR_OWNER>/ls-containerized-sync-worker:<tag> ./images/sync-worker/scripts/smoke-test.sh
```

The test checks startup migrations, health, OpenAPI, API docs, unauthenticated graph rejection, and the MCP route.

## Auto-track upstream

The image shares `images/sync/UPSTREAM_DB_SYNC_REF`, updated Saturdays at 03:00 UTC by `.github/workflows/bump-selfhost-sync-ref.yml`.
