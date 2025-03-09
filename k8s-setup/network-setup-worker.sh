#!/bin/bash

# Exit on any error
set -e

# Check if node number is provided
if [ -z "$1" ]; then
    echo "Error: Please provide node number (1 or 2)"
    echo "Usage: $0 <node_number>"
    exit 1
fi

NODE_NUM=$1
if [[ ! "$NODE_NUM" =~ ^[1-2]$ ]]; then
    echo "Error: Node number must be 1 or 2"
    exit 1
fi

IP_SUFFIX=$((100 + $NODE_NUM))
NODE_IP="192.168.10.$IP_SUFFIX"
HOSTNAME="k8s-node$NODE_NUM"

echo "[TASK 1] Configure Worker Node Network"
# Create netplan configuration
cat <<EOF | sudo tee /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses:
        - $NODE_IP/24
      gateway4: 192.168.10.2
      nameservers:
        addresses: [192.168.10.100]  # Control plane DNS
      dhcp4-overrides:
        use-dns: false
EOF

# Apply network configuration
sudo netplan apply

echo "[TASK 2] Set hostname"
sudo hostnamectl set-hostname $HOSTNAME

echo "[TASK 3] Add local DNS entries"
cat <<EOF | sudo tee -a /etc/hosts
192.168.10.100  k8s-cp.k8s.lab  k8s-cp
192.168.10.101  k8s-node1.k8s.lab  k8s-node1
192.168.10.102  k8s-node2.k8s.lab  k8s-node2
EOF

echo "Network setup complete for worker node $NODE_NUM!"
echo "Current IP address:"
ip addr show ens33 | grep "inet "
echo ""
echo "Testing DNS resolution:"
nslookup k8s-cp.k8s.lab
nslookup $HOSTNAME.k8s.lab

echo "Note: If DNS resolution fails, ensure that dnsmasq is running on the control plane (192.168.10.100)"
