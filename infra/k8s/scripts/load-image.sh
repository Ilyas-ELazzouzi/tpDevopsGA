#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-devops-app:1.0.0}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-devops-training}"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "ERROR: image '$IMAGE' not found locally. Run build-and-test-image.sh first." >&2
  exit 1
fi

if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
  echo "==> Loading $IMAGE into minikube"
  minikube image load "$IMAGE"
  minikube image ls | grep devops-app || true
  exit 0
fi

if command -v kind >/dev/null 2>&1; then
  echo "==> Loading $IMAGE into kind cluster '$KIND_CLUSTER_NAME'"
  kind load docker-image "$IMAGE" --name "$KIND_CLUSTER_NAME"
  docker exec "${KIND_CLUSTER_NAME}-control-plane" crictl images | grep devops-app || true
  exit 0
fi

echo "ERROR: neither minikube nor kind is available." >&2
echo "Install one of them, start your cluster, then rerun this script." >&2
exit 1
