#!/usr/bin/env bash
###############################################################################
# 00 - System aktualisieren und Basispakete sicherstellen
###############################################################################
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> Warte ggf. auf laufendes cloud-init (nur waehrend der Installation)..."
command -v cloud-init >/dev/null && timeout 300 cloud-init status --wait || true

echo "==> Paketquellen aktualisieren"
apt-get update

echo "==> Distribution aktualisieren"
apt-get -y dist-upgrade

echo "==> Basispakete installieren"
apt-get -y install curl wget vim less sudo ca-certificates

echo "==> Gast-Tools passend zur Plattform installieren"
# PACKER_BUILDER_TYPE wird von Packer gesetzt (proxmox-iso / vsphere-iso / ...).
case "${PACKER_BUILDER_TYPE:-}" in
  vsphere-iso | vmware-iso | vmware-vmx)
    apt-get -y install open-vm-tools
    systemctl enable --now open-vm-tools >/dev/null 2>&1 || true
    ;;
  *)
    # Proxmox/KVM: qemu-guest-agent (auf Debian udev-aktiviert -> enable-Warnung egal)
    apt-get -y install qemu-guest-agent
    systemctl enable qemu-guest-agent >/dev/null 2>&1 || true
    ;;
esac

echo "==> Automatische Updates/Upgrades fuer Templates deaktivieren"
# Hintergrund-apt soll Templates/Klone nicht ueberraschen.
sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades 2>/dev/null || true
for t in apt-daily.timer apt-daily-upgrade.timer; do
  systemctl disable --now "$t" >/dev/null 2>&1 || true
done
systemctl mask apt-daily.service apt-daily-upgrade.service >/dev/null 2>&1 || true
cat > /etc/apt/apt.conf.d/10periodic <<'EOF'
APT::Periodic::Enable "0";
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
apt-get -y purge unattended-upgrades >/dev/null 2>&1 || true

echo "==> 00-update.sh fertig"
