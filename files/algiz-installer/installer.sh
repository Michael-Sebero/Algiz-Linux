#!/bin/bash

su -c '
### INIT SYSTEM DETECTION ###
detect_init_system() {
    if command -v sv >/dev/null 2>&1 && [ -d "/etc/runit" ]; then
        echo "runit"
    elif command -v s6-service >/dev/null 2>&1; then
        echo "s6"
    elif command -v rc-update >/dev/null 2>&1; then
        echo "openrc"
    else
        # Fallback detection methods
        if [ -d "/etc/runit" ]; then
            echo "runit"
        elif [ -d "/etc/s6" ]; then
            echo "s6"
        elif [ -d "/etc/runlevels" ]; then
            echo "openrc"
        else
            echo "unknown"
        fi
    fi
}

INIT_SYSTEM=$(detect_init_system)

### RETRY LOGIC ###
retry() {
  local max_attempts="$1"
  shift
  local command="$@"
  local attempt_num=1
  
  until $command
  do
    if (( attempt_num == max_attempts ))
    then
      echo "Attempt $attempt_num failed! Filtering out unavailable packages and retrying..." >&2
      
      # Extract package names and detect package manager
      local pkg_list=""
      local pkg_manager=""
      local base_flags=""
      
      if echo "$command" | grep -q "paru.*-S"; then
        pkg_manager="paru"
        pkg_list=$(echo "$command" | sed -E "s/.*paru[[:space:]]+(-S[[:space:]]+[^[:space:]]*[[:space:]]+)*(--[^[:space:]]+[[:space:]]+)*//")
        base_flags="-S --noconfirm --needed"
      elif echo "$command" | grep -q "pacman.*-S"; then
        pkg_manager="pacman"
        pkg_list=$(echo "$command" | sed -E "s/.*pacman[[:space:]]+(-S[[:space:]]+[^[:space:]]*[[:space:]]+)*(--[^[:space:]]+[[:space:]]+)*//")
        base_flags="-S --noconfirm --needed --overwrite='*'"
      else
        echo "Unable to detect package manager (paru/pacman) from command, continuing..." >&2
        return 0
      fi
      
      # Extract additional flags (like --ignore)
      local extra_flags=""
      if echo "$command" | grep -q -- "--ignore="; then
        extra_flags=$(echo "$command" | grep -o -- "--ignore=[^ ]*")
      fi
      if echo "$command" | grep -q -- "--overwrite="; then
        local overwrite_flag=$(echo "$command" | grep -o -- "--overwrite=[^ ]*")
        if [[ "$extra_flags" != *"--overwrite="* ]]; then
          extra_flags="$extra_flags $overwrite_flag"
        fi
      fi
      
      # Get list of available packages
      echo "Checking package availability with $pkg_manager..." >&2
      local all_pkgs=($pkg_list)
      local available_pkgs=""
      local unavailable_pkgs=""
      
      for pkg in "${all_pkgs[@]}"; do
        if [ -z "$pkg" ]; then continue; fi
        
        # Check if package exists in repositories
        if $pkg_manager -Si "$pkg" &>/dev/null; then
          available_pkgs="$available_pkgs $pkg"
        else
          unavailable_pkgs="$unavailable_pkgs $pkg"
        fi
      done
      
      # Trim whitespace
      available_pkgs=$(echo "$available_pkgs" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
      unavailable_pkgs=$(echo "$unavailable_pkgs" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
      
      if [ -n "$unavailable_pkgs" ]; then
        echo "Skipping unavailable packages: $unavailable_pkgs" >&2
      fi
      
      if [ -n "$available_pkgs" ]; then
        # Reconstruct the command with available packages only
        local new_cmd="$pkg_manager $base_flags $extra_flags $available_pkgs"
        echo "Installing available packages: $available_pkgs" >&2
        echo "Executing: $new_cmd" >&2
        
        # Execute the modified command
        eval "$new_cmd" && return 0 || return 1
      else
        echo "No available packages found, skipping installation..." >&2
        return 0
      fi
    else
      echo "Attempt $attempt_num failed! Retrying in 5 seconds..." >&2
      sleep 5
      attempt_num=$(( attempt_num + 1 ))
    fi
  done
}

### SERVICE MANAGEMENT FUNCTIONS ###
add_service() {
    local service_name="$1"
    case "$INIT_SYSTEM" in
        runit)
            if [ -d "/etc/runit/sv/$service_name" ]; then
                ln -sf "/etc/runit/sv/$service_name" "/run/runit/service/"
            fi
            ;;
        s6)
            s6-service add default "$service_name"
            ;;
        openrc)
            rc-update add "$service_name" default
            ;;
    esac
}

### ALGIZ LINUX CHOICE SELECTION ###

echo -e "\e[1mSelect a Algiz Linux Variant\e[0m"
echo "1. AMD-DESKTOP"
echo "2. AMD-LAPTOP"
echo "3. INTEL-DESKTOP"
echo "4. INTEL-LAPTOP"
echo "5. NVIDIA-OPENSOURCE-DESKTOP"
echo "6. NVIDIA-PROPRIETARY-DESKTOP"

read -p "Enter your choice (1-6): " choice

# IMPORT KEYS
echo -e "\e[1mImporting repository keys...\e[0m"

curl -s https://raw.githubusercontent.com/chaotic-aur/.github/refs/heads/main/profile/README.md \
| grep -Eo "pacman-key --recv-key [0-9A-F]+" \
| sed "s/--recv-key \([0-9A-F]*\)/--recv-key \1; pacman-key --lsign-key \1/" \
| bash

### FIRST COMMANDS AND ALGIZ-LINUX IMPORT P1 ###
killall xfce4-screensaver || true
pacman -Sy --noconfirm --needed p7zip unzip git base-devel
mkdir /home/algiz-files/
git clone https://github.com/Michael-Sebero/Algiz-Linux /home/algiz-files/
cd /home/algiz-files/files/algiz-packages/
unzip -o algiz-pacman-temp-1.zip -d /etc
pacman -Sy --noconfirm artix-archlinux-support pacman-contrib artix-keyring archlinux-keyring artix-mirrorlist archlinux-mirrorlist
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
unzip -o algiz-pacman-temp-2.zip -d /etc
pacman -Sy --noconfirm alhp-keyring alhp-mirrorlist

# CPU ARCHITECTURE DETECTION
arch_support=$(/lib/ld-linux-x86-64.so.2 --help 2>&1 | grep '\''supported'\'' | head -n 1 | awk '\''{print $1}'\'')
if [ "$arch_support" = "x86-64-v3" ]; then
    unzip -o algiz-pacman-v3.zip -d /etc
elif [ "$arch_support" = "x86-64-v4" ]; then
    unzip -o algiz-pacman-v4.zip -d /etc
fi

# TEMP FIX
pacman -Rdd --noconfirm linux-firmware || true && find /etc/pacman.conf -type f -exec sed -i 's/#//g' {} +

# POPULATE & REFRESH
pacman-key --init
pacman-key --populate archlinux artix alhp chaotic
pacman -Syy

# FIND QUICKEST MIRRORLIST
echo -e "\e[1mFinding quickest mirrorlist, please wait...\e[0m"
sh -c "rankmirrors -v -n 4 -m 2 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.new && mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist && chmod 644 /etc/pacman.d/mirrorlist"

### FIRST COMMANDS AND ALGIZ-LINUX IMPORT P2 ###
pacman -S paru --noconfirm --needed && retry 5 pacman -Syyu --noconfirm --needed --overwrite='*' --ignore=linux,linux-headers
mv /home/algiz-files/files/algiz-manual/Manual /home/$USER/Desktop/

# REMOVE PACKAGES
paru -Rdd --noconfirm linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf artix-branding-base artix-grub-theme mpv mesa vulkan-intel vulkan-radeon vulkan-swrast

# REMOVE XFCE PACKAGES
paru -Rdd --noconfirm epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril xfce4-sensors-plugin xfce4-notes-plugin xfce4-dict xfce4-weather-plugin || true

# INSTALL BASE PACKAGES
retry 5 paru -S --noconfirm --needed lib32-artix-archlinux-support unrar flatpak kate librewolf tmux liferea ksnip kcalc font-manager pix gimp gamemode lib32-gamemode okular dnscrypt-proxy apparmor bleachbit konsole catfish clamav ark gufw macchanger networkmanager nm-connection-editor wine-git wine-mono winetricks-git steam lynis element-desktop rkhunter opendoas mate-system-monitor chrony downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber rust usbguard chkrootkit wget noto-fonts-emoji tauon-music-box freetube alsa-utils expect inotify-tools preload dialog tree parallel sof-firmware booster bottles vulkan-tools mimalloc mold lld protontricks-git poetry pyenv python-pip hunspell-en_us ccache yt-dlp seahorse lib32-libdisplay-info mesa-tkg-git lib32-mesa-tkg-git linux-firmware

# INSTALL INIT PACKAGES
case "$INIT_SYSTEM" in
    runit)
        retry 5 paru -S --noconfirm --needed dnscrypt-proxy-runit apparmor-runit clamav-runit networkmanager-runit ufw-runit usbguard-runit cpupower-runit earlyoom-runit
        ;;
    s6)
        retry 5 paru -S --noconfirm --needed dnscrypt-proxy-s6 apparmor-s6 clamav-s6 networkmanager-s6 ufw-s6 usbguard-s6 cpupower-s6 earlyoom-s6
        ;;
    openrc)
        retry 5 paru -S --noconfirm --needed dnscrypt-proxy-openrc apparmor-openrc clamav-openrc networkmanager-openrc ufw-openrc usbguard-openrc cpupower-openrc earlyoom-openrc
        ;;
esac

# INSTALL PYTHON PACKAGES
retry 5 paru -S --noconfirm --needed python-dateutil python-xlib python-psutil python-pyaudio python-pipenv python-matplotlib python-tqdm python-pillow python-mutagen python-magic python-piexif python-moviepy python-brotli python-websockets python-librosa python-audioread python-pypdf2

# INSTALL XFCE PACKAGES
if pacman -Qq | grep -q '^thunar$'; then
    echo "Thunar detected, installing extra XFCE packages..."
    retry 5 paru -S --noconfirm --needed mugshot xfce4-panel-profiles xorg-xrandr redshift lightdm-gtk-greeter-settings gtk-engines xdg-desktop-portal-gtk gtk-engine-murrine
else
    echo "Thunar not detected, skipping XFCE packages."
fi

# AMD/INTEL-DESKTOP CHOICE
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  paru -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin && retry 5 paru -S --noconfirm --needed linux-cachyos linux-cachyos-headers protonup-git vkbasalt lib32-vkbasalt fail2ban fail2ban-${INIT_SYSTEM}
fi

# AMD/INTEL-LAPTOP CHOICE
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  retry 5 paru -S --noconfirm --needed linux-cachyos linux-cachyos-headers throttled tlp tlp-${INIT_SYSTEM} blueman bluez bluez-${INIT_SYSTEM} brightnessctl
fi

# NVIDIA-OPENSOURCE-DESKTOP CHOICE
if [ "$choice" = "5" ]; then
  paru -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin && for pkg in nvidia-390xx-utils lib32-nvidia-390xx-utils; do pacman -Qs "^$pkg$" >/dev/null && paru -Rdd --noconfirm "$pkg"; done && retry 5 paru -S --noconfirm --needed linux-cachyos linux-cachyos-headers protonup-git nvidia-utils nvidia-utils-${INIT_SYSTEM} nvidia-settings fail2ban fail2ban-${INIT_SYSTEM} nvidia-open-dkms && { paru -S --noconfirm --needed lib32-nvidia-utils || paru -S --noconfirm --needed lib32-vulkan-driver; }
fi

# NVIDIA-PROPRIETARY-DESKTOP CHOICE
if [ "$choice" = "6" ]; then
  paru -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin && for pkg in nvidia-390xx-utils lib32-nvidia-390xx-utils; do pacman -Qs "^$pkg$" >/dev/null && paru -Rdd --noconfirm "$pkg"; done && retry 5 paru -S --noconfirm --needed linux-cachyos linux-cachyos-headers protonup-git nvidia-utils nvidia-utils-${INIT_SYSTEM} nvidia-settings fail2ban fail2ban-${INIT_SYSTEM} nvidia-dkms && { paru -S --noconfirm --needed lib32-nvidia-utils || paru -S --noconfirm --needed lib32-vulkan-driver; }
fi

# INSTALL FLATPAK PACKAGES
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak install -y flathub org.kde.haruna

# INSTALL PROTON-GE
if pacman -Q protonup-git &>/dev/null; then
    su - "$USER" -c "protonup -d /home/$USER/.local/share/Steam/compatibilitytools.d/ && protonup -y"
fi

### ALGIZ LINUX INSTALL ###

# AMD/INTEL DESKTOP SELECTION
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  unzip -o algiz-dotfiles-desktop.zip -d /home/$USER/
  unzip -o algiz-root-main.zip -d /
  unzip -o algiz-root-desktop.zip -d /
  add_service fail2ban
fi

# LAPTOP SELECTION
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  unzip -o algiz-dotfiles-laptop.zip -d /home/$USER/
  unzip -o algiz-root-main.zip -d /
  unzip -o algiz-root-laptop.zip -d /
  add_service tlp
fi

# NVIDIA SELECTION
if [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  unzip -o algiz-dotfiles-desktop.zip -d /home/$USER/
  unzip -o algiz-root-main.zip -d /
  unzip -o algiz-root-desktop.zip -d /
  unzip -o algiz-nvidia-patch.zip -d /
  add_service fail2ban
fi

### LAST COMMANDS ###

# ADD SERVICES
add_service apparmor
add_service NetworkManager
add_service dnscrypt-proxy
add_service ufw
add_service cpupower
add_service earlyoom

# REMOVE CONNMAN & REFRESH
case "$INIT_SYSTEM" in
    runit)
        unlink /run/runit/service/connmand 2>/dev/null || true
        pacman -Rdd --noconfirm connman connman-runit connman-gtk
        ;;
    s6)
        rm -f /etc/s6/adminsv/default/contents.d/connmand
        pacman -Rdd --noconfirm connman connman-s6 connman-gtk
        ;;
    openrc)
        rc-update del connman default || true
        pacman -Rdd --noconfirm connman connman-openrc connman-gtk
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

# INSTALL UNIVERSAL RC.LOCAL

# Runit
if [ -d /etc/runit ]; then
  mkdir -p /etc/runit/sv/rc.local
  cat > /etc/runit/sv/rc.local/run << 'EOF'
#!/bin/sh
exec 2>&1
/etc/rc.local
exit 0
EOF
  chmod 755 /etc/runit/sv/rc.local/run
  # Create a finish script to prevent restart
  cat > /etc/runit/sv/rc.local/finish << 'EOF'
#!/bin/sh
# Prevent automatic restart for one-shot service
exec 2>&1
exit 0
EOF
  chmod 755 /etc/runit/sv/rc.local/finish
  touch /etc/runit/sv/rc.local/down
fi

# S6
if [ -d /etc/s6 ]; then
  mv -f /etc/rc.local /etc/s6/rc.local
  chmod 755 /etc/s6/rc.local
fi

# OpenRC
if [ -d /etc/runlevels ]; then
  mv -f /etc/rc.local /etc/local.d/rc.start
  chmod 755 /etc/local.d/rc.start
fi

# RESET PERMISSIONS
reset-permissions

# HARDENING SCRIPT
sh /algiz/programs/hardening-script/hardening-script.sh && umask 027
cd /

# EXIT
mv /etc/profile{,.old}
grub-install || true
s6-db-reload || true
update-grub
rm -rf /home/algiz-files/
echo -e "\e[1mAlgiz Linux has been successfully installed\e[0m"
reboot
'
