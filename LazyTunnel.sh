#!/bin/bash

# File to store the IP addresses
ip_file="/root/ip_addresses.txt"

# Path to the current script
script_path=$(realpath "$0")

# Function to get the main IP address of the server
get_main_ip() {
    curl -s https://api.ipify.org || ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d "/" -f 1
}

if [[ $1 == "uninstall" ]]; then
    # Uninstall mode
    systemctl stop iptables-config
    systemctl disable iptables-config
    rm /etc/systemd/system/iptables-config.service
    rm "$ip_file"
    echo "Service and IP addresses file removed."
    exit 0
fi

if [ ! -f "$ip_file" ]; then
    # File does not exist, generate Mainland IP and ask for Foreign IP
    mainland_ip=$(get_main_ip)
    echo "Mainland IP Address (automatically detected): $mainland_ip"
    echo ""
    echo -n "Enter Foreign IP Address: "
    read foreign_ip

    # Store the input values for future use
    echo "$mainland_ip" > "$ip_file"
    echo "$foreign_ip" >> "$ip_file"

    # Create systemd service file
    cat > /etc/systemd/system/iptables-config.service << EOF
[Unit]
Description=Configure IPTables

[Service]
ExecStart=$script_path

[Install]
WantedBy=multi-user.target
EOF

    # Enable the service
    systemctl enable iptables-config
else
    # File exists, read the values
    mainland_ip=$(sed -n '1p' "$ip_file")
    foreign_ip=$(sed -n '2p' "$ip_file")
fi

# Run sysctl command
sysctl net.ipv4.ip_forward=1

# Run iptables commands with stored or input values
iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination $mainland_ip
iptables -t nat -A PREROUTING -j DNAT --to-destination $foreign_ip
iptables -t nat -A POSTROUTING -j MASQUERADE
