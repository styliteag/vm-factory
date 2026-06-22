# vm-factory

Baut generalisierte **VM-Templates ("Golden Images")** für **Ubuntu 26.04 LTS**
und **Debian 13 (Trixie)** auf **Proxmox VE** und **VMware vSphere** – im Stil von
[chef/bento](https://github.com/chef/bento), aber nativ mit den `proxmox-iso`- und
`vsphere-iso`-Buildern von [HashiCorp Packer](https://developer.hashicorp.com/packer).
Provisionierung, autoinstall/preseed und Skripte sind plattformübergreifend geteilt.

**Ohne Cloud-Init.** Ergebnis pro Betriebssystem: ein fertig konfiguriertes
**Template** mit `qemu-guest-agent`, festen Einstellungen (Zeitzone, Locale,
Tastatur), Interface-Name `eth0` (DHCP) und hinterlegtem **root-SSH-Key**. Zum
Ausrollen wird es geklont, gestartet und direkt per SSH-Key als `root` erreicht;
Hostname/IP werden anschließend nach Bedarf (z. B. per Ansible) gesetzt.

---

## Funktionsweise

```
            ┌────────────────────┐         API          ┌─────────────────────┐
            │  Build-Host        │ ───────────────────▶ │  Proxmox VE          │
            │  (Debian/Ubuntu)   │   proxmox-iso        │                      │
            │  + Packer          │                      │  1. lädt ISO selbst  │
            │  + HTTP-Server ◀───┼── autoinstall/preseed│  2. VM aus ISO       │
            └────────────────────┘   (http/ wird vom    │  3. Provisionierung  │
                                      Gast geladen)      │  4. → Template       │
                                                         └─────────────────────┘
```

- Der **Build-Host** ist *nicht* der Proxmox-Server, sondern eine separate
  Maschine (oder VM), die per API mit Proxmox spricht.
- Proxmox lädt das Installations-ISO **selbst** herunter (`iso_download_pve`).
- Die Installation läuft vollautomatisch via **autoinstall** (Ubuntu) bzw.
  **preseed** (Debian); die Antwortdateien werden vom kurzlebigen
  HTTP-Server des Build-Hosts ausgeliefert.
- Firmware: **UEFI** (Proxmox: OVMF + `virtio-scsi-single`; vSphere: `efi` + `pvscsi`/`vmxnet3`).
- Gast-Tools je Plattform: **qemu-guest-agent** (Proxmox) bzw. **open-vm-tools** (vSphere).

---

## Voraussetzungen

### Build-Host (diese Maschine)

| Was | Wozu |
|-----|------|
| Debian/Ubuntu Linux | Betriebssystem für den Build-Host |
| **Packer ≥ 1.11** | wird per `install-packer.sh` installiert |
| `git`, `curl` | Repo & Hilfsskripte |
| **Netzwerk** | muss Proxmox auf Port **8006** erreichen **und** vom VM-Netz aus erreichbar sein (für den HTTP-Server) |

> Wichtig: Build-Host und die zu bauende VM müssen sich gegenseitig im Netz
> erreichen. Am einfachsten ist es, wenn der Build-Host im selben L2-Segment wie
> die gewählte Proxmox-Bridge liegt.

### Proxmox VE

| Was | Details |
|-----|---------|
| Proxmox VE | 8.x oder 9.x |
| **API-Token** | für einen User mit den nötigen Rechten (siehe unten) |
| Storage für `images` | z. B. `local-lvm`, ein ZFS-Pool, Ceph … (VM-Disk + EFI) |
| Storage für `iso` | Datastore mit „ISO image"-Content (z. B. `local`) |
| Bridge mit DHCP | das VM-Netz braucht während der Installation DHCP |

> **Pre-flight Proxmox:** Der Build-Host muss vom VM-Netz aus erreichbar sein
> (HTTP-Server für autoinstall/preseed). Bei einer einzelnen NIC wählt Packer die
> IP automatisch; bei **mehreren NICs** die richtige IP per `http_ip` in
> `credentials.pkrvars.hcl` setzen (bindet den HTTP-Server an diese IP).

### VMware vSphere (optional, für `./build.sh vsphere ...`)

| Was | Details |
|-----|---------|
| vCenter | Zugang (User/Passwort) mit Rechten zum Erstellen/Templatisieren von VMs |
| Datastore | für VM-Disk und ISO-Upload (genug Platz) |
| Portgroup | Netzwerk mit DHCP, das den Build-Host erreichen kann |
| Ordner | optionaler VM-/Template-Folder |

> **Pre-flight vSphere:** Datastore ~5 GB frei (ISO-Upload). Die Portgroup muss
> DHCP haben und den Build-Host (HTTP) erreichen — bei mehreren NICs `http_ip`
> setzen. Der vCenter-User braucht u. a. Datastore (AllocateSpace/Browse/
> FileManagement), Network.Assign, Resource.AssignVMToPool, VirtualMachine.Config.\*
> (inkl. AdvancedConfig für `disk.EnableUUID`), VirtualMachine.Interact,
> VirtualMachine.Inventory, VirtualMachine.Provisioning (MarkAsTemplate) und
> VirtualMachine.GuestOperations. Open-VM-Tools werden bereits bei der Installation
> mitinstalliert, damit Packer die Gast-IP findet.

---

## Repo-Struktur

```
vm-factory/
├── plugins.pkr.hcl          # benötigte Packer-Plugins (Proxmox, vSphere)
├── variables.pkr.hcl        # alle Variablen-Definitionen
├── source.pkr.hcl           # proxmox-iso Source
├── source-vsphere.pkr.hcl   # vsphere-iso Source
├── build.pkr.hcl            # Build-Block (beide Sources) + Provisionierung
├── credentials.pkrvars.hcl.example          # Proxmox-Zugang/Storage/Netz
├── credentials-vsphere.pkrvars.hcl.example  # vCenter-Zugang/Platzierung
├── files/authorized_keys    # root-SSH-Keys (Team-Set)
├── os_pkrvars/
│   ├── ubuntu/ubuntu-26.04-x86_64.pkrvars.hcl
│   └── debian/debian-13-x86_64.pkrvars.hcl
├── http/
│   ├── ubuntu/{user-data,meta-data}  # autoinstall
│   └── debian/preseed.cfg            # preseed
├── scripts/
│   ├── 00-update.sh                  # Update, qemu-guest-agent, Auto-Updates aus
│   ├── 20-customize.sh               # Locale/Tastatur/Zeit/eth0/SSH, Cloud-Init weg, Auto-Resize
│   ├── 30-minimize.sh                # moderate Minimierung (snapd, alte Kernel, docs)
│   └── 99-cleanup.sh                 # Generalisieren
├── install-packer.sh        # Packer auf dem Build-Host installieren
└── build.sh                 # Wrapper: validate / build
```

---

## Installation & Setup

### 1. Repo klonen

```bash
git clone git@github.com:styliteag/vm-factory.git
cd vm-factory
```

### 2. Packer installieren

```bash
sudo ./install-packer.sh        # offizielles HashiCorp-APT-Repo
packer version
```

### 3. Proxmox-API-Token anlegen

Auf dem **Proxmox-Host** (einmalig). Beispiel mit dediziertem User + Rolle:

```bash
pveum role add Packer -privs "\
VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit \
VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network \
VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt \
Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit \
Sys.Audit Sys.Console Sys.Modify SDN.Use"

pveum user add packer@pve
pveum aclmod / -user packer@pve -role Packer
pveum user token add packer@pve packer --privsep 0   # Token erbt User-Rechte
```

Das ausgegebene **Token-Secret** notieren (wird nur einmal angezeigt).

> `VM.Monitor` ist wichtig – ohne diese Berechtigung kann Packer die
> `boot_command`-Tasten nicht an die VM senden.

### 4. Zugangsdaten eintragen

```bash
cp credentials.pkrvars.hcl.example credentials.pkrvars.hcl
$EDITOR credentials.pkrvars.hcl
```

Werte: API-URL, Node, Token-ID + Secret, Storage-Pools, Bridge. Diese Datei ist
per `.gitignore` vom Versionsmanagement ausgenommen.

---

## Nutzung

Aufruf: `./build.sh [proxmox|vsphere] {ubuntu-26.04|debian-13|all|validate}`
(Plattform optional, Default `proxmox`).

```bash
# Proxmox (Default)
./build.sh validate          # Konfiguration prüfen (kein Build)
./build.sh ubuntu-26.04      # nur Ubuntu
./build.sh all               # beide nacheinander

# VMware vSphere (Zugang in credentials-vsphere.pkrvars.hcl)
./build.sh vsphere validate
./build.sh vsphere debian-13
./build.sh vsphere all

# zusätzliche Packer-Argumente werden durchgereicht:
./build.sh ubuntu-26.04 -on-error=ask
```

Intern wird per `-only` die passende Source gewählt und `-force` ersetzt ein
bestehendes Template gleichen Namens. Beim **ersten** Build lohnt der Blick auf
die VM-Konsole (Proxmox noVNC bzw. vSphere Web-Konsole), um die
`boot_command`-Eingabe zu beobachten.

---

## Template nutzen (klonen, ohne Cloud-Init)

Auf dem Proxmox-Host, z. B. mit dem Template `ubuntu-26-04-x86-64`:

```bash
qm clone <TEMPLATE_VMID> 9001 --name web01 --full
qm set 9001 --memory 4096 --cores 4
qm start 9001
# Der Klon holt sich per DHCP eine IP auf eth0; danach direkt als root:
ssh root@<IP-des-Klons>
```

Hostname und ggf. statische IP werden anschließend gesetzt (manuell oder per
Ansible). Platte vergrößern: `qm disk resize 9001 scsi0 40G`, danach im Gast
`growpart /dev/sda 1 && resize2fs ...` (kein automatisches Wachsen ohne Cloud-Init).

---

## Anpassen

| Was | Wo |
|-----|-----|
| URL, Node, Token, Storage, Bridge, VLAN | `credentials.pkrvars.hcl` |
| CPU/RAM/Disk-Größe | `credentials.pkrvars.hcl` bzw. `variables.pkr.hcl` |
| ISO-Version/Checksumme | `os_pkrvars/<os>/…pkrvars.hcl` |
| Installations-Antworten | `http/ubuntu/user-data`, `http/debian/preseed.cfg` |
| Software im Template | `scripts/00-update.sh` |
| Zeitzone/Locale/Tastatur/Interface/SSH | `scripts/20-customize.sh` + Variablen unten |
| root-SSH-Keys (Team-Set) | `files/authorized_keys` (Override: `ssh_authorized_keys`) |
| Weiteres OS | siehe [CONTRIBUTING.md](CONTRIBUTING.md) |

### Anpassungs-Variablen

| Variable | Default | Bedeutung |
|----------|---------|-----------|
| `vm_timezone` | `Europe/Berlin` | Zeitzone |
| `vm_locale` | `C.UTF-8` | System-Locale (für reines ASCII: `C`) |
| `vm_keymap` | `de` | Konsolen-Tastatur |
| `ssh_authorized_keys` | _(leer)_ | Override für root-Keys; Standard: `files/authorized_keys` |
| `root_password` | _(leer)_ | root-Passwort (nur Konsole/Notfall; SSH key-only) |

> Ist `ssh_authorized_keys` leer, bleibt der Passwort-Login aktiv (sonst wäre der
> Klon ohne hinterlegten Schlüssel nicht erreichbar).

### Build-User

`autoinstall`/`preseed` legen den User **`packer`** (passwortloses sudo) für die
Provisionierung an. Mit gesetztem `ssh_authorized_keys` ist der Passwort-Login
deaktiviert – `packer` kann sich dann **nicht** mehr per SSH anmelden (nur dein
root-Key). Soll das Template den User gar nicht behalten, am Ende von
`scripts/99-cleanup.sh` ergänzen:

```bash
userdel -r packer || true
rm -f /etc/sudoers.d/90-packer
```

---

## Verifizierte Stände (Stand 2026-06)

| Komponente | Version |
|-----------|---------|
| Packer | 1.15.4 |
| Proxmox-Plugin | 1.2.3 (`boot_iso`-Block) |
| Ubuntu | 26.04 LTS (Resolute Raccoon) |
| Debian | 13.5.0 (Trixie) |

---

## Troubleshooting

- **`boot_command` greift nicht / Installer startet nicht automatisch:** GRUB war
  noch nicht bereit oder das Menü-Layout weicht ab. `boot_wait` erhöhen (z. B.
  `10s`) und die noVNC-Konsole beobachten; bei Ubuntu ggf. die Anzahl `<down>`
  anpassen.
- **403 / Permission denied beim Senden der Tasten:** dem Token fehlt
  `VM.Monitor` (siehe Schritt 3).
- **Packer findet die VM-IP nicht (SSH-Timeout):** `qemu-guest-agent` muss im
  Gast laufen – er wird in `user-data`/`preseed.cfg` installiert und aktiviert.
- **`iso_download_pve`-Fehler:** Prüfsumme muss konkret sein (`sha256:<hex>`),
  der `iso_storage_pool` muss „ISO image"-Content erlauben.
- **`format`-Fehler auf Verzeichnis-Storage:** im `disks`-Block
  `format = "qcow2"` ergänzen (Block-/ZFS-Storage braucht das nicht).
- **Klon hat kein Netz:** das Image nutzt DHCP auf `eth0`. Gibt es im Zielnetz
  kein DHCP, in `scripts/20-customize.sh` eine statische Konfiguration hinterlegen.
- **VM bleibt nach Fehlversuch liegen:** `qm destroy <VMID>` auf dem Node, dann
  erneut bauen. Mit `-on-error=ask` lässt sich der Fehlerzustand untersuchen.

---

## Lizenz

[MIT](LICENSE) · © 2026 Stylite AG
