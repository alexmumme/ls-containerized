#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-${1:-ls-containerized-sync-worker:local}}"
PORT="${PORT:-18789}"
CONTAINER_NAME="${CONTAINER_NAME:-ls-containerized-sync-worker-smoke}"
MAX_RETRIES="${MAX_RETRIES:-30}"

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

docker run -d --rm \
  --name "${CONTAINER_NAME}" \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /app/worker/.wrangler/tmp:uid=1000,gid=1000,mode=1777 \
  --tmpfs /app/worker/node_modules/.mf:uid=1000,gid=1000,mode=1777 \
  -v "${CONTAINER_NAME}_data:/data" \
  -p "127.0.0.1:${PORT}:8787" \
  "${IMAGE}" >/dev/null

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker volume rm "${CONTAINER_NAME}_data" >/dev/null 2>&1 || true
}
trap cleanup EXIT

health_json=''
for _ in $(seq 1 "${MAX_RETRIES}"); do
  if health_json="$(curl --noproxy '*' -fsS "http://127.0.0.1:${PORT}/health" 2>/dev/null)"; then
    break
  fi
  sleep 1
done

if ! grep -Eq '"ok"[[:space:]]*:[[:space:]]*true' <<<"${health_json}"; then
  echo "sync worker did not become ready after ${MAX_RETRIES} retries" >&2
  docker logs --tail 100 "${CONTAINER_NAME}" >&2 || true
  exit 1
fi

openapi_json="$(curl --noproxy '*' -fsS "http://127.0.0.1:${PORT}/openapi.json")"
grep -Eqi '"openapi"[[:space:]]*:' <<<"${openapi_json}"

docs_html="$(curl --noproxy '*' -fsS "http://127.0.0.1:${PORT}/api-docs")"
grep -Eqi '<!doctype html|<html|Logseq Server API' <<<"${docs_html}"

oauth_metadata="$(curl --noproxy '*' -fsS "http://127.0.0.1:${PORT}/.well-known/oauth-protected-resource")"
grep -Eq '"resource"[[:space:]]*:[[:space:]]*"http://127\.0\.0\.1:' <<<"${oauth_metadata}"

graphs_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/graphs")"
test "${graphs_status}" = 401

mcp_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' -H 'accept: application/json, text/event-stream' "http://127.0.0.1:${PORT}/mcp")"
case "${mcp_status}" in
  200|400|405) ;;
  *)
    echo "expected /mcp to exist, got status ${mcp_status}" >&2
    exit 1
    ;;
esac

echo "smoke test passed"
