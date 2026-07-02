#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$ROOT_DIR/infra/kubernetes/terraform"

if [[ ! -f "$TF_DIR/secret.auto.tfvars" ]]; then
  echo "==> Creating secret.auto.tfvars from example"
  cp "$TF_DIR/secret.auto.tfvars.example" "$TF_DIR/secret.auto.tfvars"
fi

echo "==> Checking cluster access"
kubectl config current-context
kubectl get nodes

echo "==> Checking local image"
docker image inspect devops-app:1.0.0 >/dev/null

cd "$TF_DIR"
terraform init -input=false
terraform fmt
terraform apply -auto-approve

echo
terraform output
echo
echo "Next: run port-forward in another terminal:"
terraform output -raw port_forward_command
