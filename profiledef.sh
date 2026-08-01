#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# NovaOS - profile definition for archiso / mkarchiso
# Defines ISO metadata, file permissions, and boot modes.
#

export iso_name="novaos"
export iso_label="NOVAOS_$(date +%Y%m)"
export iso_publisher="NovaOS Project <https://github.com/salom600/osd>"
export iso_application="NovaOS Live/Install ISO"
export iso_version="$(date +%Y.%m.%d)"
export install_dir="novaos"
export buildmodes=("iso")
# Boot modes - use the new (non-deprecated) names:
#   bios.syslinux         (replaces bios.syslinux.mbr + bios.syslinux.eltorito)
#   uefi.systemd-boot     (replaces uefi-x64.systemd-boot.esp + uefi-x64.systemd-boot.eltorito)
# Requires: syslinux, edk2-shell, memtest86+-efi in packages.x86_64
export bootmodes=("bios.syslinux" "uefi.systemd-boot")

# Filesystems and architecture
export arch="$(uname -m)"
export pacman_conf="pacman.conf"
export airootfs_image_tool_type="squashfs"
export airootfs_image_type="squashfs"
export airootfs_imageCompression="xz"
export airootfs_image_xz_options="-Xbcj x86 -T0"

# Bundle file permissions for things archiso cannot infer
declare -A file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:400"
    ["/root"]="0:0:750"
    ["/root/.automated_script.sh"]="0:0:755"
    ["/root/customize_airootfs.sh"]="0:0:755"
    ["/usr/bin/novaos-welcome"]="0:0:755"
    ["/usr/bin/novaos-store"]="0:0:755"
    ["/usr/bin/novaos-wine-launcher"]="0:0:755"
    ["/usr/bin/novaos-firstboot"]="0:0:755"
    ["/usr/bin/novaos-installer"]="0:0:755"
    ["/usr/bin/novaos-update"]="0:0:755"
    ["/usr/bin/novaos-doctor"]="0:0:755"
    ["/usr/share/novaos/scripts/"]="0:0:755"
)
