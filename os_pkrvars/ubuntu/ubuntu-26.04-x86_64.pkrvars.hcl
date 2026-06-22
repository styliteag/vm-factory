# Ubuntu 26.04 LTS (Resolute Raccoon) -- x86_64
# autoinstall via NoCloud; user-data/meta-data unter http/ubuntu/

os_name    = "ubuntu"
os_version = "26.04"
os_arch    = "x86_64"

iso_url      = "https://releases.ubuntu.com/resolute/ubuntu-26.04-live-server-amd64.iso"
iso_checksum = "sha256:dec49008a71f6098d0bcfc822021f4d042d5f2db279e4d75bdd981304f1ca5d9"

# GRUB-Menueeintrag editieren ('e'), autoinstall-Parameter an die linux-Zeile
# anhaengen, dann mit F10 booten. Die Anfuehrungszeichen schuetzen das ';'
# vor GRUB (sonst wuerde GRUB es als Kommandotrenner werten).
boot_command = [
  "<wait>e<wait>",
  "<down><down><down><end>",
  " autoinstall \"ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu/\"",
  "<wait><f10>"
]

# vSphere (firmware=efi): bewaehrter boot_command aus styliteag/bento (GRUB-c + casper)
vsphere_guest_os_type = "ubuntu64Guest"
vsphere_boot_command = [
  "<wait5s>c<wait>",
  "set gfxpayload=keep<enter><wait>",
  "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu/ ---<enter><wait>",
  "initrd /casper/initrd<enter><wait>",
  "boot<enter>"
]
