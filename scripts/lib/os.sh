#!/usr/bin/env bash
###############################################################################
# OS-Abstraktion fuer die Provisionierungs-Skripte
#
# Wird von build.pkr.hcl per file-Provisioner nach /tmp/packer-os-lib.sh
# geladen und von jedem scripts/*.sh eingebunden:
#
#     . /tmp/packer-os-lib.sh
#
# Ziel: Die Skripte beschreiben, WAS passieren soll; die Familien-Unterschiede
# (apt vs. dnf, netplan vs. NetworkManager, update-grub vs. grubby ...) stehen
# ausschliesslich hier. Fuer die Debian-Familie bilden die Funktionen exakt das
# ab, was vorher direkt in den Skripten stand -- Ubuntu/Debian-Templates sollen
# sich durch die Abstraktion nicht veraendern.
###############################################################################

# shellcheck source=/dev/null
. /etc/os-release

# ---------------------------------------------------------------------------
# Familie bestimmen: ID_LIKE ist bei Ubuntu "debian", bei Rocky/Alma
# "rhel centos fedora". ID allein reicht nicht (debian hat kein ID_LIKE).
# ---------------------------------------------------------------------------
case " ${ID:-} ${ID_LIKE:-} " in
  *" rhel "* | *" fedora "* | *" centos "*) OS_FAMILY="rhel" ;;
  *" debian "* | *" ubuntu "*) OS_FAMILY="debian" ;;
  *) echo "FEHLER: unbekannte OS-Familie (ID=${ID:-?} ID_LIKE=${ID_LIKE:-?})" >&2; exit 1 ;;
esac
export OS_FAMILY

if [ "$OS_FAMILY" = "debian" ]; then
  export DEBIAN_FRONTEND=noninteractive
fi

# ---------------------------------------------------------------------------
# Paketverwaltung
# ---------------------------------------------------------------------------
os_pkg_refresh() {
  case "$OS_FAMILY" in
    debian) apt-get update ;;
    rhel) dnf -y makecache ;;
  esac
}

os_pkg_upgrade() {
  case "$OS_FAMILY" in
    debian) apt-get -y dist-upgrade ;;
    rhel) dnf -y upgrade ;;
  esac
}

os_pkg_install() {
  case "$OS_FAMILY" in
    debian) apt-get -y install "$@" ;;
    rhel) dnf -y install "$@" ;;
  esac
}

# Entfernt Pakete, ohne bei "nicht installiert" zu scheitern.
os_pkg_remove() {
  case "$OS_FAMILY" in
    debian) apt-get -y purge "$@" >/dev/null 2>&1 || true ;;
    rhel) dnf -y remove "$@" >/dev/null 2>&1 || true ;;
  esac
}

os_pkg_autoremove() {
  case "$OS_FAMILY" in
    debian) apt-get -y autoremove --purge >/dev/null 2>&1 || true ;;
    rhel) dnf -y autoremove >/dev/null 2>&1 || true ;;
  esac
}

os_pkg_clean() {
  case "$OS_FAMILY" in
    debian)
      apt-get -y clean
      rm -rf /var/lib/apt/lists/*
      ;;
    rhel)
      dnf -y clean all
      rm -rf /var/cache/dnf/*
      ;;
  esac
}

# Paketnamen, die sich zwischen den Familien unterscheiden.
#   growpart : cloud-guest-utils (deb) / cloud-utils-growpart (rpm)
#   locale   : locales (deb)           / glibc-langpack-en (rpm)
#   keyboard : keyboard-configuration+console-setup (deb) / kbd (rpm)
os_base_packages() {
  case "$OS_FAMILY" in
    debian) echo "locales keyboard-configuration console-setup cloud-guest-utils" ;;
    rhel) echo "glibc-langpack-en kbd cloud-utils-growpart" ;;
  esac
}

# Basiswerkzeuge. 'vim' heisst auf RHEL 'vim-enhanced' (ein Paket namens 'vim'
# gibt es dort nicht), der Rest ist gleich benannt.
os_common_packages() {
  case "$OS_FAMILY" in
    debian) echo "curl wget vim less sudo ca-certificates" ;;
    # Kein 'curl': RHEL installiert 'curl-minimal', das mit 'curl' KONFLIGIERT --
    # ein 'dnf install curl' bricht die Transaktion ab. curl-minimal liefert
    # /usr/bin/curl bereits. 'ca-certificates' ist Teil der Basisinstallation.
    rhel) echo "wget vim-enhanced less sudo" ;;
  esac
}

# ---------------------------------------------------------------------------
# Lokalisierung
# ---------------------------------------------------------------------------
os_set_timezone() {
  tz="$1"
  ln -sf "/usr/share/zoneinfo/${tz}" /etc/localtime
  case "$OS_FAMILY" in
    debian)
      echo "${tz}" > /etc/timezone
      dpkg-reconfigure -f noninteractive tzdata
      ;;
    rhel)
      # timedatectl braucht einen laufenden systemd-timedated; im Build-Chroot
      # ist der Symlink oben bereits massgeblich.
      timedatectl set-timezone "${tz}" 2>/dev/null || true
      ;;
  esac
}

os_set_locale() {
  loc="$1"
  case "$OS_FAMILY" in
    debian) update-locale LANG="${loc}" LC_ALL= LANGUAGE= ;;
    rhel) printf 'LANG=%s\n' "${loc}" > /etc/locale.conf ;;
  esac
  export LANG="${loc}"
}

os_set_keymap() {
  km="$1"
  case "$OS_FAMILY" in
    debian)
      cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="${km}"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
      dpkg-reconfigure -f noninteractive keyboard-configuration || true
      setupcon --save 2>/dev/null || true
      ;;
    rhel)
      printf 'KEYMAP=%s\nFONT=eurlatgr\n' "${km}" > /etc/vconsole.conf
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Kernel-Kommandozeile (hier: net.ifnames=0 biosdevname=0 -> eth0)
# ---------------------------------------------------------------------------
os_kernel_cmdline_add() {
  args="$1"
  if grep -q '^GRUB_CMDLINE_LINUX=' /etc/default/grub 2>/dev/null; then
    grep -q "${args%% *}" /etc/default/grub \
      || sed -i "s/^\(GRUB_CMDLINE_LINUX=\"\)/\1${args} /" /etc/default/grub
  else
    echo "GRUB_CMDLINE_LINUX=\"${args}\"" >> /etc/default/grub
  fi

  case "$OS_FAMILY" in
    debian)
      update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg
      ;;
    rhel)
      # RHEL 9/10 nutzt BLS: die Boot-Eintraege liegen unter /boot/loader/entries
      # und werden von grub2-mkconfig NICHT mit neuen Argumenten versorgt.
      # grubby schreibt die Argumente in alle Eintraege -- das ist der
      # unterstuetzte Weg und ueberlebt Kernel-Updates.
      grubby --update-kernel=ALL --args="${args}" >/dev/null 2>&1 || true
      grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1 || true
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Netzwerk: eth0 per DHCP, mit auskommentierter Vorlage fuer feste IP
# ---------------------------------------------------------------------------
os_net_dhcp_eth0() {
  case "${ID:-}" in
    ubuntu) _os_net_netplan ;;
    debian) _os_net_ifupdown ;;
    *) _os_net_nmconnection ;;
  esac
}

_os_net_netplan() {
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
#  --- Feste IP? dhcp4 auf false setzen und folgende Zeilen einkommentieren ---
#  --- (Werte anpassen; ausfuehrliches Rezept: /root/SETUP.md) ----------------
#      dhcp4: false
#      addresses: [10.0.0.10/24]
#      routes:
#        - to: default
#          via: 10.0.0.1
#      nameservers:
#        addresses: [10.0.0.1, 1.1.1.1]
#  danach:  netplan apply
#
#  --- Zweite NIC (eth1)? unter "ethernets:" (gleiche Einrueckung wie eth0) ---
#      eth1:
#        dhcp4: true
#        # oder feste IP analog zu eth0 oben:
#        # dhcp4: false
#        # addresses: [10.0.1.10/24]
EOF
  chmod 0600 /etc/netplan/00-eth0.yaml
}

_os_net_ifupdown() {
  cat > /etc/network/interfaces <<'EOF'
# Von Packer erzeugt -- DHCP auf eth0 (net.ifnames=0)
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp

#--- Feste IP? Die zwei eth0-Zeilen oben durch folgendes ersetzen ---
#--- (Werte anpassen; ausfuehrliches Rezept: /root/SETUP.md) --------
#auto eth0
#iface eth0 inet static
#    address 10.0.0.10/24
#    gateway 10.0.0.1
#    dns-nameservers 10.0.0.1 1.1.1.1
#danach:  systemctl restart networking   (oder reboot)
#
#--- Zweite NIC (eth1)? folgende Zeilen einkommentieren ---
#allow-hotplug eth1
#iface eth1 inet dhcp
## oder feste IP:
## iface eth1 inet static
##     address 10.0.1.10/24
EOF
}

_os_net_nmconnection() {
  # RHEL 10 unterstuetzt keine ifcfg-Dateien mehr -- NetworkManager-Keyfiles
  # sind das einzige Format. Kommentare sind im Keyfile erlaubt (#).
  #
  # Das von Anaconda angelegte Profil wird BEWUSST NICHT geloescht:
  # NetworkManager ueberwacht system-connections/ per inotify und laedt
  # Aenderungen selbsttaetig nach -- das Entfernen des gerade AKTIVEN Profils
  # kann die Verbindung abbauen und damit die laufende Packer-SSH-Sitzung
  # kappen. Das Anaconda-Profil ist an den alten Interface-Namen (ens18/enp*)
  # gebunden und laeuft nach der Umbenennung auf eth0 (net.ifnames=0) ohnehin
  # ins Leere.
  cat > /etc/NetworkManager/system-connections/eth0.nmconnection <<'EOF'
[connection]
id=eth0
type=ethernet
interface-name=eth0
autoconnect=true

[ipv4]
method=auto
# --- Feste IP? method auf manual setzen und folgende Zeilen einkommentieren ---
# --- (Werte anpassen; ausfuehrliches Rezept: /root/SETUP.md) -----------------
#method=manual
#address1=10.0.0.10/24,10.0.0.1
#dns=10.0.0.1;1.1.1.1;
# danach:  nmcli connection reload && nmcli connection up eth0

[ipv6]
method=disabled
EOF
  # NetworkManager ignoriert Keyfiles mit zu weiten Rechten.
  chmod 0600 /etc/NetworkManager/system-connections/eth0.nmconnection
}

# ---------------------------------------------------------------------------
# Automatische Hintergrund-Updates abschalten (Templates sollen nicht
# ueberraschend im Hintergrund patchen)
# ---------------------------------------------------------------------------
os_disable_auto_updates() {
  case "$OS_FAMILY" in
    debian)
      sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades 2>/dev/null || true
      for t in apt-daily.timer apt-daily-upgrade.timer; do
        systemctl disable --now "$t" >/dev/null 2>&1 || true
      done
      systemctl mask apt-daily.service apt-daily-upgrade.service >/dev/null 2>&1 || true
      cat > /etc/apt/apt.conf.d/10periodic <<'EOF'
APT::Periodic::Enable "0";
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
      os_pkg_remove unattended-upgrades
      ;;
    rhel)
      for t in dnf-makecache.timer dnf-automatic.timer dnf-automatic-install.timer; do
        systemctl disable --now "$t" >/dev/null 2>&1 || true
      done
      systemctl mask dnf-makecache.service >/dev/null 2>&1 || true
      os_pkg_remove dnf-automatic
      ;;
  esac
}

# ---------------------------------------------------------------------------
# SSH: Unit-Namen unterscheiden sich (ssh.service vs. sshd.service)
# ---------------------------------------------------------------------------
os_ssh_service() {
  case "$OS_FAMILY" in
    debian) echo "ssh" ;;
    rhel) echo "sshd" ;;
  esac
}

# ---------------------------------------------------------------------------
# SELinux: Dateien, die wir per Shell-Umleitung angelegt haben, korrekt
# labeln. Ohne das koennen die First-Boot-Units und der root-SSH-Key auf einem
# enforcing-System stillschweigend scheitern (falscher Typ statt Rechtefehler).
# Auf der Debian-Familie ein No-op.
# ---------------------------------------------------------------------------
os_selinux_relabel() {
  [ "$OS_FAMILY" = "rhel" ] || return 0
  command -v restorecon >/dev/null 2>&1 || return 0
  restorecon -R /etc/systemd/system /usr/local/sbin /root/.ssh /etc/ssh >/dev/null 2>&1 || true
  [ -d /etc/NetworkManager/system-connections ] \
    && restorecon -R /etc/NetworkManager/system-connections >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Alte Kernel entfernen (aktuellen behalten)
# ---------------------------------------------------------------------------
os_remove_old_kernels() {
  case "$OS_FAMILY" in
    debian)
      cur="$(uname -r)"
      old="$(dpkg --list | awk '/^ii/ && $2 ~ /^linux-(image|headers|modules)-[0-9]/ {print $2}' | grep -v "$cur" || true)"
      # shellcheck disable=SC2086  # Paketliste -- Word-Splitting gewollt
      [ -n "$old" ] && apt-get -y purge $old >/dev/null 2>&1 || true
      ;;
    rhel)
      # installonly_limit=1 laesst dnf beim naechsten Kernel-Update selbst
      # aufraeumen; der aktuell laufende Kernel wird nie entfernt.
      dnf -y remove --oldinstallonly --setopt installonly_limit=1 kernel >/dev/null 2>&1 || true
      ;;
  esac
}
