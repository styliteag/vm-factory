#!/usr/bin/env bash
###############################################################################
# 00 - System aktualisieren und Basispakete sicherstellen
#
# Familien-Unterschiede (apt/dnf, Timer-Namen, Paketnamen) stehen in
# scripts/lib/os.sh, das als /tmp/packer-os-lib.sh hochgeladen wird.
###############################################################################
set -euo pipefail
# shellcheck source=/dev/null
. /tmp/packer-os-lib.sh

echo "==> Warte ggf. auf laufendes cloud-init (nur waehrend der Installation)..."
command -v cloud-init >/dev/null && timeout 300 cloud-init status --wait || true

echo "==> Paketquellen aktualisieren"
os_pkg_refresh

echo "==> Distribution aktualisieren"
os_pkg_upgrade

echo "==> Basispakete installieren"
# shellcheck disable=SC2046  # Paketliste -- Word-Splitting gewollt
os_pkg_install $(os_common_packages)

echo "==> Gast-Tools passend zur Plattform installieren"
# PACKER_BUILDER_TYPE wird von Packer gesetzt (proxmox-iso / vsphere-iso / ...).
# Die Paketnamen sind auf allen unterstuetzten Familien identisch.
case "${PACKER_BUILDER_TYPE:-}" in
  vsphere-iso | vmware-iso | vmware-vmx)
    os_pkg_install open-vm-tools
    systemctl enable --now open-vm-tools >/dev/null 2>&1 || true
    ;;
  *)
    # Proxmox/KVM: qemu-guest-agent (auf Debian udev-aktiviert -> enable-Warnung egal)
    os_pkg_install qemu-guest-agent
    systemctl enable qemu-guest-agent >/dev/null 2>&1 || true
    ;;
esac

echo "==> Automatische Updates/Upgrades fuer Templates deaktivieren"
os_disable_auto_updates

echo "==> 00-update.sh fertig"
