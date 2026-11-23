#!/usr/bin/env bash
###############################################################################
# Komfort-Wrapper um `packer build` / `packer validate`.
#
#   ./build.sh [proxmox|vsphere] {ubuntu-26.04|ubuntu-24.04|ubuntu-22.04|debian-13|debian-12|rocky-10|all|validate} [args...]
#
# Plattform ist optional (Default: proxmox). Beispiele:
#   ./build.sh ubuntu-26.04          # Proxmox, Ubuntu 26.04
#   ./build.sh proxmox all           # Proxmox, alle OS
#   ./build.sh vsphere debian-13     # vSphere, Debian
#   ./build.sh vsphere validate      # vSphere-Konfiguration pruefen
#
# Ubuntu und Debian werden standardmaessig in ZWEI Varianten gebaut/geprueft:
#   <os>-<version>-x86-64      ohne cloud-init (Golden Image)
#   <os>-<version>-x86-64-ci   mit cloud-init + Proxmox-cloudinit-Laufwerk
# Einschraenken per VARIANTS (Leerzeichen-getrennt, Default "plain ci"):
#   VARIANTS=ci ./build.sh ubuntu-22.04      # nur die -ci-Variante
#   VARIANTS=plain ./build.sh all            # nur ohne cloud-init
# Rocky wird nur ohne cloud-init gebaut (-ci dort nicht umgesetzt/getestet).
#
# Zusaetzliche Packer-Argumente werden durchgereicht (z. B. -on-error=ask).
###############################################################################
set -euo pipefail
cd "$(dirname "$0")"

UBUNTU="os_pkrvars/ubuntu/ubuntu-26.04-x86_64.pkrvars.hcl"
UBUNTU2404="os_pkrvars/ubuntu/ubuntu-24.04-x86_64.pkrvars.hcl"
UBUNTU2204="os_pkrvars/ubuntu/ubuntu-22.04-x86_64.pkrvars.hcl"
DEBIAN="os_pkrvars/debian/debian-13-x86_64.pkrvars.hcl"
DEBIAN12="os_pkrvars/debian/debian-12-x86_64.pkrvars.hcl"
ROCKY="os_pkrvars/rocky/rocky-10-x86_64.pkrvars.hcl"

usage() {
  echo "Usage: $0 [proxmox|vsphere] {ubuntu-26.04|ubuntu-24.04|ubuntu-22.04|debian-13|debian-12|rocky-10|all|validate} [packer-args...]"
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

read -r -a VARIANT_LIST <<< "${VARIANTS:-plain ci}"
for v in "${VARIANT_LIST[@]}"; do
  case "$v" in
    plain | ci) ;;
    *) echo "FEHLER: unbekannte Variante '$v' in VARIANTS (erlaubt: plain ci)"; exit 1 ;;
  esac
done

# run_one <varfile> <label> <plain|ci>
run_one() {
  local varfile="$1" label="$2" variant="$3" ci=false
  [ "$variant" = "ci" ] && ci=true && label="$label (-ci)"
  if [ "$TARGET" = "validate" ]; then
    echo "==> [$PLATFORM] $label : packer validate"
    packer validate -only="$ONLY" -var-file="$CREDS" -var-file="$varfile" -var "cloud_init=$ci" "${EXTRA[@]}" .
  else
    echo "==> [$PLATFORM] $label : packer build"
    # -force ersetzt ein bestehendes Template gleichen Namens
    packer build -only="$ONLY" -force -var-file="$CREDS" -var-file="$varfile" -var "cloud_init=$ci" "${EXTRA[@]}" .
  fi
}

# run <varfile> <label>  -> alle gewaehlten Varianten
run() {
  local v
  for v in "${VARIANT_LIST[@]}"; do
    run_one "$1" "$2" "$v"
  done
}

# Rocky: nur ohne cloud-init (und nur, wenn "plain" in VARIANTS steht)
run_plain() {
  if [[ " ${VARIANT_LIST[*]} " == *" plain "* ]]; then
    run_one "$1" "$2" plain
  else
    echo "==> [$PLATFORM] $2 : uebersprungen (nur Variante plain verfuegbar)"
  fi
}

case "$TARGET" in
  validate)
    run "$UBUNTU" "Ubuntu 26.04"
    run "$UBUNTU2404" "Ubuntu 24.04"
    run "$UBUNTU2204" "Ubuntu 22.04"
    run "$DEBIAN" "Debian 13"
    run "$DEBIAN12" "Debian 12"
    run_plain "$ROCKY" "Rocky 10"
    ;;
  ubuntu-26.04) run "$UBUNTU" "Ubuntu 26.04" ;;
  ubuntu-24.04) run "$UBUNTU2404" "Ubuntu 24.04" ;;
  ubuntu-22.04) run "$UBUNTU2204" "Ubuntu 22.04" ;;
  debian-13) run "$DEBIAN" "Debian 13" ;;
  debian-12) run "$DEBIAN12" "Debian 12" ;;
  rocky-10) run_plain "$ROCKY" "Rocky 10" ;;
  all)
    run "$UBUNTU" "Ubuntu 26.04"
    run "$UBUNTU2404" "Ubuntu 24.04"
    run "$UBUNTU2204" "Ubuntu 22.04"
    run "$DEBIAN" "Debian 13"
    run "$DEBIAN12" "Debian 12"
    run_plain "$ROCKY" "Rocky 10"
    ;;
  *) usage ;;
esac

echo "==> Fertig."
