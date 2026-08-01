# NovaOS Architecture

## High-level overview

NovaOS is built in three layers, mirroring the upstream Arch + KDE stack:

```
┌─────────────────────────────────────────────────────────────────────┐
│  NovaOS Layer (themes, branding, utilities, firstboot, store)      │
├─────────────────────────────────────────────────────────────────────┤
│  KDE Plasma 6 (KWin, Plasma Workspace, SDDM, KDE Gear apps)        │
├─────────────────────────────────────────────────────────────────────┤
│  Arch Linux userspace (pacman, systemd, NetworkManager, pipewire)   │
├─────────────────────────────────────────────────────────────────────┤
│  Linux kernel + linux-firmware (full HW support: AMD/NV/Intel)     │
└─────────────────────────────────────────────────────────────────────┘
```

## Build pipeline

```
git push ──▶ GitHub Actions ──▶ archlinux:latest container
                                     │
                                     ├── pacman -Sy archiso
                                     ├── reflector (pick fastest mirrors)
                                     ├── mkarchiso
                                     │     ├── pacstrap (install packages)
                                     │     ├── copy airootfs/* overlay
                                     │     ├── chroot + customize_airootfs.sh
                                     │     ├── squashfs (xz compression)
                                     │     └── xorriso (build bootable ISO)
                                     │
                                     └── upload novaos-*.iso as artifact

                       On failure ──▶ auto-fix.yml
                                     ├── download failed run logs
                                     ├── scripts/auto_fix.py (rules + LLM)
                                     ├── commit + push fix
                                     └── re-trigger build-iso.yml
```

## The 3-layer theme system

### Layer 1: Boot / welcome

- **Component**: SDDM theme, `Main.qml`, state `"welcome"`
- **Visual**: animated multi-stop gradient (`#0F0C29 → #302B63 → #24243E`)
  with two floating radial-gradient orbs (violet + cyan), a pulsing logo mark,
  welcome headline, submessage, and an animated circular spinner.
- **Duration**: 2200 ms, then auto-advances to Layer 2. Click anywhere to skip.
- **Asset-free**: rendered entirely in QML, no PNG/JPG dependencies.

### Layer 2: Login / password

- **Component**: SDDM theme, `Main.qml`, state `"login"`
- **Visual**: a 440×520 glass panel (radius 24, opacity 0.65, KWin blur enabled)
  containing the username + password fields, session selector, "Sign in" button,
  and a row of power controls (suspend / restart / shut down).
- **Animations**:
  - 250 ms ColorAnimation on input focus border (transparent → `#7C4DFF`)
  - 250 ms opacity fade-in on focus ring around password field
  - 120 ms opacity pulse on Sign in button hover
  - Horizontal shake on auth failure
- **User list**: optional left-side list of available users (with first-letter avatars).

### Layer 3: Desktop

- **Component**: KDE Plasma 6 with the `novaos` look-and-feel package
- **Wallpaper**: `NovaOS/contents/ui/main.qml` — procedural animated wallpaper:
  - Multi-stop gradient that shifts based on time of day (4 palettes)
  - Two large floating orbs (slow drift, 60-90 second loops)
  - Faint rotating geometric pattern overlay
- **Panel**: bottom-positioned, full-width, height 56 px, floating (8 px margin),
  72% opacity, KWin blur behind.
  - Left:   Application Launcher (start menu, "novaos-start-here" icon)
  - Center: Task manager (icons only, modern Win11 look)
  - Right:  System tray (Network, Bluetooth, Volume, Battery, ...), digital clock
- **Window decoration**: `kwin/decorations/novaos/contents/ui/Aurora.qml`
  - 14 px rounded corners
  - Adaptive opacity: 96% when active, 72% when inactive
  - Violet accent border on active window
  - Drop shadow (6 px y-offset, 28 px blur)
  - Title bar: app icon + title on left, 3 buttons on right (min/max/close)

## Resource budget

Tuned via `kwinrc` + `plasmarc` + `sddm.conf`:

| Setting | Value | Effect |
|---|---|---|
| `AnimationSpeed=2` | medium-fast | snappy without being jarring |
| `BlurStrength=15` | medium | glass effect without GPU thrash |
| `NoiseStrength=5` | minimal | subtle texture, no overhead |
| `wobblywindowsEnabled=true` | on | lightweight |
| `fallapartEnabled=false` | off | saves GPU |
| `magnifierEnabled=false` | off | saves CPU |
| `Backend=OpenGL` | hardware accel | required for blur |
| `GLCore=true` | modern path | better driver compat |
| `HiddenPreviews=5` | keep all | smooth alt-tab without memory bloat |

## Services enabled on the live ISO

- `NetworkManager` — Wi-Fi + Ethernet
- `sddm` — display manager (graphical target)
- `bluetooth` — BT stack
- `cups` — printing
- `apparmor` — MAC security
- `tlp` — power management (laptops)
- `firewalld` — firewall
- `snapd` — Snap support
- `haveged` — entropy
- `reflector.timer` — weekly mirror refresh
- `paccache.timer` — weekly cache cleanup
- `NovaOS-Firstboot.service` — one-shot post-install wizard

## NovaOS-Firstboot wizard

Runs once on first boot of an installed system:

1. Refresh pacman mirrorlist via `reflector` (pick 20 fastest HTTPS mirrors)
2. Update `archlinux-keyring` + run `pacman -Su`
3. Add Flathub Flatpak remote
4. Detect timezone via GeoIP (`ipapi.co/timezone/`), fallback `Africa/Lagos`
5. Rebuild initramfs (in case kernel updated)
6. **Security hardening**: replace passwordless wheel sudo with password-required sudo
7. Mark itself complete in `/var/lib/novaos/.firstboot-complete`
8. Disable itself

## App store (NovaOS Store)

`novaos-store` is a thin launcher around Plasma Discover, with:

- pacman backend (system packages)
- Flatpak backend (Flathub, sandboxed)
- AUR (via `yay` or `paru` if installed)
- Snap (via `snapd`)

On first launch, it ensures Flathub is configured and shows a desktop notification.

## Windows program support

`novaos-wine-launcher` is a wrapper that:

1. Detects whether `wine` or `bottles` is installed.
2. If neither: shows a desktop notification with install instructions.
3. Otherwise: launches the `.exe` via Bottles (preferred — better prefix isolation)
   or directly via `wine` as a fallback.
4. Right-click any `.exe` in Dolphin → "Open with NovaOS Wine Launcher" (via the
   `.desktop` file's `MimeType=application/x-ms-dos-executable`).

## Security model

| Layer | Mechanism |
|---|---|
| Live ISO | passwordless sudo for `wheel` group (convenience) |
| Installed | `novaos-firstboot` enforces password sudo for `wheel` |
| Network | `firewalld` enabled by default (zone `public`) |
| Sandboxing | Flatpak app store + Firejail (optional) |
| MAC | AppArmor enabled, profiles loaded |
| Updates | `novaos-update` weekly mirror refresh + system upgrade |

## Auto-fix system

See `docs/BUILD.md` for the full auto-fix flow.
