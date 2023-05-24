## VPS Tunneling Script 🚀

This simple yet powerful script allows you to instantly tunnel two VPS together using iptables with just one click. It automates the process of IP forwarding and NAT configuration, making it easy for anyone to set up a secure connection between two virtual servers.
## 📖 Usage
### 🚀 Establishing the Tunnel

You can set up the tunnel between two servers with this single line of command:

```
curl -s https://raw.githubusercontent.com/deathline94/LazyTunnel/main/LazyTunnel.sh | sudo bash
```

During execution, the script will automatically detect your server's IP address (Mainland/Iran/China/Russia IP) and ask you for the IP address of the remote server (Foreign IP) you want to tunnel with.
### 🧹 Uninstallation

If you wish to remove the tunneling configurations, you can do it easily using the uninstall argument in the following way:

```
curl -s https://raw.githubusercontent.com/deathline94/LazyTunnel/main/LazyTunnel.sh | sudo bash /dev/stdin uninstall
```
After that, Just reboot the VPS.

### ⚠️ Important Note

Please note that this script modifies your IPTables rules and sets up IP forwarding, which could impact the security posture of your server. Understand the implications before usage and use it responsibly.

If you encounter any issues or have suggestions, feel free to open an issue in this repository. Or contact me on Twitter at @namelesghoul
