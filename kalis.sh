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
#   vim kalis.conf
#   ./kalis.sh
#
# For more information, see https://github.com/rixsilverith/kalis/master/blob/README.md

CONF_FILE="kalis.conf"
LOG_FILE="kalis.log"

cyan='\033[1;36m'
reset='\033[0m'

_info() { echo -e "\033[1;36m==>\033[0m $1"; }
_note() { echo -e "\033[1;36m->\033[0m $1"; }
_enote() { echo -e "\033[1;31m->\033[0m $1"; }

pacman_install() { 
    packages=($1)
    arch-chroot /mnt pacman -Syu --noconfirm --needed ${packages[@]} &> $LOG_FILE
    if [ $? == 1 ]; then
        echo -e "\033[1;31m==>\033[0m Error installing packages: \033[1;36m${packages[@]}\033[0m"
        exit 1
    fi
}

# Introduction and config file check
clear; echo -e "\nHey! Welcome to ${cyan}Kalis (Kustom Arch Linux Install Script)${reset}!\n"

[ ! -f $CONF_FILE ] && echo -e "Could not find configuration file ${cyan}${CONF_FILE}${reset}.\n" && exit 1
source $CONF_FILE

[ -z $INSTALL_DEVICE ] && echo -e "No installation device was specified in the ${cyan}$CONF_FILE${reset} configuration file.\n" && exit 1

echo -e "The configuration provided in the ${cyan}$CONF_FILE${reset} will be used to automatically install the"
echo -e "system on the ${cyan}$INSTALL_DEVICE${reset} device. You may double check it twice before continuing with the"
echo -e "installation."

echo -e "\n${cyan}WARNING${reset} This script will nuke all the data, partitions and other operating systems included,"
echo -e "in the ${cyan}$INSTALL_DEVICE${reset} device. Just make sure you have a backup of the data"
echo -e "you want to preserve, if any.\n"

read -p "Proceed with the installation? [y/N] " yn; echo
[[ $yn != "Y" || $yn != "y" || -z $yn ]] && exit

# Initialize logging
[ -f $LOG_FILE ] && rm -f $LOG_FILE

# Redirect execution trace output to log file
exec 5>> $LOG_FILE
PS4='+ $LINENO: ' 
BASH_XTRACEFD="5" 

# Copy stdout and stderr to log file
exec > >(tee -a $LOG_FILE)
exec 2> >(tee -a $LOG_FILE)

# Enable execution trace for debugging
set -o xtrace

# Ensure UEFI mode
if [ -d /sys/firmware/efi/efivars ]; then
    _info "Installation booted in UEFI mode"
else
    echo -e "\033[1;31m==>\033[0m Seems like the installation has been booted in legacy BIOS (or CMS) mode, which as of now"
    echo -e "is not supported. Aborting installation"
    exit 1
fi

# Clock synchronization
_info "Updating the system clock"
timedatectl set-ntp true

# Device partitioning
_info "Partitioning the installation device"
efi_end="$BOOT_PARTITION_SIZE"MiB
swap_end=$(( $efi_end + $SWAP_PARTITION_SIZE ))MiB

parted -s $DEVICE mklabel gpt \
    mkpart ESP fat32 1MiB ${efi_end} \
    set 1 esp on \
    mkpart primary linux-swap ${efi_end} ${swap_end} \
    mkpart root ext4 ${swap_end} 100% &> $LOG_FILE

wipefs $PARTITION_BOOT &> $LOG_FILE
wipefs $PARTITION_SWAP &> $LOG_FILE
wipefs $PARTITION_ROOT &> $LOG_FILE

mkfs.fat -F32 $PARTITION_BOOT &> $LOG_FILE
mkswap $PARTITION_SWAP &> $LOG_FILE
mkfs.ext4 $PARTITION_ROOT &> $LOG_FILE

[ -z $BOOT_DIRECTORY ] && BOOT_DIRECTORY="/efi"

swapon $PARTITION_SWAP
mount $PARTITION_ROOT /mnt
mkdir "/mnt$BOOT_DIRECTORY"
mount $PARTITION_BOOT "/mnt$BOOT_DIRECTORY"

# Kernel and system installation
_info "Installing the Linux kernel at $INSTALL_DEVICE"

if [ "$REFLECTOR" == "true" ]; then
    countries=()
    for country in "${REFLECTOR_COUNTRIES[@]}"; do countries+=(--country "${country}"); done

    pacman -Sy --noconfirm reflector &> $LOG_FILE
    reflector "${countries[@]}" --latest 25 --age 24 --sort rate --save /etc/pacman.d/mirrorlist &> $LOG_FILE
fi

sed -i 's/#Color/Color/' /etc/pacman.conf
sed -i 's/#TotalDownload/TotalDownload' /etc/pacman.conf

pacstrap /mnt base base-devel linux linux-firmware &> $LOG_FILE

sed -i 's/#Color/Color/' /mnt/etc/pacman.conf
sed -i 's/#TotalDownload/TotalDownload/' /mnt/etc/pacman.conf

# System configuration
_info "Generating file system table"
genfstab -U /mnt >> /mnt/etc/fstab

_info "Configuring timezone and locales"
[ -z $TIMEZONE ] && TIMEZONE="Europe/Madrid"

arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
arch-chroot /mnt hwclock --systohc

for locale in "${LOCALES[@]}"; do sed -i "s/#$locale/$locale/" /mnt/etc/locale.gen; done
for l_conf in "${LOCALE_CONF[@]}"; do echo -e "$l_conf" >> /mnt/etc/locale.conf; done

arch-chroot /mnt locale-gen &> $LOG_FILE

_info "Setting up console keymap and hostname"
[ -z $KEYMAP ] && KEYMAP="en"
[ -z $HOSTNAME ] && HOSTNAME="kalis"

echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
echo $HOSTNAME > /mnt/etc/hostname

arch-chroot /mnt cat <<EOF > /etc/hosts
    127.0.0.1   localhost
    ::1         localhost
    127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
EOF

_info "Configuring root password"
printf "$ROOT_PASSWORD\n$ROOT_PASSWORD" | arch-chroot /mnt passwd &> $LOG_FILE

# Network configuration
_info "Configuring network"
pacman_install "networkmanager"
arch-chroot /mnt systemctl --now enable NetworkManager.service &> $LOG_FILE

if [ -n "$WIFI_ESSID" ]; then
    arch-chroot /mnt nmcli device wifi connect "$WIFI_ESSID" password "$WIFI_KEY" &> $LOG_FILE
fi

# User creation
_info "Creating default non-root user"
arch-chroot /mnt useradd -m -G wheel,storage,video,audio,input $USER_NAME &> $LOG_FILE
printf "$USER_PASSWORD\n$USER_PASSWORD" | arch-chroot /mnt passwd $USER_NAME &> $LOG_FILE

pacman_install "sudo"
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL' /etc/sudoers

# Bootloader configuration
_info "Configuring bootloader"
pacman_install "grub efibootmgr"

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=$BOOT_DIRECTORY --bootloader-id=Grub &> $LOG_FILE
arch-chroot /mnt grub-mkconfig -o "/boot/grub/grub.cfg" &> $LOG_FILE

# Finished installation message
echo -e "\n${cyan}Arch Linux installed successfully! :D${reset}\n"
echo -e "Now, you may reboot your system\n"

# Copy config and log file to /var/log/
mkdir /mnt/var/log/kalis
cp $CONF_FILE /mnt/var/log/kalis
cp $LOG_FILE /mnt/var/log/kalis
