#!/usr/bin/bash
set -uo pipefail

# Kustom Arch Linux Install Script (Kalis)
# 
# This is an unofficial Arch Linux install script intended for personal use
# only. Use it at your own risk.
#
# Usage:
#   loadkeys [keymap]
#   iwctl --passphrase "[WIFI_KEY]" station [WIFI_INTERFACE] connect "[WIFI_ESSID]"
#   curl https://raw.githubusercontent.com/rixsilverith/kalis/bootstrap.sh | bash
#   vim kalis.sh
#   ./kalis.sh
#
# For more information, see https://github.com/rixsilverith/kalis/master/blob/README.md

# Keyboard layout to be set with the loadkeys command
KEYS="es"

# Device for the installation. Run the `lsblk` command to get a list of all the available
# disks in your system.
DEVICE="/dev/nvme0n1"
PARTITION_BOOT="${DEVICE}p1"
PARTITION_SWAP="${DEVICE}p2"
PARTITION_ROOT="${DEVICE}p3"
BOOT_DIRECTORY="/efi"

# Swap partition size in mebibytes. 
SWAP_PARTITION_SIZE="2048"

# Wifi configuration
WIFI_INTERFACE=""
WIFI_ESSID=""
WIFI_KEY=""

# Pacman stuff
REFLECTOR="false"
REFLECTOR_COUNTRIES=("Spain")
PACMAN_MIRROR="https://mirrors.kernel.org/archlinux/\$repo/os/\$arch"

# Localization
TIMEZONE="/usr/share/zoneinfo/Europe/Madrid"
LOCALES=("en_GB.UTF-8 UTF-8")
LOCALE_CONF=("LANG=en_GB.UTF-8")
KEYMAP="KEYMAP=en"

# System and user credentials
HOSTNAME=""
ROOT_PASSWORD=""
USER_NAME=""
USER_PASSWORD=""

cyan='\033[1;36m'
reset='\033[0m'

_info() { echo -e "\033[1;36m==>\033[0m $1"; }
_note() { echo -e "\033[1;36m->\033[0m $1"; }
_enote() { echo -e "\033[1;31m->\033[0m $1"; }

pacman_install() { 
    packages=($1)
    arch-chroot /mnt pacman -Syu --noconfirm --needed ${packages[@]} 
    if [ $? == 1 ];
        echo -e "\033[1;31m==>\033[0m Error installing packages: \033[1;36m${packages[@]}\033[0m"
        exit 1
    fi
}

# Welcome and warning message
echo -e "Hey! Welcome to \033[1;36mKalis (Kustom Arch Linux Install Script)\033[0m!\n"
echo -e "\033[1;33mWarning! This script is in an early development stage and may have some bugs that in"
echo -e "\033[1;33mthe worst case scenario could lead to data loss. Proceed at your own risk.\033[0m\n"
read -p "Do you want to continue [y/N] " yn

case $yn in
    [Yy]* ) ;;
    [Nn]* ) exit ;;
    * ) exit ;;
esac
unset yn

# Check variables
echo -e "\nThe following configuration will be used to autoinstall the system. Please, check everything"
echo -e "is fine before continuing.\n\n"

if [ -n $DEVICE ]; then 
    _note "The system will be installed on the ${cyan}$DEVICE${reset} device"
else
    _enote "No installation device was specified. Aborting installation...\n"
    exit 1
fi

if [ -n $BOOT_DIRECTORY ]; then 
    _note "Boot/EFI partition will be mounted on the ${cyan}$BOOT_DIRECTORY${reset} directory"
else
    _enote "No mount directory was specified for the boot partition. Aborting installation...\n"
    exit 1
fi

_note "The swap partition will be ${cyan}$SWAP_PARTITION_SIZE MiB${reset} large"

if [ -z $WIFI_INTERFACE ]; then
    _note "No wireless network connection will be set up by default"
else
    _note "A wireless network connection will be set up with ESSID ${cyan}$WIFI_ESSID${reset} through the ${cyan}$WIFI_INTERFACE${reset} interface"
fi

if [ $REFLECTOR == true ]; then
    _note "${cyan}Reflector enabled${reset} for faster download times"
else
    _note "${cyan}Reflector disabled${reset}. This may increase the time needed to download the system"
fi

if [ -n $TIMEZONE ]; then
    _note "Timezone will be set to ${cyan}$TIMEZONE${cyan}"
else
    _enote "No timezone specified. ${cyan}/usr/share/zoneinfo/Europe/Madrid${reset} will be used by default"
fi

echo -en "${cyan}->${reset} The following list of locales will be generated: "
for locale in "${LOCALES[@]}"; do
    echo -en "${cyan}$locale${reset}  "
done

echo -en "${cyan}->${reset} The following locale configuration will be set up: "
for locale_conf in "${LOCALE_CONF[@]}"; do
    echo -en "${cyan}$locale_conf${reset}  "
done

if [ -n "$HOSTNAME" ]; then
    _note "The hostname for the machine will be set to ${cyan}$HOSTNAME${cyan}"
else
    _enote "No hostname was specified. Aborting installation...\n"
    exit 1
fi

read -p "\nEverything fine? Proceed with the installation? [y/N] " yn
case $yn in
    [Yy]* ) ;;
    [Nn]* ) exit ;;
    * ) exit ;;
esac

# Ensure UEFI mode
if [ -d /sys/firmware/efi ]; then
    _info "Installation booted in UEFI mode"
else
    echo -e "\033[1;31m==>\033[0m Seems like the installation has been booted in legacy BIOS (or CMS) mode, which as of now"
    echo -e "is not supported. Aborting installation"
    exit 1
fi

# Clock synchronization
_info "Updating the system clock"
timedatectl set-ntp true

# Kernel and system installation
_info "Installing the Linux kernel"

[ -n "$PACMAN_MIRROR" ] && echo "Server = $PACMAN_MIRROR" > /etc/pacman.d/mirrorlist

if [ "$REFLECTOR" == "true" ]; then
    countries=()
    for country in "${REFLECTOR_COUNTRIES[@]}"; do countries+=(--country "${country}"); done

    pacman -Sy --noconfirm reflector
    reflector "${countries[@]}" --latest 25 --age 24 --protocol https --completion-percent 100 --sort rate \
        --save /etc/pacman.d/mirrorlist
fi

sed -i 's/#Color/Color/' /etc/pacman.conf
sed -i 's/#TotalDownload/TotalDownload' /etc/pacman.conf

pacstrap /mnt base base-devel linux linux-firmware

sed -i 's/#Color/Color/' /mnt/etc/pacman.conf
sed -i 's/#TotalDownload/TotalDownload/' /mnt/etc/pacman.conf

# Device partitioning
_info "Partitioning the installation device"
efi_end=512MiB
swap_end=$(( $efi_end + $SWAP_PARTITION_SIZE ))MiB

parted -s $DEVICE mklabel gpt \
    mkpart ESP fat32 1MiB ${efi_end} \
    set 1 boot on \
    set 1 esp on \
    mkpart primary linux-swap ${efi_end} ${swap_end} \
    mkpart primary ext4 ${swap_end} 100%

wipefs $PARTITION_BOOT
wipefs $PARTITION_SWAP
wipefs $PARTITION_ROOT

mkfs.vfat -F32 $PARTITION_BOOT
mkswap $PARTITION_SWAP
mkfs.ext4 $PARTITION_ROOT

mounted_boot_dir="/mnt$BOOT_DIRECTORY"

swapon $PARTITION_SWAP
mount $PARTITION_ROOT /mnt
mkdir $mounted_boot_dir
mount $PARTITION_BOOT $mounted_boot_dir

# System configuration
_info "Generating file system table"
genfstab -U /mnt >> /mnt/etc/fstab

_info "Configuring time zone and locales"
arch-chroot /mnt ln -sf $TIMEZONE /etc/localtime
arch-chroot /mnt hwclock --systohc

for locale in "${LOCALES[@]}"; do
    sed -i "s/#$locale/$locale/" /etc/locale.gen
    sed -i "s/#$locale/$locale/" /mnt/etc/locale.gen
done

for l_conf in "${LOCALE_CONF[@]}"; do
    echo -e "$l_conf" >> /mnt/etc/locale.conf
done

locale-gen
arch-chroot /mnt locale-gen

_info "Setting up console keymap and hostname"
echo $KEYMAP > /mnt/etc/vconsole.conf
echo $HOSTNAME > /mnt/etc/hostname

arch-chroot /mnt cat <<EOF > /etc/hosts
    127.0.0.1   localhost
    ::1         localhost
    127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
EOF

_info "Configuring root password"
printf "$ROOT_PASSWORD\n$ROOT_PASSWORD" | arch-chroot /mnt passwd

# Network configuration
_info "Configuring network"
pacman_install "networkmanager"
arch-chroot /mnt systemctl enable NetworkManager.service

if [ -n "$WIFI_ESSID" ]; then
    arch-chroot /mnt nmcli device wifi connect "$WIFI_ESSID" password "$WIFI_KEY"
fi

# User creation
_info "Creating default non-root user"
arch-chroot /mnt useradd -m -G wheel,storage,video,audio,input $USER_NAME
printf "$USER_PASSWORD\n$USER_PASSWORD" | arch-chroot /mnt passwd $USER_NAME

pacman_install "sudo"
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL' /etc/sudoers

# Bootloader configuration
_info "Configuring bootloader"
pacman_install "grub efibootmgr"

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=$BOOT_DIRECTORY --bootloader-id=grub --recheck
arch-chroot /mnt grub-mkconfig -o "$BOOT_DIRECTORY/grub/grub.cfg"

# Finished installation message
echo -e "\n\033[1;32m==> Arch Linux installed successfully!\033[0m\n"
echo -e "Now, you may reboot your system\n"
