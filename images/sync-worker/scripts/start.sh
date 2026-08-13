#!/bin/sh
set -eu

persist_dir=/data/wrangler
port="${PORT:-8787}"

mkdir -p "${persist_dir}"

wrangler d1 migrations apply DB \
  --config /app/worker/wrangler.selfhost.toml \
  --local \
  --persist-to "${persist_dir}"

exec wrangler dev \
  /app/worker/sync-worker.mjs \
  --no-bundle \
  --config /app/worker/wrangler.selfhost.toml \
  --ip 0.0.0.0 \
  --port "${port}" \
  --persist-to "${persist_dir}"
