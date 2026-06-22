#!/usr/bin/env bash
###############################################################################
# Installiert HashiCorp Packer aus dem offiziellen APT-Repo (Debian/Ubuntu).
# Idempotent -- mehrfaches Ausfuehren ist unkritisch.
###############################################################################
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Bitte als root ausfuehren (sudo $0)"; exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release
CODENAME="${VERSION_CODENAME:-bookworm}"

echo "==> Voraussetzungen installieren"
apt-get update
apt-get -y install gpg wget lsb-release

echo "==> HashiCorp GPG-Key hinterlegen"
install -m 0755 -d /usr/share/keyrings
wget -qO- https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
chmod 0644 /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "==> APT-Quelle fuer '${CODENAME}' einrichten"
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" \
  > /etc/apt/sources.list.d/hashicorp.list

echo "==> Packer installieren"
apt-get update
apt-get -y install packer

echo "==> Installiert:"
packer version
