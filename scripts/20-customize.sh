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

# shellcheck source=/dev/null
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
echo "Erstkonfiguration (Hostname, feste IP, Platten): siehe /root/SETUP.md"
echo
EOF
  chmod 0755 /etc/update-motd.d/99-stylite
else
  {
    echo "Dieses System wurde mit Packer bei der Stylite AG erstellt."
    echo "Erstkonfiguration (Hostname, feste IP, Platten): siehe /root/SETUP.md"
  } > /etc/motd
fi

echo "==> Konsolen-Login: aktuelle IP am Prompt anzeigen (/etc/issue)"
# agetty-Escapes: \S=OS, \n=Hostname, \l=tty, \4{eth0}=IPv4 von eth0.
# Hilft headless, die per DHCP vergebene IP ohne Hypervisor-Konsole zu sehen.
cat > /etc/issue <<'EOF'
\S \r -- \n (\l)
eth0 IPv4: \4{eth0}

EOF

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
# --- Feste IP? dhcp4 auf false setzen und folgende Zeilen einkommentieren ---
# --- (Werte anpassen; ausfuehrliches Rezept: /root/SETUP.md) ----------------
#     dhcp4: false
#     addresses: [10.0.0.10/24]
#     routes:
#       - to: default
#         via: 10.0.0.1
#     nameservers:
#       addresses: [10.0.0.1, 1.1.1.1]
# danach:  netplan apply
#
# --- Zweite NIC (eth1)? unter "ethernets:" (gleiche Einrueckung wie eth0) ---
#     eth1:
#       dhcp4: true
#       # oder feste IP analog zu eth0 oben:
#       # dhcp4: false
#       # addresses: [10.0.1.10/24]
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

# --- Feste IP? Die zwei eth0-Zeilen oben durch folgendes ersetzen ---
# --- (Werte anpassen; ausfuehrliches Rezept: /root/SETUP.md) --------
# auto eth0
# iface eth0 inet static
#     address 10.0.0.10/24
#     gateway 10.0.0.1
#     dns-nameservers 10.0.0.1 1.1.1.1
# danach:  systemctl restart networking   (oder reboot)
#
# --- Zweite NIC (eth1)? folgende Zeilen einkommentieren ---
# allow-hotplug eth1
# iface eth1 inet dhcp
# # oder feste IP:
# # iface eth1 inet static
# #     address 10.0.1.10/24
EOF
    ;;
esac

echo "==> Erstkonfigurations-Hilfen ablegen (passiv, nichts laeuft automatisch)"
# Zentrale Anleitung fuer den Installer/Operator nach dem Klonen.
cat > /root/SETUP.md <<'EOF'
# Erstkonfiguration nach dem Klonen

Dieses Image ist ein Golden Template **ohne** Cloud-Init. Hostname, feste IP und
zusätzliche Platten werden bewusst NICHT automatisch gesetzt — hier die Rezepte.
(Auskommentierte Kurzvorlagen stehen zusätzlich direkt in den jeweiligen
Konfigdateien.)

## Hostname setzen
    hostnamectl set-hostname my-name
    # /etc/hosts mitziehen (Zeile anlegen oder ersetzen):
    sed -i 's/^127\.0\.1\.1.*/127.0.1.1\tmy-name/' /etc/hosts

## Feste IP

### Ubuntu (netplan) — /etc/netplan/00-eth0.yaml
DHCP-Block ersetzen, dann `netplan apply`:
    network:
      version: 2
      renderer: networkd
      ethernets:
        eth0:
          dhcp4: false
          addresses: [10.0.0.10/24]
          routes:
            - to: default
              via: 10.0.0.1
          nameservers:
            addresses: [10.0.0.1, 1.1.1.1]

### Debian (ifupdown) — /etc/network/interfaces
eth0-Block ersetzen, dann `systemctl restart networking`:
    auto eth0
    iface eth0 inet static
        address 10.0.0.10/24
        gateway 10.0.0.1
        dns-nameservers 10.0.0.1 1.1.1.1

### Zweite NIC (eth1)
Zweites Interface in Proxmox/vSphere hinzufügen, dann (auskommentierte Vorlage
steht schon in der jeweiligen Configdatei):

Ubuntu — unter `ethernets:` in `00-eth0.yaml`:
    eth1:
      dhcp4: true            # oder feste IP wie bei eth0

Debian — in `/etc/network/interfaces`:
    allow-hotplug eth1
    iface eth1 inet dhcp     # oder  inet static  mit address/...

## Zweite Platte einbinden (z. B. /dev/sdb -> /data)
ACHTUNG: `mkfs` löscht die Platte. Erst mit `lsblk` das richtige Gerät prüfen!
    lsblk                       # richtige Platte finden
    mkfs.ext4 /dev/sdb
    mkdir -p /data
    blkid /dev/sdb              # UUID ablesen
    # Zeile in /etc/fstab eintragen (nofail: fehlende Platte haengt den Boot nicht):
    echo "UUID=<UUID-AUS-BLKID> /data ext4 defaults,nofail 0 2" >> /etc/fstab
    mount -a                    # testen, dass fstab stimmt

## Root-Platte vergrößern
Platte am Host vergrößern (Beispiel Proxmox):
    qm disk resize <VMID> scsi0 40G
Dann die VM neu starten — die Root-Partition wächst beim Boot automatisch
(`growroot.service`, einmalig). Kein manuelles `growpart`/`resize2fs` nötig.
Prüfen:  `df -h /`

## Sanity-Check nach dem Klonen
    hostnamectl                            # Hostname korrekt gesetzt?
    cat /etc/machine-id                    # nicht leer, pro Klon eindeutig
    ip a                                   # IP auf eth0 vorhanden?
    systemctl is-active qemu-guest-agent   # bzw. open-vm-tools (vSphere)
    df -h /                                # Root auf voller Plattengröße?
EOF
chmod 0644 /root/SETUP.md

# Kurz-Stub direkt in der fstab (passiv, auskommentiert).
cat >> /etc/fstab <<'EOF'

# --- Zweite Platte einbinden? Rezept: /root/SETUP.md --------------------
# ACHTUNG: mkfs loescht Daten -- Geraet zuerst mit  lsblk  pruefen!
#   mkfs.ext4 /dev/sdb && mkdir -p /data && blkid /dev/sdb
# dann hier eintragen (UUID aus blkid einsetzen):
# UUID=<UUID>  /data  ext4  defaults,nofail  0  2
EOF

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

echo "==> Packer-Build-User beim ersten Boot entfernen (im Build unmoeglich)"
# userdel scheitert waehrend des Builds an der aktiven packer-Login-Session
# ("user packer is currently used by process ..."). Daher verschoben auf den
# ersten Boot des Klons -- dort ist niemand als packer angemeldet.
cat > /usr/local/sbin/remove-packer-user.sh <<'EOF'
#!/bin/sh
# Entfernt den Build-User 'packer' einmalig beim ersten Boot und loescht sich
# danach selbst (Service-Unit + dieses Skript).
set -eu
if id packer >/dev/null 2>&1; then
  pkill -KILL -u packer 2>/dev/null || true
  userdel -r packer 2>/dev/null || true
fi
rm -f /etc/sudoers.d/90-packer
systemctl disable remove-packer-user.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/remove-packer-user.service /usr/local/sbin/remove-packer-user.sh
EOF
chmod 0755 /usr/local/sbin/remove-packer-user.sh
cat > /etc/systemd/system/remove-packer-user.service <<'EOF'
[Unit]
Description=Remove the Packer build user on first boot (once)
ConditionPathExists=/usr/local/sbin/remove-packer-user.sh

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/remove-packer-user.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable remove-packer-user.service >/dev/null 2>&1 || true

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
