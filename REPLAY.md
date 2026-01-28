# DevOps Exam - Guide de Reproduction Complet

Ce guide détaille toutes les étapes pour reconstruire l'infrastructure et le déploiement GitOps de l'application ToDo.

## 1. Préparation (Local Windows)

1. **Identifiants AWS** : Récupérer les clés (Access Key, Secret Key, Session Token) depuis AWS Academy.
2. **Clé SSH** : Créer un fichier `labsuser.pem` ou `vockey.pem` avec la clé privée RSA fournie par AWS.
3. **Permissions SSH** : Configurer les permissions de la clé :
   ```powershell
   icacls labsuser.pem /reset
   icacls labsuser.pem /inheritance:r
   icacls labsuser.pem /grant:r "$($env:USERNAME):R"
   ```

---

## 2. Infrastructure (Terraform)

1. Aller dans le dossier `terraform/`.
2. Charger les credentials dans le terminal (PowerShell) :
   ```powershell
   $env:AWS_ACCESS_KEY_ID="..."
   $env:AWS_SECRET_ACCESS_KEY="..."
   $env:AWS_SESSION_TOKEN="..."
   ```
3. Exécuter Terraform :
   ```bash
   terraform init
   terraform apply -auto-approve
   ```
4. Noter l'IP publique du Master (`master_public_ip`).

---

## 3. Installation Kubernetes (Sur les instances)

### Installation des prérequis (Tous les nœuds)

**Important** : Les scripts ont des fins de ligne Windows (CRLF). Utiliser `sed` pour les convertir :

```powershell
# Master
Get-Content scripts\install_k8s.sh | ssh -o StrictHostKeyChecking=no -i labsuser.pem ubuntu@<MASTER_IP> "sed 's/\r$//' | sudo bash"

# Worker 1
Get-Content scripts\install_k8s.sh | ssh -o StrictHostKeyChecking=no -i labsuser.pem ubuntu@<WORKER1_IP> "sed 's/\r$//' | sudo bash"

# Worker 2
Get-Content scripts\install_k8s.sh | ssh -o StrictHostKeyChecking=no -i labsuser.pem ubuntu@<WORKER2_IP> "sed 's/\r$//' | sudo bash"
```

### Initialisation du Master

```powershell
Get-Content scripts\init_master.sh | ssh -o StrictHostKeyChecking=no -i labsuser.pem ubuntu@<MASTER_IP> "sed 's/\r$//' | bash"
```

**Copier la commande `kubeadm join`** affichée à la fin.

### Rattachement des Workers

Se connecter à chaque Worker et exécuter la commande `kubeadm join` :

```powershell
ssh -o StrictHostKeyChecking=no -i labsuser.pem ubuntu@<WORKER_IP>
sudo kubeadm join <MASTER_IP>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
exit
```

---

## 4. GitOps avec Argo CD (Sur le Master)

Se connecter au Master :
```powershell
ssh -o StrictHostKeyChecking=no -i labsuser.pem ubuntu@<MASTER_IP>
```

### 4.1 Installer Argo CD

```bash
# Créer le namespace et installer Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.7/manifests/install.yaml

# Exposer Argo CD via NodePort
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "nodePort": 30080}, {"port": 443, "nodePort": 30443}]}}'

# Récupérer le mot de passe admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### 4.2 Installer NGINX Ingress Controller

```bash
# Installer NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml

# Attendre le déploiement
sleep 30

# Activer hostNetwork pour accès direct via IP publique
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' -p='[{"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true}]'

# Forcer le pod sur le Master node
kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"nodeSelector":{"node-role.kubernetes.io/control-plane":""}}}}}'

# Ajouter la tolération pour le taint du Master
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/tolerations",
    "value": [
      {
        "key": "node-role.kubernetes.io/control-plane",
        "operator": "Exists",
        "effect": "NoSchedule"
      }
    ]
  }
]'

# Vérifier que le pod tourne sur le Master
kubectl get pods -n ingress-nginx -o wide
```

### 4.3 Déployer l'Application via Argo CD

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: todo-app-gitops
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/kchalouah/Devops-Exam.git
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: examen-26
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
```

### 4.4 Vérifier le déploiement

```bash
# Attendre la synchronisation
sleep 15

# Vérifier le statut
kubectl get applications -n argocd
kubectl get pods -n examen-26
kubectl get svc -n examen-26
kubectl get ingress -n examen-26
```

---

## 5. Configuration DNS (DuckDNS)

### Option 1 : Via le site web
1. Aller sur [DuckDNS](https://www.duckdns.org)
2. Se connecter
3. Mettre à jour le domaine `karim-exam-devops` avec l'IP publique du Master

### Option 2 : Via curl (sur le Master)
```bash
curl "https://www.duckdns.org/update?domains=karim-exam-devops&token=VOTRE_TOKEN&ip=<MASTER_PUBLIC_IP>"
```

---

## 6. Accès à l'Application

- **DuckDNS** : `http://karim-exam-devops.duckdns.org`
- **NodePort** : `http://<MASTER_IP>:30001`
- **Argo CD UI** : `http://<MASTER_IP>:30080` (username: `admin`, password: voir étape 4.1)

---

## 7. Pipelines CI/CD

- **CI (GitHub Actions)** : Chaque push sur `main` reconstruit et pousse l'image `kchalouah/simple-todo-app:1.0.0` sur Docker Hub.
- **GitOps (Argo CD)** : Synchronise automatiquement les changements du dossier `k8s/` du dépôt GitHub vers le namespace `examen-26`.

---

## Notes Importantes

- **Fins de ligne** : Les scripts shell ont des fins de ligne Windows (CRLF). Toujours utiliser `sed 's/\r$//'` lors de l'exécution via SSH.
- **Ingress Controller** : Doit tourner sur le Master node avec `hostNetwork: true` pour que DuckDNS fonctionne.
- **Taint Master** : Le Master a un taint `NoSchedule`. L'Ingress Controller nécessite une tolération pour s'y déployer.
- **Security Group** : Ports 22, 80, 443, 6443, et 30000-32767 doivent être ouverts.
