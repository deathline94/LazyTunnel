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

# Function to install IPTables rules and set up service
install() {
  # Check and update /etc/hosts
  hostname=$(hostname)
  if ! grep -q "127.0.0.1 ${hostname}" "${HOSTS_FILE}"; then
    echo "127.0.0.1 ${hostname}" >> "${HOSTS_FILE}"
    echo "Added 127.0.0.1 ${hostname} to ${HOSTS_FILE}"
  fi
  
  # Enable IP forwarding
  sysctl net.ipv4.ip_forward=1

  mainland_ip=$(curl -s https://api.ipify.org)
  echo "Mainland IP Address (automatically detected): ${mainland_ip}"
  read -p "Foreign IP Address: " foreign_ip

  # Save IP addresses to file
  echo "${mainland_ip}" > "${IP_FILE}"
  echo "${foreign_ip}" >> "${IP_FILE}"

  # Set up IPTables rules
  iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination "${mainland_ip}"
  iptables -t nat -A PREROUTING -j DNAT --to-destination "${foreign_ip}"
  iptables -t nat -A POSTROUTING -j MASQUERADE

  # Create and enable systemd service
  echo "[Unit]
Description=Persistent IPTables NAT rules
Before=network.target
[Service]
ExecStart=/sbin/iptables-restore ${IP_FILE}
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" | sudo tee "${SERVICE_FILE}" > /dev/null

  sudo systemctl enable iptables > /dev/null 2>&1
  sudo systemctl start iptables

  echo "Installation complete."
}

# Function to uninstall IPTables rules and remove service
uninstall() {
  echo "Uninstalling..."

  # Read mainland IP address from file
  mainland_ip=$(head -n 1 "${IP_FILE}")
  foreign_ip=$(tail -n 1 "${IP_FILE}")

  # Remove IPTables rules
  iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination "${mainland_ip}"
  iptables -t nat -D PREROUTING -j DNAT --to-destination "${foreign_ip}"
  iptables -t nat -D POSTROUTING -j MASQUERADE

  # Clear IPTables rules and policies
  iptables -F
  iptables -X
  iptables -t nat -F
  iptables -t nat -X
  iptables -t mangle -F
  iptables -t mangle -X
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT

  # Stop and disable the service
  sudo systemctl stop iptables
  sudo systemctl disable iptables > /dev/null 2>&1

  # Remove service file and IP file
  sudo rm -f "${SERVICE_FILE}"
  sudo rm -f "${IP_FILE}"
  sudo rm -f "${SCRIPT_FILE}"

  echo "Uninstallation complete."
}

# Main script logic
if [[ "$1" == "uninstall" ]]; then
  uninstall
else
  download_script
  install
fi
