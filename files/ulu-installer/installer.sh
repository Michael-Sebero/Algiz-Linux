#!/bin/bash

su -c '
if command -v pacman &>/dev/null; then

#######################
# ARTIX LINUX SECTION #
#######################

### INIT SYSTEM DETECTION ###
detect_init_system() {
    if pacman -Qi runit &>/dev/null; then
        echo "runit"
        return
    fi
    case "$(ps -p 1 -o comm=)" in
        s6-svscan)
            echo "s6"
            ;;
        init|openrc-init)
            echo "openrc"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

INIT_SYSTEM=$(detect_init_system)

### INSTALL PACKAGES ONE BY ONE WITH RETRIES ###
careful_install() {
  local failed_packages=()
  for pkg in "$@"; do
    local success=false
    for attempt in $(seq 1 5); do
      echo "Installing $pkg (attempt $attempt/5)..." >&2
      if paru -S --noconfirm --needed --ignore=nvidia-390xx-utils,lib32-nvidia-390xx-utils,modemmanager "$pkg"; then
        success=true
        break
      else
        if [ "$attempt" -lt 5 ]; then
          echo "Attempt $attempt failed for $pkg, retrying in 5 seconds..." >&2
          sleep 5
        else
          echo "All 5 attempts failed for $pkg, skipping..." >&2
          failed_packages+=("$pkg")
        fi
      fi
    done
  done

  if [ "${#failed_packages[@]}" -gt 0 ]; then
    echo -e "\e[1mThe following packages failed to install and were skipped:\e[0m" >&2
    for pkg in "${failed_packages[@]}"; do
      echo "  - $pkg" >&2
    done
  fi
}

### SERVICE MANAGEMENT FUNCTIONS ###
add_service() {
    local service_name="$1"
    case "$INIT_SYSTEM" in
        s6)
            s6 set enable "$service_name"
            ;;
        openrc)
            rc-update add "$service_name" default
            ;;
        runit)
            ln -sf "/etc/runit/sv/$service_name" /etc/runit/runsvdir/default/
            ;;
    esac
}

remove_service() {
    local service_name="$1"
    case "$INIT_SYSTEM" in
        s6)
            s6 set disable "$service_name"
            ;;
        openrc)
            rc-update del "$service_name" default || true
            ;;
        runit)
            unlink "/etc/runit/runsvdir/default/$service_name" 2>/dev/null || true
            ;;
    esac
}

# Sync s6 repo after package installs/removals (requires root)
sync_s6_repo() {
    if [ "$INIT_SYSTEM" = "s6" ]; then
        s6 repo sync
    fi
}

# Commit and apply staged s6 set changes
reload_s6_db() {
    if [ "$INIT_SYSTEM" = "s6" ]; then
        s6 set commit && s6 live install
    fi
}

### ULU LINUX CHOICE SELECTION ###

echo -e "\e[1mSelect a ULU Variant\e[0m"
echo "1. AMD-DESKTOP"
echo "2. AMD-LAPTOP"
echo "3. INTEL-DESKTOP"
echo "4. INTEL-LAPTOP"
echo "5. NVIDIA-OPENSOURCE-DESKTOP"
echo "6. NVIDIA-PROPRIETARY-DESKTOP"

read -p "Enter your choice (1-6): " choice

# IMPORT KEYS
echo -e "\e[1mImporting repository keys...\e[0m"

# AUR
curl -s https://raw.githubusercontent.com/chaotic-aur/.github/refs/heads/main/profile/README.md \
| grep -Eo "pacman-key --recv-key [0-9A-F]+" \
| sed "s/--recv-key \([0-9A-F]*\)/--recv-key \1; pacman-key --lsign-key \1/" \
| bash

# AURIS
curl https://auris.artixlinux.org/api/packages/auris/arch/repository.key -o repository.key
gpg --show-keys repository.key
pacman-key --add repository.key
pacman-key --lsign-key 74E5750C4A3C00F037070EF2357B525A97500B9F

### FIRST COMMANDS AND ULU-LINUX IMPORT P1 ###
killall xfce4-screensaver || true
pacman -Sy --noconfirm --needed p7zip unzip git base-devel
mkdir /home/ulu-files/
git clone https://github.com/Michael-Sebero/ULU /home/ulu-files/
cd /home/ulu-files/files/ulu-packages/
unzip -o ulu-pacman-temp-1.zip -d /etc
pacman -Sy --noconfirm artix-archlinux-support pacman-contrib artix-keyring archlinux-keyring artix-mirrorlist archlinux-mirrorlist
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
unzip -o ulu-pacman-temp-2.zip -d /etc
pacman -Sy --noconfirm alhp-keyring alhp-mirrorlist

# CPU ARCHITECTURE DETECTION
arch_support=$(/lib/ld-linux-x86-64.so.2 --help 2>&1 | grep '\''supported'\'' | head -n 1 | awk '\''{print $1}'\'')
if [ "$arch_support" = "x86-64-v3" ]; then
    unzip -o ulu-pacman-v3.zip -d /etc
elif [ "$arch_support" = "x86-64-v4" ]; then
    unzip -o ulu-pacman-v4.zip -d /etc
fi

# ACTIVATE REPOS
find /etc/pacman.conf -type f -exec sed -i 's/#//g' {} +

# POPULATE & REFRESH
pacman-key --init
pacman-key --populate archlinux artix alhp chaotic
pacman -Syy

# FIND QUICKEST MIRRORLIST
(
    set +m
    echo -ne "\033[1mFinding quickest mirrorlist, please wait... 0s\033[0m"
    seconds=0
    sh -c "rankmirrors -n 5 -m 3 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.new && mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist && chmod 644 /etc/pacman.d/mirrorlist" &>/dev/null &
    RANK_PID=$!
    while kill -0 $RANK_PID 2>/dev/null; do
        sleep 1
        seconds=$((seconds + 1))
        echo -ne "\r\033[1mFinding quickest mirrorlist, please wait... ${seconds}s\033[0m"
    done
)

### FIRST COMMANDS AND ULU-LINUX IMPORT P2 ###
pacman -S paru --noconfirm --needed
for attempt in $(seq 1 5); do
  echo "Running full system update (attempt $attempt/5)..." >&2
  if pacman -Syyu --noconfirm --needed --overwrite='*' --ignore=linux,linux-headers,nvidia-390xx-utils,lib32-nvidia-390xx-utils,modemmanager; then
    echo "System update succeeded." >&2
    break
  else
    if [ "$attempt" -lt 5 ]; then
      echo "Attempt $attempt failed, retrying in 5 seconds..." >&2
      sleep 5
    else
      echo "All 5 attempts failed for full system update. Continuing anyway..." >&2
    fi
  fi
done

mv /home/ulu-files/files/ulu-manual/Manual /home/$USER/Desktop/

# REMOVE PACKAGES
for pkg in linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf nvidia-390xx-utils lib32-nvidia-390xx-utils modemmanager lib32-nvidia-580xx-utils; do
    if pacman -Qi "$pkg" &>/dev/null; then
        paru -Rdd --noconfirm "$pkg"
    fi
done

# INSTALL BASE PACKAGES
careful_install \
  lib32-artix-archlinux-support unrar flatpak \
  gamemode lib32-gamemode dnscrypt-proxy apparmor \
  clamav gufw macchanger wine-git wine-mono winetricks-git steam lynis rkhunter opendoas \
  downgrade rust usbguard chkrootkit expect earlyoom \
  inotify-tools preload dialog tree parallel sof-firmware booster vulkan-tools mimalloc mold \
  protontricks-git poetry pyenv python-pip ccache yt-dlp-git \
  lib32-libdisplay-info realtime-privileges gallery-dl tesseract-data-eng \
  scx-scheds debtap fwupd chrony dnsmasq mesa lib32-mesa tk nix

# INSTALL PYTHON PACKAGES
careful_install \
  python-dateutil python-xlib python-pyaudio python-pipenv \
  python-matplotlib python-tqdm python-magic \
  python-piexif python-moviepy python-brotli python-websockets python-librosa \
  python-pypdf2 python-pytesseract

# INSTALL XFCE PACKAGES
if pacman -Qq | grep -q ''^thunar$''; then
    careful_install \
      networkmanager seahorse ffmpegthumbnailer

    case "$INIT_SYSTEM" in
        s6)
            careful_install networkmanager-s6
            ;;
        openrc)
            careful_install networkmanager-openrc
            ;;
        runit)
            careful_install networkmanager-runit
            ;;
    esac
else
    echo "Thunar not detected, skipping XFCE packages."
fi

# INSTALL INIT PACKAGES
case "$INIT_SYSTEM" in
    s6)
        careful_install \
          dnscrypt-proxy-s6 dnsmasq-s6 apparmor-s6 clamav-s6 \
          ufw-s6 usbguard-s6 earlyoom-s6
        ;;
    openrc)
        careful_install \
          dnscrypt-proxy-openrc dnsmasq-openrc apparmor-openrc clamav-openrc \
          ufw-openrc usbguard-openrc earlyoom-openrc
        ;;
    runit)
        careful_install \
          dnscrypt-proxy-runit dnsmasq-runit apparmor-runit clamav-runit \
          ufw-runit usbguard-runit earlyoom-runit
        ;;
esac

# AMD-DESKTOP CHOICE
if [ "$choice" = "1" ]; then
  if pacman -Qq | grep -q ''^thunar$''; then
    paru -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin
  fi
  careful_install \
    linux-xanmod-edge-x64v3 linux-xanmod-edge-x64v3-headers \
    vulkan-radeon lib32-vulkan-radeon protonup-git libva-utils \
    fail2ban fail2ban-${INIT_SYSTEM} cpupower cpupower-${INIT_SYSTEM}
fi

# AMD-LAPTOP CHOICE
if [ "$choice" = "2" ]; then
  careful_install \
    linux-x64v3 linux-x64v3-headers \
    vulkan-radeon lib32-vulkan-radeon libva-utils throttled \
    tlp tlp-${INIT_SYSTEM} blueman bluez bluez-${INIT_SYSTEM} brightnessctl
fi

# INTEL-DESKTOP CHOICE
if [ "$choice" = "3" ]; then
  if pacman -Qq | grep -q ''^thunar$''; then
    paru -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin
  fi
  careful_install \
    linux-xanmod-edge-x64v3 linux-xanmod-edge-x64v3-headers \
    vulkan-intel lib32-vulkan-intel protonup-git libva-utils \
    fail2ban fail2ban-${INIT_SYSTEM} cpupower cpupower-${INIT_SYSTEM}
fi

# INTEL-LAPTOP CHOICE
if [ "$choice" = "4" ]; then
  careful_install \
    linux-x64v3 linux-x64v3-headers \
    vulkan-intel lib32-vulkan-intel libva-utils throttled \
    tlp tlp-${INIT_SYSTEM} blueman bluez bluez-${INIT_SYSTEM} brightnessctl
fi

# NVIDIA-OPENSOURCE-DESKTOP CHOICE
if [ "$choice" = "5" ]; then
  if pacman -Qq | grep -q ''^thunar$''; then
    paru -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin
  fi
  careful_install \
    linux-xanmod-edge-x64v3 linux-xanmod-edge-x64v3-headers protonup-git \
    nvidia-utils nvidia-utils-${INIT_SYSTEM} nvidia-settings \
    fail2ban fail2ban-${INIT_SYSTEM} cpupower cpupower-${INIT_SYSTEM} nvidia-open-dkms
  # lib32 NVIDIA / Vulkan fallback
  careful_install lib32-nvidia-utils || careful_install lib32-vulkan-driver
fi

# NVIDIA-PROPRIETARY-DESKTOP CHOICE
if [ "$choice" = "6" ]; then
  if pacman -Qq | grep -q ''^thunar$''; then
    paru -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin
  fi
  careful_install \
    linux-xanmod-edge-x64v3 linux-xanmod-edge-x64v3-headers protonup-git \
    nvidia-utils nvidia-utils-${INIT_SYSTEM} nvidia-settings \
    fail2ban fail2ban-${INIT_SYSTEM} cpupower cpupower-${INIT_SYSTEM} nvidia-dkms
  # lib32 NVIDIA / Vulkan fallback
  careful_install lib32-nvidia-utils || careful_install lib32-vulkan-driver
fi

# IMPORT FLATPAK BETA REPO
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo

# INSTALL PROTON-GE
if pacman -Q protonup-git &>/dev/null; then
    su - "$USER" -c "protonup -d /home/$USER/.local/share/Steam/compatibilitytools.d/ && protonup -y"
fi

### ULU LINUX INSTALL ###

# AMD/INTEL SELECTION
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  unzip -o ulu-dotfiles.zip -d /home/$USER/
  unzip -o ulu-root-main.zip -d /
  unzip -o ulu-root-programs.zip -d /
  unzip -o ulu-root.zip -d /
  add_service fail2ban
  add_service cpupower
fi

# LAPTOP SELECTION
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  unzip -o ulu-dotfiles.zip -d /home/$USER/
  unzip -o ulu-root-main.zip -d /
  unzip -o ulu-root-programs.zip -d /
  unzip -o ulu-root.zip -d /
  unzip -o ulu-root-laptop.zip -d /
  add_service tlp
fi

# NVIDIA SELECTION
if [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  unzip -o ulu-dotfiles.zip -d /home/$USER/
  unzip -o ulu-root-main.zip -d /
  unzip -o ulu-root-programs.zip -d /
  unzip -o ulu-root.zip -d /
  unzip -o ulu-nvidia-patch.zip -d /
  add_service fail2ban
  add_service cpupower
fi

### LAST COMMANDS ###

# ADD SERVICES
add_service apparmor
add_service dnscrypt-proxy
add_service dnsmasq
add_service ufw
add_service earlyoom
add_service usbguard

if pacman -Qq | grep -q ''^thunar$''; then
    add_service NetworkManager
fi

# REMOVE CONNMAN & REFRESH
if pacman -Qi connman &>/dev/null || pacman -Qi connman-s6 &>/dev/null || pacman -Qi connman-openrc &>/dev/null || pacman -Qi connman-runit &>/dev/null; then
    s6-rc -d change connmand || true
    s6 set disable connmand || true
    find /etc/s6 \( -iname '*connman*' -o -iname '*connmand*' \) -print -exec rm -rf {} + || true
    find /etc/runit \( -iname '*connman*' -o -iname '*connmand*' \) -print -exec rm -rf {} + || true
    CONNMAN_PKGS=()
    for pkg in connman connman-s6 connman-openrc connman-runit connman-gtk; do
        pacman -Qi "$pkg" &>/dev/null && CONNMAN_PKGS+=("$pkg")
    done
    pacman -Rdd --noconfirm "${CONNMAN_PKGS[@]}" || true
else
    echo "connman not detected, skipping removal."
fi
# Sync repo after all package installs/removals, then commit and apply set changes
case "$INIT_SYSTEM" in
    s6)
        sync_s6_repo
        reload_s6_db
        ;;
    openrc)
        rc-update -u || true
        ;;
    runit)
        # runsvdir polls /etc/runit/runsvdir/default automatically; no explicit reload step needed
        ;;
esac

grub-mkconfig -o /boot/grub/grub.cfg

# CREATE GAMEMODE GROUP
if [ "$choice" = "1" ] || [ "$choice" = "3" ] || [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  groupadd -f gamemode
  TARGET_USER=$USER
  if [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=$(find /home -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | head -1)
  fi
  usermod -aG gamemode "$TARGET_USER"
  echo "Added user $TARGET_USER to gamemode group"
  if id "$TARGET_USER" | grep -o "gamemode" &>/dev/null; then
    echo "Successfully added to gamemode group"
  else
    echo "Failed to add to gamemode group"
  fi
fi

# ADD USER TO REALTIME
usermod -aG realtime "$(logname)"

# INSTALL UNIVERSAL RC.LOCAL

# s6
if [ -d /etc/s6 ]; then
  mv -f /etc/rc.local /etc/s6/rc.local
  chmod 755 /etc/s6/rc.local
fi

# OpenRC
if [ -d /etc/runlevels ]; then
  mv -f /etc/rc.local /etc/local.d/rc.start
  chmod 755 /etc/local.d/rc.start
  add_service local
fi

# RESET PERMISSIONS
reset-permissions

# HARDENING SCRIPT
hardening-script

# EXIT
cd /
grub-install || true
update-grub
rm -rf /home/ulu-files/
echo -e "\e[1mULU Linux has been successfully installed\e[0m"
reboot

elif command -v xbps-install &>/dev/null; then

######################
# VOID LINUX SECTION #
######################

### SERVICE MANAGEMENT FUNCTIONS ###
add_service() {
    local service_name="$1"
    ln -sf "/etc/sv/$service_name" /var/service/
}

remove_service() {
    local service_name="$1"
    sv down "$service_name" &>/dev/null || true
    rm -f "/var/service/$service_name"
}

### INSTALL PACKAGES ONE BY ONE WITH RETRIES ###
careful_install() {
  local failed_packages=()
  for pkg in "$@"; do
    local success=false
    for attempt in $(seq 1 5); do
      echo "Installing $pkg (attempt $attempt/5)..." >&2
      if xbps-install -y "$pkg"; then
        success=true
        break
      else
        if [ "$attempt" -lt 5 ]; then
          echo "Attempt $attempt failed for $pkg, retrying in 5 seconds..." >&2
          sleep 5
        else
          echo "All 5 attempts failed for $pkg, skipping..." >&2
          failed_packages+=("$pkg")
        fi
      fi
    done
  done

  if [ "${#failed_packages[@]}" -gt 0 ]; then
    echo -e "\e[1mThe following packages failed to install and were skipped:\e[0m" >&2
    for pkg in "${failed_packages[@]}"; do
      echo "  - $pkg" >&2
    done
  fi
}

### ULU LINUX CHOICE SELECTION ###

echo -e "\e[1mSelect a ULU Variant\e[0m"
echo "1. AMD-DESKTOP"
echo "2. AMD-LAPTOP"
echo "3. INTEL-DESKTOP"
echo "4. INTEL-LAPTOP"
echo "5. NVIDIA-OPENSOURCE-DESKTOP"
echo "6. NVIDIA-PROPRIETARY-DESKTOP"

read -p "Enter your choice (1-6): " choice

### FIRST COMMANDS AND ULU-LINUX IMPORT P1 ###
xbps-install -Syu 7zip unzip git xbps
mkdir -p /home/ulu-files/
git clone https://github.com/Michael-Sebero/ULU /home/ulu-files/
cd /home/ulu-files/files/ulu-packages/

# ENABLE NONFREE + MULTILIB REPOS (needed for Steam, NVIDIA, 32-bit libs, etc.)
xbps-install -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
xbps-install -Sy

### FULL SYSTEM UPDATE WITH RETRIES ###
for attempt in $(seq 1 5); do
  echo "Running full system update (attempt $attempt/5)..." >&2
  if xbps-install -Suy; then
    echo "System update succeeded." >&2
    break
  else
    if [ "$attempt" -lt 5 ]; then
      echo "Attempt $attempt failed, retrying in 5 seconds..." >&2
      sleep 5
    else
      echo "All 5 attempts failed for full system update. Continuing anyway..." >&2
    fi
  fi
done
# xbps sometimes updates itself in a separate transaction; run a second pass for the rest
xbps-install -Suy || true

mv /home/ulu-files/files/ulu-manual/Manual /home/$USER/Desktop/

# REMOVE PACKAGES
for pkg in pulseaudio nvidia390 nvidia470 nvidia470-libs-32bit ModemManager; do
    if xbps-query "$pkg" &>/dev/null; then
        xbps-remove -y "$pkg" || true
    fi
done

# INSTALL BASE PACKAGES
careful_install \
  unrar flatpak tmux \
  gamemode dnscrypt-proxy apparmor \
  clamav ufw gufw macchanger earlyoom \
  wine wine-mono winetricks steam lynis rkhunter opendoas \
  pipewire alsa-pipewire wireplumber \
  rust usbguard chkrootkit alsa-utils expect \
  inotify-tools preload dialog tree parallel sof-firmware Vulkan-Tools mimalloc mold \
  protontricks python3-pip ccache yt-dlp \
  libdisplay-info-32bit gallery-dl tesseract-ocr tesseract-ocr-eng \
  fwupd chrony dnsmasq mesa mesa-32bit tk scx libgamemode-32bit nix

# Headers for the currently running/installed kernel (needed by DKMS drivers like NVIDIA).
KVER=$(uname -r | cut -d. -f1-2)
if [ -n "$KVER" ]; then
  careful_install "linux${KVER}-headers"
fi

# INSTALL PYTHON PACKAGES
careful_install \
  python3-dateutil python3-xlib python3-PyAudio python3-pipenv \
  python3-matplotlib python3-tqdm python3-magic \
  python3-piexif python3-websockets \

# INSTALL XFCE PACKAGES
if xbps-query thunar &>/dev/null; then
    careful_install \
      NetworkManager seahorse ffmpegthumbnailer \
else
    echo "Thunar not detected, skipping XFCE packages."
fi

# AMD-DESKTOP CHOICE
if [ "$choice" = "1" ]; then
  if xbps-query thunar &>/dev/null; then
    xbps-remove -y xfce4-power-manager xfce4-battery-plugin || true
  fi
  careful_install \
    mesa-vulkan-radeon mesa-vulkan-radeon-32bit libva-utils \
    fail2ban cpupower
fi

# AMD-LAPTOP CHOICE
if [ "$choice" = "2" ]; then
  careful_install \
    mesa-vulkan-radeon mesa-vulkan-radeon-32bit libva-utils \
    tlp blueman bluez brightnessctl
fi

# INTEL-DESKTOP CHOICE
if [ "$choice" = "3" ]; then
  if xbps-query thunar &>/dev/null; then
    xbps-remove -y xfce4-power-manager xfce4-battery-plugin || true
  fi
  careful_install \
    mesa-vulkan-intel mesa-vulkan-intel-32bit libva-utils \
    fail2ban cpupower
fi

# INTEL-LAPTOP CHOICE
if [ "$choice" = "4" ]; then
  careful_install \
    mesa-vulkan-intel mesa-vulkan-intel-32bit libva-utils \
    tlp blueman bluez brightnessctl
fi

# NVIDIA-OPENSOURCE-DESKTOP CHOICE
if [ "$choice" = "5" ]; then
  if xbps-query thunar &>/dev/null; then
    xbps-remove -y xfce4-power-manager xfce4-battery-plugin || true
  fi
  careful_install \
    nvidia nvidia-libs-32bit \
    fail2ban cpupower
fi

# NVIDIA-PROPRIETARY-DESKTOP CHOICE
if [ "$choice" = "6" ]; then
  if xbps-query thunar &>/dev/null; then
    xbps-remove -y xfce4-power-manager xfce4-battery-plugin || true
  fi
  careful_install \
    nvidia580 nvidia580-libs-32bit \
    fail2ban cpupower
fi

# IMPORT FLATPAK BETA REPO
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo

# INSTALL PROTON-GE
if xbps-query protonup-ng &>/dev/null; then
    su - "$USER" -c "protonup -d /home/$USER/.local/share/Steam/compatibilitytools.d/ && protonup -y"
fi

### ULU LINUX INSTALL ###

# AMD/INTEL SELECTION
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  unzip -o ulu-dotfiles.zip -d /home/$USER/
  unzip -o ulu-root-main.zip -d /
  unzip -o ulu-root-programs.zip -d /
  unzip -o ulu-root.zip -d /
  add_service fail2ban
  add_service cpupower
fi

# LAPTOP SELECTION
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  unzip -o ulu-dotfiles.zip -d /home/$USER/
  unzip -o ulu-root-main.zip -d /
  unzip -o ulu-root-programs.zip -d /
  unzip -o ulu-root.zip -d /
  unzip -o ulu-root-laptop.zip -d /
  add_service tlp
fi

# NVIDIA SELECTION
if [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  unzip -o ulu-dotfiles.zip -d /home/$USER/
  unzip -o ulu-root-main.zip -d /
  unzip -o ulu-root-programs.zip -d /
  unzip -o ulu-root.zip -d /
  unzip -o ulu-nvidia-patch.zip -d /
  add_service fail2ban
  add_service cpupower
fi

### LAST COMMANDS ###

# ADD SERVICES
add_service apparmor
add_service dnscrypt-proxy
add_service dnsmasq
add_service ufw
add_service earlyoom
add_service usbguard

if xbps-query thunar &>/dev/null; then
    add_service NetworkManager
fi

# REMOVE CONNMAN & REFRESH
if xbps-query connman &>/dev/null; then
    sv down connmand &>/dev/null || true
    rm -f /var/service/connmand
    find /etc/sv -maxdepth 1 -iname "*connman*" -print -exec rm -rf {} + || true
    xbps-remove -y connman connman-gtk || true
else
    echo "connman not detected, skipping removal."
fi

grub-mkconfig -o /boot/grub/grub.cfg

# CREATE GAMEMODE GROUP
if [ "$choice" = "1" ] || [ "$choice" = "3" ] || [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  groupadd -f gamemode
  TARGET_USER=$USER
  if [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=$(find /home -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | head -1)
  fi
  usermod -aG gamemode "$TARGET_USER"
  echo "Added user $TARGET_USER to gamemode group"
  if id "$TARGET_USER" | grep -o "gamemode" &>/dev/null; then
    echo "Successfully added to gamemode group"
  else
    echo "Failed to add to gamemode group"
  fi
fi

# ADD USER TO REALTIME
groupadd -f realtime
usermod -aG realtime "$(logname)"

# RESET PERMISSIONS
reset-permissions

# HARDENING SCRIPT
hardening-script

# EXIT
cd /
grub-install || true
rm -rf /home/ulu-files/
echo -e "\e[1mULU Linux has been successfully installed\e[0m"
reboot

else

###############################################
# DEBIAN/UBUNTU/OPENSUSE/FEDORA LINUX SECTION #
###############################################

### PACKAGE MANAGER / DISTRO DETECTION ###
if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
elif command -v zypper &>/dev/null; then
    PKG_MANAGER="zypper"
else
    echo "Unsupported distribution. This section supports Linux Mint, Ubuntu, Fedora and OpenSUSE." >&2
    exit 1
fi

DISTRO_ID="unknown"
if [ -f /etc/os-release ]; then
    DISTRO_ID=$(. /etc/os-release && echo "$ID")
fi

echo -e "\e[1mDetected distribution: $DISTRO_ID ($PKG_MANAGER)\e[0m"

### INIT SYSTEM ###
# Linux Mint, Ubuntu, Fedora and OpenSUSE all ship systemd.
INIT_SYSTEM="systemd"

### SERVICE MANAGEMENT FUNCTIONS ###
add_service() {
    local service_name="$1"
    systemctl enable "$service_name" &>/dev/null || true
}

remove_service() {
    local service_name="$1"
    systemctl disable "$service_name" &>/dev/null || true
}

### PACKAGE NAME MAPPING ###
# Translates the canonical package name used throughout this script (the
# same names the Artix/Void sections above install) into whatever apt, dnf
# or zypper calls it. Echoes "" for anything with no equivalent, or that is
# handled separately below - careful_install() just skips those quietly.
map_package_names() {
    local base_pkg="$1"
    case "$PKG_MANAGER" in
        apt)
            case "$base_pkg" in
                unrar) echo "unrar" ;;
                flatpak) echo "flatpak" ;;
                gamemode) echo "gamemode" ;;
                lib32-gamemode) echo "libgamemode0:i386" ;;
                dnscrypt-proxy) echo "dnscrypt-proxy" ;;
                dnsmasq) echo "dnsmasq" ;;
                apparmor) echo "apparmor apparmor-utils" ;;
                gufw) echo "gufw" ;;
                macchanger) echo "macchanger" ;;
                wine) echo "wine" ;;
                wine-mono) echo "" ;;
                winetricks) echo "winetricks" ;;
                steam) echo "steam-installer" ;;
                lynis) echo "lynis" ;;
                rkhunter) echo "rkhunter" ;;
                usbguard) echo "usbguard" ;;
                chkrootkit) echo "chkrootkit" ;;
                expect) echo "expect" ;;
                inotify-tools) echo "inotify-tools" ;;
                preload) echo "preload" ;;
                dialog) echo "dialog" ;;
                tree) echo "tree" ;;
                parallel) echo "parallel" ;;
                sof-firmware) echo "firmware-sof-signed" ;;
                booster) echo "" ;;
                vulkan-tools) echo "vulkan-tools" ;;
                mimalloc) echo "libmimalloc2.0" ;;
                mold) echo "mold" ;;
                protontricks) echo "" ;;
                poetry) echo "" ;;
                pyenv) echo "" ;;
                python-pip) echo "python3-pip" ;;
                ccache) echo "ccache" ;;
                yt-dlp) echo "yt-dlp" ;;
                lib32-libdisplay-info) echo "" ;;
                realtime-privileges) echo "" ;;
                gallery-dl) echo "gallery-dl" ;;
                tesseract-data-eng) echo "tesseract-ocr-eng" ;;
                debtap) echo "" ;;
                downgrade) echo "" ;;
                opendoas) echo "doas" ;;
                rust) echo "rustc cargo" ;;
                scx-scheds) echo "" ;;
                fwupd) echo "fwupd" ;;
                chrony) echo "chrony" ;;
                mesa) echo "mesa-utils" ;;
                lib32-mesa) echo "libgl1-mesa-dri:i386" ;;
                tk) echo "tk" ;;
                nix) echo "" ;;
                networkmanager) echo "network-manager" ;;
                seahorse) echo "seahorse" ;;
                ffmpegthumbnailer) echo "ffmpegthumbnailer" ;;
                libva-utils) echo "libva-utils" ;;
                clamav) echo "clamav clamav-daemon" ;;
                earlyoom) echo "earlyoom" ;;
                fail2ban) echo "fail2ban" ;;
                cpupower) echo "linux-tools-common linux-tools-generic" ;;
                tlp) echo "tlp tlp-rdw" ;;
                throttled) echo "" ;;
                blueman) echo "blueman" ;;
                bluez) echo "bluez" ;;
                brightnessctl) echo "brightnessctl" ;;
                vulkan-driver) echo "mesa-vulkan-drivers" ;;
                lib32-vulkan-driver) echo "mesa-vulkan-drivers:i386" ;;
                python-dateutil) echo "python3-dateutil" ;;
                python-xlib) echo "python3-xlib" ;;
                python-pyaudio) echo "python3-pyaudio" ;;
                python-pipenv) echo "pipenv" ;;
                python-matplotlib) echo "python3-matplotlib" ;;
                python-tqdm) echo "python3-tqdm" ;;
                python-magic) echo "python3-magic" ;;
                python-piexif) echo "python3-piexif" ;;
                python-moviepy) echo "" ;;
                python-brotli) echo "python3-brotli" ;;
                python-websockets) echo "python3-websockets" ;;
                python-librosa) echo "" ;;
                python-pypdf2) echo "python3-pypdf2" ;;
                python-pytesseract) echo "python3-pytesseract" ;;
                *) echo "$base_pkg" ;;
            esac
            ;;
        dnf)
            case "$base_pkg" in
                unrar) echo "unrar" ;;
                flatpak) echo "flatpak" ;;
                gamemode) echo "gamemode" ;;
                lib32-gamemode) echo "gamemode.i686" ;;
                dnscrypt-proxy) echo "dnscrypt-proxy" ;;
                dnsmasq) echo "dnsmasq" ;;
                apparmor) echo "" ;;
                gufw) echo "firewall-config" ;;
                macchanger) echo "macchanger" ;;
                wine) echo "wine" ;;
                wine-mono) echo "" ;;
                winetricks) echo "winetricks" ;;
                steam) echo "steam" ;;
                lynis) echo "lynis" ;;
                rkhunter) echo "rkhunter" ;;
                usbguard) echo "usbguard" ;;
                chkrootkit) echo "chkrootkit" ;;
                expect) echo "expect" ;;
                inotify-tools) echo "inotify-tools" ;;
                preload) echo "" ;;
                dialog) echo "dialog" ;;
                tree) echo "tree" ;;
                parallel) echo "parallel" ;;
                sof-firmware) echo "alsa-sof-firmware" ;;
                booster) echo "" ;;
                vulkan-tools) echo "vulkan-tools" ;;
                mimalloc) echo "mimalloc" ;;
                mold) echo "mold" ;;
                protontricks) echo "" ;;
                poetry) echo "" ;;
                pyenv) echo "" ;;
                python-pip) echo "python3-pip" ;;
                ccache) echo "ccache" ;;
                yt-dlp) echo "yt-dlp" ;;
                lib32-libdisplay-info) echo "" ;;
                realtime-privileges) echo "" ;;
                gallery-dl) echo "gallery-dl" ;;
                tesseract-data-eng) echo "tesseract-langpack-eng" ;;
                debtap) echo "" ;;
                downgrade) echo "" ;;
                opendoas) echo "doas" ;;
                rust) echo "rust cargo" ;;
                scx-scheds) echo "" ;;
                fwupd) echo "fwupd" ;;
                chrony) echo "chrony" ;;
                mesa) echo "glx-utils" ;;
                lib32-mesa) echo "mesa-dri-drivers.i686" ;;
                tk) echo "tk" ;;
                nix) echo "" ;;
                networkmanager) echo "NetworkManager" ;;
                seahorse) echo "seahorse" ;;
                ffmpegthumbnailer) echo "ffmpegthumbnailer" ;;
                libva-utils) echo "libva-utils" ;;
                clamav) echo "clamav clamav-update" ;;
                earlyoom) echo "earlyoom" ;;
                fail2ban) echo "fail2ban fail2ban-firewalld" ;;
                cpupower) echo "kernel-tools" ;;
                tlp) echo "tlp" ;;
                throttled) echo "" ;;
                blueman) echo "blueman" ;;
                bluez) echo "bluez" ;;
                brightnessctl) echo "brightnessctl" ;;
                vulkan-driver) echo "mesa-vulkan-drivers" ;;
                lib32-vulkan-driver) echo "mesa-vulkan-drivers.i686" ;;
                python-dateutil) echo "python3-dateutil" ;;
                python-xlib) echo "python3-xlib" ;;
                python-pyaudio) echo "python3-pyaudio" ;;
                python-pipenv) echo "pipenv" ;;
                python-matplotlib) echo "python3-matplotlib" ;;
                python-tqdm) echo "python3-tqdm" ;;
                python-magic) echo "python3-magic" ;;
                python-piexif) echo "python3-piexif" ;;
                python-moviepy) echo "" ;;
                python-brotli) echo "python3-brotli" ;;
                python-websockets) echo "python3-websockets" ;;
                python-librosa) echo "" ;;
                python-pypdf2) echo "python3-pypdf2" ;;
                python-pytesseract) echo "python3-pytesseract" ;;
                *) echo "$base_pkg" ;;
            esac
            ;;
        zypper)
            case "$base_pkg" in
                unrar) echo "unrar" ;;
                flatpak) echo "flatpak" ;;
                gamemode) echo "gamemode" ;;
                lib32-gamemode) echo "gamemode-32bit" ;;
                dnscrypt-proxy) echo "dnscrypt-proxy" ;;
                dnsmasq) echo "dnsmasq" ;;
                apparmor) echo "apparmor apparmor-utils" ;;
                gufw) echo "firewall-config" ;;
                macchanger) echo "macchanger" ;;
                wine) echo "wine" ;;
                wine-mono) echo "" ;;
                winetricks) echo "winetricks" ;;
                steam) echo "steam" ;;
                lynis) echo "lynis" ;;
                rkhunter) echo "rkhunter" ;;
                usbguard) echo "usbguard" ;;
                chkrootkit) echo "chkrootkit" ;;
                expect) echo "expect" ;;
                inotify-tools) echo "inotify-tools" ;;
                preload) echo "" ;;
                dialog) echo "dialog" ;;
                tree) echo "tree" ;;
                parallel) echo "parallel" ;;
                sof-firmware) echo "sof-firmware" ;;
                booster) echo "" ;;
                vulkan-tools) echo "vulkan-tools" ;;
                mimalloc) echo "mimalloc" ;;
                mold) echo "mold" ;;
                protontricks) echo "" ;;
                poetry) echo "" ;;
                pyenv) echo "" ;;
                python-pip) echo "python3-pip" ;;
                ccache) echo "ccache" ;;
                yt-dlp) echo "yt-dlp" ;;
                lib32-libdisplay-info) echo "" ;;
                realtime-privileges) echo "" ;;
                gallery-dl) echo "gallery-dl" ;;
                tesseract-data-eng) echo "tesseract-ocr-traineddata-english" ;;
                debtap) echo "" ;;
                downgrade) echo "" ;;
                opendoas) echo "doas" ;;
                rust) echo "rust cargo" ;;
                scx-scheds) echo "scx" ;;
                fwupd) echo "fwupd" ;;
                chrony) echo "chrony" ;;
                mesa) echo "Mesa-demo-x" ;;
                lib32-mesa) echo "Mesa-libGL1-32bit" ;;
                tk) echo "tk" ;;
                nix) echo "" ;;
                networkmanager) echo "NetworkManager" ;;
                seahorse) echo "seahorse" ;;
                ffmpegthumbnailer) echo "ffmpegthumbnailer" ;;
                libva-utils) echo "libva-utils" ;;
                clamav) echo "clamav" ;;
                earlyoom) echo "earlyoom" ;;
                fail2ban) echo "fail2ban" ;;
                cpupower) echo "cpupower" ;;
                tlp) echo "tlp" ;;
                throttled) echo "" ;;
                blueman) echo "blueman" ;;
                bluez) echo "bluez" ;;
                brightnessctl) echo "brightnessctl" ;;
                vulkan-driver) echo "Mesa-vulkan-drivers" ;;
                lib32-vulkan-driver) echo "Mesa-vulkan-drivers-32bit" ;;
                python-dateutil) echo "python3-python-dateutil" ;;
                python-xlib) echo "python3-python-xlib" ;;
                python-pyaudio) echo "python3-PyAudio" ;;
                python-pipenv) echo "python3-pipenv" ;;
                python-matplotlib) echo "python3-matplotlib" ;;
                python-tqdm) echo "python3-tqdm" ;;
                python-magic) echo "python3-python-magic" ;;
                python-piexif) echo "python3-piexif" ;;
                python-moviepy) echo "" ;;
                python-brotli) echo "python3-Brotli" ;;
                python-websockets) echo "python3-websockets" ;;
                python-librosa) echo "" ;;
                python-pypdf2) echo "python3-PyPDF2" ;;
                python-pytesseract) echo "python3-pytesseract" ;;
                *) echo "$base_pkg" ;;
            esac
            ;;
    esac
}

### INSTALL PACKAGES ONE BY ONE WITH RETRIES (already-correct distro package names) ###
careful_install_raw() {
    local failed_packages=()
    for pkg in "$@"; do
        local success=false
        for attempt in $(seq 1 5); do
            echo "Installing $pkg (attempt $attempt/5)..." >&2
            local result=0
            case "$PKG_MANAGER" in
                apt)    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" || result=$? ;;
                dnf)    dnf install -y "$pkg" || result=$? ;;
                zypper) zypper --non-interactive install --no-recommends "$pkg" || result=$? ;;
            esac
            if [ "$result" -eq 0 ]; then
                success=true
                break
            else
                if [ "$attempt" -lt 5 ]; then
                    echo "Attempt $attempt failed for $pkg, retrying in 5 seconds..." >&2
                    sleep 5
                else
                    echo "All 5 attempts failed for $pkg, skipping..." >&2
                    failed_packages+=("$pkg")
                fi
            fi
        done
    done

    if [ "${#failed_packages[@]}" -gt 0 ]; then
        echo -e "\e[1mThe following packages failed to install and were skipped:\e[0m" >&2
        for pkg in "${failed_packages[@]}"; do
            echo "  - $pkg" >&2
        done
    fi
}

### INSTALL PACKAGES ONE BY ONE WITH RETRIES (canonical Artix/Void-style names) ###
careful_install() {
    local mapped_all=()
    for base_pkg in "$@"; do
        local mapped
        mapped=$(map_package_names "$base_pkg")
        if [ -n "$mapped" ]; then
            mapped_all+=($mapped)
        fi
    done
    if [ "${#mapped_all[@]}" -gt 0 ]; then
        careful_install_raw "${mapped_all[@]}"
    fi
}

### ULU LINUX CHOICE SELECTION ###

echo -e "\e[1mSelect a ULU Variant\e[0m"
echo "1. AMD-DESKTOP"
echo "2. AMD-LAPTOP"
echo "3. INTEL-DESKTOP"
echo "4. INTEL-LAPTOP"
echo "5. NVIDIA-OPENSOURCE-DESKTOP"
echo "6. NVIDIA-PROPRIETARY-DESKTOP"

read -p "Enter your choice (1-6): " choice

### INITIAL SETUP & PREREQUISITE TOOLS ###
echo -e "\e[1mUpdating package lists...\e[0m"
case "$PKG_MANAGER" in
    apt)
        export DEBIAN_FRONTEND=noninteractive
        dpkg --add-architecture i386
        apt-get update
        apt-get install -y --no-install-recommends ca-certificates curl gnupg wget git unzip p7zip-full software-properties-common apt-transport-https
        ;;
    dnf)
        dnf install -y dnf-plugins-core git unzip p7zip curl wget
        ;;
    zypper)
        zypper --non-interactive install curl wget git unzip p7zip gpg2
        ;;
esac

### ENABLE ADDITIONAL REPOSITORIES ###
echo -e "\e[1mEnabling additional repositories...\e[0m"
case "$PKG_MANAGER" in
    apt)
        if command -v add-apt-repository &>/dev/null; then
            add-apt-repository -y universe 2>/dev/null || true
            add-apt-repository -y multiverse 2>/dev/null || true
        fi
        apt-get update
        ;;
    dnf)
        FEDORA_VER=$(rpm -E %fedora)
        dnf install -y --nogpgcheck \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" || true
        dnf config-manager --set-enabled crb 2>/dev/null || true
        dnf makecache
        ;;
    zypper)
        . /etc/os-release
        if [ "$ID" = "opensuse-tumbleweed" ]; then
            PACKMAN_URL="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/"
            NVIDIA_URL="https://download.nvidia.com/opensuse/tumbleweed/"
        else
            PACKMAN_URL="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${VERSION_ID}/"
            NVIDIA_URL="https://download.nvidia.com/opensuse/leap/${VERSION_ID}/"
        fi
        zypper --non-interactive addrepo -cfp 90 "$PACKMAN_URL" packman 2>/dev/null || true
        zypper --non-interactive addrepo -f "$NVIDIA_URL" nvidia 2>/dev/null || true
        zypper --gpg-auto-import-keys refresh
        ;;
esac

### FIRST COMMANDS AND ULU-LINUX IMPORT P1 ###
mkdir -p /home/ulu-files/
git clone https://github.com/Michael-Sebero/ULU /home/ulu-files/
cd /home/ulu-files/files/ulu-packages/

### FULL SYSTEM UPDATE WITH RETRIES ###
for attempt in $(seq 1 5); do
    echo "Running full system update (attempt $attempt/5)..." >&2
    result=0
    case "$PKG_MANAGER" in
        apt)    DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade || result=$? ;;
        dnf)    dnf upgrade -y --refresh || result=$? ;;
        zypper) zypper --non-interactive update || result=$? ;;
    esac
    if [ "$result" -eq 0 ]; then
        echo "System update succeeded." >&2
        break
    else
        if [ "$attempt" -lt 5 ]; then
            echo "Attempt $attempt failed, retrying in 5 seconds..." >&2
            sleep 5
        else
            echo "All 5 attempts failed for full system update. Continuing anyway..." >&2
        fi
    fi
done

mv /home/ulu-files/files/ulu-manual/Manual /home/$USER/Desktop/

### REMOVE CONFLICTING PACKAGES ###
case "$PKG_MANAGER" in
    apt)
        for pkg in pulseaudio pulseaudio-module-bluetooth modemmanager; do
            if dpkg -s "$pkg" &>/dev/null; then
                apt-get purge -y "$pkg" || true
            fi
        done
        ;;
    dnf|zypper)
        for pkg in pulseaudio ModemManager; do
            if rpm -q "$pkg" &>/dev/null; then
                case "$PKG_MANAGER" in
                    dnf)    dnf remove -y "$pkg" || true ;;
                    zypper) zypper --non-interactive remove "$pkg" || true ;;
                esac
            fi
        done
        ;;
esac

### INSTALL BASE PACKAGES ###
careful_install \
  unrar flatpak gamemode lib32-gamemode dnscrypt-proxy apparmor \
  clamav gufw macchanger wine wine-mono winetricks steam lynis rkhunter opendoas \
  rust usbguard chkrootkit expect earlyoom \
  inotify-tools preload dialog tree parallel sof-firmware vulkan-tools mimalloc mold \
  python-pip ccache yt-dlp \
  realtime-privileges gallery-dl tesseract-data-eng \
  fwupd chrony dnsmasq mesa lib32-mesa tk

### INSTALL NIX PACKAGE MANAGER ###
# No native package on these distros; the official multi-user installer
# works identically regardless of PKG_MANAGER.
if ! command -v nix &>/dev/null; then
    echo -e "\e[1mInstalling the Nix package manager...\e[0m"
    sh <(curl -L https://nixos.org/nix/install) --daemon --yes || echo "Nix installation failed, skipping." >&2
fi

### INSTALL SCX-SCHEDS (kernel 6.12+ only) ###
check_kernel_version() {
    local kernel_version
    kernel_version=$(uname -r | cut -d. -f1,2)
    local major minor
    major=$(echo "$kernel_version" | cut -d. -f1)
    minor=$(echo "$kernel_version" | cut -d. -f2)
    if [ "$major" -gt 6 ] || { [ "$major" -eq 6 ] && [ "$minor" -ge 12 ]; }; then
        return 0
    else
        return 1
    fi
}

if check_kernel_version; then
    echo -e "\e[1mKernel is 6.12+, installing scx-scheds...\e[0m"
    case "$PKG_MANAGER" in
        apt)
            echo "No scx-scheds package on apt-based systems; skipping (build it from source if you need it)."
            ;;
        dnf)
            dnf copr enable -y bieszczaders/kernel-cachyos-addons 2>/dev/null || true
            careful_install_raw scx-scheds
            ;;
        zypper)
            careful_install_raw scx
            ;;
    esac
else
    echo "Kernel is below 6.12, skipping scx-scheds installation." >&2
fi

### INSTALL PYTHON PACKAGES ###
careful_install \
  python-dateutil python-xlib python-pyaudio python-pipenv \
  python-matplotlib python-tqdm python-magic \
  python-piexif python-moviepy python-brotli python-websockets python-librosa \
  python-pypdf2 python-pytesseract

### INSTALL XFCE PACKAGES ###
if command -v thunar &>/dev/null; then
    careful_install \
      networkmanager seahorse ffmpegthumbnailer
    add_service NetworkManager
else
    echo "Thunar not detected, skipping XFCE packages."
fi

### CPU MICROARCHITECTURE DETECTION (used for the XanMod kernel on apt systems) ###
arch_support=$(/lib/ld-linux-x86-64.so.2 --help 2>&1 | grep supported | head -n 1 | awk "{print \$1}")
XANMOD_SUFFIX="x64v3"
if [ "$arch_support" = "x86-64-v4" ]; then
    XANMOD_SUFFIX="x64v4"
fi

### XANMOD KERNEL HELPER (apt-based systems only) ###
setup_xanmod_repo() {
    if [ -f /etc/apt/sources.list.d/xanmod-release.list ]; then
        return 0
    fi
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://dl.xanmod.org/archive.key | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg
    XANMOD_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
    echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org $XANMOD_CODENAME main" > /etc/apt/sources.list.d/xanmod-release.list
    apt-get update
}

install_xanmod_kernel() {
    local flavor="$1"
    setup_xanmod_repo
    local kernel_pkg="linux-xanmod-${XANMOD_SUFFIX}"
    if [ -n "$flavor" ]; then
        kernel_pkg="linux-xanmod-${flavor}-${XANMOD_SUFFIX}"
    fi
    careful_install_raw "$kernel_pkg" || careful_install_raw "linux-xanmod-${XANMOD_SUFFIX}" || careful_install_raw linux-xanmod
}

# AMD-DESKTOP CHOICE
if [ "$choice" = "1" ]; then
    if command -v thunar &>/dev/null; then
        case "$PKG_MANAGER" in
            apt)    apt-get purge -y xfce4-power-manager xfce4-battery-plugin || true ;;
            dnf)    dnf remove -y xfce4-power-manager xfce4-battery-plugin || true ;;
            zypper) zypper --non-interactive remove xfce4-power-manager xfce4-battery-plugin || true ;;
        esac
    fi
    if [ "$PKG_MANAGER" = "apt" ]; then
        install_xanmod_kernel edge
    fi
    careful_install vulkan-driver lib32-vulkan-driver libva-utils fail2ban cpupower
fi

# AMD-LAPTOP CHOICE
if [ "$choice" = "2" ]; then
    if [ "$PKG_MANAGER" = "apt" ]; then
        install_xanmod_kernel ""
    fi
    careful_install vulkan-driver lib32-vulkan-driver libva-utils tlp blueman bluez brightnessctl
fi

# INTEL-DESKTOP CHOICE
if [ "$choice" = "3" ]; then
    if command -v thunar &>/dev/null; then
        case "$PKG_MANAGER" in
            apt)    apt-get purge -y xfce4-power-manager xfce4-battery-plugin || true ;;
            dnf)    dnf remove -y xfce4-power-manager xfce4-battery-plugin || true ;;
            zypper) zypper --non-interactive remove xfce4-power-manager xfce4-battery-plugin || true ;;
        esac
    fi
    if [ "$PKG_MANAGER" = "apt" ]; then
        install_xanmod_kernel edge
    fi
    # Mesa Vulkan driver package covers both AMD and Intel on this distro
    # family, unlike the Arch split vulkan-radeon/vulkan-intel packages.
    careful_install vulkan-driver lib32-vulkan-driver libva-utils fail2ban cpupower
fi

# INTEL-LAPTOP CHOICE
if [ "$choice" = "4" ]; then
    if [ "$PKG_MANAGER" = "apt" ]; then
        install_xanmod_kernel ""
    fi
    careful_install vulkan-driver lib32-vulkan-driver libva-utils tlp blueman bluez brightnessctl
fi

# NVIDIA-OPENSOURCE-DESKTOP CHOICE
if [ "$choice" = "5" ]; then
    if command -v thunar &>/dev/null; then
        case "$PKG_MANAGER" in
            apt)    apt-get purge -y xfce4-power-manager xfce4-battery-plugin || true ;;
            dnf)    dnf remove -y xfce4-power-manager xfce4-battery-plugin || true ;;
            zypper) zypper --non-interactive remove xfce4-power-manager xfce4-battery-plugin || true ;;
        esac
    fi
    case "$PKG_MANAGER" in
        apt)
            install_xanmod_kernel edge
            apt-get install -y --no-install-recommends ubuntu-drivers-common 2>/dev/null || true
            RECOMMENDED_DRIVER=$(ubuntu-drivers devices 2>/dev/null | awk "/recommended/{print \$3}" | head -n1)
            if [ -n "$RECOMMENDED_DRIVER" ]; then
                careful_install_raw "${RECOMMENDED_DRIVER}-open" || careful_install_raw "$RECOMMENDED_DRIVER"
            else
                ubuntu-drivers autoinstall || true
            fi
            ;;
        dnf)
            careful_install_raw akmod-nvidia-open xorg-x11-drv-nvidia-cuda
            ;;
        zypper)
            NVIDIA_OPEN_PKG=$(zypper --non-interactive packages -r nvidia 2>/dev/null | awk -F"|" "{print \$3}" | grep -E "^ *nvidia-open-driver-G[0-9]+-signed-kmp-default *$" | head -n1 | tr -d " ")
            if [ -n "$NVIDIA_OPEN_PKG" ]; then
                careful_install_raw "$NVIDIA_OPEN_PKG"
            else
                zypper --non-interactive install-new-recommends --repo nvidia || true
            fi
            ;;
    esac
    careful_install libva-utils fail2ban cpupower
fi

# NVIDIA-PROPRIETARY-DESKTOP CHOICE
if [ "$choice" = "6" ]; then
    if command -v thunar &>/dev/null; then
        case "$PKG_MANAGER" in
            apt)    apt-get purge -y xfce4-power-manager xfce4-battery-plugin || true ;;
            dnf)    dnf remove -y xfce4-power-manager xfce4-battery-plugin || true ;;
            zypper) zypper --non-interactive remove xfce4-power-manager xfce4-battery-plugin || true ;;
        esac
    fi
    case "$PKG_MANAGER" in
        apt)
            install_xanmod_kernel edge
            apt-get install -y --no-install-recommends ubuntu-drivers-common 2>/dev/null || true
            RECOMMENDED_DRIVER=$(ubuntu-drivers devices 2>/dev/null | awk "/recommended/{print \$3}" | head -n1)
            if [ -n "$RECOMMENDED_DRIVER" ]; then
                careful_install_raw "$RECOMMENDED_DRIVER"
            else
                ubuntu-drivers autoinstall || true
            fi
            ;;
        dnf)
            careful_install_raw akmod-nvidia xorg-x11-drv-nvidia-cuda
            ;;
        zypper)
            NVIDIA_PROP_PKG=$(zypper --non-interactive packages -r nvidia 2>/dev/null | awk -F"|" "{print \$3}" | grep -E "^ *nvidia-driver-G[0-9]+-kmp-default *$" | head -n1 | tr -d " ")
            if [ -n "$NVIDIA_PROP_PKG" ]; then
                careful_install_raw "$NVIDIA_PROP_PKG"
            else
                zypper --non-interactive install-new-recommends --repo nvidia || true
            fi
            ;;
    esac
    careful_install libva-utils fail2ban cpupower
fi

### IMPORT FLATHUB + FLATPAK BETA REPOS ###
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo

### INSTALL PROTON-GE ###
# ProtonUp-Qt (Flatpak) replaces the Arch-only protonup-git CLI tool and
# works identically across every distro this section supports.
if command -v flatpak &>/dev/null; then
    flatpak install -y flathub net.davidotek.pupgui2 2>/dev/null || echo "ProtonUp-Qt install failed, skipping." >&2
fi

### ULU LINUX INSTALL ###

# AMD/INTEL SELECTION
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
    unzip -o ulu-dotfiles.zip -d /home/$USER/
    unzip -o ulu-root-main.zip -d /
    unzip -o ulu-root-programs.zip -d /
    unzip -o ulu-root.zip -d /
    add_service fail2ban
    add_service cpupower
fi

# LAPTOP SELECTION
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
    unzip -o ulu-dotfiles.zip -d /home/$USER/
    unzip -o ulu-root-main.zip -d /
    unzip -o ulu-root-programs.zip -d /
    unzip -o ulu-root.zip -d /
    unzip -o ulu-root-laptop.zip -d /
    add_service tlp
fi

# NVIDIA SELECTION
if [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
    unzip -o ulu-dotfiles.zip -d /home/$USER/
    unzip -o ulu-root-main.zip -d /
    unzip -o ulu-root-programs.zip -d /
    unzip -o ulu-root.zip -d /
    unzip -o ulu-nvidia-patch.zip -d /
    add_service fail2ban
    add_service cpupower
fi

### INSTALL UNIVERSAL RC.LOCAL (systemd compatibility unit) ###
case "$PKG_MANAGER" in
    dnf|zypper) RC_LOCAL_PATH="/etc/rc.d/rc.local" ;;
    apt)        RC_LOCAL_PATH="/etc/rc.local" ;;
esac

if [ -f /etc/rc.local ] && [ "/etc/rc.local" != "$RC_LOCAL_PATH" ]; then
    mkdir -p "$(dirname "$RC_LOCAL_PATH")"
    mv /etc/rc.local "$RC_LOCAL_PATH"
fi
if [ -f "$RC_LOCAL_PATH" ]; then
    chmod +x "$RC_LOCAL_PATH"
    if ! grep -q "^exit 0" "$RC_LOCAL_PATH"; then
        echo "" >> "$RC_LOCAL_PATH"
        echo "exit 0" >> "$RC_LOCAL_PATH"
    fi

    if [ ! -f /etc/systemd/system/rc-local.service ]; then
cat > /etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local Compatibility
ConditionFileIsExecutable=$RC_LOCAL_PATH
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$RC_LOCAL_PATH start
TimeoutSec=0
StandardOutput=journal+console
StandardError=journal+console
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    add_service rc-local
fi

### LAST COMMANDS ###

# ADD SERVICES
add_service apparmor
add_service dnscrypt-proxy
add_service dnsmasq
add_service earlyoom
add_service usbguard
if command -v ufw &>/dev/null; then
    add_service ufw
fi
if command -v firewalld &>/dev/null; then
    add_service firewalld
fi

# REMOVE CONNMAN & REFRESH
CONNMAN_INSTALLED=false
case "$PKG_MANAGER" in
    apt)        dpkg -s connman &>/dev/null && CONNMAN_INSTALLED=true ;;
    dnf|zypper) rpm -q connman &>/dev/null && CONNMAN_INSTALLED=true ;;
esac
if [ "$CONNMAN_INSTALLED" = true ]; then
    systemctl disable --now connman 2>/dev/null || true
    case "$PKG_MANAGER" in
        apt)    apt-get purge -y connman connman-gtk || true ;;
        dnf)    dnf remove -y connman || true ;;
        zypper) zypper --non-interactive remove connman || true ;;
    esac
else
    echo "connman not detected, skipping removal."
fi

case "$PKG_MANAGER" in
    apt)        update-grub 2>/dev/null || true ;;
    dnf|zypper) grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true ;;
esac

# CREATE GAMEMODE GROUP
if [ "$choice" = "1" ] || [ "$choice" = "3" ] || [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
    groupadd -f gamemode
    TARGET_USER=$USER
    if [ "$TARGET_USER" = "root" ]; then
        TARGET_USER=$(find /home -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | head -1)
    fi
    usermod -aG gamemode "$TARGET_USER"
    echo "Added user $TARGET_USER to gamemode group"
    if id "$TARGET_USER" | grep -o "gamemode" &>/dev/null; then
        echo "Successfully added to gamemode group"
    else
        echo "Failed to add to gamemode group"
    fi
fi

# ADD USER TO REALTIME
# No native "realtime-privileges" package on these distros - create the
# group and PAM limits by hand instead (works the same everywhere systemd
# and pam_limits are used).
groupadd -f realtime
cat > /etc/security/limits.d/99-realtime-privileges.conf <<EOF
@realtime - rtprio 95
@realtime - memlock unlimited
@realtime - nice -19
EOF
usermod -aG realtime "$(logname)"

# RESET PERMISSIONS
reset-permissions

# HARDENING SCRIPT
hardening-script

# EXIT
cd /
rm -rf /home/ulu-files/
echo -e "\e[1mULU Linux has been successfully installed\e[0m"
reboot

fi
'
