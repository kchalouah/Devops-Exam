#!/bin/bash
# Run this on the MASTER node ONLY

# 1. Initialize the cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.32.0

# 2. Configure kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 3. Install Flannel (CNI)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# 4. Generate Join command for workers
echo "-----------------------------------------"
echo "RUN THE FOLLOWING ON WORKER NODES:"
kubeadm token create --print-join-command
echo "-----------------------------------------"
