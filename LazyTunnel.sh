#!/bin/bash

# Function to print characters with delay
print_with_delay() {
    text="$1"
    delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}

# Introduction animation
print_with_delay "LazyTunnel by DEATHLINE | @NamelesGhoul" 0.1

SERVICE_FILE="/etc/systemd/system/iptables.service"
IP_FILE="/root/ip.txt"
SCRIPT_FILE="/root/LazyTunnel.sh"
HOSTS_FILE="/etc/hosts"

# Function to download the script
download_script() {
  curl -fsSL -o "${SCRIPT_FILE}" https://raw.githubusercontent.com/deathline94/LazyTunnel/main/LazyTunnel.sh
  chmod +x "${SCRIPT_FILE}"
}

# Function to get the current SSH port
get_ssh_port() {
  ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}')
  if [ -z "$ssh_port" ]; then
    ssh_port=22
  fi
  echo "Detected SSH port: $ssh_port"
}

# Function to install IPTables rules and set up service
install() {
  # Get current SSH port
  get_ssh_port

  # Ask user whether to tunnel all ports or specific ports
  read -p "Do you want to tunnel all ports (excluding SSH port $ssh_port)? [y/n]: " tunnel_all
  if [[ "$tunnel_all" == "y" || "$tunnel_all" == "Y" ]]; then
    tunnel_all_ports=true
  else
    tunnel_all_ports=false
    read -p "Please enter the ports you want to tunnel, separated by spaces (e.g., 80 443 1194): " user_ports
    # Convert user_ports into an array
    IFS=' ' read -r -a ports_array <<< "$user_ports"
  fi

  # Check and update /etc/hosts
  hostname=$(hostname)
  if ! grep -q "127.0.0.1 ${hostname}" "${HOSTS_FILE}"; then
    echo "127.0.0.1 ${hostname}" >> "${HOSTS_FILE}"
    echo "Added 127.0.0.1 ${hostname} to ${HOSTS_FILE}"
  fi

  # Enable IP forwarding
  sysctl -w net.ipv4.ip_forward=1

  # Get mainland IP address
  mainland_ip=$(curl -s https://api.ipify.org)
  echo "Mainland IP Address (automatically detected): ${mainland_ip}"
  read -p "Foreign IP Address: " foreign_ip

  # Save IP addresses to file
  echo "${mainland_ip}" > "${IP_FILE}"
  echo "${foreign_ip}" >> "${IP_FILE}"
  echo "${ssh_port}" >> "${IP_FILE}"

  # Flush existing IPTables rules
  iptables -F
  iptables -t nat -F

  # Set up IPTables rules
  if [ "$tunnel_all_ports" = true ]; then
    # Exclude SSH port from forwarding
    iptables -t nat -A PREROUTING -p tcp --dport "$ssh_port" -j DNAT --to-destination "${mainland_ip}"
    iptables -t nat -A PREROUTING -p tcp -j DNAT --to-destination "${foreign_ip}"
  else
    # Forward only specified ports
    for port in "${ports_array[@]}"; do
      if [ "$port" != "$ssh_port" ]; then
        iptables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "${foreign_ip}"
      else
        # Exclude SSH port
        iptables -t nat -A PREROUTING -p tcp --dport "$ssh_port" -j DNAT --to-destination "${mainland_ip}"
      fi
    done
    # Ensure SSH port is forwarded to mainland IP
    if [[ ! " ${ports_array[@]} " =~ " ${ssh_port} " ]]; then
      iptables -t nat -A PREROUTING -p tcp --dport "$ssh_port" -j DNAT --to-destination "${mainland_ip}"
    fi
  fi

  # Set up POSTROUTING
  iptables -t nat -A POSTROUTING -j MASQUERADE

  # Create and enable systemd service
  echo "[Unit]
Description=Persistent IPTables NAT rules
Before=network.target
[Service]
Type=oneshot
ExecStart=/usr/sbin/iptables-restore /etc/iptables/rules.v4
ExecReload=/usr/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" | sudo tee "${SERVICE_FILE}" > /dev/null

  # Save IPTables rules to a file
  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4

  sudo systemctl enable iptables > /dev/null 2>&1
  sudo systemctl start iptables

  echo "Installation complete."
}

# Function to uninstall IPTables rules and remove service
uninstall() {
  echo "Uninstalling..."

  # Read IP addresses from file
  mainland_ip=$(sed -n '1p' "${IP_FILE}")
  foreign_ip=$(sed -n '2p' "${IP_FILE}")
  ssh_port=$(sed -n '3p' "${IP_FILE}")

  # Flush IPTables rules
  iptables -F
  iptables -t nat -F

  # Stop and disable the service
  sudo systemctl stop iptables
  sudo systemctl disable iptables > /dev/null 2>&1

  # Remove service file, IP file, and IPTables rules file
  sudo rm -f "${SERVICE_FILE}"
  sudo rm -f "${IP_FILE}"
  sudo rm -f "${SCRIPT_FILE}"
  sudo rm -f /etc/iptables/rules.v4

  echo "Uninstallation complete."
}

# Main script logic
if [[ "$1" == "uninstall" ]]; then
  uninstall
else
  download_script
  install
fi
