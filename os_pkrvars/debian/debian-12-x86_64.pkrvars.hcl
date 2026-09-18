# Debian 12 (Bookworm) -- x86_64
# preseed via Netzwerk; preseed.cfg unter http/debian/ (mit Debian 13 geteilt)

os_name    = "debian"
os_version = "12"
os_arch    = "x86_64"

# Debian 12 ist oldstable und liegt NICHT mehr unter debian-cd/current/,
# sondern im Archiv. Archiv-URLs rotieren nicht -> stabil, aber beim
# Point-Release-Wechsel manuell nachziehen:
# https://cdimage.debian.org/cdimage/archive/
iso_url      = "https://cdimage.debian.org/cdimage/archive/12.15.0/amd64/iso-cd/debian-12.15.0-amd64-netinst.iso"
iso_checksum = "sha256:cd4462c06aa8892e692c0c4b9c17802f38c8ab8690e85cbfb5ccaa5956e9af17"

# Identisch zu Debian 13: GRUB-Kommandozeile + feste install.amd-Pfade.
# Zum Timing und zur Hotkey-Falle des Debian-Menues siehe debian-13.
#
# ipv6.disable=1 gilt NUR fuer den Installer-Kernel: Im Build-Netz werden
# IPv6-Router-Advertisements verteilt, es gibt aber keinen funktionierenden
# IPv6-Ausgang. deb.debian.org hat AAAA-Records -> der Installer laeuft in
# Timeouts und meldet "Bad archive mirror", der Build haengt im Dialog bis zum
# SSH-Timeout. Mit IPv4 laeuft der Mirror-Schritt normal durch.
#
# Absicht: nur der Installer, NICHT das Template -- ob IPv6 im Image an bleibt,
# ist eine Policy-Entscheidung und soll nicht als Nebenwirkung hier fallen.
# Ob d-i den Parameter in die GRUB-Config des Ziels uebernimmt, ist beim
# Klon-Test zu pruefen (/etc/default/grub im Klon).
boot_wait = "15s"
boot_command = [
  "<wait5s>c<wait2s>",
  "linux /install.amd/vmlinuz auto=true priority=critical preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed.cfg hostname=debian domain=local interface=auto ipv6.disable=1 vga=788 ---<enter><wait>",
  "initrd /install.amd/initrd.gz<enter><wait>",
  "boot<enter>"
]

vsphere_guest_os_type = "debian12_64Guest"
