# Contributing to NovaOS

Thanks for your interest in NovaOS! This document describes how to contribute.

## Project layout

See [`README.md`](../README.md) for the full tree. The key directories:

- `airootfs/` — files copied verbatim into the ISO's root filesystem
- `packages.x86_64` — list of packages to install (one per line)
- `profiledef.sh` — archiso profile metadata
- `.github/workflows/` — CI workflows (build, validate, auto-fix)
- `scripts/auto_fix.py` — the self-healing log analyzer

## Development workflow

### 1. Clone + branch

```sh
git clone https://github.com/salom600/osd.git
cd osd
git checkout -b feature/my-feature
```

### 2. Make changes

For most changes (themes, scripts, configs), edit files under `airootfs/`. For
package list changes, edit `packages.x86_64`.

### 3. Validate locally

```sh
# Syntax check
bash -n profiledef.sh
bash -n airootfs/root/customize_airootfs.sh
for s in airootfs/usr/bin/novaos-*; do bash -n "$s"; done
python3 -m py_compile scripts/auto_fix.py
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-iso.yml'))"
```

### 4. Test build locally (Arch host)

```sh
sudo mkarchiso -v -w ./work -o ./out .
```

If you don't have an Arch host, push to a branch and let GitHub Actions build it.
The `test-build.yml` workflow runs fast validation on every PR.

### 5. Commit + push + open PR

```sh
git add -A
git commit -m "feat: my new feature"
git push origin feature/my-feature
# Open a PR on GitHub
```

## Coding standards

### Bash scripts (`airootfs/usr/bin/novaos-*`)

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Use `log()` / `err()` helpers for consistent output.
- Prefer `command -v foo` over `which foo`.
- Always check for dependencies before using them.

### QML files (themes)

- Use `import QtQuick 2.15` (NOT 2.16+ — not all Qt versions ship it).
- Use `readonly property` for constants.
- Animate with `Behavior on ...` for property transitions.
- Always provide a fallback for missing config values.

### Python (`scripts/auto_fix.py`)

- Python 3.12+, stdlib + `requests` only.
- All fixers must be **idempotent** — running twice must not corrupt files.
- Never edit `.github/workflows/`, `scripts/auto_fix.py`, or any file under
  `.git/` (the LLM fallback enforces this).

## Adding a new package

1. Edit `packages.x86_64` — add the package name on its own line.
2. If the package needs configuration, add it under `airootfs/etc/` or
   `airootfs/usr/share/`.
3. If the package needs to be enabled as a systemd service, add a symlink in
   `airootfs/etc/systemd/system/multi-user.target.wants/` (or
   `graphical.target.wants/`).
4. Test the build.

## Adding a new auto-fix rule

See [`docs/BUILD.md`](BUILD.md#adding-a-new-auto-fix-rule) for the full guide.

## Reporting bugs

Open an issue at https://github.com/salom600/osd/issues with:

1. NovaOS version (`cat /etc/os-release`)
2. Hardware (CPU, GPU, Wi-Fi card)
3. What you expected vs. what happened
4. Logs (run `novaos-doctor` and paste the output; or attach
   `journalctl -b -p err --no-pager` output)

## Code of conduct

Be excellent to each other. Disagreements are fine; personal attacks are not.
