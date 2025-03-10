#!/bin/bash
# 文件名: set-static-ip.sh
# 用途: 备份当前网络配置 → 禁用 DHCP → 设置静态 IP → 保留其他参数
# 执行权限: sudo required
# 用法: sudo ./set-static-ip.sh <接口名> <新IP/CIDR>

set -eo pipefail  # 严格错误检查

# =====================
# 函数定义
# =====================

# 优雅退出函数
clean_exit() {
  local exit_code=$1
  shift
  echo -e "\n❌ 错误: $*" >&2
  exit $exit_code
}

# 获取当前网络参数
get_current_config() {
  local interface=$1
  local config_file=$2
  
  echo "正在检查配置文件: $config_file"
  
  # 检查配置文件是否存在
  if [ ! -f "$config_file" ]; then
    clean_exit 1 "配置文件不存在: $config_file"
  fi
  
  # 显示配置文件内容用于调试
  echo "配置文件内容:"
  cat "$config_file"
  echo ""
  
  # 提取当前IP地址
  current_ip=$(ip -4 addr show "$interface" | grep -w inet | awk '{print $2}')
  echo "当前IP地址: $current_ip"
  
  # 从路由表获取网关
  current_gateway=$(ip route show default | awk '/default/ {print $3}')
  echo "从路由表获取的网关: $current_gateway"
  
  # 从resolv.conf获取DNS
  current_dns=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -1)
  echo "从resolv.conf获取的DNS: $current_dns"
  
  # 提取DHCP设置
  current_dhcp=$(grep -A3 "$interface:" "$config_file" | grep -E 'dhcp4:|dhcp:' | head -1 | sed -E 's/.*dhcp4:|dhcp:[ ]*(true|false|yes|no).*/\1/')
  echo "DHCP状态: $current_dhcp"
  
  # 容错处理
  if [ -z "$current_gateway" ]; then
    clean_exit 1 "无法获取网关，请确认网络连接正常或手动指定网关"
  fi
  
  if [ -z "$current_dns" ]; then
    # 尝试使用常见的DNS服务器
    current_dns="8.8.8.8"
    echo "未找到DNS服务器，使用默认值: $current_dns"
  fi
  
  # 显示提取到的网络参数
  echo -e "\n📊 当前网络参数:"
  echo "========================"
  echo "接口: $interface"
  echo "IP地址: $current_ip"
  echo "网关: $current_gateway"
  echo "DNS服务器: $current_dns"
  echo "DHCP状态: $current_dhcp"
  echo "========================\n"
}

# =====================
# 主程序
# =====================

# 检查 root 权限
[ "$EUID" -ne 0 ] && clean_exit 1 "必须使用 sudo 执行"

# 参数验证
if [ $# -ne 2 ]; then
  echo "用法: $0 <网络接口> <IP地址/CIDR>"
  echo "示例: $0 ens33 192.168.2.100/24"
  exit 1
fi

INTERFACE=$1
NEW_IP=$2
CONFIG_FILE=$(ls /etc/netplan/*.yaml | head -n1)
BACKUP_FILE="${CONFIG_FILE}.bak-$(date +%Y%m%d%H%M%S)"

# 第一步: 备份当前配置
echo "🔧 正在备份网络配置..."
cp -v "$CONFIG_FILE" "$BACKUP_FILE" || clean_exit 1 "备份失败"

# 获取当前参数
echo "📡 正在提取当前网络参数..."
get_current_config "$INTERFACE" "$CONFIG_FILE"

# 第二步: 生成新配置
echo "⚙️ 生成新配置..."
cat > "$CONFIG_FILE" <<EOF
# 配置于 $(date)
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: false     # 禁用 DHCP
      dhcp6: false
      addresses:
        - $NEW_IP      # 设置新 IP
      routes:
        - to: default
          via: $current_gateway  # 保留原网关
      nameservers:
        addresses: [$current_dns]  # 保留原 DNS
EOF

# 第三步: 应用配置
echo "🚀 应用新配置..."
chmod 600 "$CONFIG_FILE"
if ! netplan apply; then
  echo "‼️ 配置应用失败，正在回滚..."
  cp -f "$BACKUP_FILE" "$CONFIG_FILE"
  netplan apply
  clean_exit 1 "网络配置回滚完成"
fi

# 第四步: 验证结果并显示新配置
echo -e "\n✅ 配置完成！新网络参数："
echo "========================"
# 显示新的IP地址
new_actual_ip=$(ip -4 addr show "$INTERFACE" | grep -w inet | awk '{print $2}')
echo "接口: $INTERFACE"
echo "新IP地址: $new_actual_ip (配置为: $NEW_IP)"
echo "默认网关: $(ip route show default | awk '{print $3}')"
echo "DNS 服务器: $(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -1)"
echo "========================"