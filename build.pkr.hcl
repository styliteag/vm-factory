###############################################################################
# Build-Block: Provisionierung nach der OS-Installation
#
# Die Skripte laufen als 'packer' via sudo. Reihenfolge:
#   00  System aktualisieren + Pakete (qemu-guest-agent, cloud-init)
#   10  Cloud-Init fuer Proxmox (NoCloud/ConfigDrive) konfigurieren
#   99  Aufraeumen + Generalisieren (cloud-init clean, machine-id, host-keys)
###############################################################################

build {
  name = "templates"
  sources = [
    "source.proxmox-iso.vm",
    "source.vsphere-iso.vm",
  ]

  # SSH-Keys (Team-Set) auf die Build-VM laden -> 20-customize installiert sie
  provisioner "file" {
    source      = "files/authorized_keys"
    destination = "/tmp/packer-authorized_keys"
  }

  # OS-Abstraktion (apt/dnf, netplan/NetworkManager, ...) -- die shell-Provisioner
  # binden sie mit '. /tmp/packer-os-lib.sh' ein. Muss ein eigener file-Provisioner
  # sein: 'scripts = [...]' laedt nur die dort gelisteten Dateien hoch.
  provisioner "file" {
    source      = "scripts/lib/os.sh"
    destination = "/tmp/packer-os-lib.sh"
  }

  provisioner "shell" {
    # 'sudo env {{ .Vars }}' reicht die environment_vars zuverlaessig an root weiter
    # (sudo -E wird von der Policy ignoriert).
    execute_command   = "echo '${var.ssh_password}' | sudo -S -p '' env {{ .Vars }} bash -eu '{{ .Path }}'"
    expect_disconnect = true
    environment_vars = [
      "VM_TIMEZONE=${var.vm_timezone}",
      "VM_LOCALE=${var.vm_locale}",
      "VM_KEYMAP=${var.vm_keymap}",
      "SSH_AUTHORIZED_KEYS=${var.ssh_authorized_keys}",
      "ROOT_PASSWORD=${var.root_password}",
      "CLOUD_INIT=${var.cloud_init}",
    ]
    scripts = [
      "scripts/00-update.sh",
      "scripts/20-customize.sh",
      "scripts/30-minimize.sh",
      "scripts/99-cleanup.sh",
    ]
  }
}
