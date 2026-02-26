# Overview
This file contains a detailed guide on how I setup an ArchLinux system from scratch (literally). This guide covers the initial Arch installation all the way to the final result. This guide shows the process I follow to build my Hyprland WM system, my way. Before anything, I'll ask whoever is reading this to have some grade of skepticism about what's written here, not because it's wrong (somethings surely are) but mainly because of the nature of Arch itself, don't forget to check the [**ArchWiki**](https://wiki.archlinux.org/title/Main_page) :)

# Arch Installation
## Environment Setup (Pre-installation)

### Installation Media and Live Environment
I assume the installation media already exists and the boot into the live enviroment was successful.

### Keyboard Layout
Default keyboard layout is `us`, Available layouts can be listed with:

```
# localectl list-keymaps
```

To set the keyboard layout run:

```
# loadkeys <keys>
```

### Internet Connection
A LAN cable is the easiest way to get network access but in case that is not possible, using [**iwctl**](https://wiki.archlinux.org/title/Iwd#iwctl):

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

If there's connection but no internet access, a DHCP client might be needed, using [**dhcpcd**](https://wiki.archlinux.org/title/Dhcpcd):

```
# dhcpcd <dev_name>
# ping arch.org      # Test connection
```

If got a timed-out error try:

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

**Recommended sizes vary based on the desired installation**. To create them, use [**fdisk/cfdisk**](https://wiki.archlinux.org/title/Fdisk).

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

Mirrors can be choosen in `/etc/pacman.d/mirrorlist`. It is recommended to check the date with `timedatectl` and upload the `keyring` as well to avoid signature problems.

```
# timedatectl
# pacman -Sy archlinux-keyring
```

If there's still signature problems, but a system is needed somehow, set `SigLevel = TrustAll` in `/etc/pacman.conf` for a **temporary** workaround to get going with the starting installation.

To install the programs, `pacstrap` is used. Here's the complete command I run to install the base system packages and what I consider "must have" software (adjust to your preferences and needings): 

```
# pacstrap -K /mnt base base linux linux-firmware dbus polkit udisks2 p7zip vim neovim base-devel git iwd bluez bluez-utils impala grub efibootmgr <amd/intel>-ucode sof-firmware pacman-contrib 
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
Uncomment `en_US.UTF-8 UTF-8` in `/etc/locale.gen` and then run:

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
Edit the sudoers file with your preferred editor with:

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

Before setting up the bootloader I like to make sure the network configuration works. The architecture I use uses the following components:

- `iwd` is in charge of wireless authentication only (`wlan`-like interfaces).
- `systemd-networkd` is in charge of ethernet connections (`eth`-like interfaces) and DHCP protocol for both `wlan` and `eth` interfaces.
- `systemd-resolved` is in charge of DNS resolution.

Take `wlan0` and `eth0` as example interfaces. Network interfaces can be listed with:

```
# ip link
# ip a           # More details         
```

For `systemd-networkd`, in the folder `/etc/systemd/network`, create a `XX-interface.network` file for each network interface you intend to use. The file naming follows this structure because of 1) files being evaluated alphabetically (in case there were different files for one same network interface) and 2) to make the management easier when doing changes. 
For this example, it would be two files named `01-eth0.network` and `02-wlan0.network` with the following content:

```ini
[Match]
Name=<interface>

[Network]
DHCP=yes    
```

If you prefer a static IP, the file would look something like this:

```ini
[Match]
Name=<dev_name>

[Network]
Address=192.168.1.100/24
Gateway=192.168.1.1
DNS=8.8.8.8
```

Once the `.network` files have been created, `iwd` must be explicitly configured so it doesn't manage **DHCP** for wireless interfaces since `systemd-networkd` is the tool intended to do so, this can be achieved by editing (or creating if it doesn't exists) the file `/etc/iwd/main.conf` which should look like this: 

```ini
[General]
EnableNetworkConfiguration=false
```

Now, for `systemd-resolved`, verify that `/etc/resolv.conf` is a symbolic link to `/run/systemd/resolve/stub-resolv.conf` with:

```
# ls -l /etc/resolv.conf 
```

The expected output should look something like this:

```
> /etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf
```

if it is not, the file must be deleted to then, regenerate the link and verify again:

```
# rm /etc/resolv.conf
# ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
# ls -l /etc/resolv.conf
```

Once everything has been stablished, services are enabled to apply changes:

```
# systemctl enable --now iwd
# systemctl enable --now systemd-networkd
# systemctl enable --now systemd-resolved
```

If there's a network available, test the configuration with:

```
# networkctl status <interface>
```

The output should show some section like

```
> DNS: 192.168.1.1
```

or similar.

### Bootloader

To install the bootloader do:

```
# grub-install <boot_part>
# grub-mkconfig -o /boot/grub/grub.cfg
```

After that, to reboot into the freshly installed system run:

```
# exit
# umount -a
# reboot
```

# System Setup

From now on it's about adding more "familiar" packages to the system in order to customize it and get the best out of it.

### AUR Helper

Some software required will be available through AUR, for this, it's essential to have an AUR helper installed, in this case we'll use [**yay**](https://github.com/Jguer/yay):

```
$ sudo pacman -Sy git base-devel     # If not installed already
$ git clone https://aur.archlinux.org/yay.git
$ cd yay
$ makepkg -si
```

### Graphics

Since we'll be using a [**Wayland**](https://wayland.freedesktop.org/) compositor, we'll start with that:

```
$ sudo pacman -Sy wayland
```

Now we have to make sure our system's graphic drivers work. Depending on the system and personal preferences, certain packages will be needed:

```
$ sudo pacman -Sy mesa   # Intel/AMD GPU
$ sudo pacman -Sy nvidia # or nvidia-dkms (dynamic kernel support) | Nvidia GPU
$ sudo pacman -Sy vulkan-*   # If care about Vulcan
$ sudo pacman -Sy libva      # or mesa-vdpau | Video accel
```

If you have Nvidia you might want to check the [**Hyprland-Nvidia page**](https://wiki.hypr.land/Nvidia/).

## Basic Must-Have Utilities

[**Here**](https://wiki.hypr.land/Useful-Utilities/Must-have/) you can see that there's certain software strongly recommended to be running beforehand in order to have a smooth **Hyprland** experience so we'll do just that.

### Notification Daemon

```
$ sudo pacman -Sy dunst
```

`/usr/bin/dunst` must be started by window manager or desktop environment on startup/login.

### Pipewire

Required for screensharing. We'll also install `pipewire-pulse` for audio and `pavucontrol` for the GUI:

```
$ sudo pacman -Sy pipewire wireplumber pipewire-pulse pavucontrol
```

**Note:** Typically a package like `pulseaudio-bluetooth` would be needed, but since we're using `pipewire`, that is not necessary.

### XDG Desktop Portal

File pickers, screensharing, etc.

```
$ sudo pacman -Sy xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
```

### Authentication Agent

Things that pop up a window asking you for a password whenever an app wants to elevate its privileges. Since `polkit` was installed with `pacstrap` we just do:

```
$ sudo pacman -Sy hyprpolkitagent
```

Must be started by window manager or desktop environment on startup/login.

### Qt Wayland Support

```
$ sudo pacman -Sy qt5-wayland qt6-wayland
```

### Fonts

A sans-serif font is required to render text. Without one, you may see squares instead of text. A common choice is `noto-fonts`.

```
$ sudo pacman -Sy noto-fonts noto-fonts-emoji
```

### Nerd Font

Nerd Fonts are a collection of fonts patched to include a variety of programming and development-related icons and glyps. We'll need that in order to have the icons of things like status bar or some TUI applications to render correctly.

Some fonts I've liked so far are

- [**0xProto**](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/0xProto)

- [**GeistMono**](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/GeistMono)

- [**Noto**](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/Noto)

To install fonts, place them in `~/.local/share/fonts/` or `/usr/share/fonts/` for system wide access.

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

Might be started by window manager or desktop environment on startup/login with `webcord --start-minimized` (who would want that anyway?).

```
$ yay -Sy webcord
```

### Color Picker

```
$ sudo pacman -Sy hyprpicker
```

### Clipboard Manager

```
$ yay -Sy cursor-clip-git
```

`cursor-clip --daemon` must be started by window manager or desktop environment on startup/login 

### File Manager

```
$ sudo pacman -Sy thunar
```

### Shell

For the shell, my choice is [**fish**](https://fishshell.com/).

```
$ sudo pacman -Sy fish
```

### Terminal Emulator

```
$ sudo pacman -Sy kitty
```

### VPN

For privacy, I use [**Mullvad VPN**](https://wiki.archlinux.org/title/Mullvad).

```
$ sudo pacman -Sy mullvad-vpn
$ sudo systemctl enable --now mullvad-vpn
$ sudo systemctl enable --now mullvad-early-boot-blocking
```

### GUI's for Command-Line Packages

```
$ sudo pacman -Sy udiskie iwgtk blueman
```

### System Control and Misc. Utilites

```
$ sudo pacman -Sy brightnessctl playerctl fastfetch vlc cups exa bat slurp grim
```

### Install Hyprland

Now that all the system background is ready we install `hyprland`:

```
$ sudo pacman -Sy hyprland
```

Check if everything works correctly by starting a session via `start-hyprland` (**without root acces**).

### Display/login manager

For simplicity I use [**Ly**](https://wiki.archlinux.org/title/Ly) which is simple, lightweight and customizable. To start **Ly** at boot. First make sure to enable `ly@ttyX.service`, then disable `getty@ttyX.service` where `X` stands for a number from 1 to 6. Again, this is done **after checking** that the hyprland sessions runs successfully.

```
$ sudo pacman -Sy ly
$ sudo systemctl enable ly@ttyX
$ sudo systemctl disable getty@ttyX
```
