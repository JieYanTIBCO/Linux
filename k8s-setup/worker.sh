#!/bin/bash

# Exit on any error
set -e

echo "Worker node setup"
echo "1. Make sure base-setup.sh has been run first"
echo "2. Get the join command from the control plane node by running:"
echo "   kubeadm token create --print-join-command"
echo "3. Run the join command with sudo"
echo ""
echo "Example:"
echo "sudo kubeadm join 192.168.1.10:6443 --token xxxxxx.xxxxxxxxxxxxxxxx --discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
