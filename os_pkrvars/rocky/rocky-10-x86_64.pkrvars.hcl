# Rocky Linux 10 -- x86_64
# kickstart via Netzwerk; ks.cfg unter http/rocky/

os_name    = "rocky"
os_version = "10"
os_arch    = "x86_64"

# Point-Release: https://download.rockylinux.org/pub/rocky/10/isos/x86_64/CHECKSUM
# Das "minimal"-ISO enthaelt BaseOS + AppStream -- die Installation braucht
# keinen Mirror.
iso_url      = "https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.2-x86_64-minimal.iso"
iso_checksum = "sha256:aac6ac3ce781b91a91ce78463405f66c611a5dca4b3840c79e5e01d97302f6c8"

# GRUB-Kommandozeile wie bei Debian, ABER mit umgekehrter Zeitanforderung:
# Das Rocky-Menue setzt 'set timeout=60' und 'set default="1"' -- Eintrag 1 ist
# "Test this media & install" (langsamer rd.live.check). Zu spaetes 'c' startet
# also den Medientest; zu frueh geht es im OVMF-POST verloren. 20s (boot_wait
# 15s + <wait5s>) liegt komfortabel in beiden Grenzen.
#
# Werte direkt aus EFI/BOOT/grub.cfg des ISO uebernommen:
#   * Kernel/initrd liegen unter /images/pxeboot/
#   * linuxefi/initrdefi (nicht linux/initrd) -- so nutzt es die ISO selbst
#   * inst.stage2-Label ist "...-dvd", AUCH beim minimal-ISO (nicht "-minimal")
#
# ipv6.disable=1: siehe Kommentar in debian-13 -- im Build-Netz werden
# IPv6-RAs verteilt, ohne funktionierenden IPv6-Ausgang.
# Anaconda installiert ~350 Pakete und baut danach initramfs + SELinux-Relabel
# ("Set file contexts") -- das dauert laenger als eine Debian-netinst- oder
# Ubuntu-Installation. Gemessen: gut 30 min. Der globale Default von 30m ist
# dafuer zu knapp.
ssh_timeout = "60m"

boot_wait = "15s"
boot_command = [
  "<wait5s>c<wait2s>",
  "linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=Rocky-10-2-x86_64-dvd inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/rocky/ks.cfg inst.text ipv6.disable=1 quiet<enter><wait2s>",
  "initrdefi /images/pxeboot/initrd.img<enter><wait2s>",
  "boot<enter>"
]

# vSphere: bewusst kein eigener guest_os_type gesetzt -> Default
# "otherLinux64Guest". Der Rocky-Build ist bisher nur auf Proxmox verifiziert;
# fuer vSphere waere ein passender Typ (z. B. "rhel9_64Guest") zu pruefen.
