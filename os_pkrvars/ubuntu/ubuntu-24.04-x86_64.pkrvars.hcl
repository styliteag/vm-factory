# Ubuntu 24.04 LTS (Noble Numbat) -- x86_64
# autoinstall via NoCloud; user-data/meta-data unter http/ubuntu/ (mit 26.04 geteilt)

os_name    = "ubuntu"
os_version = "24.04"
os_arch    = "x86_64"

# Point-Release: releases.ubuntu.com/24.04/ + SHA256SUMS
iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04.5-live-server-amd64.iso"
iso_checksum = "sha256:97f3d7ffb032c3eb3b23d2c8be9cc76e60c2c1f2c0146ba5ba9fe01cafae0fd8"

# Bewusst der GRUB-Kommandozeilen-Weg (wie vsphere_boot_command), nicht das
# Menue-Editieren per 'e' + <down><down><down><end> wie bei 26.04: Die Anzahl
# der <down> haengt an der Zeilenposition im Menueeintrag der jeweiligen ISO
# und bricht bei einem Point-Release still. Feste casper-Pfade sind stabil.
#
# Timing grosszuegig (siehe Kommentar in debian-13): Ubuntus Menue setzt zwar
# keine Hotkeys, ein zu frueh getipptes 'c' geht aber trotzdem im OVMF-POST
# verloren.
boot_wait = "15s"
boot_command = [
  "<wait5s>c<wait2s>",
  "set gfxpayload=keep<enter><wait>",
  "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu/ ---<enter><wait>",
  "initrd /casper/initrd<enter><wait>",
  "boot<enter>"
]

vsphere_guest_os_type = "ubuntu64Guest"
