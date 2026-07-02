# Exercice 06 — Figer l'application en image Docker

Avant de migrer vers Kubernetes, il faut figer l'application sous forme d'image. Kubernetes ne construit pas l'image pour nous : il consomme une image déjà disponible dans le runtime du cluster.

## Pré-requis

- Docker opérationnel
- le dossier `app/` (application fil rouge)
- un cluster local `minikube` ou `kind` déjà créé

Vérifier :

```bash
docker version
kubectl config current-context
kubectl get nodes
```

## 1. Lire le Dockerfile du fil rouge

Depuis la racine du dépôt :

```bash
sed -n '1,120p' app/Dockerfile
```

Repérer :

- le stage `test`, qui exécute `npm test`
- le stage `production`, qui installe uniquement les dépendances runtime
- `USER node`
- `EXPOSE 3000`
- le `HEALTHCHECK` sur `/health`

## 2. Construire l'image

```bash
docker build -t devops-app:1.0.0 app
```

Ou via le script :

```bash
./infra/k8s/scripts/build-and-test-image.sh
```

Vérifier :

```bash
docker images devops-app
docker image inspect devops-app:1.0.0 --format '{{.Config.User}} {{.Config.ExposedPorts}}'
```

Résultat attendu :

- l'image `devops-app:1.0.0` existe
- l'utilisateur runtime est `node`
- le port exposé est `3000/tcp`

## 3. Tester l'image avant Kubernetes

```bash
docker run --rm -d \
  --name devops-app-image-check \
  -p 18080:3000 \
  devops-app:1.0.0

curl http://localhost:18080/
curl http://localhost:18080/health
docker logs devops-app-image-check --tail=20
docker stop devops-app-image-check
```

Le script `build-and-test-image.sh` enchaîne build, inspection et ces tests automatiquement.

## 4. Charger l'image dans le cluster local

```bash
./infra/k8s/scripts/load-image.sh
```

### minikube

```bash
minikube image load devops-app:1.0.0
minikube image ls | grep devops-app
```

### kind

```bash
kind load docker-image devops-app:1.0.0 --name devops-training
docker exec devops-training-control-plane crictl images | grep devops-app
```

> Adaptez `devops-training` si votre cluster kind a un autre nom (`KIND_CLUSTER_NAME`).

## 5. Contrat pour l'exercice Kubernetes (07)

Ces valeurs sont réutilisées par le Terraform Kubernetes :

```text
image_repository = "devops-app"
image_tag        = "1.0.0"
app_port         = 3000
```

Fichier de référence : `infra/k8s/image-contract.env.example`.

## Pourquoi Kubernetes a besoin de l'image dans le cluster ?

Un cluster Kubernetes local (`minikube`, `kind`) possède son propre runtime de conteneurs, distinct du daemon Docker de votre machine. Quand un Pod démarre, le kubelet demande au runtime de **tirer** (`pull`) l'image depuis un registre ou depuis le cache local du nœud.

Si l'image n'existe que sur votre Docker Desktop et n'a jamais été chargée dans le cluster, le Pod reste en `ImagePullBackOff` ou `ErrImagePull`. D'où l'étape `minikube image load` ou `kind load docker-image` avant le déploiement Terraform.

## Livrable

- [ ] Image locale `devops-app:1.0.0`
- [ ] Test `curl /health` réussi depuis un conteneur Docker local
- [ ] Image chargée dans `minikube` ou `kind`
- [ ] Compréhension : Kubernetes consomme une image déjà disponible, il ne la construit pas

## Aide

### Si Kubernetes ne trouve pas l'image

Symptôme probable dans l'exercice 07 :

```bash
kubectl get pods -n devops-training
kubectl describe pod -n devops-training <pod>
```

Si vous voyez `ImagePullBackOff` ou `ErrImagePull`, rechargez l'image :

```bash
./infra/k8s/scripts/load-image.sh
```

### Nettoyage optionnel

```bash
docker stop devops-app-image-check 2>/dev/null || true
docker image rm devops-app:1.0.0
```
