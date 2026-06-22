###############################################################################
# vsphere-iso Source
#
# Baut dieselben Golden Images wie die proxmox-iso Source, aber auf VMware
# vSphere. Provisionierung (scripts/) und autoinstall/preseed werden geteilt.
# Werte orientieren sich am bewaehrten styliteag/bento (stylite-vsphere):
# vmxnet3, pvscsi, disk.EnableUUID=TRUE, convert_to_template.
###############################################################################

source "vsphere-iso" "vm" {
  # ---- vCenter-Verbindung ----
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = var.vsphere_insecure

  # ---- Platzierung ----
  datacenter    = var.vsphere_datacenter
  datastore     = var.vsphere_datastore
  cluster       = var.vsphere_cluster != "" ? var.vsphere_cluster : null
  host          = var.vsphere_host != "" ? var.vsphere_host : null
  resource_pool = var.vsphere_resource_pool != "" ? var.vsphere_resource_pool : null
  folder        = var.vsphere_folder != "" ? var.vsphere_folder : null

  # ---- VM-Identitaet / Template ----
  vm_name             = local.vm_name
  guest_os_type       = var.vsphere_guest_os_type
  firmware            = "efi"
  notes               = "Packer-Build ${var.os_name} ${var.os_version} (${var.os_arch}) - ${timestamp()}"
  convert_to_template = true
  remove_cdrom        = true
  configuration_parameters = {
    "disk.EnableUUID" = "TRUE"
  }

  # ---- CPU / RAM ----
  CPUs            = var.vm_cpu_cores
  RAM             = var.vm_memory
  RAM_reserve_all = false
  # HW-Version: bewusst nicht gesetzt -> vCenter/Host-Default (kompatibel mit dem
  # bauenden Host). Fuer mischversionierte Cluster bei Bedarf spaeter ergaenzen.

  # ---- Festplatte / Controller ----
  disk_controller_type = ["pvscsi"]
  storage {
    disk_size             = var.vsphere_disk_size_mb
    disk_thin_provisioned = true
  }

  # ---- Netzwerk ----
  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  # ---- Boot-ISO (Packer laedt herunter und auf den Datastore hoch) ----
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # ---- Automatische Installation ----
  http_directory = "http"
  http_ip        = var.http_ip != "" ? var.http_ip : null
  boot_command   = length(var.vsphere_boot_command) > 0 ? var.vsphere_boot_command : var.boot_command
  boot_wait      = var.vsphere_boot_wait

  # ---- SSH (Provisionierung nach Installation) ----
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = var.ssh_timeout
  shutdown_command = "echo '${var.ssh_password}' | sudo -S -p '' shutdown -P now"
}
