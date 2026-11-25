#!/bin/bash
# Remove vc520-ports. A reboot returns the I354 ports and switch to their unconfigured state.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
systemctl disable --now vc520-media.service vc520-ports.service 2>/dev/null || true
rm -f /etc/systemd/system/vc520-ports.service /etc/systemd/system/vc520-media.service /usr/local/sbin/vc520-ports
rm -rf /usr/local/share/doc/vc520-ports
systemctl daemon-reload
echo "removed (left /etc/default/vc520-ports in place). Reboot to fully revert."
