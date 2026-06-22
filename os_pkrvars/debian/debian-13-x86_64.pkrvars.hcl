# Debian 13 (Trixie) -- x86_64
# preseed via Netzwerk; preseed.cfg unter http/debian/

os_name    = "debian"
os_version = "13"
os_arch    = "x86_64"

# "current" zeigt aktuell auf 13.5.0. Bei einem Point-Release Version + Checksum
# anpassen (https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS).
iso_url      = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.5.0-amd64-netinst.iso"
iso_checksum = "sha256:95838884f5ea6c82421dfe6baaa5a639dbbe6756c1e380f9fe7a7cb0c1949d2a"

# Debian-netinst bootet unter UEFI via GRUB. Wir oeffnen die GRUB-Kommandozeile
# ('c') und laden Kernel/initrd mit fixen, versionsstabilen Pfaden direkt -- das
# ist robuster als das Navigieren im Menue.
boot_command = [
  "<wait>c<wait>",
  "linux /install.amd/vmlinuz auto=true priority=critical preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed.cfg hostname=debian domain=local interface=auto vga=788 ---<enter><wait>",
  "initrd /install.amd/initrd.gz<enter><wait>",
  "boot<enter>"
]

# vSphere (firmware=efi): eigener boot_command mit laengerem Vorlauf (GRUB-c).
# (Debian-vSphere hat keinen Fork-Praezedenzfall -> beim ersten Build Konsole beobachten.)
vsphere_guest_os_type = "debian12_64Guest"
vsphere_boot_command = [
  "<wait5s>c<wait2s>",
  "linux /install.amd/vmlinuz auto=true priority=critical preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed.cfg hostname=debian domain=local interface=auto vga=788 ---<enter><wait>",
  "initrd /install.amd/initrd.gz<enter><wait>",
  "boot<enter>"
]
