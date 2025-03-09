#!/bin/bash

# Exit on any error
set -e

echo "[TASK 1] Install MetalLB"
# Create metallb namespace
kubectl create namespace metallb-system

# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Wait for MetalLB pods to be ready
echo "Waiting for MetalLB pods to be ready..."
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

echo "[TASK 2] Configure MetalLB IP Pool"
# Note: Replace IP range according to your network setup
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.10.201-192.168.10.250  # Reserved range for LoadBalancer services
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
EOF

echo "[TASK 3] Install NGINX Ingress Controller"
# Install NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.kind=DaemonSet \
  --set controller.tolerations[0].key=node-role.kubernetes.io/control-plane \
  --set controller.tolerations[0].operator=Exists \
  --set controller.tolerations[0].effect=NoSchedule

echo "[TASK 4] Install cert-manager"
# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Wait for cert-manager to be ready
echo "Waiting for cert-manager pods to be ready..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=90s

echo "Ingress setup complete!"
echo ""
echo "Next steps:"
echo "1. Verify MetalLB installation:"
echo "   kubectl -n metallb-system get pods"
echo "2. Verify NGINX Ingress Controller:"
echo "   kubectl -n ingress-nginx get pods"
echo "3. Verify cert-manager:"
echo "   kubectl -n cert-manager get pods"
echo ""
echo "Note: Update the MetalLB IP range in this script according to your network"
