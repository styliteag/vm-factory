#!/usr/bin/env bash
###############################################################################
# 20 - Template-Anpassungen (Golden Image, OHNE Cloud-Init)
#
#   * Zeitzone / Locale / Konsolen-Tastatur
#   * MOTD-Branding
#   * Netzwerk-Interface -> eth0 (net.ifnames=0) + DHCP-Konfig
#   * Cloud-Init vollstaendig entfernen
#   * Auto-Resize der Root-Partition beim ersten Boot (Ersatz fuer cloud-init)
#   * Root-SSH-Key(s) + SSH-Haertung (nur Key-Login) + optionales root-Passwort
#
# Laeuft identisch auf Ubuntu und Debian.
###############################################################################
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

: "${VM_TIMEZONE:=Europe/Berlin}"
: "${VM_LOCALE:=C.UTF-8}"
: "${VM_KEYMAP:=de}"
: "${SSH_AUTHORIZED_KEYS:=}"
: "${ROOT_PASSWORD:=}"

. /etc/os-release

echo "==> Pakete fuer Locale/Tastatur/Resize sicherstellen"
# cloud-guest-utils liefert 'growpart' (eigenstaendig, NICHT cloud-init).
apt-get -y install locales keyboard-configuration console-setup cloud-guest-utils >/dev/null

echo "==> Zeitzone: ${VM_TIMEZONE}"
ln -sf "/usr/share/zoneinfo/${VM_TIMEZONE}" /etc/localtime
echo "${VM_TIMEZONE}" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

echo "==> Locale: ${VM_LOCALE} (englische Meldungen)"
update-locale LANG="${VM_LOCALE}" LC_ALL= LANGUAGE=
export LANG="${VM_LOCALE}"

echo "==> Konsolen-Tastatur: ${VM_KEYMAP}"
cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="${VM_KEYMAP}"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
dpkg-reconfigure -f noninteractive keyboard-configuration || true
setupcon --save 2>/dev/null || true

echo "==> MOTD-Branding"
if [ -d /etc/update-motd.d ]; then
  cat > /etc/update-motd.d/99-stylite <<'EOF'
#!/bin/sh
echo
echo "Dieses System wurde mit Packer bei der Stylite AG erstellt."
echo
EOF
  chmod 0755 /etc/update-motd.d/99-stylite
else
  echo "Dieses System wurde mit Packer bei der Stylite AG erstellt." > /etc/motd
fi

echo "==> Interface-Benennung auf eth0 (net.ifnames=0 biosdevname=0)"
if grep -q '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
  grep -q 'net.ifnames=0' /etc/default/grub \
    || sed -i 's/^\(GRUB_CMDLINE_LINUX="\)/\1net.ifnames=0 biosdevname=0 /' /etc/default/grub
else
  echo 'GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"' >> /etc/default/grub
fi
update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Cloud-Init vollstaendig entfernen"
apt-get -y purge cloud-init >/dev/null 2>&1 || true
apt-get -y autoremove --purge >/dev/null 2>&1 || true
rm -rf /etc/cloud /var/lib/cloud

echo "==> Netzwerk-Konfiguration fuer eth0 (DHCP, ersetzt Cloud-Init-Netz)"
case "${ID:-debian}" in
  ubuntu)
    rm -f /etc/netplan/50-cloud-init.yaml /etc/netplan/00-installer-config.yaml
    cat > /etc/netplan/00-eth0.yaml <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
      accept-ra: false
      dhcp-identifier: mac
EOF
    chmod 0600 /etc/netplan/00-eth0.yaml
    ;;
  *)
    # Debian: ifupdown
    cat > /etc/network/interfaces <<'EOF'
# Von Packer erzeugt -- DHCP auf eth0 (net.ifnames=0)
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
EOF
    ;;
esac

echo "==> Auto-Resize der Root-Partition beim ersten Boot einrichten"
cat > /usr/local/sbin/growroot.sh <<'EOF'
#!/bin/sh
# Vergroessert die Root-Partition/-FS einmalig auf die volle Plattengroesse.
set -eu
[ -f /var/lib/growroot.done ] && exit 0
ROOT_SRC=$(findmnt -no SOURCE /)
if echo "$ROOT_SRC" | grep -q '/dev/mapper/'; then
  PV=$(pvs --noheadings -o pv_name 2>/dev/null | head -1 | tr -d ' ')
  DISK=$(lsblk -no pkname "$PV" | head -1)
  PART=$(echo "$PV" | grep -o '[0-9]*$')
  growpart "/dev/$DISK" "$PART" || true
  pvresize "$PV" || true
  lvextend -l +100%FREE "$ROOT_SRC" || true
  resize2fs "$ROOT_SRC" || true
else
  DISK=$(lsblk -no pkname "$ROOT_SRC" | head -1)
  PART=$(echo "$ROOT_SRC" | grep -o '[0-9]*$')
  growpart "/dev/$DISK" "$PART" || true
  resize2fs "$ROOT_SRC" || true
fi
touch /var/lib/growroot.done
EOF
chmod 0755 /usr/local/sbin/growroot.sh
cat > /etc/systemd/system/growroot.service <<'EOF'
[Unit]
Description=Grow root filesystem to fill the disk (once)
After=local-fs.target
ConditionPathExists=!/var/lib/growroot.done

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/growroot.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable growroot.service >/dev/null 2>&1 || true

echo "==> SSH-Host-Keys beim ersten Boot neu erzeugen (in 99-cleanup entfernt)"
# Ohne Cloud-Init wuerde sshd sonst mangels Host-Keys nicht starten.
cat > /etc/systemd/system/regenerate-ssh-host-keys.service <<'EOF'
[Unit]
Description=Regenerate missing SSH host keys on first boot
Before=ssh.service ssh.socket
ConditionPathExists=!/etc/ssh/ssh_host_ed25519_key

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable regenerate-ssh-host-keys.service >/dev/null 2>&1 || true

echo "==> Root-SSH-Key(s) + SSH-Haertung"
install -d -m 0700 /root/.ssh
mkdir -p /etc/ssh/sshd_config.d

KEYS=""
if [ -s /tmp/packer-authorized_keys ]; then
  KEYS="$(cat /tmp/packer-authorized_keys)"   # Team-Set aus files/authorized_keys
elif [ -n "${SSH_AUTHORIZED_KEYS}" ]; then
  KEYS="${SSH_AUTHORIZED_KEYS}"               # optionaler Variablen-Override
fi

if [ -n "$KEYS" ]; then
  printf '%s\n' "$KEYS" > /root/.ssh/authorized_keys
  chmod 0600 /root/.ssh/authorized_keys
  cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
EOF
  echo "    $(grep -c . /root/.ssh/authorized_keys) Key(s) hinterlegt, Passwort-Login deaktiviert."
else
  echo "    WARNUNG: keine SSH-Keys -> Passwort-Login bleibt aktiv (kein Lockout)."
fi
rm -f /tmp/packer-authorized_keys

if [ -n "${ROOT_PASSWORD}" ]; then
  echo "==> root-Passwort setzen (nur Konsole/Notfall; SSH bleibt key-only)"
  echo "root:${ROOT_PASSWORD}" | chpasswd
fi

# sshd dauerhaft beim Boot starten: Socket-Aktivierung (Default auf Debian 13 /
# Ubuntu 26.04) abschalten und den klassischen Dienst aktivieren -- sonst lauscht
# im Klon evtl. nichts auf Port 22. (Ohne --now, um die laufende Build-SSH-Sitzung
# nicht zu unterbrechen; greift beim naechsten Boot.)
systemctl disable ssh.socket >/dev/null 2>&1 || true
systemctl enable ssh.service >/dev/null 2>&1 || systemctl enable ssh >/dev/null 2>&1 || systemctl enable sshd >/dev/null 2>&1 || true

# Konfiguration testen (Tippfehler wuerden aussperren)
sshd -t

echo "==> 20-customize.sh fertig"
