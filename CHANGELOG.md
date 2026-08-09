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
  mit `nofail`, Root-Platte vergrößern, Sanity-Check nach dem Klonen), MOTD-Zeiger
  darauf sowie auskommentierte Kurzvorlagen direkt in `00-eth0.yaml` /
  `/etc/network/interfaces` und `/etc/fstab`.
- **Konsolen-Login zeigt die aktuelle IP** (`/etc/issue` mit agetty-Escape
  `\4{eth0}`) — DHCP-IP headless ohne Hypervisor-Konsole ablesbar.

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

- **Auto-Resize der Root-Platte blieb im Klon wirkungslos:** `growroot.service`
  war ein Einmal-Dienst mit Marker `/var/lib/growroot.done`; der Marker wurde
  unbedingt gesetzt (auch wenn `growpart` nichts tat), und `|| true` verschluckte
  echte Fehler. Damit verbrauchte bereits der erste Boot des Templates den Lauf —
  jede später vergrößerte Platte blieb dauerhaft ungenutzt (Symptom: 64-GB-Disk,
  7,5-GB-Root, GPT spannt die Platte nicht). Der Dienst läuft jetzt bei jedem Boot
  und ist idempotent; Marker entfällt, `resize2fs` ist das einzige harte
  Erfolgskriterium (Fehler lassen die Unit sichtbar fehlschlagen). Abschalten per
  `touch /etc/growroot.disabled`. **Bereits ausgerollte VMs** brauchen einmalig
  `rm -f /var/lib/growroot.done` + Reboot (oder `growpart /dev/sda 2 && resize2fs /dev/sda2`).
- **SSH-Härtung war wirkungslos:** Die von autoinstall (`ssh: allow-pw`) zur
  Laufzeit erzeugte `/etc/ssh/sshd_config.d/50-cloud-init.conf` überlebte das
  `purge cloud-init` (paketfremde Datei) und setzte `PasswordAuthentication yes`.
  Da sshd je Option den ersten Treffer nimmt und der Include alphabetisch sortiert,
  gewann sie gegen `99-hardening.conf`. Datei wird jetzt entfernt, die Härtung
  heißt `00-hardening.conf`, und `sshd -T` verifiziert am Ende des Builds, dass
  `PasswordAuthentication no` effektiv gilt (sonst bricht der Build ab).
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
- **Packer-Build-User wurde nie aus dem Template entfernt:** `userdel -r packer`
  in `99-cleanup.sh` scheiterte an der aktiven Build-Login-Session
  (`user packer is currently used by process …`) und wurde per `|| true`
  verschluckt → Golden Image enthielt den Build-User samt `/home/packer`. Löschung
  jetzt auf den ersten Klon-Boot verschoben (`remove-packer-user.service`,
  self-removing Oneshot); `99-cleanup.sh` entzieht nur noch die sudo-Rechte.

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
