#!/usr/bin/env bash
###############################################################################
# 30 - Moderate Minimierung
#
#   * snapd entfernen (nur Ubuntu)
#   * alte Kernel/Header/Module entfernen (aktuellen behalten)
#   * *-doc-Pakete und /usr/share/doc entfernen
#   * /var/cache leeren, apt aufraeumen
#
# Bewusst NICHT entfernt: perl, rsync, cifs-utils, bash-completion, X11-Libs,
# Firmware -- das wuerde Tools/Monitoring (checkmk) gefaehrden.
###############################################################################
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# shellcheck source=/dev/null
. /etc/os-release

if [ "${ID:-}" = "ubuntu" ]; then
  echo "==> [minimize] snapd entfernen"
  apt-get -y purge snapd >/dev/null 2>&1 || true
  rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd 2>/dev/null || true
fi

echo "==> [minimize] alte Kernel entfernen (aktuellen behalten)"
CUR="$(uname -r)"
OLD="$(dpkg --list | awk '/^ii/ && $2 ~ /^linux-(image|headers|modules)-[0-9]/ {print $2}' | grep -v "$CUR" || true)"
# shellcheck disable=SC2086  # OLD ist eine Paketliste -- Word-Splitting gewollt
if [ -n "$OLD" ]; then apt-get -y purge $OLD >/dev/null 2>&1 || true; fi

echo "==> [minimize] -doc-Pakete entfernen"
DOC="$(dpkg --list | awk '/^ii/ {print $2}' | grep -- '-doc$' || true)"
# shellcheck disable=SC2086  # DOC ist eine Paketliste -- Word-Splitting gewollt
if [ -n "$DOC" ]; then apt-get -y purge $DOC >/dev/null 2>&1 || true; fi

echo "==> [minimize] Doku/Cache aufraeumen"
rm -rf /usr/share/doc/* 2>/dev/null || true
find /var/cache -type f -delete 2>/dev/null || true

apt-get -y autoremove --purge >/dev/null 2>&1 || true
apt-get -y clean

echo "==> 30-minimize.sh fertig"
