#!/bin/bash
# Runs once when the NAT instance boots. Turns this small server into a
# simple internet router so the private subnet (backend + redis) can reach
# the internet to install Docker and download this project's code, without
# needing AWS's paid NAT Gateway service.
set -euxo pipefail

sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

dnf install -y iptables
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -j ACCEPT
iptables-save > /etc/sysconfig/iptables
