# NovaOS 2026 "Aurora"

<p align="center">
  <strong>A modern, lightweight Linux distribution built on Arch Linux + KDE Plasma 6.</strong><br/>
  Glassmorphism desktop, animated 3-layer login, integrated app store, one-click Windows program support.
</p>

<p align="center">
  <a href="https://github.com/salom600/osd/actions/workflows/build-iso.yml">
    <img alt="Build ISO" src="https://github.com/salom600/osd/actions/workflows/build-iso.yml/badge.svg" />
  </a>
  <a href="https://github.com/salom600/osd/actions/workflows/test-build.yml">
    <img alt="Validate" src="https://github.com/salom600/osd/actions/workflows/test-build.yml/badge.svg" />
  </a>
  <a href="https://github.com/salom600/osd/actions/workflows/auto-fix.yml">
    <img alt="Auto-Fix" src="https://github.com/salom600/osd/actions/workflows/auto-fix.yml/badge.svg" />
  </a>
</p>

---

## What is NovaOS?

NovaOS is a custom Linux distribution built from scratch using **Arch Linux** as the base
and **KDE Plasma 6** as the desktop environment, with a deeply customized glassmorphism theme
inspired by Windows 11 and macOS. It is built entirely via GitHub Actions — every push to
`main` produces a fresh, bootable ISO that you can flash to a USB stick and run on real hardware.

### Why Arch + KDE Plasma 6?

| Requirement | Choice | Why |
|---|---|---|
| Avoid Ubuntu family | **Arch Linux** | Rolling, latest kernel = best 2026 hardware support |
| Lightweight but full-featured | **Arch + Plasma 6** | Plasma 6 with proper config uses ~600 MB RAM idle |
| Modern UI (no LXQt/XFCE) | **KDE Plasma 6** | Native KWin blur, animations, glass effects, custom themes |
| Support all devices | **Arch + linux + linux-firmware + DKMS** | AMD, NVIDIA, Intel 2009+, all modern Wi-Fi/BT |
| One-click app store | **Discover + Flatpak + pacman** | Curated, secure, no terminal needed |
| Run Windows programs | **Wine + Bottles** | Right-click any `.exe` → "Open with NovaOS Wine Launcher" |
| Build via CI | **archiso + GitHub Actions** | Reproducible, automatic, self-healing |

### The 3-layer NovaOS theme

NovaOS implements a three-layer visual experience, all custom-built and shipped with the ISO:

**Layer 1 — Boot/welcome screen**
The moment the ISO finishes booting and the display manager starts, the user sees an animated
welcome: a slowly drifting multi-stop gradient with floating violet/cyan orbs, the NovaOS logo,
and the words *"Welcome to NovaOS — Initializing your experience, please wait a moment."* The
welcome layer auto-advances to the login layer after ~2 seconds, or can be dismissed by clicking
anywhere. This mirrors the modern Windows 11 boot flow.

**Layer 2 — Login / password screen**
A translucent glass panel (radius 24, opacity 0.65, KWin blur enabled) hosts the username +
password fields. The panel uses adaptive opacity — when focused, the input's border transitions
to the NovaOS accent color (`#7C4DFF`) over 250 ms. A row of power controls (suspend / restart /
shut down) sits at the bottom. A large modern clock is centered at the bottom of the screen.
On authentication failure, the panel shakes horizontally (a macOS-style error cue).

**Layer 3 — Desktop**
The desktop layer is built on KDE Plasma 6 with the NovaOS Aurora look-and-feel package:
- **Animated wallpaper**: a procedural QML wallpaper that renders a multi-stop gradient with
  floating orbs and a faint rotating geometric pattern. The palette shifts with time of day
  (night / morning / noon / evening).
- **Glass bottom panel**: a floating, full-width panel at the bottom with 72% opacity and
  KWin blur behind. Contains the Application Launcher (start menu), task manager, system tray,
  and a modern digital clock.
- **Glass window decoration**: every window gets a 14 px-rounded, translucent border with
  adaptive opacity (96% when active, 72% when inactive) and a violet accent border on the
  active window.
- **Modern animations**: wobbly windows, scale-in on unminimize, glide on dialog open, blur
  on the panel and menus, and an animated cursor (Bibata Modern Classic).

### Hardware support

NovaOS bundles every driver needed for 2026-era + legacy (2009+) hardware:

- **AMD**: `amdgpu` (SI+, CIK+), `radeon` (legacy), `vulkan-radeon`, `libva-mesa-driver`
- **NVIDIA**: `nvidia-dkms` (latest), `nvidia-utils`, `lib32-nvidia-utils`, `vulkan-icd-loader`
- **Intel**: `i915` (with `fastboot`, `enable_fbc`, `enable_guc=2`), `vulkan-intel`, `intel-media-driver`
- **Wi-Fi**: `iwlwifi`-family firmware, `rtw89`, `ath11k`, `mt76`, `brcmfmac` (all in `linux-firmware`)
- **Bluetooth**: `bluez` + `bluez-utils` + `btusb`
- **Audio**: `pipewire` + `wireplumber` + `sof-firmware` (modern Sound Open Firmware)

### Resource consumption target

On a fresh boot, NovaOS targets:

| Metric | Idle (live ISO) | Idle (installed) |
|---|---|---|
| RAM | ≤ 900 MB | ≤ 650 MB |
| CPU | < 2% | < 1% |
| GPU | < 5% (compositor only) | < 3% |
| Disk | — | ≤ 9 GB base install |

## Repository structure

```
novaos/
├── .github/workflows/
│   ├── build-iso.yml         # Main ISO build (Arch container + archiso)
│   ├── auto-fix.yml          # Self-healing: analyze failure → patch → retry
│   └── test-build.yml        # Fast pre-build validation
├── airootfs/                 # Root filesystem overlay (copied into the ISO)
│   ├── etc/
│   │   ├── os-release        # NovaOS branding
│   │   ├── sddm.conf.d/      # SDDM login manager config
│   │   ├── systemd/system/   # Enabled services (NM, SDDM, BT, cups, ...)
│   │   ├── pacman.conf       # In-image pacman config (multilib enabled)
│   │   └── skel/             # Default ~/.config for new users
│   ├── root/
│   │   └── customize_airootfs.sh   # Build-time customization script
│   └── usr/
│       ├── bin/              # novaos-store, novaos-wine-launcher, novaos-doctor, ...
│       └── share/
│           ├── sddm/themes/novaos/        # Layer 1 + 2: custom QML login theme
│           ├── plasma/look-and-feel/novaos/  # Layer 3: KDE Plasma look
│           ├── plasma/desktoptheme/novaos/   # Plasma widgets + colors
│           ├── kwin/decorations/novaos/      # Glass window decoration
│           ├── color-schemes/NovaOS.colors   # System color scheme
│           ├── wallpapers/NovaOS/            # Animated wallpaper (QML)
│           └── applications/                 # Desktop entries (.desktop)
├── efiboot/                  # UEFI bootloader (systemd-boot config)
├── syslinux/                 # BIOS bootloader (syslinux config)
├── profiledef.sh             # archiso profile metadata
├── packages.x86_64           # Package list (~300 packages)
├── pacman.conf               # Build-time pacman config
├── scripts/
│   └── auto_fix.py           # Log analyzer + auto-patcher (used by auto-fix.yml)
└── docs/                     # Architecture + build docs
```

## How the build works

1. **Push to `main`** triggers `build-iso.yml`.
2. The workflow spins up an Ubuntu runner, then runs `mkarchiso` inside a `archlinux:latest`
   Docker container (with `--privileged` for loop devices + mount).
3. archiso:
   a. Bootstraps a minimal Arch root via `pacstrap`
   b. Installs every package in `packages.x86_64`
   c. Copies `airootfs/*` over the root (our customizations)
   d. Runs `customize_airootfs.sh` inside the chroot
   e. Squashes the rootfs into `airootfs.sfs` (xz-compressed)
   f. Builds a bootable ISO with GRUB (UEFI) + SYSLINUX (BIOS)
4. The resulting `novaos-*.iso` is uploaded as a GitHub Actions artifact (14-day retention).
5. On tag pushes (`v*`), a GitHub Release is created with the ISO attached.

## How auto-fix works

1. When `build-iso.yml` fails, the `workflow_run` event fires `auto-fix.yml`.
2. The auto-fix job:
   a. Downloads the failed run's logs (both the GH Actions logs ZIP and the
      `novaos-build-logs-*` artifact uploaded by the build).
   b. Concatenates every log file into one blob.
   c. Runs `scripts/auto_fix.py` against the logs.
   d. The script has a **rule registry** of common failure patterns:
      - `target not found: <pkg>` → comment the package out of `packages.x86_64`
      - keyring / PGP signature errors → inject keyring refresh in `customize_airootfs.sh`
      - `module "QtQuick.xxx" is not installed` → downgrade QML import to 2.15
      - `failed retrieving file ... novaos ... db` → disable the `[novaos]` repo in `pacman.conf`
      - `No space left on device` → trim heavy optional packages (LibreOffice, Kdenlive, ...)
   e. If no rule matches, the script calls the **ZAI LLM** (when `ZAI_API_KEY` is set) to
      suggest a one-shot find/replace edit.
   f. The fix is committed as `auto-fix: <sha> attempt N/5 - <summary>` and pushed.
3. The build workflow is re-triggered via the GitHub API.
4. **Retry budget**: maximum 5 auto-fix attempts per commit SHA. After that, an issue is filed.

## Quick start

### Build the ISO locally (Arch Linux host)

```sh
sudo pacman -S archiso
git clone https://github.com/salom600/osd.git
cd osd
sudo mkarchiso -v -w ./work -o ./out .
```

The ISO appears in `./out/novaos-*.iso`.

### Build via GitHub Actions

Just push to `main`. The build runs automatically and the ISO is published as a workflow
artifact. Tag a release (`git tag v2026.01 && git push --tags`) to attach the ISO to a
GitHub Release.

### Flash and boot

```sh
sha256sum -c novaos-*.iso.sha256       # verify
sudo dd if=novaos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
# Boot from the USB stick. Live login: novaos / novaos
# To install: double-click "Install NovaOS" on the desktop.
```

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — full system architecture
- [`docs/BUILD.md`](docs/BUILD.md) — build + customization guide
- [`docs/THEME.md`](docs/THEME.md) — how the 3-layer theme works
- [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) — how to contribute

## License

NovaOS is licensed under **AGPL-3.0-or-later**. Theme assets are dual-licensed under
CC-BY-SA-4.0 where upstream licenses require it. See [`LICENSE`](LICENSE).

## Credits

NovaOS is built on the work of thousands of upstream contributors:
[Arch Linux](https://archlinux.org), [KDE Plasma](https://kde.org/plasma-desktop),
[SDDM](https://github.com/sddm/sddm), [Calamares](https://calamares.io),
[Wine](https://www.winehq.org), [Bottles](https://usebottles.com),
[archiso](https://gitlab.archlinux.org/archlinux/archiso).
