#!/bin/bash

# Exit on any error
set -e

echo "[TASK 1] System Updates and Essential Packages"
# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install common utilities
sudo apt install -y curl wget git vim htop net-tools tree unzip zip gnupg lsof \
    build-essential cmake gcc g++ make python3 python3-pip tmux

# Install networking tools
sudo apt install -y net-tools iputils-ping traceroute dnsutils tcpdump nmap socat \
    sysstat dstat iotop iftop

echo "[TASK 2] System Configuration for Kubernetes"
# Disable swap completely
sudo swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

# Load all modules immediately
sudo modprobe overlay
sudo modprobe br_netfilter
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh
sudo modprobe nf_conntrack

# Configure sysctl params for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
# Bridge network settings
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1

# Memory settings
vm.swappiness                       = 0
vm.overcommit_memory                = 1

# File system settings
fs.inotify.max_user_watches        = 524288
fs.file-max                        = 2097152

# Network performance tuning
net.core.somaxconn                  = 32768
net.core.netdev_max_backlog         = 16384
net.ipv4.tcp_max_syn_backlog       = 8096
net.ipv4.tcp_tw_reuse              = 1
net.ipv4.ip_local_port_range       = 10240 65535
net.ipv4.tcp_fin_timeout           = 15
net.ipv4.neigh.default.gc_thresh1  = 4096
net.ipv4.neigh.default.gc_thresh2  = 8192
net.ipv4.neigh.default.gc_thresh3  = 16384
EOF

# Apply sysctl params
sudo sysctl --system

echo "[TASK 3] Install and Configure containerd"
# Install containerd
sudo apt-get update
sudo apt-get install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[TASK 4] Installing Kubernetes Components"
# Add Kubernetes apt repository
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[TASK 5] Configure bashrc aliases"
cat <<EOF >> ~/.bashrc
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias ll='ls -ltra'
EOF

# Reload shell configurations
source ~/.bashrc

echo "Base setup complete! Node is ready for Kubernetes cluster configuration."
echo "For control plane node, run control-plane.sh after this"
echo "For worker node, wait for control plane initialization to get the join command"
