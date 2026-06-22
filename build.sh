#!/usr/bin/env bash
###############################################################################
# Komfort-Wrapper um `packer build` / `packer validate`.
#
#   ./build.sh [proxmox|vsphere] {ubuntu-26.04|debian-13|all|validate} [args...]
#
# Plattform ist optional (Default: proxmox). Beispiele:
#   ./build.sh ubuntu-26.04          # Proxmox, Ubuntu
#   ./build.sh proxmox all           # Proxmox, beide
#   ./build.sh vsphere debian-13     # vSphere, Debian
#   ./build.sh vsphere validate      # vSphere-Konfiguration pruefen
#
# Zusaetzliche Packer-Argumente werden durchgereicht (z. B. -on-error=ask).
###############################################################################
set -euo pipefail
cd "$(dirname "$0")"

UBUNTU="os_pkrvars/ubuntu/ubuntu-26.04-x86_64.pkrvars.hcl"
DEBIAN="os_pkrvars/debian/debian-13-x86_64.pkrvars.hcl"

usage() {
  echo "Usage: $0 [proxmox|vsphere] {ubuntu-26.04|debian-13|all|validate} [packer-args...]"
  exit 1
}

# Plattform optional als erstes Argument
PLATFORM="proxmox"
case "${1:-}" in
  proxmox | vsphere) PLATFORM="$1"; shift ;;
esac

TARGET="${1:-}"
[ -z "$TARGET" ] && usage
shift || true
EXTRA=("$@")

case "$PLATFORM" in
  proxmox) CREDS="credentials.pkrvars.hcl"; ONLY="templates.proxmox-iso.vm" ;;
  vsphere) CREDS="credentials-vsphere.pkrvars.hcl"; ONLY="templates.vsphere-iso.vm" ;;
esac

if [ ! -f "$CREDS" ]; then
  echo "FEHLER: $CREDS fehlt. Vorlage: cp ${CREDS}.example $CREDS  und anpassen."
  exit 1
fi

echo "==> packer init"
packer init .

run() {
  local varfile="$1" label="$2"
  if [ "$TARGET" = "validate" ]; then
    echo "==> [$PLATFORM] $label : packer validate"
    packer validate -only="$ONLY" -var-file="$CREDS" -var-file="$varfile" "${EXTRA[@]}" .
  else
    echo "==> [$PLATFORM] $label : packer build"
    # -force ersetzt ein bestehendes Template gleichen Namens
    packer build -only="$ONLY" -force -var-file="$CREDS" -var-file="$varfile" "${EXTRA[@]}" .
  fi
}

case "$TARGET" in
  validate)
    run "$UBUNTU" "Ubuntu 26.04"
    run "$DEBIAN" "Debian 13"
    ;;
  ubuntu-26.04) run "$UBUNTU" "Ubuntu 26.04" ;;
  debian-13) run "$DEBIAN" "Debian 13" ;;
  all)
    run "$UBUNTU" "Ubuntu 26.04"
    run "$DEBIAN" "Debian 13"
    ;;
  *) usage ;;
esac

echo "==> Fertig."
