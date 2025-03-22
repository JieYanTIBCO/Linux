#!/bin/bash

# Exit on any error
set -e



echo "[TASK 1] Configure Control Plane Network"

# [TASK 1] Configure Control Plane Network
# NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"  # 硬编码已知文件
NETPLAN_FILE=$(ls /etc/netplan/*.yaml | head -n 1)

# 备份原配置
sudo cp "$NETPLAN_FILE" "$NETPLAN_FILE.bak"

# 写入新配置
sudo tee "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses: [192.168.10.100/24]
      routes:
        - to: default
          via: 192.168.10.2
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

# 设置权限
sudo chmod 600 "$NETPLAN_FILE"
sudo netplan apply

echo "[TASK 2] Set hostname"
sudo hostnamectl set-hostname k8s-cp

echo "[TASK 3] Install and configure dnsmasq"

# Disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl mask systemd-resolved  # 彻底禁止启动

sudo apt update
sudo apt install -y dnsmasq

# Backup original dnsmasq configuration
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup



# Configure dnsmasq
cat <<EOF | sudo tee /etc/dnsmasq.conf
# DNS Configuration
listen-address=127.0.0.1,192.168.10.100
domain=k8s.lab
expand-hosts
local=/k8s.lab/

# Static DNS entries
address=/k8s-cp.k8s.lab/192.168.10.100
address=/k8s-node1.k8s.lab/192.168.10.101
address=/k8s-node2.k8s.lab/192.168.10.102

# DHCP Configuration
dhcp-range=192.168.10.103,192.168.10.200,12h
dhcp-option=option:domain-search,k8s.lab
EOF

# Start and enable dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# Create proper resolv.conf
cat <<EOF | sudo tee /etc/resolv.conf
nameserver 127.0.0.1
search k8s.lab
domain k8s.lab
EOF

# Make resolv.conf immutable to prevent overwriting
sudo chattr +i /etc/resolv.conf

echo "[TASK 4] Add local DNS entries"
cat <<EOF | sudo tee -a /etc/hosts
192.168.10.100  k8s-cp.k8s.lab  k8s-cp
192.168.10.101  k8s-node1.k8s.lab  k8s-node1
192.168.10.102  k8s-node2.k8s.lab  k8s-node2
EOF

echo "Network setup complete for control plane node!"
echo "Current IP address:"
ip addr show ens33 | grep "inet "
echo ""
echo "Testing DNS resolution:"
nslookup k8s-cp.k8s.lab
