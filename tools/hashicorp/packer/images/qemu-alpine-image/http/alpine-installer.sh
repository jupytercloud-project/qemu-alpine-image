#set -ux

TMP_SIZE="${1}"
SRV_HTTP="${2}"
ALPINE_MIRROR="${3}"

ALPINE_RELEASE="$(cat /etc/alpine-release)"
ALPINE_VERSION="v$(printf "${ALPINE_RELEASE}" | cut -d'.' -f1,2)"
APK_REPO_MAIN="${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"
APK_REPO_COMMUNITY="${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community"
APK_REPO_EDGE_COMMUNITY="${ALPINE_MIRROR}/alpine/edge/community"
APK_REPO_EDGE_TESTING="${ALPINE_MIRROR}/alpine/edge/testing"
#
# vda in packer virtual build environment
#
DISK='vda'
DISK_DEV="/dev/${DISK}"
BOOT_PART_ORDER=1
BOOT_DEV="${DISK_DEV}${BOOT_PART_ORDER}"
BOOT_LABEL='boot'
#
# not less than 18M
#
BOOT_SIZE="18M"
ROOT_PART_ORDER=2
ROOT_DEV="${DISK_DEV}${ROOT_PART_ORDER}"
ROOT_LABEL='root'
LVM_VG='alpine'
LVM_LV='slash'
LVM_ROOT="/dev/mapper/${LVM_VG}-${LVM_LV}"
GRUB_LVM_ROOT="lvm/${LVM_VG}-${LVM_LV}"
BOOT_FS="ext4"
ROOT_FS="xfs"
ROOT="/mnt"

#
# cf https://wiki.alpinelinux.org/wiki/Install_to_disk
#

function install_setup_dependencies {
  #
  # setup the apk repositories file
  #
  printf "%s\n%s\n%s\n%s\n"      \
    "${APK_REPO_MAIN}"           \
    "${APK_REPO_COMMUNITY}"      \
    "${APK_REPO_EDGE_COMMUNITY}" \
    "${APK_REPO_EDGE_TESTING}"   \
  >> /etc/apk/repositories
  #
  # install the packages from the packages file
  #
  wget "${SRV_HTTP}/packages-apk.txt" -O - | xargs apk add
}

#
# format the disk with one partition
#
function disk_format {
  parted --script \
         --align optimal \
         "${DISK_DEV}" \
         -- \
         unit MiB \
         mklabel gpt \
         mkpart primary 2048s 4095s \
         name ${BOOT_PART_ORDER} grub \
         set  ${BOOT_PART_ORDER} legacy_boot on \
         set  ${BOOT_PART_ORDER} bios_grub on \
         mkpart primary 4096s 100% \
         name ${ROOT_PART_ORDER} ${LVM_VG} \
         set  ${ROOT_PART_ORDER} lvm on \
         print
  pvcreate "${ROOT_DEV}"
  vgcreate "${LVM_VG}" "${ROOT_DEV}"
  lvcreate -n ${LVM_LV} -l 100%FREE "${LVM_VG}"
  mkfs."${ROOT_FS}" -L "${ROOT_LABEL}" "${LVM_ROOT}"
}

#
# mount the formated disk
#
function disk_mount {
  mount -t "${ROOT_FS}" "${LVM_ROOT}" "${ROOT}"
  for dir in boot tmp var/tmp; do
    mkdir -p "${ROOT}/${dir}"
  done
  mount -t tmpfs -o size="${TMP_SIZE}" tmpfs "${ROOT}/tmp"
  mount -t tmpfs -o size="${TMP_SIZE}" tmpfs "${ROOT}/var/tmp"
  for dir in proc dev sys; do
      mkdir -p "${ROOT}/${dir}"
      mount --bind "/${dir}" "${ROOT}/${dir}"
  done
}

#
# install on the formated disk
#
function disk_install {
  setup-disk "${ROOT}"
}

#
# cf https://wiki.alpinelinux.org/wiki/Bootloaders
#
function disk_bootloader {
  local grub_dir='/boot/grub'
  local grub_cfg="${grub_dir}/grub.cfg"
  local grub_cfg_esh="${grub_cfg}.esh"

  for dir in "${ROOT}" '/tmp'; do
    mkdir -p "${dir}${grub_dir}"
  done
  #
  # fetch the config template
  #
  wget "${SRV_HTTP}/data${grub_cfg_esh}" \
       -O "/tmp${grub_cfg_esh}"
  #
  # render the config template
  #
  esh -o "${ROOT}${grub_cfg}" \
      "/tmp${grub_cfg_esh}" \
      ALPINE_RELEASE="${ALPINE_RELEASE}" \
      GRUB_LVM_ROOT="${GRUB_LVM_ROOT}" \
      LVM_ROOT="${LVM_ROOT}"
  #
  # install the boot loader
  #
  grub-install --boot-directory="${ROOT}/boot" \
               --root-directory="${ROOT}" \
               "${DISK_DEV}"
}

############################################################################
#
# https://wiki.alpinelinux.org/wiki/Alpine_setup_scripts
# https://busybox.net/downloads/BusyBox.html#udhcpc
#
############################################################################
function network_configure {
  cat > "${ROOT}/etc/network/interfaces" << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

  cat /etc/resolv.conf > "${ROOT}/etc/resolv.conf"
}

#
#
#
function chroot_install {
  chroot "${ROOT}" /bin/sh -x << CHROOT
# Create Initial User
adduser -D alpine -G wheel
printf "%s\n" "alpine:alpine" | chpasswd
wget "${SRV_HTTP}/data/etc/sudoers.d/wheel" -O /etc/sudoers.d/wheel

# Lock the root account
passwd -d -l root

apk add haveged openssh

rc-update add networking boot
rc-update add acpid default
rc-update add haveged default
rc-update add sshd default
printf "%s\n" "rc_sshd_after='haveged'" >> /etc/rc.conf
apk del syslinux
CHROOT
}
#
#
#
function disk_umount {
  for dir in proc dev sys tmp var/tmp ''; do
    umount "${ROOT}/${dir}"
  done
}

#
#
#
function main {
  install_setup_dependencies
  disk_format
  disk_mount
  disk_install
  disk_bootloader
  network_configure
  chroot_install
  disk_umount
  reboot
}

main
