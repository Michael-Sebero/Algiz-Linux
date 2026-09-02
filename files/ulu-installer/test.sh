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
for pkg in linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf artix-branding-base artix-grub-theme nvidia-390xx-utils lib32-nvidia-390xx-utils epiphany xfce4-screensaver xfce4-terminal parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril xfce4-sensors-plugin xfce4-notes-plugin xfce4-dict xfce4-weather-plugin modemmanager xf86-video-intel falkon vlc lib32-nvidia-580xx-utils; do
    if pacman -Qi "$pkg" &>/dev/null; then
        paru -Rdd --noconfirm "$pkg"
    fi
done

# INSTALL BASE PACKAGES
careful_install \
  lib32-artix-archlinux-support unrar flatpak librewolf tmux \
  font-manager gamemode lib32-gamemode dnscrypt-proxy apparmor \
  bleachbit catfish clamav gufw macchanger \
  wine-git wine-mono winetricks-git steam lynis element rkhunter opendoas \
  downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber \
  rust usbguard chkrootkit noto-fonts-emoji tauon-music-box freetube alsa-utils expect \
  inotify-tools preload dialog tree parallel sof-firmware booster vulkan-tools mimalloc mold \
  protontricks-git poetry pyenv python-pip hunspell-en_us ccache yt-dlp-git \
  lib32-libdisplay-info realtime-privileges gallery-dl tesseract-data-eng \
  scx-scheds debtap fwupd gimp chrony dnsmasq haruna mesa lib32-mesa tk nix

# INSTALL PYTHON PACKAGES
careful_install \
  python-dateutil python-xlib python-pyaudio python-pipenv \
  python-matplotlib python-tqdm python-magic \
  python-piexif python-moviepy python-brotli python-websockets python-librosa \
  python-pypdf2 python-pytesseract

# INSTALL XFCE PACKAGES
if pacman -Qq | grep -q ''^thunar$''; then
    careful_install \
      kate konsole kcalc networkmanager \
      mugshot xfce4-panel-profiles redshift mate-system-monitor pix seahorse ffmpegthumbnailer okular ark \
      lightdm-gtk-greeter-settings gtk-engines gtk-engine-murrine akregator
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

# TEMP XLIBRE FIX
find /usr/lib/xorg -name "intel_drv.so" -delete 2>/dev/null || true

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

### NOTES ON THIS SECTION ###
# - Void has one init system (runit), so there is no per-init detection/branching like the
#   Artix section needs. Void packages that run as daemons ship their runit service
#   directly (e.g. "tlp" already provides /etc/sv/tlp), so there is no need for the
#   "<pkg>-runit"-style sub-packages Artix requires.
# - Naming differences from Arch/AUR that matter below:
#     1. 32-bit/multilib packages are suffixed "-32bit" (e.g. mesa-dri-32bit) instead of
#        prefixed "lib32-".
#     2. Python library packages are prefixed "python3-" instead of "python-".
#     3. There is no AUR, no ALHP, and no official XanMod build for Void. Packages that only
#        exist as Chaotic-AUR/AUR builds in the Artix section (linux-xanmod-*, booster,
#        downgrade, debtap, the -git/-mono-git/-tricks-git flavors, tauon-music-box,
#        scx-scheds, throttled) either have a plain Void package, go through Nix instead
#        (per the design note at the bottom of this file), or are dropped where nothing
#        sensible applies. Void keeps its stock kernel here, since there is no reliable
#        always-current XanMod package to swap in, and hard-coding a version would go stale.
# - Assumes a glibc Void install (musl has known gaps with Steam, NVIDIA, and Wine).

### SERVICE MANAGEMENT FUNCTIONS (runit is the only init system Void uses) ###
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

### INSTALL PACKAGES VIA NIX (fallback for what Void does not package natively) ###
nix_install() {
  for pkg in "$@"; do
    echo "Installing $pkg via Nix..." >&2
    if ! su - "$USER" -c "nix-env -iA nixpkgs.$pkg"; then
      echo "Failed to install $pkg via Nix, skipping..." >&2
    fi
  done
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
for pkg in pulseaudio nvidia390 nvidia470 nvidia470-libs-32bit epiphany xfce4-screensaver xfce4-terminal parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril xfce4-sensors-plugin xfce4-dict xfce4-weather-plugin ModemManager xf86-video-intel falkon vlc; do
    if xbps-query "$pkg" &>/dev/null; then
        xbps-remove -y "$pkg" || true
    fi
done

# INSTALL BASE PACKAGES
# librewolf: void-packages rejects browser forks upstream (issue #32914); needs a
# third-party repo (e.g. index-0/librewolf-void) if you want it on Void.
careful_install \
  unrar flatpak tmux \
  fontmanager gamemode dnscrypt-proxy apparmor \
  bleachbit catfish clamav ufw gufw macchanger \
  wine wine-mono winetricks steam lynis element-desktop rkhunter opendoas \
  libreoffice pipewire alsa-pipewire wireplumber \
  rust usbguard chkrootkit noto-fonts-emoji alsa-utils expect \
  inotify-tools preload dialog tree parallel sof-firmware Vulkan-Tools mimalloc mold \
  protontricks python3-pip ccache yt-dlp \
  libdisplay-info-32bit gallery-dl tesseract-ocr tesseract-ocr-eng \
  fwupd gimp chrony dnsmasq haruna mesa mesa-32bit tk nix

# Headers for the currently running/installed kernel (needed by DKMS drivers like NVIDIA).
# Void keeps its own stock kernel here - see the note at the top of this section for why we
# do not swap in a XanMod-style kernel the way the Artix section does.
KVER=$(uname -r | cut -d. -f1-2)
if [ -n "$KVER" ]; then
  careful_install "linux${KVER}-headers"
fi

### SET UP NIX (must come after "nix" is installed above, before anything below uses it) ###
add_service nix-daemon
sv up nix-daemon &>/dev/null || true
source /etc/profile &>/dev/null || true
nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs &>/dev/null || true
nix-channel --update &>/dev/null || true
su - "$USER" -c "nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && nix-channel --update" &>/dev/null || true

# INSTALL PYTHON PACKAGES
careful_install \
  python3-dateutil python3-xlib python3-PyAudio python3-pipenv \
  python3-matplotlib python3-tqdm python3-magic \
  python3-piexif python3-Brotli python3-websockets \
  python3-pypdf

# INSTALL XFCE PACKAGES
if xbps-query thunar &>/dev/null; then
    careful_install \
      kate konsole kcalc NetworkManager \
      mugshot xfce4-panel-profiles redshift mate-system-monitor seahorse ffmpegthumbnailer okular ark \
      lightdm-gtk-greeter-settings gtk-engine-murrine akregator
else
    echo "Thunar not detected, skipping XFCE packages."
fi

# Packages Void does not package natively; installed through Nix instead (see design note)
nix_install tauon freetube scx

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
  nix_install throttled
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
  nix_install throttled
fi

# NVIDIA-OPENSOURCE-DESKTOP CHOICE
# The Void "nvidia" package moved to NVIDIA open-source-published DKMS kernel modules as of
# the 595.xx driver series (Turing and newer); userspace bits stay proprietary either way.
# This is the closest match to the Artix section nvidia-open-dkms package.
if [ "$choice" = "5" ]; then
  if xbps-query thunar &>/dev/null; then
    xbps-remove -y xfce4-power-manager xfce4-battery-plugin || true
  fi
  careful_install \
    nvidia nvidia-libs-32bit \
    fail2ban cpupower
fi

# NVIDIA-PROPRIETARY-DESKTOP CHOICE
# nvidia580 is the Void legacy branch that kept the fully-proprietary kernel module (also
# covers pre-Turing cards the open modules cannot support).
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
# protonup-ng is PyPI-only on Void (no xbps package), so this never fires as written.
# Install via: pip install protonup-ng --break-system-packages (first, if you want this step)
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

# ADD USER TO REALTIME (Void has no guaranteed realtime-privileges package, so make sure the
# group exists ourselves even though we attempted it above too)
groupadd -f realtime
usermod -aG realtime "$(logname)"

# INSTALL UNIVERSAL RC.LOCAL (runit oneshot wrapper; Void has no built-in rc.local hook)
mkdir -p /etc/sv/rc-local
cat > /etc/sv/rc-local/run << EOF
#!/bin/sh
[ -x /etc/rc.local ] && /etc/rc.local
exec chpst -b rc-local pause
EOF
chmod 755 /etc/sv/rc-local/run
chmod 755 /etc/rc.local 2>/dev/null || true
add_service rc-local

# RESET PERMISSIONS
reset-permissions

# HARDENING SCRIPT
hardening-script

# TEMP XLIBRE FIX
find /usr/lib/xorg -name "intel_drv.so" -delete 2>/dev/null || true

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

## use unified configs for all without redundancy, from void to debian, ubuntu, opensuse and fedora itll use nix but void will mostly use its own packages, this is done to make package name management easier. Note: from debian to fedora itll only use nix packages and not their own package manager to install packages for convenience.

### Detect OS > if Ubuntu/Debian = nix, if Fedora = nix, if OpenSUSE = nix, if Void Linux = nix + xbps, if Arch = pacman, if Artix = pacman + detect init for services > unpack zip files into directories but move specific files depending how each OS does it

    echo "No supported package manager found (expected pacman for Artix or xbps-install for Void)." >&2
    echo "Debian/Ubuntu/openSUSE/Fedora support is not implemented in this script." >&2
    exit 1

fi
'
