#!/bin/bash

# Exit on any error
set -e

echo "[TASK 1] Install Metrics Server"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Add toleration to metrics-server if control plane is tainted
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"key": "node-role.kubernetes.io/control-plane", "operator": "Exists", "effect": "NoSchedule"}]}]'

echo "[TASK 2] Install Prometheus and Grafana"
# Create monitoring namespace
kubectl create namespace monitoring

# Add Prometheus Stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

echo "Monitoring setup complete!"
echo ""
echo "Access Grafana:"
echo "1. Get admin password:"
echo "   kubectl -n monitoring get secret prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo "2. Forward port:"
echo "   kubectl -n monitoring port-forward svc/prometheus-grafana 3000:80"
echo "3. Visit: http://localhost:3000 (user: admin)"
