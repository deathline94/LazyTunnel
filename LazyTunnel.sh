#!/bin/bash

SERVICE_FILE="/etc/systemd/system/iptables.service"
IP_FILE="/root/ip.txt"

# Function to copy script to /root directory
copy_script() {
  SCRIPT_PATH=$(readlink -f "$0")
  SCRIPT_NAME=$(basename "$0")
  TARGET_PATH="/root/${SCRIPT_NAME}"

  if [ "${SCRIPT_PATH}" != "${TARGET_PATH}" ]; then
    rsync -a "${SCRIPT_PATH}" "${TARGET_PATH}"
  fi
}

# Function to install IPTables rules and set up service
install() {
  copy_script

  mainland_ip=$(curl -s https://api.ipify.org)
  echo "Mainland IP Address (automatically detected): ${mainland_ip}"
  read -p "Foreign IP Address: " foreign_ip

  # Save IP addresses to file
  echo "${mainland_ip}" > "${IP_FILE}"
  echo "${foreign_ip}" >> "${IP_FILE}"

  # Set up IPTables rules
  sudo iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination "${mainland_ip}"
  sudo iptables -t nat -A PREROUTING -j DNAT --to-destination "${foreign_ip}"
  sudo iptables -t nat -A POSTROUTING -j MASQUERADE

  # Create and enable systemd service
  echo "[Unit]
Description=Persistent IPTables NAT rules
Before=network.target
[Service]
ExecStart=/sbin/iptables-restore ${IP_FILE}
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" | sudo tee "${SERVICE_FILE}" > /dev/null

  sudo systemctl enable iptables
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
  sudo iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination "${mainland_ip}"
  sudo iptables -t nat -D PREROUTING -j DNAT --to-destination "${foreign_ip}"
  sudo iptables -t nat -D POSTROUTING -j MASQUERADE

  # Clear IPTables rules and policies
  sudo iptables -F
  sudo iptables -X
  sudo iptables -t nat -F
  sudo iptables -t nat -X
  sudo iptables -t mangle -F
  sudo iptables -t mangle -X
  sudo iptables -P INPUT ACCEPT
  sudo iptables -P FORWARD ACCEPT
  sudo iptables -P OUTPUT ACCEPT

  # Stop and disable the service
  sudo systemctl stop iptables
  sudo systemctl disable iptables

  # Remove service file and IP file
  sudo rm -f "${SERVICE_FILE}"
  sudo rm -f "${IP_FILE}"

  echo "Uninstallation complete."
}

# Main script logic
if [[ "$1" == "uninstall" ]]; then
  uninstall
else
  install
fi
