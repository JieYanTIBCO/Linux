#!/bin/bash
# Filename: set-static-ip.sh
# Purpose: Backup current network config → Disable DHCP → Set static IP → Preserve other parameters
# Permissions: sudo required
# Usage: sudo ./set-static-ip.sh <interface> <new-IP/CIDR>

# Create log file with timestamp
LOG_FILE="setup.log"
echo "=== Static IP Setup started at $(date) ===" >> $LOG_FILE

# Send output to both console and log file
exec > >(tee -a $LOG_FILE) 2>&1

set -eo pipefail  # Strict error checking

# =====================
# Function Definitions
# =====================

# Clean exit function
clean_exit() {
  local exit_code=$1
  shift
  echo -e "\n❌ Error: $*" >&2
  echo "=== Setup failed at $(date) with error: $* ===" >> $LOG_FILE
  exit $exit_code
}

# Get current network parameters
get_current_config() {
  local interface=$1
  local config_file=$2
  
  echo "Checking config file: $config_file"
  
  # Check if config file exists
  if [ ! -f "$config_file" ]; then
    clean_exit 1 "Config file does not exist: $config_file"
  fi
  
  # Display config file for debugging
  echo "Config file content:"
  cat "$config_file"
  echo ""
  
  # Extract current IP address
  current_ip=$(ip -4 addr show "$interface" | grep -w inet | awk '{print $2}')
  echo "Current IP: $current_ip"
  
  # Get default gateway from routing table
  current_gateway=$(ip route show default | awk '/default/ {print $3}')
  echo "Gateway from routing table: $current_gateway"
  
  # Get DNS servers using resolvectl (more accurate method)
  echo "Retrieving DNS server info..."
  if command -v resolvectl &> /dev/null; then
    # Get DNS server for the specific interface
    current_dns=$(resolvectl status "$interface" | grep "Current DNS Server:" | awk '{print $4}')
    if [ -z "$current_dns" ]; then
      # If no interface-specific DNS found, try to get any DNS server
      current_dns=$(resolvectl status | grep "DNS Servers:" | head -1 | awk '{print $3}')
    fi
    echo "DNS from resolvectl: $current_dns"
  else
    # Fall back to resolv.conf if resolvectl is unavailable
    current_dns=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -1)
    echo "DNS from resolv.conf: $current_dns (resolvectl unavailable)"
  fi
  
  # Extract DHCP settings
  current_dhcp=$(grep -A3 "$interface:" "$config_file" | grep -E 'dhcp4:|dhcp:' | head -1 | sed -E 's/.*dhcp4:|dhcp:[ ]*(true|false|yes|no).*/\1/')
  echo "DHCP status: $current_dhcp"
  
  # Error handling
  if [ -z "$current_gateway" ]; then
    clean_exit 1 "Unable to detect gateway, please check network connection or specify manually"
  fi
  
  if [ -z "$current_dns" ]; then
    # Use common DNS server as fallback
    current_dns="8.8.8.8"
    echo "No DNS server found, using default: $current_dns"
  fi
  
  # Display extracted network parameters
  echo -e "\n📊 Current Network Parameters:"
  echo "========================"
  echo "Interface: $interface"
  echo "IP Address: $current_ip"
  echo "Gateway: $current_gateway"
  echo "DNS Server: $current_dns"
  echo "DHCP Status: $current_dhcp"
  echo "========================\n"
}

# =====================
# Main Program
# =====================

# Check root privileges
[ "$EUID" -ne 0 ] && clean_exit 1 "Must be run with sudo"

# Parameter validation
if [ $# -ne 2 ]; then
  echo "Usage: $0 <interface> <IP-address/CIDR>"
  echo "Example: $0 ens33 192.168.10.101/24"
  exit 1
fi

INTERFACE=$1
NEW_IP=$2
CONFIG_FILE=$(ls /etc/netplan/*.yaml | head -n1)
BACKUP_FILE="${CONFIG_FILE}.bak-$(date +%Y%m%d%H%M%S)"

# Check subnet compatibility
NEW_IP_NETWORK=$(echo $NEW_IP | cut -d'.' -f1-3)
GATEWAY=$(ip route show default | awk '/default/ {print $3}')
GATEWAY_NETWORK=$(echo $GATEWAY | cut -d'.' -f1-3)

echo "Checking IP subnet compatibility..."
if [ "$NEW_IP_NETWORK" != "$GATEWAY_NETWORK" ]; then
  echo "⚠️ WARNING: Your new IP ($NEW_IP_NETWORK.x) is not in the same subnet as your gateway ($GATEWAY_NETWORK.x)"
  echo "This may cause connectivity issues. It is recommended to use an IP in the $GATEWAY_NETWORK.x subnet."
  read -p "Continue anyway? (y/n): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    clean_exit 0 "Operation canceled by user"
  fi
  echo "Proceeding with configuration despite subnet mismatch..."
fi

# Step 1: Backup current configuration
echo "🔧 Backing up network configuration..."
cp -v "$CONFIG_FILE" "$BACKUP_FILE" || clean_exit 1 "Backup failed"

# Get current parameters
echo "📡 Extracting current network parameters..."
get_current_config "$INTERFACE" "$CONFIG_FILE"

# Step 2: Generate new configuration
echo "⚙️ Generating new configuration..."
cat > "$CONFIG_FILE" <<EOF
# Configured on $(date)
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: false     # Disable DHCP
      dhcp6: false
      addresses:
        - $NEW_IP      # Set new IP
      routes:
        - to: default
          via: $current_gateway  # Keep original gateway
      nameservers:
        addresses: []  # Keep original DNS
EOF

# Step 3: Apply configuration with timeout
echo "🚀 Applying new configuration..."
echo "This may take a moment, please wait..."
sudo chmod 600 "$CONFIG_FILE"

# Use timeout command to prevent hanging
echo "Running netplan apply with 30 second timeout..."
if ! timeout 30 netplan apply; then
  echo "‼️ Configuration application timed out or failed, rolling back..."
  cp -f "$BACKUP_FILE" "$CONFIG_FILE"
  netplan apply
  clean_exit 1 "Network configuration rolled back after timeout or failure"
fi

# Brief pause to allow network to stabilize
echo "Waiting for network to stabilize..."
sleep 5

# Step 4: Verify results and display new configuration
echo -e "\n✅ Configuration complete! New network parameters:"
echo "========================"

# Show new IP address
new_actual_ip=$(ip -4 addr show "$INTERFACE" | grep -w inet | awk '{print $2}' || echo "Not available")
echo "Interface: $INTERFACE"
echo "New IP Address: $new_actual_ip (Configured as: $NEW_IP)"
echo "Default Gateway: $(ip route show default | awk '{print $3}' || echo "Not available")"
echo "DNS Server: $(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -1 || echo "Not available")"
echo "========================"

# Test network connectivity
echo -e "\n🔍 Testing network connectivity:"
echo "========================"
echo "Pinging gateway..."
if ping -c 2 $current_gateway &>/dev/null; then
  echo "✅ Gateway reachable: $current_gateway"
else
  echo "❌ Cannot reach gateway: $current_gateway"
  echo "Network connectivity issues detected. You may need to rollback:" | tee -a $LOG_FILE
  echo "sudo cp $BACKUP_FILE $CONFIG_FILE && sudo netplan apply" | tee -a $LOG_FILE
fi

echo "Pinging DNS server..."
if ping -c 2 $current_dns &>/dev/null; then
  echo "✅ DNS server reachable: $current_dns"
else
  echo "❌ Cannot reach DNS server: $current_dns"
fi

echo "Pinging internet (8.8.8.8)..."
if ping -c 2 8.8.8.8 &>/dev/null; then
  echo "✅ Internet connectivity: OK"
else
  echo "❌ Cannot reach internet"
fi
echo "========================"

# Record completion in log
echo "=== Static IP Setup completed at $(date) ===" >> $LOG_FILE
echo "Log saved to: $LOG_FILE"

# Provide rollback instructions
echo -e "\n📝 If you experience connectivity issues, restore the backup with:"
echo "sudo cp $BACKUP_FILE $CONFIG_FILE && sudo netplan apply"