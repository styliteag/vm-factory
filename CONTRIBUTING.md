# Mitwirken

Kurzleitfaden zum Erweitern und Pflegen dieses Repos.

## Voraussetzungen für Entwicklung

- [Packer](https://developer.hashicorp.com/packer) ≥ 1.11 (siehe `install-packer.sh`)
- `shellcheck` für die Skripte (optional, empfohlen)
- Zugriff auf einen Proxmox-VE-Server zum Testen

## Vor jedem Commit

```bash
packer fmt -recursive .     # HCL formatieren
./build.sh validate         # beide OS-Konfigurationen prüfen
shellcheck scripts/*.sh *.sh
```

## Ein weiteres Betriebssystem hinzufügen

1. Neue Variablendatei anlegen, z. B. `os_pkrvars/ubuntu/ubuntu-24.04-x86_64.pkrvars.hcl`
   mit `os_name`, `os_version`, `os_arch`, `iso_url`, `iso_checksum`, `boot_command`.
2. ISO-URL und **konkrete** `sha256:`-Prüfsumme eintragen
   (nötig, weil PVE das ISO selbst herunterlädt).
3. Antwortdatei(en) ergänzen:
   - Ubuntu/autoinstall → `http/<os>/user-data` (+ `meta-data`)
   - Debian/preseed → `http/<os>/preseed.cfg`
4. Ein Ziel in `build.sh` ergänzen (case-Block).
5. `./build.sh validate` ausführen und einen Testbau durchführen.

## Konventionen

- HCL: 2 Leerzeichen Einrückung, `packer fmt`-konform.
- Shell: `#!/usr/bin/env bash` + `set -euo pipefail`, shellcheck-sauber.
- Keine Geheimnisse einchecken — alles Umgebungsspezifische gehört in
  `credentials.pkrvars.hcl` (per `.gitignore` ausgenommen).
- Commit-Messages knapp und im Imperativ.
