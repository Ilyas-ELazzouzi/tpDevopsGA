# tpDevopsGA

Projet fil rouge DevOps : application Node.js, CI/CD, infrastructure Terraform/Ansible, puis Kubernetes.

## Structure

| Dossier | Rôle |
|---------|------|
| `app/` | Application Node.js (API `/`, `/health`, `/metrics`) |
| `infra/terraform/` | Provisionnement Docker (dev/prod) |
| `infra/ansible/` | Configuration des conteneurs (inventaire généré depuis Terraform) |
| `infra/k8s/` | Préparation image Docker pour Kubernetes |
| `infra/kubernetes/terraform/` | Déploiement Kubernetes (Terraform) |
| `docs/` | Guides des exercices |

## Démarrage rapide

```bash
# Tests application
cd app && npm test

# Image Docker (prérequis Kubernetes)
docker build -t devops-app:1.0.0 app
./infra/k8s/scripts/build-and-test-image.sh
```

## Exercices

- [06 — Image Docker pour Kubernetes](docs/06-image-kubernetes.md)
- [07 — Déploiement Kubernetes avec Terraform](docs/07-kubernetes-terraform.md)
