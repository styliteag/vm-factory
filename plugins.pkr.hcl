###############################################################################
# Packer- und Plugin-Anforderungen
#
# Das Proxmox-Plugin wird via `packer init .` heruntergeladen.
###############################################################################

packer {
  required_version = ">= 1.11.0"

  required_plugins {
    proxmox = {
      # boot_iso-Block + iso_download_pve benoetigen >= 1.2.2
      version = ">= 1.2.2"
      source  = "github.com/hashicorp/proxmox"
    }
    vsphere = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}
