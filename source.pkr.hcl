###############################################################################
# proxmox-iso Source
#
# Eine einzige, parametrisierte Source fuer alle Betriebssysteme. Die OS-Auswahl
# erfolgt ueber das jeweilige -var-file (siehe build.sh).
###############################################################################

locals {
  # Proxmox verlangt gueltige DNS-Namen: '.' und '_' -> '-'
  template_name = replace(replace("${var.os_name}-${var.os_version}-${var.os_arch}", ".", "-"), "_", "-")
  vm_name       = replace(replace("packer-${var.os_name}-${var.os_version}", ".", "-"), "_", "-")
}

source "proxmox-iso" "vm" {
  # ---- Proxmox-Verbindung ----
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_insecure_tls

  # ---- VM-Identitaet / Template ----
  vm_name              = local.vm_name
  vm_id                = var.vm_id
  template_name        = local.template_name
  template_description = "Packer-Build ${var.os_name} ${var.os_version} (${var.os_arch}) - ${timestamp()}"
  tags                 = var.template_tags
  onboot               = false

  # ---- Firmware: UEFI / OVMF ----
  bios    = "ovmf"
  machine = "q35"
  os      = "l26"
  efi_config {
    efi_storage_pool  = var.efi_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = false # Secure Boot deaktiviert -> maximale Kompatibilitaet
  }

  # ---- CPU / RAM ----
  cores    = var.vm_cpu_cores
  sockets  = var.vm_cpu_sockets
  cpu_type = var.vm_cpu_type
  memory   = var.vm_memory

  # ---- Boot-ISO (PVE laedt es selbst herunter) ----
  boot_iso {
    type             = "ide"
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = var.iso_storage_pool
    iso_download_pve = true
    unmount          = true # ISO nach der Installation aus dem Template entfernen
  }

  # ---- Festplatte ----
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    storage_pool = var.vm_storage_pool
    disk_size    = var.vm_disk_size
    io_thread    = true
    discard      = true
    ssd          = true
  }

  # ---- Netzwerk ----
  network_adapters {
    model  = "virtio"
    bridge = var.network_bridge
    # 0 -> null = kein VLAN-Tag (Proxmox lehnt tag=0 ab)
    vlan_tag = var.network_vlan > 0 ? var.network_vlan : null
    firewall = var.network_firewall
  }

  # ---- Anzeige / Guest-Agent ----
  vga {
    type = "std"
  }
  qemu_agent = true # noetig, damit Packer die VM-IP nach dem Reboot findet

  # ---- Automatische Installation ----
  boot_wait      = var.boot_wait
  boot_command   = var.boot_command
  http_directory = "http"

  # ---- SSH (Provisionierung nach Installation) ----
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = var.ssh_timeout
}
