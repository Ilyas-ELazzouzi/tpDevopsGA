#!/usr/bin/env bash
set -euo pipefail

echo "==> Vérification des outils"
for cmd in docker kubectl terraform; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' introuvable. Installez-le avant de continuer." >&2
    exit 1
  fi
done

if [[ ! -f "${KUBECONFIG:-$HOME/.kube/config}" ]]; then
  echo "==> Aucun kubeconfig trouvé. Démarrage d'un cluster local..."
  if command -v minikube >/dev/null 2>&1; then
    minikube start
  elif command -v kind >/dev/null 2>&1; then
    kind create cluster --name devops-training
    echo "IMPORTANT: dans terraform.tfvars, utilisez kube_context = \"kind-devops-training\""
  else
    echo "ERROR: ni minikube ni kind n'est installé." >&2
    echo "Installez l'un des deux, ou activez Kubernetes dans Docker Desktop." >&2
    exit 1
  fi
fi

echo "==> Contexte kubectl actuel"
kubectl config current-context
kubectl get nodes

echo "==> Image applicative"
if ! docker image inspect devops-app:1.0.0 >/dev/null 2>&1; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  docker build -t devops-app:1.0.0 "$ROOT_DIR/app"
fi

if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
  minikube image load devops-app:1.0.0
elif command -v kind >/dev/null 2>&1; then
  kind load docker-image devops-app:1.0.0 --name devops-training
fi

echo
echo "OK: cluster prêt. Lancez ensuite :"
echo "  cd infra/kubernetes/terraform"
echo "  cp secret.auto.tfvars.example secret.auto.tfvars"
echo "  terraform init && terraform apply"
