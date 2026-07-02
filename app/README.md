# DevOps Demo App

Application fil rouge de la formation.

## Endpoints

- `/` : réponse JSON simple
- `/health` : healthcheck HTTP pour Docker/Kubernetes
- `/metrics` : métriques Prometheus en texte brut

## Commandes

```bash
npm test
npm start
docker build -t devops-app:1.0.0 .
docker run -d --rm -p 3000:3000 --name devops-smoke devops-app:1.0.0
npm run smoke-test
docker stop devops-smoke
```

## Image Kubernetes

Avant le déploiement Kubernetes, construire et valider l'image :

```bash
# depuis la racine du dépôt
./infra/k8s/scripts/build-and-test-image.sh
./infra/k8s/scripts/load-image.sh
```

Voir [docs/06-image-kubernetes.md](../docs/06-image-kubernetes.md).

Le déploiement Kubernetes (exercice 07) se trouve dans `infra/kubernetes/terraform` — voir [docs/07-kubernetes-terraform.md](../docs/07-kubernetes-terraform.md).
