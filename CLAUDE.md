# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Branch-Workflow

- Entwicklung erfolgt direkt auf `main`. **Keine** Feature-Branches anlegen, außer der User fordert es ausdrücklich.
- Dies überschreibt das Standardverhalten „auf dem Default-Branch zuerst branchen".

## Build / Validieren

- `packer init .` vor dem ersten validate/build (lädt proxmox- und vsphere-Plugin).
- Bauen/Prüfen über den Wrapper: `./build.sh [proxmox|vsphere] {ubuntu-26.04|debian-13|all|validate}` (Plattform optional, Default `proxmox`).
- `build.sh` braucht die Credentials-Datei: `credentials.pkrvars.hcl` (Proxmox) bzw. `credentials-vsphere.pkrvars.hcl` (vSphere). Beide gitignored → aus der `.example` kopieren.

## Vor jedem Commit

```bash
packer fmt -recursive .
./build.sh validate
shellcheck scripts/*.sh *.sh
```

## Architektur

- Eine parametrisierte Source pro Plattform (`source.pkr.hcl` = proxmox-iso, `source-vsphere.pkr.hcl` = vsphere-iso); OS-Auswahl über `-var-file` aus `os_pkrvars/<os>/`.
- HTTP-IP-Override: Proxmox nutzt `http_bind_address`, vSphere `http_ip` — beide gespeist aus `var.http_ip` (für Build-Hosts mit mehreren NICs).
- Weiteres OS hinzufügen: siehe @CONTRIBUTING.md
