# Exercice 07 — Migrer l'application vers Kubernetes avec Terraform

## Objectif

Migrer l'application fil rouge des conteneurs Docker provisionnés par Terraform vers Kubernetes, en gardant Terraform comme source de vérité.

L'exercice 06 a rendu le lien Terraform → Ansible propre : Terraform générait l'inventaire, Ansible configurait les conteneurs Docker. Ici, on change de runtime. Kubernetes remplace les conteneurs Docker pilotés un par un, et les informations qui passaient par l'inventaire Ansible deviennent des objets Kubernetes : `ConfigMap`, `Secret`, `Service`, `Deployment`.

À la fin de l'exercice, vous aurez :

- une image Docker `devops-app:1.0.0`
- un cluster Kubernetes local qui exécute l'application
- un namespace, une ConfigMap, un Secret, PostgreSQL, un Deployment applicatif et un Service créés par Terraform
- une preuve de fonctionnement via `kubectl` et `curl`
- une bascule contrôlée depuis l'ancien runtime Docker vers Kubernetes

## Contexte

### Ancien flux (exercice 06)

- Terraform provider Docker → conteneurs Docker locaux
- `terraform output -raw ansible_inventory` → inventaire Ansible généré
- Ansible → configuration des conteneurs existants

### Nouveau flux (exercice 07)

- Terraform provider Kubernetes → objets Kubernetes
- `ConfigMap` / `Secret` → configuration applicative
- `Service` → nom réseau stable pour l'application et la base
- `Deployment` → nombre de replicas, probes et rolling updates

On ne génère plus d'inventaire Ansible pour les pods. Dans Kubernetes, les pods sont éphémères : on cible des labels, des Services et des Deployments, pas des noms de conteneurs écrits quelque part.

## Pré-requis

- Docker opérationnel
- `terraform` et `kubectl`
- un cluster local `minikube` ou `kind`
- le contexte `kubectl` pointe sur le bon cluster
- exercice 06 terminé : image `devops-app:1.0.0` construite et chargée dans le cluster

Vérifier :

```bash
kubectl config current-context
kubectl get nodes
docker images devops-app:1.0.0
```

Pour `minikube` :

```bash
minikube image ls | grep devops-app
```

Pour `kind` :

```bash
docker exec devops-training-control-plane crictl images | grep devops-app
```

Rappel du flux précédent (non réutilisé en Kubernetes) :

```bash
cd infra/terraform/environments/dev
terraform output -raw ansible_inventory | head -40

cd ../../../ansible
./scripts/render-inventory.sh
ansible-inventory -i inventory.yml --graph
```

## Structure

```
infra/kubernetes/terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── secret.auto.tfvars.example
```

## Déploiement

### 1. Préparer les secrets

```bash
cd infra/kubernetes/terraform
cp secret.auto.tfvars.example secret.auto.tfvars
```

Pour **kind**, adapter le contexte dans `terraform.tfvars` :

```hcl
kube_context = "kind-devops-training"
```

(Voir aussi `terraform.tfvars.kind.example`.)

### 2. Appliquer Terraform

```bash
terraform init
terraform fmt
terraform plan
terraform apply
```

Vérifier :

```bash
terraform output
kubectl get all -n devops-training
kubectl wait --for=condition=available deployment/devops-app -n devops-training --timeout=120s
kubectl exec -n devops-training deploy/devops-app -- printenv | grep -E 'APP_LOG_LEVEL|LOG_LEVEL|DB_HOST'
```

### 3. Accéder à l'application

Utiliser le port `18080` pour éviter un conflit avec les anciens conteneurs Docker sur `8080`/`8081` :

```bash
kubectl port-forward -n devops-training svc/devops-app-svc 18080:80
```

Dans un autre terminal :

```bash
curl http://localhost:18080/
curl http://localhost:18080/health
```

Ou utiliser la commande générée :

```bash
terraform output -raw port_forward_command
```

## Bascule depuis Docker/Ansible

Pendant quelques minutes, les deux versions peuvent coexister :

- **ancienne** : conteneurs Docker (exercice 06) + Ansible
- **nouvelle** : pods Kubernetes via `devops-app-svc`

Quand Kubernetes fonctionne, détruire l'ancien runtime Docker :

```bash
cd infra/terraform/environments/dev
terraform destroy -var-file="terraform.tfvars" -var="db_password=secret123"
```

Le déploiement Kubernetes reste dans `infra/kubernetes/terraform` et continue de fonctionner.

## Scaling déclaratif

Dans `terraform.tfvars`, changer `app_replicas = 5`, puis :

```bash
terraform plan
terraform apply
kubectl get pods -n devops-training -l app=devops-app
```

Comparer avec un changement manuel :

```bash
kubectl scale deployment devops-app --replicas=2 -n devops-training
terraform plan
```

Terraform doit détecter un **drift** : l'état réel ne correspond plus au code.

## Rolling update déclaratif

```bash
docker build -t devops-app:1.0.1 app
./infra/k8s/scripts/load-image.sh   # IMAGE=devops-app:1.0.1
```

Dans `terraform.tfvars` : `image_tag = "1.0.1"`, puis :

```bash
terraform apply
kubectl rollout status deployment/devops-app -n devops-training
kubectl rollout history deployment/devops-app -n devops-training
```

## Pourquoi Kubernetes ne remplace pas la construction d'image ?

Kubernetes **consomme** une image déjà disponible dans le runtime du cluster. Terraform Kubernetes crée les objets (`Deployment`, `Service`, etc.) mais ne build pas l'image. C'est le rôle de l'exercice 06 (`docker build` + `minikube image load` / `kind load docker-image`).

## Livrable

- [ ] Dossier `infra/kubernetes/terraform`
- [ ] Déploiement Terraform réussi sur Kubernetes
- [ ] Namespace `devops-training`
- [ ] Deployment `devops-app` avec 3 replicas, probes et Service
- [ ] PostgreSQL avec PVC et Service interne
- [ ] Preuve `curl /` et `curl /health`
- [ ] Preuve que `app_log_level` est dans la ConfigMap / variables d'environnement
- [ ] Démonstration d'un scaling via Terraform
- [ ] Explication du drift après un `kubectl scale` manuel

## Aide

### Commandes utiles

```bash
kubectl get all -n devops-training
kubectl describe pod -n devops-training <pod>
kubectl logs -n devops-training -l app=devops-app --tail=50
kubectl get events -n devops-training --sort-by=.metadata.creationTimestamp
kubectl exec -n devops-training deploy/devops-app -- printenv | sort
kubectl get configmap app-config -n devops-training -o yaml
```

### Erreur `config_path refers to an invalid path` ou `connection refused`

Ces erreurs signifient que **Terraform ne peut pas joindre l'API Kubernetes** :

1. **Pas de fichier kubeconfig** (`~/.kube/config` absent)
2. **Cluster arrêté** (minikube/kind éteint)
3. **Mauvais contexte** dans `terraform.tfvars` (`kube_context`)

Correction :

```bash
# Option A — minikube
minikube start
kubectl config current-context   # doit afficher "minikube"

# Option B — kind
kind create cluster --name devops-training
kubectl config current-context   # doit afficher "kind-devops-training"
# puis dans terraform.tfvars : kube_context = "kind-devops-training"

# Vérifier que l'API répond
kubectl get nodes

# Puis relancer Terraform
cd infra/kubernetes/terraform
terraform apply
```

Script automatique :

```bash
./infra/kubernetes/scripts/setup-cluster.sh
```

Si vous êtes sous **WSL** mais que le kubeconfig est sur Windows (Docker Desktop) :

```hcl
# terraform.tfvars
kubeconfig_path = "/mnt/c/Users/<VOTRE_USER>/.kube/config"
kube_context    = "docker-desktop"
```

```bash
./infra/k8s/scripts/load-image.sh
kubectl describe pod -n devops-training <pod>
```

### Nettoyage

```bash
cd infra/kubernetes/terraform
terraform destroy
```

Si le namespace reste bloqué :

```bash
kubectl delete namespace devops-training
```
