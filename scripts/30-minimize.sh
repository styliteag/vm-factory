#!/usr/bin/env bash
###############################################################################
# 30 - Moderate Minimierung
#
#   * snapd entfernen (nur Ubuntu)
#   * alte Kernel/Header/Module entfernen (aktuellen behalten)
#   * *-doc-Pakete und /usr/share/doc entfernen (Debian-Familie)
#   * /var/cache leeren, Paketcache aufraeumen
#
# Bewusst NICHT entfernt: perl, rsync, cifs-utils, bash-completion, X11-Libs,
# Firmware -- das wuerde Tools/Monitoring (checkmk) gefaehrden.
###############################################################################
set -euo pipefail
# shellcheck source=/dev/null
. /tmp/packer-os-lib.sh

if [ "${ID:-}" = "ubuntu" ]; then
  echo "==> [minimize] snapd entfernen"
  os_pkg_remove snapd
  rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd 2>/dev/null || true
fi

echo "==> [minimize] alte Kernel entfernen (aktuellen behalten)"
os_remove_old_kernels

if [ "$OS_FAMILY" = "debian" ]; then
  echo "==> [minimize] -doc-Pakete entfernen"
  # RPM-Distributionen kennen keine eigenstaendigen -doc-Pakete (Doku steckt im
  # Hauptpaket) -- dort bleibt nur das Leeren von /usr/share/doc unten.
  DOC="$(dpkg --list | awk '/^ii/ {print $2}' | grep -- '-doc$' || true)"
  # shellcheck disable=SC2086  # Paketliste -- Word-Splitting gewollt
  if [ -n "$DOC" ]; then apt-get -y purge $DOC >/dev/null 2>&1 || true; fi
fi

echo "==> [minimize] Doku/Cache aufraeumen"
rm -rf /usr/share/doc/* 2>/dev/null || true
find /var/cache -type f -delete 2>/dev/null || true

os_pkg_autoremove
os_pkg_clean

echo "==> 30-minimize.sh fertig"
