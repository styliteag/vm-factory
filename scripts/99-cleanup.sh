#!/usr/bin/env bash
###############################################################################
# 99 - Aufraeumen & Generalisieren
#
# Letzter Schritt vor der Template-Erstellung: Maschinen-spezifische Identitaet
# entfernen, damit jeder Klon eindeutig ist.
###############################################################################
set -euo pipefail
# shellcheck source=/dev/null
. /tmp/packer-os-lib.sh

echo "==> Paketcache aufraeumen"
os_pkg_autoremove
os_pkg_clean

echo "==> SSH-Host-Keys entfernen (werden beim ersten Boot neu erzeugt)"
rm -f /etc/ssh/ssh_host_*

echo "==> machine-id zuruecksetzen"
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
# Der dbus-Symlink existiert nur dort, wo es /var/lib/dbus ueberhaupt gibt
# (Debian/Ubuntu). Auf RHEL 10 liest dbus direkt /etc/machine-id, das
# Verzeichnis fehlt -- ein 'ln' dorthin bricht mit ENOENT ab.
if [ -d /var/lib/dbus ]; then
  ln -sf /etc/machine-id /var/lib/dbus/machine-id
fi

echo "==> Logs leeren"
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true

echo "==> Login-Records & random-seed entfernen"
: > /var/log/lastlog 2>/dev/null || true
: > /var/log/wtmp 2>/dev/null || true
: > /var/log/btmp 2>/dev/null || true
rm -f /var/lib/systemd/random-seed 2>/dev/null || true

echo "==> Temporaere Dateien, DHCP-Leases und Shell-History entfernen"
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
rm -f /var/lib/dhcp/* 2>/dev/null || true
rm -f /root/.bash_history /home/*/.bash_history 2>/dev/null || true

echo "==> Packer-User: sudo-Rechte entziehen (Account-Loeschung erfolgt beim ersten"
echo "    Boot via remove-packer-user.service -- userdel scheitert hier an der"
echo "    aktiven packer-Login-Session)"
rm -f /etc/sudoers.d/90-packer

sync
echo "==> 99-cleanup.sh fertig"
