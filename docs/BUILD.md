# Building NovaOS

## Prerequisites

### Local build (Arch Linux host)

```sh
sudo pacman -S archiso git
```

Disk space: ~5 GB free in `/tmp` (or wherever you point `work/`).

### GitHub Actions build

No prerequisites — the workflow uses an `archlinux:latest` Docker container
with `--privileged` to run `mkarchiso`. Just push to `main`.

## Local build

```sh
git clone https://github.com/salom600/osd.git
cd osd

# Optional: build the local [novaos] repo (currently empty)
mkdir -p /tmp/novaos-repo/x86_64
cd /tmp/novaos-repo/x86_64
repo-add novaos.db.tar.gz
cd -

# Build the ISO (sudo needed for pacstrap, mount, mksquashfs)
sudo mkarchiso -v -w ./work -o ./out .

# Result:
ls -la out/
#   novaos-<version>-x86_64.iso
#   novaos-<version>-x86_64.iso.sha256  (only on CI; locally run sha256sum yourself)
```

### Common local build issues

| Symptom | Fix |
|---|---|
| `error: target not found: <pkg>` | the package was renamed/removed upstream; remove it from `packages.x86_64` |
| `invalid or corrupted package (PGP signature)` | `sudo pacman -Sy archlinux-keyring && sudo pacman-key --populate archlinux` |
| `No space left on device` | the squashfs is huge; trim heavy packages from `packages.x86_64` |
| slow build / slow mirrors | `sudo reflector --country us,gb,de --age 12 --protocol https --sort rate --number 20 --save /etc/pacman.d/mirrorlist` |

## GitHub Actions build

### Triggering

- **Push to `main`**: triggers `build-iso.yml` automatically.
- **Tag push (`v*`)**: same build, plus a GitHub Release is created with the ISO attached.
- **Manual**: Actions tab → "Build NovaOS ISO" → "Run workflow".

### Outputs

- **Artifact**: `novaos-iso-<run-id>` — the ISO + SHA256, retained 14 days.
- **Build logs**: `novaos-build-logs-<run-id>` — full `mkarchiso.log`, retained 30 days.
- **Release** (on tag): `https://github.com/salom600/osd/releases/tag/v*`.

### Downloading artifacts

```sh
# Requires `gh` CLI (or use the web UI)
gh run download <run-id> --repo salom600/osd --name novaos-iso-<run-id>
```

## Customizing the build

### Add a package

Edit `packages.x86_64` — add one package per line (no comments after the package name).
Run `.github/workflows/test-build.yml` locally to validate:

```sh
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test-build.yml'))"
bash -n profiledef.sh
```

### Change the wallpaper

Replace `airootfs/usr/share/wallpapers/NovaOS/contents/ui/main.qml` with your own
QML wallpaper, or drop a static image at `airootfs/usr/share/wallpapers/NovaOS/contents/images/1920x1080.png`
and update `theme.json` to point to it.

### Change the accent color

Edit `airootfs/usr/share/color-schemes/NovaOS.colors` and the `cAccent` property
in `airootfs/usr/share/sddm/themes/novaos/Main.qml`. The accent is `#7C4DFF` (violet).

### Change the desktop layout

Edit `airootfs/usr/share/plasma/look-and-feel/novaos/contents/layouts/org.kde.plasma.desktop-layout.js`
to add/remove panel applets.

## Auto-fix system

The auto-fix system is the self-healing layer. When `build-iso.yml` fails:

1. `auto-fix.yml` triggers automatically (via the `workflow_run` event).
2. It downloads the failed run's logs + the `novaos-build-logs-*` artifact.
3. `scripts/auto_fix.py` runs against the combined log:
   - **Rule-based fixers** handle common patterns (missing package, keyring error,
     QML import version, disk space, [novaos] repo not built).
   - If no rule matches, the script calls the **ZAI LLM** (GLM-4.6) to suggest a
     find/replace edit. Set `ZAI_API_KEY` as a repo secret to enable this.
4. The fix is committed as `auto-fix: <sha> attempt N/5 - <summary>` and pushed.
5. The build is re-triggered via the GitHub API.
6. **Retry budget**: max 5 attempts per commit SHA. After that, an issue is filed.

### Adding a new auto-fix rule

Edit `scripts/auto_fix.py` and add a new `Fixer` to the `RULES` list:

```python
Fixer(
    name="my-fix",
    description="what it does",
    pattern=re.compile(r"some error pattern", re.IGNORECASE),
    apply=lambda m, root: my_fix_function(m, root),
),
```

The `apply` function receives the regex match and the repo root Path, and must
return a list of edited file paths (strings). It should be idempotent — running
it twice should not corrupt the file.

### Setting the ZAI LLM key (optional, for LLM-based fixes)

```sh
gh secret set ZAI_API_KEY --repo salom600/osd --body "your-zai-api-key"
```

If `ZAI_API_KEY` is not set, the LLM fallback is skipped silently.

## Debugging a failed build

1. Go to the Actions tab.
2. Click the failed run.
3. Download the `novaos-build-logs-<run-id>` artifact — it contains `mkarchiso.log`.
4. The auto-fix workflow's "Analyze logs and apply fix" step also prints which
   rule matched (if any).
5. To re-trigger auto-fix manually:
   - Actions → "Auto-Fix Failed Build" → "Run workflow" → enter the run ID.
