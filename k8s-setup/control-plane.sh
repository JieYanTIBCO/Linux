#!/bin/bash

# Exit on any error
set -e

echo "[TASK 1] Initialize Kubernetes control plane"
# Pull required container images
sudo kubeadm config images pull

# Initialize control plane (adjust parameters as needed)
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl for the current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[TASK 2] Install Calico CNI"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

echo "[TASK 3] Install Helm package manager"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[TASK 4] Install development tools"
# Install k9s
curl -sS https://webinstall.dev/k9s | bash

# Install kubectx and kubens
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# Install stern
curl -sS https://webinstall.dev/stern | bash

echo "[TASK 5] Add Helm repositories"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo "Control plane setup complete!"
echo "Next steps:"
echo "1. Check node status: kubectl get nodes"
echo "2. Use the join command below on worker nodes"
echo "3. After worker nodes join, run post-init scripts for additional components"
echo ""
echo "Join command for worker nodes:"
kubeadm token create --print-join-command
