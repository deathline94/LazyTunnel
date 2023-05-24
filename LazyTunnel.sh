#!/bin/bash

script_path="/root/LazyTunnel.sh"

mainland_ip=$(curl -s https://api.ipify.org)

if [[ "$1" == "uninstall" ]]; then
  echo "Uninstalling..."
  foreign_ip=$(cat /root/ip.txt)
  sudo iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${mainland_ip}
  sudo iptables -t nat -D PREROUTING -j DNAT --to-destination ${foreign_ip}
  sudo iptables -t nat -D POSTROUTING -j MASQUERADE
  sudo iptables -F
  sudo iptables -X
  sudo iptables -t nat -F
  sudo iptables -t nat -X
  sudo iptables -t mangle -F
  sudo iptables -t mangle -X
  sudo iptables -P INPUT ACCEPT
  sudo iptables -P FORWARD ACCEPT
  sudo iptables -P OUTPUT ACCEPT
  sudo systemctl stop iptables
  sudo systemctl disable iptables
  sudo rm /etc/systemd/system/iptables.service
  sudo rm /root/ip.txt
  sudo systemctl daemon-reload
  sudo rm "${script_path}"
  exit 0
fi

# Check if the rules are already in place
if sudo iptables -t nat -C PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${mainland_ip} 2>/dev/null; then
  echo "IPTables rules are already set, nothing to do."
  exit 0
fi

echo "Mainland IP Address (automatically detected): ${mainland_ip}"
read -p "Foreign IP Address : " foreign_ip
echo ${foreign_ip} > /root/ip.txt

sysctl net.ipv4.ip_forward=1

sudo iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${mainland_ip}
sudo iptables -t nat -A PREROUTING -j DNAT --to-destination ${foreign_ip}
sudo iptables -t nat -A POSTROUTING -j MASQUERADE

echo "[Unit]
Description=Persistent IPTables NAT rules
Before=network.target
[Service]
ExecStart=/sbin/iptables-restore /root/ip.txt
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/iptables.service > /dev/null

sudo systemctl enable iptables
sudo systemctl start iptables

# Save a copy of the script locally
cp "$0" "${script_path}"
