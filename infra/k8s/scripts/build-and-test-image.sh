#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
IMAGE="${IMAGE:-devops-app:1.0.0}"
CONTAINER_NAME="${CONTAINER_NAME:-devops-app-image-check}"
HOST_PORT="${HOST_PORT:-18080}"
APP_PORT="${APP_PORT:-3000}"

cd "$ROOT_DIR"

echo "==> Build $IMAGE"
docker build -t "$IMAGE" app

echo "==> Inspect runtime user and exposed ports"
docker image inspect "$IMAGE" --format 'User={{.Config.User}} Ports={{.Config.ExposedPorts}}'

USER="$(docker image inspect "$IMAGE" --format '{{.Config.User}}')"
PORTS="$(docker image inspect "$IMAGE" --format '{{.Config.ExposedPorts}}')"

if [[ "$USER" != "node" ]]; then
  echo "ERROR: expected runtime user 'node', got '$USER'" >&2
  exit 1
fi

if [[ "$PORTS" != *"3000/tcp"* ]]; then
  echo "ERROR: expected exposed port 3000/tcp, got '$PORTS'" >&2
  exit 1
fi

docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "==> Run container on http://localhost:${HOST_PORT}"
docker run --rm -d \
  --name "$CONTAINER_NAME" \
  -p "${HOST_PORT}:${APP_PORT}" \
  "$IMAGE"

cleanup() {
  docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in $(seq 1 15); do
  if curl -sf "http://localhost:${HOST_PORT}/health" >/dev/null; then
    break
  fi
  sleep 1
done

echo "==> GET /"
curl -sf "http://localhost:${HOST_PORT}/"

echo
echo "==> GET /health"
curl -sf "http://localhost:${HOST_PORT}/health"

echo
echo "==> Logs (last 5 lines)"
docker logs "$CONTAINER_NAME" --tail=5

echo
echo "OK: image $IMAGE built and verified"
