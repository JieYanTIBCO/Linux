# Kubernetes Cluster Setup Guide

This guide helps you set up a Kubernetes cluster with 1 control plane and 2 worker nodes.

## Network Architecture

- Control Plane (k8s-cp): 192.168.10.100
- Worker Node 1 (k8s-node1): 192.168.10.101
- Worker Node 2 (k8s-node2): 192.168.10.102
- MetalLB Range: 192.168.10.201-192.168.10.250
- DHCP Range: 192.168.10.103-192.168.10.200

## Setup Steps

### 1. Control Plane Setup

```bash
# Copy scripts to control plane node
scp -r k8s-setup/ user@192.168.10.55:~/

# SSH into control plane
ssh user@192.168.10.55

# Make scripts executable
chmod +x ~/k8s-setup/*.sh
chmod +x ~/k8s-setup/post-init/*.sh

# Setup network and DNS
cd ~/k8s-setup
./network-setup-cp.sh

# Install base components
./base-setup.sh

# Initialize control plane
./control-plane.sh
```

### 2. Worker Node Setup

For each worker node (after cloning VM):

```bash
# Copy scripts to worker node
scp -r k8s-setup/ user@worker-ip:~/

# SSH into worker node
ssh user@worker-ip

# Make scripts executable
chmod +x ~/k8s-setup/*.sh

# Setup network (replace N with 1 or 2)
cd ~/k8s-setup
./network-setup-worker.sh N

# Install base components
./base-setup.sh

# Join cluster using the command from control plane
sudo kubeadm join ...
```

### 3. Post-Installation (on control plane)

After all nodes have joined:

```bash
cd ~/k8s-setup/post-init
./monitoring.sh
./ingress.sh
```

## Verification

1. Check node status:
```bash
kubectl get nodes
```

2. Verify DNS resolution:
```bash
nslookup k8s-cp.k8s.lab
nslookup k8s-node1.k8s.lab
nslookup k8s-node2.k8s.lab
```

3. Check core components:
```bash
kubectl get pods -A
```

## Important Notes

1. Run scripts in the specified order
2. Ensure control plane DNS (dnsmasq) is running before setting up worker nodes
3. Make sure all nodes can reach each other before starting cluster setup
4. Adjust gateway (192.168.10.2) in network scripts if your network is different
