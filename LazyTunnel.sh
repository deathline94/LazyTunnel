#!/bin/bash

script_path="/root/LazyTunnel.sh"

mainland_ip=$(curl -s https://api.ipify.org)

if [[ "$1" == "uninstall" ]]; then
  echo "Uninstalling..."
  iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${mainland_ip}
  iptables -t nat -D PREROUTING -j DNAT --to-destination ${foreign_ip}
  iptables -t nat -D POSTROUTING -j MASQUERADE
  iptables -F
  iptables -X
  iptables -t nat -F
  iptables -t nat -X
  iptables -t mangle -F
  iptables -t mangle -X
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  systemctl stop iptables
  systemctl disable iptables
  rm /etc/systemd/system/iptables.service
  rm /root/ip.txt
  systemctl daemon-reload
  rm "${script_path}"
  exit 0
fi

# Check if the rules are already in place
if iptables -t nat -C PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${mainland_ip} 2>/dev/null; then
  echo "IPTables rules are already set, nothing to do."
  exit 0
fi

echo "Mainland IP Address (automatically detected): ${mainland_ip}"
read -p "Foreign IP Address : " foreign_ip
echo ${foreign_ip} > /root/ip.txt

sysctl net.ipv4.ip_forward=1

iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${mainland_ip}
iptables -t nat -A PREROUTING -j DNAT --to-destination ${foreign_ip}
iptables -t nat -A POSTROUTING -j MASQUERADE

echo "[Unit]
Description=Persistent IPTables NAT rules
Before=network.target
[Service]
ExecStart=/sbin/iptables-restore /root/ip.txt
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/iptables.service

systemctl enable iptables
systemctl start iptables

# Save a copy of the script locally
cp "$0" "${script_path}"
