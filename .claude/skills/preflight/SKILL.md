---
name: preflight
description: Pre-Commit-Checks für vm-factory in einem Lauf — packer fmt, build.sh validate, shellcheck. Vor jedem Commit ausführen.
---

Führe die Pre-Commit-Prüfungen dieses Repos aus, jede einzeln, und melde Ergebnisse zusammengefasst.

1. **Format:** `packer fmt -recursive .` — formatiert alle HCL-Dateien. Wenn Dateien geändert wurden, die geänderten nennen.
2. **Validate:** `./build.sh validate` — prüft beide OS-Konfigurationen (Proxmox). Für vSphere zusätzlich `./build.sh vsphere validate`, falls vSphere-Änderungen betroffen sind.
3. **Shellcheck:** `shellcheck scripts/*.sh *.sh` — prüft alle Bash-Skripte.

Voraussetzung: `packer init .` muss gelaufen sein (Plugins) und die Credentials-Datei (`credentials.pkrvars.hcl`) muss existieren, sonst bricht `build.sh validate` ab.

Bei Fehler: exakte Ausgabe zitieren, nicht beschönigen. Erst nach grünem Durchlauf zum Commit raten.
