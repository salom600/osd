#!/usr/bin/env bash
#
# NovaOS - airootfs customization script
# Executed by archiso (mkarchiso) inside the chroot after packages are
# installed but before the squashfs image is generated.
#
# This script:
#   1. Sets hostname, locale, timezone
#   2. Enables systemd services
#   3. Creates the `novaos` user (UID 1000) for the live ISO
#   4. Installs NovaOS artwork + Calamares installer config
#   5. Configures SDDM theme + Plasma 6 look-and-feel
#   6. Pre-builds the initramfs with the right hooks
#   7. Cleans up to keep the ISO small
#
set -euo pipefail

echo "============================================================"
echo "  NovaOS - customize_airootfs.sh starting"
echo "============================================================"

# ---- 1. Locale + timezone ----
echo ">>> Generating locales..."
locale-gen

echo ">>> Setting timezone to Africa/Lagos..."
ln -sf /usr/share/zoneinfo/Africa/Lagos /etc/localtime

# ---- 2. Hostname + machine-id ----
echo "novaos" > /etc/hostname
systemd-tmpfiles --create --purge --root=/ >/dev/null 2>&1 || true
# Generate a stable machine-id for the live image
systemd-machine-id-setup --root=/ >/dev/null 2>&1 || true

# ---- 3. Create live user `novaos` ----
echo ">>> Creating live user 'novaos' (UID 1000)..."
# Create the 'autologin' group if it doesn't exist (needed for SDDM auto-login)
if ! getent group autologin >/dev/null 2>&1; then
    groupadd --system autologin 2>/dev/null || true
fi
if ! id novaos >/dev/null 2>&1; then
    useradd -m -G wheel,storage,optical,power,video,audio,input,network,lp,autologin -s /bin/bash -u 1000 novaos
    # Default live password is "novaos" - users change on first boot
    echo 'novaos:novaos' | chpasswd
    echo 'root:novaos'   | chpasswd
fi

# Make sure the live user's home directory exists and is owned correctly
install -d -m 0750 -o novaos -g novaos /home/novaos
# Copy skel to /home/novaos (skeleton: KDE Plasma config + NovaOS theme)
if [ -d /etc/skel ]; then
    cp -aT /etc/skel /home/novaos/ 2>/dev/null || true
    chown -R novaos:novaos /home/novaos
fi

# ---- 4. Enable systemd services ----
echo ">>> Enabling systemd services..."
systemctl enable NetworkManager.service          2>/dev/null || true
systemctl enable sddm.service                    2>/dev/null || true
systemctl enable bluetooth.service               2>/dev/null || true
systemctl enable cups.service                    2>/dev/null || true
systemctl enable apparmor.service                2>/dev/null || true
systemctl enable systemd-timesyncd.service       2>/dev/null || true
systemctl enable systemd-resolved.service        2>/dev/null || true
systemctl enable tlp.service                     2>/dev/null || true
systemctl enable reflector.timer                 2>/dev/null || true
systemctl enable paccache.timer                  2>/dev/null || true
systemctl enable firewalld.service               2>/dev/null || true
systemctl enable snapd.service                   2>/dev/null || true
systemctl enable haveged.service                 2>/dev/null || true
systemctl enable NovaOS-Firstboot.service        2>/dev/null || true

# Disable services that conflict with NetworkManager
systemctl disable systemd-networkd.service       2>/dev/null || true
systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true

# ---- 5. Configure SDDM ----
echo ">>> Configuring SDDM..."
mkdir -p /etc/sddm.conf.d
# Theme is set in /etc/sddm.conf.d/novaos.conf (already in airootfs)

# ---- 6. Apply Plasma 6 look-and-feel globally ----
echo ">>> Setting global Plasma look-and-feel to NovaOS..."
LOOK_AND_FEEL_DIR=/usr/share/plasma/look-and-feel
if [ -d "${LOOK_AND_FEEL_DIR}/novaos" ]; then
    # Apply system-wide default for new users
    mkdir -p /etc/skel/.config
    cat > /etc/skel/.config/kdeglobals <<'EOF'
[KDE]
LookAndFeelPackage=novaos
WidgetStyle=Breeze
ColorScheme=NovaOS

[Icons]
Theme=novaos

[General]
ColorScheme=NovaOS
Name=NovaOS
XftAntialias=true
XftHintStyle=hintslight
XftSubPixel=rgb

[WM]
activeBackground=124,77,255
activeForeground=255,255,255
inactiveBackground=30,30,46
inactiveForeground=180,180,200
EOF

    cat > /etc/skel/.config/plasmarc <<'EOF'
[Theme]
name=novaos

[Wallpapers]
UsersWallpapers=/usr/share/wallpapers
EOF

    cat > /etc/skel/.config/kwinrc <<'EOF'
[org.kde.kdecoration2]
library=org.kde.novaos
theme=NovaOS

[Windows]
BorderlessMaximizedWindows=true

[Effect-blur]
BlurStrength=15
NoiseStrength=5

[Effect-wobblywindows]
Drag=85
Stiffness=8.5
WobblynessLevel=2

[Effect-magnifier]
InitialZoom=1.0

[Effect-scale]
Duration=400

[Effect-fade]
Duration=180

[Effect-blur]
Enabled=true

[Effect-glide]
Duration=180

[Effect-squash]
Duration=180

[Compositing]
Backend=OpenGL
GLColorCorrection=true
GLCore=true
GLPreferBufferSwap=a/a
HiddenPreviews=5
OpenGLIsUnsafe=false
AnimationSpeed=2
WindowsBlockCompositing=false
EOF
fi

# ---- 7. Initramfs hooks ----
echo ">>> Configuring mkinitcpio for NovaOS..."
# Patch /etc/mkinitcpio.conf to include NovaOS-friendly hooks
if [ -f /etc/mkinitcpio.conf ]; then
    sed -i 's|^HOOKS=.*|HOOKS=(base udev archiso modconf kms keyboard keymap consolefont block filesystems fsck resume)|' /etc/mkinitcpio.conf
fi

# Regenerate all initramfs images (linux + linux-lts if present)
echo ">>> Regenerating initramfs..."
mkinitcpio -P 2>&1 | tail -20 || true

# ---- 8. Install Calamares branding (if config exists) ----
echo ">>> Setting up Calamares installer..."
if [ -d /etc/calamares ]; then
    # Branding is shipped at /usr/share/calamares/branding/novaos
    # Configs ship at /etc/calamares/
    if [ -f /etc/calamares/settings.conf ]; then
        sed -i 's|branding:.*|branding: novaos|' /etc/calamares/settings.conf 2>/dev/null || true
    fi
fi

# Make the Calamares desktop file visible on the live desktop
if [ -f /usr/share/applications/calamares.desktop ]; then
    install -d -m 0755 /home/novaos/Desktop
    cp /usr/share/applications/calamares.desktop /home/novaos/Desktop/ 2>/dev/null || true
    chown novaos:novaos /home/novaos/Desktop/calamares.desktop 2>/dev/null || true
fi

# ---- 9. Install NovaOS utilities to /usr/bin (already in airootfs/usr/bin) ----
echo ">>> Ensuring NovaOS utilities are executable..."
chmod 0755 /usr/bin/novaos-* 2>/dev/null || true
chmod 0755 /usr/share/novaos/scripts/*.sh 2>/dev/null || true

# ---- 10. Flatpak: add Flathub remote ----
echo ">>> Adding Flathub remote for Flatpak..."
if command -v flatpak >/dev/null 2>&1; then
    flatpak remote-add --if-not-exists --system flathub \
        https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
fi

# ---- 11. Tidy pacman cache (keep only the latest versions) ----
echo ">>> Cleaning pacman cache..."
# Keep only the latest version of each cached package
paccache -rk1 --cachedir /var/cache/pacman/pkg 2>/dev/null || true
# Remove orphaned cache files
rm -f /var/cache/pacman/pkg/*.part 2>/dev/null || true

# ---- 12. Remove heavy docs / manpages to slim the ISO ----
echo ">>> Trimming docs to slim the ISO..."
# Keep man pages (useful), but strip locale-specific man pages we don't ship
find /usr/share/man/ -mindepth 1 -maxdepth 1 -type d ! -name 'man*' -exec rm -rf {} + 2>/dev/null || true
# Strip info pages
rm -rf /usr/share/info/* 2>/dev/null || true

# ---- 13. Final permissions ----
echo ">>> Setting final permissions..."
chmod 0440 /etc/sudoers.d/* 2>/dev/null || true
chmod 0644 /etc/os-release 2>/dev/null || true
chmod 0755 /etc/novaos 2>/dev/null || true

# Make sure /etc/shadow and /etc/gshadow are restricted
chmod 0400 /etc/shadow /etc/gshadow 2>/dev/null || true

# ---- 14. NovaOS motd + issue ----
cat > /etc/motd <<'EOF'

  ███╗   ██╗ ██████╗  ██████╗ ███╗   ██╗███████╗████████╗
  ████╗  ██║██╔═══██╗██╔═══██╗████╗  ██║██╔════╝╚══██╔══╝
  ██╔██╗ ██║██║   ██║██║   ██║██╔██╗ ██║█████╗     ██║
  ██║╚██╗██║██║   ██║██║   ██║██║╚██╗██║██╔══╝     ██║
  ██║ ╚████║╚██████╔╝╚██████╔╝██║ ╚████║███████╗   ██║
  ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝

  Welcome to NovaOS 2026 "Aurora" (Arch-based, KDE Plasma 6)
  - Live user:  novaos   Password: novaos
  - Root user:  root     Password: novaos
  - To install NovaOS to disk:  click "Install NovaOS" on the desktop
  - Need help?  https://github.com/salom600/osd/issues

EOF

cat > /etc/issue <<'EOF'
NovaOS 2026 "Aurora" (x86_64)
Live user: novaos / novaos   |   root / novaos
Type `startx` to launch Plasma, or `sudo systemctl start sddm`.
EOF

echo "============================================================"
echo "  NovaOS - customize_airootfs.sh complete"
echo "============================================================"
