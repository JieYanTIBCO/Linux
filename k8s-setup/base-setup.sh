#!/bin/bash

# 创建日志文件并添加时间戳
LOG_FILE="setup.log"
echo "=== Setup started at $(date) ===" > $LOG_FILE

# 配置脚本将所有输出同时发送到控制台和日志文件
exec > >(tee -a $LOG_FILE) 2>&1

# Exit on any error
set -e

# 预配置dpkg以自动接受服务重启提示
export DEBIAN_FRONTEND=noninteractive

echo "[TASK 1] System Updates and Essential Packages"
# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install common utilities
sudo apt install -y curl wget git vim htop net-tools tree unzip zip gnupg lsof \
    build-essential cmake gcc g++ make python3 python3-pip tmux

# Install networking tools
sudo apt install -y net-tools iputils-ping traceroute dnsutils tcpdump nmap socat \
    sysstat dstat iotop iftop

# Install VMware Tools
echo "[TASK 1.1] Installing VMware Tools"
sudo apt install -y open-vm-tools open-vm-tools-desktop

# 检查VMware Tools服务状态而不尝试启用它
echo "检查 VMware Tools 服务状态:"
if systemctl is-active --quiet vmtoolsd; then
  echo "✅ VMware Tools 服务 (vmtoolsd) 已经在运行"
else
  echo "⚠️ VMware Tools 服务 (vmtoolsd) 未运行，尝试启动..."
  sudo systemctl start vmtoolsd || echo "无法启动 VMware Tools 服务，系统可能已通过其他方式配置它"
fi

# 显示服务状态但不使用--no-pager，这样可以看到更多信息
systemctl status vmtoolsd || true

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
for module in overlay br_netfilter ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack; do
  sudo modprobe $module || echo "⚠️ 无法加载模块 $module，继续执行..."
done

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

# Apply sysctl params with error handling
echo "应用系统内核参数..."
sudo sysctl --system || echo "⚠️ 部分内核参数应用失败，但继续执行脚本..."

echo "[TASK 3] Install and Configure containerd"
# Install containerd
sudo apt-get update
sudo apt-get install -y containerd.io || {
  echo "⚠️ 标准仓库中未找到 containerd.io，尝试添加 Docker 仓库..."
  # 添加Docker官方仓库
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y containerd.io
}

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[TASK 4] Installing Kubernetes Components"
# Add Kubernetes apt repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

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
source ~/.bashrc || echo "无法重新加载 ~/.bashrc，重新登录后别名将生效"

echo "Base setup complete! Node is ready for Kubernetes cluster configuration."
echo "For control plane node, run control-plane.sh after this"
echo "For worker node, wait for control plane initialization to get the join command"

# 记录脚本执行完成的时间
echo -e "\n=== Setup completed at $(date) ===\n" | tee -a $LOG_FILE
echo "Setup log has been saved to $LOG_FILE"
