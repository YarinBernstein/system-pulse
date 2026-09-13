#!/bin/bash
# Runs once when the NAT instance boots. Turns this small server into a
# simple internet router so the private subnet (backend + redis) can reach
# the internet to install Docker and download this project's code, without
# needing AWS's paid NAT Gateway service.
set -euxo pipefail

sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

dnf install -y iptables

# Detect the real primary network interface name instead of assuming
# "eth0" - modern instance types (e.g. t3) rename it to something like
# "ens5" via the ENA driver, which silently breaks a hardcoded rule.
IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)

iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
iptables -A FORWARD -j ACCEPT
iptables-save > /etc/sysconfig/iptables
