# DevOps Exam - Guide de Reproduction Complet

Ce guide détaille toutes les étapes pour reconstruire l'infrastructure et le déploiement GitOps de l'application ToDo.

### 1. Préparation (Local Windows)
1. **Identifiants AWS** : Récupérer les clés (Access Key, Secret Key, Session Token) depuis AWS Academy.
2. **Clé SSH** : Créer un fichier `vockey.pem` avec la clé privée RSA fournie par AWS.

---

### 2. Infrastructure (Terraform)
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
4. Noter l'IP du Master (`master_public_ip`).

---

### 3. Installation Kubernetes (Sur les instances)
Pour chaque instance (Master + 2 Workers) :
1. Envoyer le script d'installation :
   ```powershell
   scp -i vockey.pem scripts/install_k8s.sh ubuntu@<NODE_IP>:/home/ubuntu/
   ```
2. Lancer l'installation :
   ```powershell
   ssh -i vockey.pem ubuntu@<NODE_IP> "bash install_k8s.sh"
   ```

**Initialisation du Master :**
1. Envoyer et lancer `init_master.sh` sur le Master :
   ```powershell
   scp -i vockey.pem scripts/init_master.sh ubuntu@<MASTER_IP>:/home/ubuntu/
   ssh -i vockey.pem ubuntu@<MASTER_IP> "bash init_master.sh"
   ```
2. **Copier la commande `kubeadm join`** affichée à la fin.

**Rattachement des Workers :**
1. Sur chaque Worker, coller la commande avec `sudo` :
   ```bash
   sudo kubeadm join ...
   ```

---

### 4. GitOps avec Argo CD (Sur le Master)
1. Installer Argo CD :
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```
2. Installer le Controller Ingress (pour DuckDNS) :
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
   ```
3. Exposer l'interface Argo CD :
   ```bash
   kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "targetPort": 8081, "nodePort": 30443}]}}'
   ```
4. Déployer l'application GitOps :
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kchalouah/Devops-Exam/main/argocd/argocd-app.yaml
   ```

---

### 5. Finalisation (DNS)
1. Mettre à jour l'IP sur le site [DuckDNS](https://www.duckdns.org) avec l'IP du Master.
2. L'application est accessible sur : `http://karim-exam-devops.duckdns.org`
3. Argo CD est accessible sur : `https://<MASTER_IP>:30443` (admin / mdp initial).

---

### 6. Pipelines CI/CD
- **CI** : Chaque push sur `main` recrée l'image `1.0.0` sur Docker Hub.
- **GitOps** : Argo CD synchronise automatiquement les changements faits dans le dossier `k8s/` du dépôt.
