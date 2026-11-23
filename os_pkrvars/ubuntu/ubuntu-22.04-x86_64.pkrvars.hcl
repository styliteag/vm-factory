# Ubuntu 22.04 LTS (Jammy Jellyfish) -- x86_64
# autoinstall via NoCloud; user-data/meta-data unter http/ubuntu/ (mit 24.04/26.04 geteilt)
#
# Wird u. a. fuer BigBlueButton 3.0 gebraucht (Pakete nur fuer jammy).

os_name    = "ubuntu"
os_version = "22.04"
os_arch    = "x86_64"

# Point-Release: releases.ubuntu.com/22.04/ + SHA256SUMS
iso_url      = "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
iso_checksum = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"

# GRUB-Kommandozeilen-Weg wie bei 24.04 (stabile casper-Pfade statt
# Menue-Editieren, siehe Kommentar in ubuntu-24.04-x86_64.pkrvars.hcl).
boot_wait = "15s"
boot_command = [
  "<wait5s>c<wait2s>",
  "set gfxpayload=keep<enter><wait>",
  "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu/ ---<enter><wait>",
  "initrd /casper/initrd<enter><wait>",
  "boot<enter>"
]

vsphere_guest_os_type = "ubuntu64Guest"
