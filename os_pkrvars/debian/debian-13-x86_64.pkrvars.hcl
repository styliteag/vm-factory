# Debian 13 (Trixie) -- x86_64
# preseed via Netzwerk; preseed.cfg unter http/debian/

os_name    = "debian"
os_version = "13"
os_arch    = "x86_64"

# "current" zeigt aktuell auf 13.7.0. Bei einem Point-Release Version + Checksum
# anpassen (https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS).
iso_url      = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.7.0-amd64-netinst.iso"
iso_checksum = "sha256:a7ef94ac2fb9a7fec454552abd629b7cc9d5155c886165a45649f5ce6167e355"

# Debian-netinst bootet unter UEFI via GRUB. Wir oeffnen die GRUB-Kommandozeile
# ('c') und laden Kernel/initrd mit fixen, versionsstabilen Pfaden direkt -- das
# ist robuster als das Navigieren im Menue.
#
# WICHTIG -- grosszuegig warten, bevor 'c' getippt wird:
# Das GRUB-Menue der ISO setzt KEIN timeout (geprueft in /boot/grub/grub.cfg,
# x86_64-efi/grub.cfg und efi.img), wartet also unbegrenzt. Zu langes Warten
# kostet daher nichts, zu kurzes ist fatal: Kommt 'c' noch waehrend des
# OVMF-POST an, wird es verschluckt; die danach getippte 'linux'-Zeile landet
# im Menue, und das 'i' aus "linux" loest den Hotkey der Menueposition
# 'menuentry --hotkey=i Install' aus -> interaktiver Installer (Sprachauswahl),
# Build laeuft in den SSH-Timeout. Ubuntus Menue hat keine Hotkeys, dort faellt
# knappes Timing nicht auf.
boot_wait = "15s"
boot_command = [
  "<wait5s>c<wait2s>",
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
