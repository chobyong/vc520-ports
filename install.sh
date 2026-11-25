#!/bin/bash
# Install vc520-ports on a VeloCloud Edge 520 running Debian 12 / Turnium.
#   ./install.sh          install + enable at boot
#   ./install.sh --now    also run it immediately
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
command -v python3 >/dev/null || { echo "python3 required"; exit 1; }
cd "$(dirname "$0")"
lspci -n -s 00:14.0 2>/dev/null | grep -q '8086:1f41' || { echo "No Intel I354 at 00:14.0 - not a VC520? aborting"; exit 1; }

install -m 0755 vc520-ports         /usr/local/sbin/vc520-ports
install -m 0644 vc520-ports.service /etc/systemd/system/vc520-ports.service
install -d /usr/local/share/doc/vc520-ports
install -m 0644 README.md           /usr/local/share/doc/vc520-ports/README.md
[ -f /etc/default/vc520-ports ] || install -m 0644 vc520-ports.default /etc/default/vc520-ports

systemctl daemon-reload
systemctl enable vc520-ports.service
echo "installed vc520-ports $(/usr/local/sbin/vc520-ports --version)"
if [ "${1:-}" = "--now" ]; then
  systemctl start vc520-ports.service
  systemctl --no-pager status vc520-ports.service | head -20
  ip -br link
fi
