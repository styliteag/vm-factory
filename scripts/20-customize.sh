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
# Laeuft auf der Debian- und der RHEL-Familie; die Unterschiede stecken in
# scripts/lib/os.sh (hochgeladen als /tmp/packer-os-lib.sh).
###############################################################################
set -euo pipefail

: "${VM_TIMEZONE:=Europe/Berlin}"
: "${VM_LOCALE:=C.UTF-8}"
: "${VM_KEYMAP:=de}"
: "${SSH_AUTHORIZED_KEYS:=}"
: "${ROOT_PASSWORD:=}"
: "${CLOUD_INIT:=false}"   # true -> cloud-init behalten (Template-Variante -ci)

# shellcheck source=/dev/null
. /tmp/packer-os-lib.sh   # setzt OS_FAMILY, ID, DEBIAN_FRONTEND

echo "==> Pakete fuer Locale/Tastatur/Resize sicherstellen"
# Liefert u. a. 'growpart' (eigenstaendig, NICHT cloud-init):
# cloud-guest-utils (Debian) bzw. cloud-utils-growpart (RHEL).
# shellcheck disable=SC2046  # Paketliste -- Word-Splitting gewollt
os_pkg_install $(os_base_packages) >/dev/null

echo "==> Zeitzone: ${VM_TIMEZONE}"
os_set_timezone "${VM_TIMEZONE}"

echo "==> Locale: ${VM_LOCALE} (englische Meldungen)"
os_set_locale "${VM_LOCALE}"

echo "==> Konsolen-Tastatur: ${VM_KEYMAP}"
os_set_keymap "${VM_KEYMAP}"

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

echo "==> Installer-Bootparameter aus /etc/default/grub entfernen"
# Subiquity (u. a. 26.04) uebernimmt die Parameter aus dem boot_command in
# GRUB_CMDLINE_LINUX_DEFAULT, z. B. 'autoinstall ds=nocloud-net;s=http://<packer>/'.
# cloud-init wertet ds= aus (seed=cmdline) und wuerde im Klon den laengst
# beendeten Packer-HTTP-Server als Datasource ansprechen.
if [ -f /etc/default/grub ]; then
  sed -i -E '/^GRUB_CMDLINE_LINUX(_DEFAULT)?=/{
    s/(["[:space:]])autoinstall([[:space:]]|")/\1\2/g
    s/(["[:space:]])ds=[^"[:space:]]*/\1/g
    s/  +/ /g
    s/=" /="/
    s/ "$/"/
  }' /etc/default/grub
fi

echo "==> Interface-Benennung auf eth0 (net.ifnames=0 biosdevname=0)"
os_kernel_cmdline_add "net.ifnames=0 biosdevname=0"

# Zur Laufzeit erzeugt (autoinstall "ssh: allow-pw"), gehoert keinem Paket und
# ueberlebt daher das purge. Enthaelt "PasswordAuthentication yes" und wuerde die
# spaetere Haertung aushebeln (sshd: erster Treffer gewinnt, Include ist alphabetisch).
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf

if [ "${CLOUD_INIT}" = "true" ]; then
  echo "==> Cloud-Init BEHALTEN und fuer Proxmox (NoCloud/ConfigDrive) konfigurieren"
  os_pkg_install cloud-init >/dev/null
  mkdir -p /etc/cloud/cloud.cfg.d
  # Reste des Installers entfernen: 99-installer.cfg zeigt auf den
  # Packer-HTTP-Server als Datasource, subiquity-disable-cloudinit-networking
  # wuerde verhindern, dass cloud-init die Netzwerk-Konfig (ipconfig0) schreibt.
  rm -f /etc/cloud/cloud.cfg.d/99-installer.cfg \
    /etc/cloud/cloud.cfg.d/90-installer-network.cfg \
    /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg \
    /etc/cloud/ds-identify.cfg
  cat > /etc/cloud/cloud.cfg.d/99-vm-factory.cfg <<'EOF'
# vm-factory: Template-Variante MIT cloud-init (Suffix -ci)
# Proxmox liefert die Daten per NoCloud-Laufwerk (ide2: cloudinit).
datasource_list: [NoCloud, ConfigDrive, None]
# root-Login per Key erlauben (Default bei Ubuntu waere "disable_root: true",
# das wuerde die root-Keys durch einen "bitte als ubuntu anmelden"-Hinweis ersetzen)
disable_root: false
ssh_pwauth: false
EOF
  # Netz macht cloud-init: Installer-Netzkonfig entfernen (netplan bzw.
  # /etc/network/interfaces). Ohne cloud-init-Laufwerk (Datasource None) faellt
  # cloud-init auf DHCP fuer die erste NIC (eth0) zurueck.
  os_net_cloudinit
else
  echo "==> Cloud-Init vollstaendig entfernen"
  os_pkg_remove cloud-init
  os_pkg_autoremove
  rm -rf /etc/cloud /var/lib/cloud

  echo "==> Netzwerk-Konfiguration fuer eth0 (DHCP, ersetzt Cloud-Init-Netz)"
  # netplan (Ubuntu) / ifupdown (Debian) / NetworkManager-Keyfile (RHEL) --
  # inkl. auskommentierter Vorlage fuer feste IP; siehe scripts/lib/os.sh.
  os_net_dhcp_eth0
fi

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

### Rocky/RHEL (NetworkManager) — /etc/NetworkManager/system-connections/eth0.nmconnection
Im Abschnitt `[ipv4]` `method=auto` durch folgendes ersetzen, dann
`nmcli connection reload && nmcli connection up eth0`:
    method=manual
    address1=10.0.0.10/24,10.0.0.1
    dns=10.0.0.1;1.1.1.1;
Alternativ komplett per nmcli:
    nmcli con mod eth0 ipv4.method manual ipv4.addresses 10.0.0.10/24 \
          ipv4.gateway 10.0.0.1 ipv4.dns "10.0.0.1 1.1.1.1"

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
(`growroot.service`). Der Dienst läuft bei jedem Boot und ist idempotent; die
Reihenfolge ist egal (vergrößern vor oder nach dem ersten Boot).
Kein manuelles `growpart`/`resize2fs`/`xfs_growfs` nötig.
Prüfen:  `df -h /`
Ohne Reboot geht es auch online (ext4, schreibt die Partitionstabelle):
    systemctl start growroot
Automatik abschalten (z. B. wenn am Plattenende Platz frei bleiben soll):
    touch /etc/growroot.disabled

## Sanity-Check nach dem Klonen
    hostnamectl                            # Hostname korrekt gesetzt?
    cat /etc/machine-id                    # nicht leer, pro Klon eindeutig
    ip a                                   # IP auf eth0 vorhanden?
    systemctl is-active qemu-guest-agent   # bzw. open-vm-tools (vSphere)
    df -h /                                # Root auf voller Plattengröße?
EOF
if [ "${CLOUD_INIT}" = "true" ]; then
  # Hinweis voranstellen: in der -ci-Variante setzt cloud-init Hostname/IP
  {
    head -n 1 /root/SETUP.md
    echo
    echo "> **Variante -ci:** Dieses Template enthaelt cloud-init. Hostname, feste IP"
    echo "> und SSH-Keys kommen beim Klonen aus dem Proxmox-cloud-init-Laufwerk"
    echo "> (ipconfig0, nameserver, sshkeys). Die Rezepte unten sind nur der Notfallweg."
    tail -n +2 /root/SETUP.md
  } > /root/SETUP.md.new
  mv /root/SETUP.md.new /root/SETUP.md
fi
chmod 0644 /root/SETUP.md

# Kurz-Stub direkt in der fstab (passiv, auskommentiert).
cat >> /etc/fstab <<'EOF'

# --- Zweite Platte einbinden? Rezept: /root/SETUP.md --------------------
# ACHTUNG: mkfs loescht Daten -- Geraet zuerst mit  lsblk  pruefen!
#   mkfs.ext4 /dev/sdb && mkdir -p /data && blkid /dev/sdb
# dann hier eintragen (UUID aus blkid einsetzen):
# UUID=<UUID>  /data  ext4  defaults,nofail  0  2
EOF

echo "==> Auto-Resize der Root-Partition bei jedem Boot einrichten"
cat > /usr/local/sbin/growroot.sh <<'EOF'
#!/bin/sh
# Vergroessert Root-Partition/-Dateisystem auf die volle Plattengroesse.
#
# Laeuft bei JEDEM Boot und ist idempotent -- absichtlich kein einmaliger
# Marker: sonst verbraucht schon der erste Boot des Templates den Lauf, und
# eine spaeter vergroesserte Platte bleibt fuer immer ungenutzt.
# Abschalten:  touch /etc/growroot.disabled
set -eu

# Vergroesserungs-Schritte duerfen "nichts zu tun" melden (growpart NOCHANGE,
# lvextend "size matches existing") -- das ist der Normalfall ab dem 2. Boot.
# 2>&1: growpart schreibt "NOCHANGE: ..." nach stderr -- ohne Umleitung stuende
# im Journal nur der rc, und "nichts zu tun" waere nicht von "Fehler" trennbar.
try() { "$@" 2>&1 || echo "growroot: $1 rc=$? (nichts zu tun oder Fehler)"; }

ROOT_SRC=$(findmnt -no SOURCE /)
if echo "$ROOT_SRC" | grep -q '/dev/mapper/'; then
  PV=$(pvs --noheadings -o pv_name 2>/dev/null | head -1 | tr -d ' ')
  DISK=$(lsblk -no pkname "$PV" | head -1)
  PART=$(echo "$PV" | grep -o '[0-9]*$')
  try growpart "/dev/$DISK" "$PART"
  try pvresize "$PV"
  try lvextend -l +100%FREE "$ROOT_SRC"
else
  DISK=$(lsblk -no pkname "$ROOT_SRC" | head -1)
  PART=$(echo "$ROOT_SRC" | grep -o '[0-9]*$')
  try growpart "/dev/$DISK" "$PART"
fi

# Dateisystem vergroessern -- Werkzeug je nach Typ:
#   ext2/3/4 : resize2fs auf dem DEVICE
#   xfs      : xfs_growfs auf dem MOUNTPOINT (XFS ist Default auf RHEL 10)
# Beide liefern auch bei "nichts zu tun" Exit-Code 0; ein echter Fehler laesst
# die Unit fehlschlagen (sichtbar in `systemctl status growroot`).
FSTYPE=$(findmnt -no FSTYPE /)
case "$FSTYPE" in
  ext2 | ext3 | ext4) resize2fs "$ROOT_SRC" ;;
  xfs) xfs_growfs / ;;
  *)
    echo "growroot: unbekannter Dateisystemtyp '$FSTYPE' -- kein Resize"
    exit 1
    ;;
esac

# Deckt das Dateisystem das Device wirklich ab? Ohne diese Pruefung bliebe ein
# steckengebliebener Grow-Schritt (LVM: lvextend) unbemerkt, weil das Resize auf
# dem ungewachsenen Device trivial erfolgreich ist.
case "$FSTYPE" in
  ext2 | ext3 | ext4)
    FS_BYTES=$(dumpe2fs -h "$ROOT_SRC" 2>/dev/null | awk -F: '
      /^Block count:/ { c = $2 } /^Block size:/ { s = $2 } END { printf "%.0f", c * s }')
    ;;
  xfs)
    # xfs_info: "data     =   bsize=4096   blocks=2097152, imaxpct=25"
    FS_BYTES=$(xfs_info / 2>/dev/null | awk '
      /^data/ { for (i = 1; i <= NF; i++) {
                  if ($i ~ /^bsize=/) { sub(/bsize=/, "", $i); b = $i }
                  if ($i ~ /^blocks=/) { sub(/blocks=/, "", $i); sub(/,/, "", $i); c = $i }
                } }
      END { printf "%.0f", b * c }')
    ;;
esac
DEV_BYTES=$(blockdev --getsize64 "$ROOT_SRC")
# 64 MiB Toleranz fuer Metadaten-/Ausrichtungs-Rundung
if [ -n "${FS_BYTES:-}" ] && [ "$((DEV_BYTES - FS_BYTES))" -gt 67108864 ]; then
  echo "growroot: FS ${FS_BYTES}B < Device ${DEV_BYTES}B -- Grow unvollstaendig"
  exit 1
fi
EOF
chmod 0755 /usr/local/sbin/growroot.sh
cat > /etc/systemd/system/growroot.service <<'EOF'
[Unit]
Description=Grow root filesystem to fill the disk
After=local-fs.target
ConditionPathExists=!/etc/growroot.disabled

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/growroot.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable growroot.service >/dev/null 2>&1 || true

echo "==> SSH-Host-Keys beim ersten Boot neu erzeugen (in 99-cleanup entfernt)"
# Ohne Cloud-Init wuerde sshd sonst mangels Host-Keys nicht starten.
SSH_UNIT="$(os_ssh_service)"   # ssh (Debian) bzw. sshd (RHEL)
cat > /etc/systemd/system/regenerate-ssh-host-keys.service <<EOF
[Unit]
Description=Regenerate missing SSH host keys on first boot
Before=${SSH_UNIT}.service ${SSH_UNIT}.socket
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
  # 00-*: sshd nimmt den ERSTEN Treffer je Option, der Include ist alphabetisch
  # sortiert -- die Haertung muss daher vor allen anderen Drop-ins stehen.
  rm -f /etc/ssh/sshd_config.d/99-hardening.conf
  cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
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
systemctl disable "${SSH_UNIT}.socket" >/dev/null 2>&1 || true
systemctl enable "${SSH_UNIT}.service" >/dev/null 2>&1 || systemctl enable "${SSH_UNIT}" >/dev/null 2>&1 || true

# Konfiguration testen (Tippfehler wuerden aussperren)
sshd -t

# Haertung wirklich wirksam? sshd -T zeigt die effektive Konfiguration inklusive
# aller Drop-ins -- faengt ein Drop-in ab, das die Haertung ueberstimmt.
# (Nur wenn Keys hinterlegt sind; ohne Keys bleibt Passwort-Login gewollt aktiv.)
if [ -n "$KEYS" ]; then
  # Ausgabe erst einsammeln, dann pruefen: 'sshd -T | grep -q' ist unter
  # 'set -o pipefail' unzuverlaessig -- grep -q beendet sich beim Treffer,
  # sshd stirbt am SIGPIPE (Status 141) und die Pipeline gilt als
  # fehlgeschlagen, obwohl der Treffer da war.
  SSHD_EFFECTIVE="$(sshd -T)"
  if ! printf '%s\n' "$SSHD_EFFECTIVE" | grep -qi '^passwordauthentication no'; then
    echo "FEHLER: PasswordAuthentication ist trotz Haertung nicht 'no':"
    printf '%s\n' "$SSHD_EFFECTIVE" | grep -i 'passwordauthentication\|permitrootlogin'
    exit 1
  fi
  echo "    sshd -T geprueft: PasswordAuthentication no wirksam."
fi

# SELinux-Kontexte der per Shell erzeugten Dateien richtigstellen (No-op auf
# Debian/Ubuntu). Muss nach allen Schreibzugriffen laufen.
os_selinux_relabel

echo "==> 20-customize.sh fertig"
