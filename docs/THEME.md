# NovaOS Theme System

NovaOS ships a complete 3-layer theme built on top of KDE Plasma 6 + SDDM + KWin.
This document describes how each layer works and how to customize it.

## Layer 1: Boot / welcome screen

**File**: `airootfs/usr/share/sddm/themes/novaos/Main.qml` (state `"welcome"`)

### How it works

The SDDM theme's `Main.qml` is a single QML file with two visual states: `welcome`
and `login`. On startup, `state = "welcome"`. After `welcomeMs` (default 2200 ms),
a `Timer` switches to `state = "login"`. Clicking anywhere also advances.

### Visual elements

1. **Background**: a `Rectangle` with a vertical 3-stop gradient
   (`#0F0C29` → `#302B63` → `#24243E`).
2. **Two floating orbs**: large `Item`s containing radial-gradient `Rectangle`s
   with infinite `NumberAnimation` on `x` and `y` (different durations create
   a parallax effect).
3. **Noise canvas**: a `Canvas` that draws ~1200 small white dots at random
   positions on every paint, with a 4-second opacity pulse.
4. **Logo mark**: a rounded `Rectangle` with a `DropShadow`, containing the
   letter "N" in white. A second `Rectangle` behind it pulses outward.
5. **Welcome headline + submessage**: `Text` elements fading in over 600 ms.
6. **Spinner**: a `Rectangle` with a `RotationAnimation` masked to look like
   an arc.

### Customization

| Want | Edit |
|---|---|
| Welcome text | `theme.conf` → `welcomeMessage`, `welcomeSubmessage` |
| Duration | `theme.conf` → `welcomeDurationMs` |
| Colors | `theme.conf` → `backgroundStart/Mid/End`, `accent` |
| Logo letter | `Main.qml` → search for `text: "N"` |
| Disable welcome layer | set `welcomeDurationMs=0` in `theme.conf` |

## Layer 2: Login / password screen

**File**: same `Main.qml`, state `"login"`

### Visual elements

1. **Glass panel**: a `Rectangle` (440×520, radius 24, opacity 0.65) with:
   - A translucent white border (`Qt.rgba(1,1,1,0.18)`)
   - A `MultiEffect` for drop shadow
   - A second `Rectangle` inside for the dark tint
   - An entrance scale animation (0.92 → 1.0 with `OutBack` easing)

2. **Logo + brand**: a small version of the Layer-1 logo + "NovaOS" text.

3. **Username field**: `TextField` with a custom `background` that animates
   border color on focus (transparent → violet over 200 ms).

4. **Password field**: same as username, plus:
   - A focus ring `Rectangle` outside the field that fades in on focus.
   - A "Show password" `Switch` toggling `echoMode` between `Password` and `Normal`.

5. **Session selector**: `ComboBox` populated by SDDM's `sessionModel`.

6. **Sign in button**: `Button` with a horizontal gradient background
   (violet → cyan), 120 ms opacity pulse on hover, and a 3-second `SequentialAnimation`
   on `scale` for an idle "breathing" effect.

7. **Power row**: three custom `PowerButton` components (suspend / restart / shut down),
   each calling `sddm.suspend()`, `sddm.reboot()`, `sddm.powerOff()`.

8. **Clock**: a row at the bottom of the screen with a large 48 px time and a
   smaller date. Updated every 30 seconds via `Timer`.

9. **User list** (optional, left side): a `ListView` of available users with
   first-letter avatars.

### Customization

| Want | Edit |
|---|---|
| Glass opacity | `theme.conf` → `glassOpacity` |
| Glass blur | `theme.conf` → `glassBlur` |
| Corner radius | `theme.conf` → `glassRadius` |
| Hide user list | `theme.conf` → `showUserList=false` |
| Clock format | `theme.conf` → `clockFormat` (e.g. `HH:mm:ss`) |
| Accent color | `theme.conf` → `accent` (hex color) |
| Disable animations | `theme.conf` → `animationEnabled=false` |

## Layer 3: Desktop

### Animated wallpaper

**File**: `airootfs/usr/share/wallpapers/NovaOS/contents/ui/main.qml`

Procedural QML wallpaper:
- Reads `new Date().getHours()` to pick one of 4 palettes (`night`/`morning`/`noon`/`evening`).
- Renders a 3-stop vertical gradient.
- Two large floating orbs (radial-gradient circles) drifting in opposite directions.
- A `Canvas` with 24 lines radiating from center, slowly rotating.
- A `Timer` triggers a re-paint every 15 minutes to update the palette.

To use a static image instead:
1. Drop your image at `airootfs/usr/share/wallpapers/NovaOS/contents/images/1920x1080.png`.
2. Edit `theme.json` and set `WallpaperPath=/usr/share/wallpapers/NovaOS/contents/images/1920x1080.png`.

### Plasma look-and-feel

**Files**:
- `airootfs/usr/share/plasma/look-and-feel/novaos/metadata.json` (package metadata)
- `airootfs/usr/share/plasma/look-and-feel/novaos/contents/layouts/org.kde.plasma.desktop-layout.js`
  (panel layout)
- `airootfs/usr/share/plasma/desktoptheme/novaos/colors` (color scheme override)
- `airootfs/usr/share/plasma/desktoptheme/novaos/theme.json` (panel opacity / radius)

### KWin window decoration

**File**: `airootfs/usr/share/kwin/decorations/novaos/contents/ui/Aurora.qml`

Custom KWin decoration that renders:
- A `Rectangle` background with adaptive opacity (96% active, 72% inactive).
- A `DropShadow` for window shadow.
- A title bar with app icon, title text, and 3 window buttons.
- Each button is a custom `WindowButton` component with hover color animation.

### Color scheme

**File**: `airootfs/usr/share/color-schemes/NovaOS.colors`

Standard KDE color scheme file (INI format) defining colors for:
- `Button`, `Selection`, `View`, `Tooltip`, `Window`, `Complementary` categories.
- Each has: `BackgroundNormal`, `BackgroundAlternate`, `DecorationFocus`, `DecorationHover`,
  `ForegroundNormal`, `ForegroundActive`, etc.
- Accent is `124,77,255` (= `#7C4DFF`).

### Icons

NovaOS uses the **Papirus** icon theme as a base (pre-installed in `packages.x86_64`)
with the **novaos-start-here** application icon overridden at
`airootfs/usr/share/icons/novaos/` (TBD — currently falls back to Papirus).

### Cursors

**Bibata Modern Classic** is pre-installed and configured as the default in:
- `airootfs/etc/sddm.conf.d/novaos.conf` → `CursorTheme=Bibata-Modern-Classic`
- `airootfs/etc/skel/.config/kdeglobals` → `[Icons]` section

## How the look-and-feel is applied

1. On ISO build, `customize_airootfs.sh` writes `/etc/skel/.config/kdeglobals`,
   `plasmarc`, and `kwinrc` with the NovaOS defaults.
2. When the live user `novaos` logs in, `/etc/skel/*` is copied to `/home/novaos/`.
3. SDDM reads `/etc/sddm.conf.d/novaos.conf` → `Current=novaos` → loads our theme.
4. Plasma reads `kdeglobals` → `LookAndFeelPackage=novaos` → applies our look-and-feel.
5. KWin reads `kwinrc` → `library=org.kde.novaos` → loads our decoration.

## Modifying the theme live

Once booted into NovaOS:

```sh
# Edit the SDDM theme
sudo nano /usr/share/sddm/themes/novaos/Main.qml
sudo systemctl restart sddm

# Edit the KWin decoration
sudo nano /usr/share/kwin/decorations/novaos/contents/ui/Aurora.qml
qdbus org.kde.KWin /KWin reconfigure

# Edit the wallpaper
sudo nano /usr/share/wallpapers/NovaOS/contents/ui/main.qml
# (will reload on next wallpaper refresh)
```

To package your changes back into the ISO build, copy the modified files back
into the `airootfs/` tree in your local clone, commit, and push.
