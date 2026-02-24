
# Table of contents


# Overview
This file contains a detailed guide on how I setup an ArchLinux system from scratch (literally). This guide covers the initial Arch installation all the way to the final result: a fully customized, functional system. This guide shows the process I follow to build my Hyprland WM system, my way. Before anything, I'll ask whoever is reading this to have some grade of skepticism about what's written here, not because it's wrong (somethings surely are since this is the second window manager I try) but mainly because of the nature of Arch itself, don't forget to check the [ArchWiki](https://wiki.archlinux.org/title/Main_page) :)

# Arch Installation
## Environment Setup (Pre-installation)

### Installation Media and Live Environment
I assume the installation media already exists and the boot into the live enviroment was successful.

### Keyboard Layout
Default keyboard layout is `us`, Available layouts can be listed with

```
# localectl list-keymaps
```

To set the keyboard layout run

```
# loadkeys <keys>
```

### Internet Connection
A LAN cable is the easiest way to get network access but in case that is not possible, [**iwctl**](https://wiki.archlinux.org/title/Iwd#iwctl) can be used:

```
[iwd]# device list
[iwd]# device <dev_name> show
[iwd]# device <dev_name> set-property Powered on        # In case the device is powered off
[iwd]# adapter <dev_adapter> set-property Powered on    
[iwd]# station <dev_name> scan
[iwd]# station <dev_name> get-networks
[iwd]# station <dev_name> connect <SSID>
[iwd]# station <dev_name> disconnect
```

If it happens that there's connection but not internet access, a DHCP client will most likely be needed, in this case, using [dhcpcd](https://wiki.archlinux.org/title/Dhcpcd):

```
# dhcpcd <dev_name>
# ping arch.org      # Test connection
```

If got a timed-out error try

```
# ip a               # List network interfaces
# systemctl status dhcpcd@<dev_name>
# journalctl -xn
# dhclient -r
# dhclient
# ip a
# ping arch.org      # Test connection
```

### Disk Partitions

Basic installation requires **three partitions**:

- Boot (~1 GB)
- Swap (~4 GB) 
- Root (~10 GB)

**Recommended sizes vary based on the desired installation**. To create them, [**fdisk/cfdisk**](https://wiki.archlinux.org/title/Fdisk) can be used.

### Formating the Partitions

```
# mkfs.fat -F 32 <boot_part>
# swapon <swap_part>
# mkfs.ext4 <root_part>
```

### Mount Partitions in File System

```
# mount <boot_part> /mnt/boot/efi
# swapon <swap_part>
# mount <root_part> /mnt
```

**NOTE**: The `/mnt/boot/efi` folder must be created previously.

## Installation

Mirrors can be choosen in `/etc/pacman.d/mirrorlist`. It is recommended to check the date with `timedatectl` and upload the `keyring` as well to avoid signature problems

```
# timedatectl
# pacman -Sy archlinux-keyring
```

In the rare case there's still signature problems, but you need a system somehow, you can try setting `SigLevel = TrustAll` in `/etc/pacman.conf`. After installation, check that `SigLevel` is not in `TrustAll` anymore because of **security**.

To install the programs, `pacstrap` is used. Here's the complete command I run to install the system and all my "must have" software (this "must have" software is that one needed in order to make the system able to do the most basic and fundamental stuff I believe a computer should do): 

```
# pacstrap -K /mnt base base linux linux-firmware dbus polkit udisks2 neovim vim base-devel iwd impala git grub efibootmgr <amd/intel>-ucode sof-firmware pacman-contrib
``` 

## System Configuration
### fstab

```
genfstab -U /mnt > /mnt/etc/fstab
``` 

**Verify** that the result on `/mnt/etc/fstab` contains all of the three partitions created and mounted previously.

### Enter the newly installed system

```
# arch-chroot /mnt
```

### Time Zone

```
# ln -sf /usr/share/zoneinfo/<Region>/<City> /etc/localtime
# hwclock --systohc
```

**NOTE**: Using the `ls` command the available time zones can be seen.

### Localization
Uncomment `en_US.UTF-8 UTF-8` in `/etc/locale.gen` and then run

```
# locale-gen
```

Set locals in `/etc/locale.conf`. Add `LANG=en_US.UTF-8`.

Set console layout in `/etc/vconsole.conf`. Add `KEYMAP=<keys>`.

### Hostname

Set hostname in `/etc/hostname`.

### Root password

```
# passwd
```

### Sudoers file
Edit the sudoers file with your editor via

```
# EDITOR=<editor> visudo
```

Uncomment the line containing

```
%wheel ALL=(ALL) ALL
```

### Create users

```
# useradd -m -G wheel -s /bin/bash <user>
# passwd <user>
```

Note that the user is linked to the `wheel` group in order to make it able to execute `sudo` commands.

### Set-up Working Network Configuration

Before setting up the bootloader I like to setup the network configuration. The architecture I use uses the following components (make sure they are all installed beforehand):

- `iwd` is in charge of wireless authentication only (`wlan`-like interfaces).
- `systemd-networkd` is in charge of ethernet connections (`eth`-like interfaces) and DHCP protocol for both `wlan` and `eth` interfaces.
- `systemd-resolved` is in charge of DNS resolution.

We'll be taking `wlan0` and `eth0` as example interfaces. Network interfaces can be listed with

```
# ip link
# ip a           # More details         
```

For `systemd-networkd`, in the folder `/etc/systemd/network`, a `XX-interface.network` file must be created for each network interface we want to use. The file naming follows this structure because of 1) files being evaluated alphabetically (in case there were different files for one same network interface) and 2) to make the management easier in case we'd like to change something. 

In this case, it would be two files named `01-eth0.network` and `02-wlan0.network` with the following content:

```ini
[Match]
Name=<interface>

[Network]
DHCP=yes    
```

If a static IP is prefered, the file would look somethink like this:

```ini
[Match]
Name=<dev_name>

[Network]
Address=192.168.1.100/24
Gateway=192.168.1.1
DNS=8.8.8.8
```

Once the `.network` files have been created, I want to avoid `iwd` being in charge of **DHCP** for wireless interfaces since `systemd-networkd` is what I intend to use to do so, this can be achieved by editing (or creating if it doesn't exists) the file `/etc/iwd/main.conf` which should look just like this: 

```ini
[General]
EnableNetworkConfiguration=false
```

Now, for `systemd-resolved`, we must verify that `/etc/resolv.conf` is a symbolic link to `/run/systemd/resolve/stub-resolv.conf` which can be done with

```
# ls -l /etc/resolv.conf 
```

The expected output should look something like this:

```
> /etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf
```

if it is not, we must delete the file, generate the link and then verify again:

```
# rm /etc/resolv.conf
# ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
# ls -l /etc/resolv.conf
```

Once everything has been stablished, we enable the services to apply changes:

```
# systemctl enable --now iwd
# systemctl enable --now systemd-networkd
# systemctl enable --now systemd-resolved
```

If there's a network available we can test the adequate functioning of the configuration with

```
# networkctl status <interface>
```

The output should show some section like

```
> DNS: 192.168.1.1
```

or similar.

### Bootloader

To install the bootloader do

```
# grub-install <boot_part>
# grub-mkconfig -o /boot/grub/grub.cfg
```

## Reboot

```
# exit
# umount -a
# reboot
```

# Window Manager

Once the base system boots cleanly and the internet access is established successfully, we'll build a solid background to then build our WM setup.

## AUR Helper

Some software required will be available through AUR, for this, it's essential to have an AUR helper installed, in this case we'll use [**yay**](https://github.com/Jguer/yay)

```
$ sudo pacman -S --needed git base-devel     # If not installed already
$ git clone https://aur.archlinux.org/yay.git
$ cd yay
$ makepkg -si
```

## Graphics

Since we'll be using a [**Wayland**](https://wayland.freedesktop.org/) compositor, we'll start with that:

```
$ sudo pacman -Sy wayland
```

Now we have to make sure our system's graphic drivers work. Depending on the system and your preferences, certain packages will be needed:

```
$ sudo pacman -Sy mesa   # Intel/AMD GPU
$ sudo pacman -Sy nvidia # or nvidia-dkms (dynamic kernel support) | Nvidia GPU
$ sudo pacman -Sy vulkan-*   # If care about Vulcan
$ sudo pacman -Sy libva      # or mesa-vdpau | Video accel needed
```

If you have Nvidia you might want to check the [**Hyprland-Nvidia page**](https://wiki.hypr.land/Nvidia/).

## Basic Must-Have Utilities

[**Here**](https://wiki.hypr.land/Useful-Utilities/Must-have/) you can see that there's certain software strongly recommended to be running beforehand in order to have a smooth Hyprland experience so we'll do just that.

### Notification Daemon

```
$ sudo pacman -Sy dunst
```

`/usr/bin/dunst` must be started by window manager or desktop environment on startup/login.

### Pipewire

Required for screensharing. We'll also install `pipewire-pulse` for audio and `pavucontrol` for the GUI.

```
$ sudo pacman -Sy pipewire wireplumber pipewire-pulse pavucontrol
```

### XDG Desktop Portal

File pickers, screensharing, etc.

```
$ sudo pacman -Sy xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
```

### Authentication Agent

Things that pop up a window asking you for a password whenever an app wants to elevate its privileges. Since `polkit` was installed with `pacstrap` we just do

```
$ sudo pacman -Sy hyprpolkitagent
```

Must be started by window manager or desktop environment on startup/login.

### Qt Wayland Support

```
$ sudo pacman -Sy qt5-wayland qt6-wayland
```

### Fonts

**NOTE** To be added: Nerdfont

A sans-serif font is required to render text. Without one, you may see squares instead of text. A common choice is `noto-fonts`.

```
$ sudo pacman -Sy noto-fonts noto-fonts-emoji
```

### Status Bar

```
$ sudo pacman -Sy waybar
```

Must be started by window manager or desktop environment on startup/login.

### Wallpaper

TBD

### App Launcher

```
$ sudo pacman -Sy rofi
```

### App Clients

Some clients are known for being a massive pain under Wayland. Here are some replacements for the ones I use:

[**Webcord**](https://github.com/SpacingBat3/WebCord) (Discord)

Might be started by window manager or desktop environment on startup/loginwith `webcord --start-minimized` (who would want that anyway?).

```
$ yay -S webcord
```

### VPN

For privacy, I use [**Mullvad VPN**](https://wiki.archlinux.org/title/Mullvad).

```
$ sudo pacman -Sy mullvad-vpn
$ sudo systemctl enable mullvad-vpn
$ sudo systemctl enable mullvad-early-boot-blocking  # Pretty self-explanatory isn't it?
```


### Pending packages to include somewhere
- `brightnessctl`
- `playerctl`
- `udiskie`
- `fastfetch`
- `fish`
- `kitty`
- `ly`
- `hyprland`
- `thunar`
- `cursor-clip-git` (AUR)
- `vlc`
- `iwgtk` (AUR)
- `mullvad-vpn`
- `cups`
