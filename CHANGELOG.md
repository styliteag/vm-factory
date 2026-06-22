# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.
Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung nach [SemVer](https://semver.org/lang/de/).

## [Unreleased]

### Hinzugefügt

- **VMware-vSphere-Unterstützung** (`vsphere-iso`, Plugin v2): neue
  `source-vsphere.pkr.hcl`, gemeinsamer Build-Block, plattformabhängige Gast-Tools
  (open-vm-tools), `disk.EnableUUID=TRUE`, `pvscsi`/`vmxnet3`, `firmware=efi`,
  `convert_to_template`.
- `build.sh` mit Plattform-Auswahl (`./build.sh [proxmox|vsphere] ...`, `-only` + `-force`).
- vSphere-Variablen + `credentials-vsphere.pkrvars.hcl.example`; Ubuntu nutzt den
  bewährten Fork-`boot_command` (GRUB-`c`/casper) via `vsphere_boot_command`.
- **Erstkonfigurations-Hilfen** für den Klon (passiv, Golden Image bleibt sauber):
  zentrale `/root/SETUP.md` mit Rezepten (Hostname inkl. `/etc/hosts`, feste IP für
  netplan/ifupdown, zweite NIC `eth1`, zweite Platte via `lsblk`/`mkfs`/`blkid`/`fstab`
  mit `nofail`), MOTD-Zeiger darauf sowie auskommentierte Kurzvorlagen direkt in
  `00-eth0.yaml` / `/etc/network/interfaces` und `/etc/fstab`.

### Geändert

- **Cloud-Init vollständig entfernt** – Templates sind reine Golden Images
  (kein Cloud-Init-Paket, kein Cloud-Init-Laufwerk).
- Neues `scripts/20-customize.sh` setzt feste Zeitzone (`Europe/Berlin`),
  Locale (`C.UTF-8`), Konsolen-Tastatur (`de`), benennt das Interface in `eth0`
  (`net.ifnames=0`) inkl. DHCP-Konfiguration und hinterlegt den root-SSH-Key.
- SSH-Härtung: nur Key-Login, `PermitRootLogin prohibit-password`,
  Passwort-Login deaktiviert (sofern `ssh_authorized_keys` gesetzt).
- Neue Variablen: `vm_timezone`, `vm_locale`, `vm_keymap`, `ssh_authorized_keys`,
  `root_password`.
- `scripts/10-cloud-init-pve.sh` entfernt.

### Übernommen aus styliteag/bento (stylite-vsphere)

- **Team-SSH-Keys** in `files/authorized_keys` (per file-Provisioner als root).
- **Auto-Resize der Root-Partition** beim ersten Boot (systemd-Oneshot, ersetzt
  die entfallene Cloud-Init-`growpart`-Funktion).
- **Automatische Updates deaktiviert** (`apt-daily`-Timer, `release-upgrades`,
  periodic, `unattended-upgrades` entfernt).
- **Moderate Minimierung** (`scripts/30-minimize.sh`): snapd (Ubuntu), alte
  Kernel, `*-doc`, `/usr/share/doc`, `/var/cache`.
- **MOTD-Branding** sowie Entfernen von `random-seed`/Login-Records.
- Optionales **root-Passwort** (`root_password`) nur für Konsole/Notfall.

### Behoben

- **SSH startete im Klon nicht:** Ohne Cloud-Init fehlte die Neuerzeugung der in
  `99-cleanup.sh` entfernten Host-Keys → `sshd` startete mangels Keys nicht. Neuer
  systemd-Oneshot `regenerate-ssh-host-keys.service` (`ssh-keygen -A`, vor `ssh.service`/
  `ssh.socket`) erzeugt sie beim ersten Boot.
- **sshd lauschte nach dem Klonen nicht:** Debian 13 / Ubuntu 26.04 nutzen
  Socket-Aktivierung; das frühere `systemctl enable ssh` kollidierte damit. Jetzt
  `ssh.socket` deaktiviert und `ssh.service` aktiviert (dauerhaft laufender sshd).
- `network_adapters.vlan_tag = 0` → `null` (Proxmox lehnt `tag=0` ab).
- `sudo -E` aus `execute_command` entfernt (von der Policy ignoriert);
  Env-Variablen werden nun via `sudo env` zuverlässig übergeben.
- Harmlose `systemctl enable`-Warnung für qemu-guest-agent auf Debian unterdrückt.
- **README-Doku zur Platten-Vergrößerung korrigiert:** Root wächst beim Boot
  automatisch (`growroot.service`), nicht erst nach manuellem `growpart`/`resize2fs`
  (veralteter Cloud-Init-Hinweis entfernt).

## [0.1.0] - 2026-06-21

### Hinzugefügt

- Packer-Setup (`proxmox-iso`, Plugin ≥ 1.2.2) für Cloud-Init-fähige Templates.
- Ziel-Images: **Ubuntu 26.04 LTS** (autoinstall) und **Debian 13 / Trixie** (preseed).
- Parametrisierte Source mit OS-Auswahl über `os_pkrvars/<os>/*.pkrvars.hcl`.
- UEFI/OVMF, `virtio-scsi-single`, `qemu-guest-agent` + `cloud-init`, Cloud-Init-Laufwerk.
- ISO-Bereitstellung via `iso_download_pve` (PVE lädt das ISO selbst).
- Provisioning-Skripte: Update, Cloud-Init-Datasource für Proxmox, Generalisierung.
- Helfer: `install-packer.sh`, `build.sh` (validate/build), Beispiel-Credentials.
- Dokumentation: README, CONTRIBUTING, MIT-Lizenz.
