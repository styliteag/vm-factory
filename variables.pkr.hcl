###############################################################################
# Variablen-Definitionen
#
#   * Verbindungs-/Storage-/Netzwerk-Werte  -> credentials.pkrvars.hcl
#   * OS-spezifische Werte (ISO, boot_command) -> os_pkrvars/<os>/<...>.pkrvars.hcl
###############################################################################

# ---------------------------------------------------------------------------
# Proxmox API-Verbindung
# ---------------------------------------------------------------------------
variable "proxmox_url" {
  type        = string
  default     = ""
  description = "Proxmox API-Endpunkt, z. B. https://pve.example.com:8006/api2/json"
}

variable "proxmox_node" {
  type        = string
  default     = ""
  description = "Name des Proxmox-Node, auf dem gebaut wird (siehe: pvesh get /nodes)"
}

variable "proxmox_username" {
  type        = string
  default     = ""
  description = "API-Token-ID im Format user@realm!tokenname (z. B. packer@pve!packer)"
}

variable "proxmox_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "API-Token-Secret (UUID)"
}

variable "proxmox_insecure_tls" {
  type        = bool
  default     = false
  description = "true, falls Proxmox ein selbstsigniertes Zertifikat verwendet"
}

# ---------------------------------------------------------------------------
# Storage / Netzwerk (an die Umgebung anpassen)
# ---------------------------------------------------------------------------
variable "vm_storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage-Pool fuer die VM-Festplatte"
}

variable "iso_storage_pool" {
  type        = string
  default     = "local"
  description = "Storage-Pool, in den PVE das ISO laedt (muss 'ISO image'-Content erlauben)"
}

variable "efi_storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage-Pool fuer die EFI-Disk (UEFI/OVMF)"
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Proxmox-Netzwerk-Bridge"
}

variable "network_vlan" {
  type        = number
  default     = 0
  description = "VLAN-Tag (0 = kein Tag)"
}

variable "network_firewall" {
  type        = bool
  default     = false
  description = "Proxmox-Firewall am NIC aktivieren"
}

# ---------------------------------------------------------------------------
# VM-Hardware
# ---------------------------------------------------------------------------
variable "vm_id" {
  type        = number
  default     = 0
  description = "Feste VMID (0 = automatisch vergeben)"
}

variable "vm_cpu_cores" {
  type    = number
  default = 2
}

variable "vm_cpu_sockets" {
  type    = number
  default = 1
}

variable "vm_cpu_type" {
  type        = string
  default     = "host"
  description = "CPU-Typ (host = beste Performance; kvm64 = maximale Migrierbarkeit)"
}

variable "vm_memory" {
  type        = number
  default     = 2048
  description = "Arbeitsspeicher in MB"
}

variable "vm_disk_size" {
  type        = string
  default     = "8G"
  description = "Groesse der VM-Festplatte (Template; waechst beim Klonen via growroot)"
}

# ---------------------------------------------------------------------------
# SSH (Packer verbindet sich nach der Installation; IP via qemu-guest-agent)
# ---------------------------------------------------------------------------
variable "ssh_username" {
  type        = string
  default     = "packer"
  description = "Build-User, den autoinstall/preseed anlegt"
}

variable "ssh_password" {
  type        = string
  default     = "packer"
  sensitive   = true
  description = "Passwort des Build-Users"
}

variable "ssh_timeout" {
  type    = string
  default = "30m"
}

# ---------------------------------------------------------------------------
# Template-Metadaten
# ---------------------------------------------------------------------------
variable "template_tags" {
  type        = string
  default     = "packer"
  description = "Proxmox-Tags fuer das Template (durch ';' getrennt)"
}

variable "task_timeout" {
  type        = string
  default     = "30m"
  description = "Timeout fuer PVE-Tasks (v. a. der ISO-Download durch den Node). Der Plugin-Default von 1m reicht fuer grosse ISOs nicht; gemessen wurden auf px1 ~2,5 MB/s vom Rocky-Redirector (2 GB => ~13 min), waehrend derselbe Download vom Build-Host mit 45 MB/s lief. Grosszuegig setzen: ein hoher Wert bremst schnelle Tasks nicht, ein zu niedriger bricht einen laufenden Download ab."
}

variable "boot_wait" {
  type        = string
  default     = "5s"
  description = "Wartezeit bis zum Start des boot_command (bis GRUB bereit ist)"
}

# ---------------------------------------------------------------------------
# Template-Anpassungen (Locale / Tastatur / Zeit / SSH)
# ---------------------------------------------------------------------------
variable "vm_timezone" {
  type        = string
  default     = "Europe/Berlin"
  description = "Zeitzone des Templates"
}

variable "vm_locale" {
  type        = string
  default     = "C.UTF-8"
  description = "System-Locale (LANG). C.UTF-8 = englische Meldungen + UTF-8; fuer reines ASCII 'C' setzen"
}

variable "vm_keymap" {
  type        = string
  default     = "de"
  description = "Konsolen-Tastaturlayout (XKBLAYOUT)"
}

variable "ssh_authorized_keys" {
  type        = string
  default     = ""
  description = "Optionaler Override fuer root-Keys (mehrzeilig). Standard: files/authorized_keys (Team-Set)"
}

variable "root_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Optionales root-Passwort (nur Konsole/Notfall; SSH bleibt key-only). Leer = kein Passwort"
}

# ---------------------------------------------------------------------------
# OS-spezifisch -- gesetzt in os_pkrvars/<os>/<...>.pkrvars.hcl (Pflicht)
# ---------------------------------------------------------------------------
variable "os_name" {
  type        = string
  description = "z. B. ubuntu / debian"
}

variable "os_version" {
  type        = string
  description = "z. B. 26.04 / 13"
}

variable "os_arch" {
  type    = string
  default = "x86_64"
}

variable "iso_url" {
  type        = string
  description = "Download-URL des Installations-ISO"
}

variable "iso_checksum" {
  type        = string
  description = "Pruefsumme im Format 'sha256:<hex>' (konkret, da PVE selbst herunterlaedt)"
}

variable "boot_command" {
  type        = list(string)
  description = "Tastatureingaben, um autoinstall/preseed zu starten"
}

variable "vsphere_guest_os_type" {
  type        = string
  default     = "otherLinux64Guest"
  description = "vSphere Guest-OS-ID (z. B. ubuntu64Guest, debian12_64Guest)"
}

# ---------------------------------------------------------------------------
# HTTP-Server (autoinstall/preseed) -- plattformuebergreifend
# ---------------------------------------------------------------------------
variable "http_ip" {
  type        = string
  default     = ""
  description = "IP des Build-Hosts, die der Gast erreichen soll (leer = automatisch)"
}

# ---------------------------------------------------------------------------
# vSphere / vCenter (nur fuer den vsphere-iso Build)
# ---------------------------------------------------------------------------
variable "vsphere_server" {
  type        = string
  default     = ""
  description = "vCenter-/ESXi-Hostname oder IP"
}

variable "vsphere_username" {
  type    = string
  default = ""
}

variable "vsphere_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "vsphere_insecure" {
  type        = bool
  default     = true
  description = "TLS-Zertifikat des vCenter ignorieren"
}

variable "vsphere_datacenter" {
  type    = string
  default = ""
}

variable "vsphere_cluster" {
  type    = string
  default = ""
}

variable "vsphere_host" {
  type        = string
  default     = ""
  description = "Optional: bestimmter ESXi-Host im Cluster"
}

variable "vsphere_resource_pool" {
  type    = string
  default = ""
}

variable "vsphere_datastore" {
  type    = string
  default = ""
}

variable "vsphere_folder" {
  type        = string
  default     = ""
  description = "Ziel-Ordner (VM/Template-Folder) im Datacenter"
}

variable "vsphere_network" {
  type        = string
  default     = "VM Network"
  description = "Portgroup/Netzwerk-Name"
}

variable "vsphere_disk_size_mb" {
  type        = number
  default     = 8192
  description = "VM-Disk-Groesse in MB (vSphere; waechst beim Klonen via growroot)"
}

variable "vsphere_boot_wait" {
  type    = string
  default = "15s"
}

variable "vsphere_boot_command" {
  type        = list(string)
  default     = []
  description = "Optionaler vSphere-spezifischer boot_command (leer = gemeinsamer boot_command)"
}
