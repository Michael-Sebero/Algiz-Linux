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
for pkg in linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf nvidia-390xx-utils lib32-nvidia-390xx-utils modemmanager xf86-video-intel lib32-nvidia-580xx-utils; do
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

### FETCH A PREBUILT XANMOD KERNEL FROM CHAOTIC-AUR AND CONVERT IT FOR VOID ###
# Void has no prebuilt XanMod package of its own, but Chaotic-AUR (already used by the
# Artix section above) does, and a kernel image plus modules are not tied to the distro
# that packaged them - only to the exact build that produced them. So instead of compiling
# xanmod from source, this downloads the Chaotic-AUR build of linux-xanmod-edge-x64v3 (the
# same package the Artix section installs), verifies its signature, unpacks it, and
# repackages the kernel and headers as local xbps packages (split the same way the native
# linuxX.Y / linuxX.Y-headers pair is) installed alongside the stock kernel. To make it
# behave like a normal Void kernel rather than a pile of copied files, this also runs
# depmod and then directly invokes the real /etc/kernel.d/post-install hooks already on
# the system (the same dracut and dkms hooks a native kernel package triggers), then folds
# the resulting initramfs back into the package so xbps-remove cleans it up like it would
# for any other kernel. Much faster than a from-source build, but cross-distro kernel
# repackaging is inherently less battle-tested than a native package - if anything looks
# wrong, this backs out and the stock kernel installed elsewhere in this script is never
# touched.
CHAOTIC_MIRROR_URL="https://builds.garudalinux.org/repos/chaotic-aur/x86_64"
# Chaotic-AUR rotates their signing key from time to time (the old FBA220DFC880C036 key
# is dead - keyservers reject fetching it - and packages are now signed with a newer key).
# Scrape the current key from their own README, the same way the Artix section above does
# via pacman-key, instead of trusting a value that will eventually go stale again. Falls
# back to the key that is current as of this writing if the scrape itself fails.
CHAOTIC_SIGNING_KEY=$(curl -fsSL https://raw.githubusercontent.com/chaotic-aur/.github/refs/heads/main/profile/README.md 2>/dev/null \
  | grep -oE "pacman-key --recv-key [0-9A-Fa-f]+" | head -n1 | awk '\''{print $NF}'\'')
CHAOTIC_SIGNING_KEY="${CHAOTIC_SIGNING_KEY:-3056513887B78AEB}"

install_xanmod_void() {
  echo -e "\e[1mFetching XanMod from Chaotic-AUR and converting it for Void...\e[0m" >&2

  careful_install curl gnupg

  local build_dir
  build_dir=$(mktemp -d -p /var/tmp) || { echo "Could not create a build directory, skipping XanMod." >&2; return 1; }

  (
    set -e
    cd "$build_dir"
    export GNUPGHOME="$build_dir/gnupg"
    mkdir -m 700 "$GNUPGHOME"

    curl -fsSL "$CHAOTIC_MIRROR_URL/" -o index.html

    # Filenames carry the current version, so discover them instead of guessing.
    base_pkg=$(grep -oE "href=\"linux-xanmod-edge-x64v3-[0-9][^\"]*\.pkg\.tar\.zst\"" index.html | sed -E "s/^href=\"//; s/\"\$//" | sort -V | tail -n1)
    headers_pkg=$(grep -oE "href=\"linux-xanmod-edge-x64v3-headers-[0-9][^\"]*\.pkg\.tar\.zst\"" index.html | sed -E "s/^href=\"//; s/\"\$//" | sort -V | tail -n1)
    if [ -z "$base_pkg" ] || [ -z "$headers_pkg" ]; then
      echo "Could not find linux-xanmod-edge-x64v3 on Chaotic-AUR" >&2
      exit 1
    fi

    for f in "$base_pkg" "$headers_pkg"; do
      curl -fsSL "$CHAOTIC_MIRROR_URL/$f" -o "$f"
      curl -fsSL "$CHAOTIC_MIRROR_URL/$f.sig" -o "$f.sig"
    done

    key_fetched=false
    for ks in keyserver.ubuntu.com keys.openpgp.org pgp.mit.edu; do
      if timeout 30 gpg --batch --keyserver "$ks" --recv-keys "$CHAOTIC_SIGNING_KEY"; then
        key_fetched=true
        break
      fi
      echo "Keyserver $ks failed for key $CHAOTIC_SIGNING_KEY, trying next..." >&2
    done
    if [ "$key_fetched" != true ]; then
      echo "Could not fetch Chaotic-AUR signing key $CHAOTIC_SIGNING_KEY from any keyserver" >&2
      exit 1
    fi
    for f in "$base_pkg" "$headers_pkg"; do
      gpg --batch --verify "$f.sig" "$f"
    done

    mkdir base_extract headers_extract
    (tar --zstd -xf "$base_pkg" -C base_extract) || (zstd -dc "$base_pkg" | tar -x -C base_extract)
    (tar --zstd -xf "$headers_pkg" -C headers_extract) || (zstd -dc "$headers_pkg" | tar -x -C headers_extract)

    krelease=$(find base_extract/usr/lib/modules -mindepth 1 -maxdepth 1 -type d | head -n1 | xargs -n1 basename)
    if [ -z "$krelease" ]; then
      echo "Could not find a kernel modules directory in the downloaded package" >&2
      exit 1
    fi

    # Normalize to plain, uncompressed modules so module loading never depends on
    # whatever compression support happens to be compiled into the kmod package.
    find "base_extract/usr/lib/modules/$krelease" -name "*.ko.zst" -exec zstd -d --rm -f {} \;
    find "base_extract/usr/lib/modules/$krelease" -name "*.ko.xz" -exec xz -d -f {} \;

    vmlinuz=$(find base_extract -type f -iname "vmlinuz*" | head -n1)
    if [ -z "$vmlinuz" ]; then
      echo "Could not find a vmlinuz image in the downloaded package" >&2
      exit 1
    fi

    headers_tree=$(find headers_extract -type f -name "Module.symvers" -exec dirname {} \; | head -n1)
    if [ -z "$headers_tree" ]; then
      echo "Could not find a headers/build tree in the downloaded headers package" >&2
      exit 1
    fi

    # xbps versions may not contain dashes or underscores, so fold the dash-separated
    # kernel release string into dots instead of guessing a version number.
    ver=$(printf "%s" "$krelease" | tr -- "-_" "..")

    # Base kernel package: vmlinuz + modules, laid out exactly like a native Void
    # kernel package so xbps, dracut, and DKMS all treat it identically to one.
    kdestdir="kroot"
    mkdir -p "$kdestdir/boot" "$kdestdir/usr/lib/modules/$krelease"
    cp "$vmlinuz" "$kdestdir/boot/vmlinuz-$krelease"
    cp -a "base_extract/usr/lib/modules/$krelease"/. "$kdestdir/usr/lib/modules/$krelease/"
    rm -f "$kdestdir/usr/lib/modules/$krelease/vmlinuz" "$kdestdir/usr/lib/modules/$krelease/build" "$kdestdir/usr/lib/modules/$krelease/source"
    ln -s "/usr/src/linux-headers-$krelease" "$kdestdir/usr/lib/modules/$krelease/build"

    # Separate headers package, matching the base+-headers split every native Void
    # kernel uses, since DKMS (nvidia, etc.) looks for exactly that pair.
    hdestdir="hroot"
    mkdir -p "$hdestdir/usr/src"
    cp -a "$headers_tree" "$hdestdir/usr/src/linux-headers-$krelease"

    xbps-create -A x86_64 -n "linux-xanmod-${ver}_1" \
      -m "converted from Chaotic-AUR" -l "GPL-2.0-only" "$kdestdir"
    xbps-create -A x86_64 -n "linux-xanmod-headers-${ver}_1" \
      -m "converted from Chaotic-AUR" -l "GPL-2.0-only" "$hdestdir"

    xbps-rindex -a ./*.xbps
    xbps-install --repository="$PWD" -y "linux-xanmod-${ver}" "linux-xanmod-headers-${ver}"

    depmod "$krelease"

    # Run the same /etc/kernel.d hooks a native kernel package triggers on install
    # (dracut for the initramfs, dkms for any modules already registered, etc.)
    # instead of re-implementing what each of them individually does.
    export VERSION="$krelease" ACTION="post" UPDATE="no"
    for hook in /etc/kernel.d/post-install/*; do
      if [ -x "$hook" ]; then
        "$hook" || echo "kernel.d hook $hook reported an error, continuing" >&2
      fi
    done

    if [ ! -e "/boot/initramfs-$krelease.img" ]; then
      echo "No initramfs was generated for $krelease" >&2
      exit 1
    fi

    # xbps-create has no flag for the kernel_hooks_version metadata that a native
    # kernel template gets from xbps-src, so xbps-reconfigure will not automatically
    # re-run the hooks above for this package later (e.g. after a future nvidia
    # update adds a new DKMS module). Leave a small standalone helper that does the
    # same depmod-and-hooks sequence on demand, so that gap has a real fix instead
    # of just a warning.
    mkdir -p /usr/local/bin
    cat > /usr/local/bin/xanmod-reconfigure <<HELPEREOF
#!/bin/bash
# Rebuilds DKMS modules and regenerates the initramfs for the XanMod kernel
# converted from Chaotic-AUR (release $krelease). Run this after installing or
# updating a DKMS driver such as nvidia if it has not picked up this kernel.
set -e
depmod "$krelease"
export VERSION="$krelease" ACTION="post" UPDATE="no"
for hook in /etc/kernel.d/post-install/*; do
  [ -x "\$hook" ] && "\$hook"
done
echo "Reconfigured $krelease"
HELPEREOF
    chmod +x /usr/local/bin/xanmod-reconfigure

    # Fold the now-generated initramfs into the tracked package files too, so
    # xbps-remove cleans it up like it would for any other kernel package. This is
    # a finishing touch, not core functionality - the kernel above already works,
    # so a failure here only prints a warning rather than undoing everything.
    (
      set -e
      cp "/boot/initramfs-$krelease.img" "$kdestdir/boot/"
      rm -f ./*.xbps
      xbps-create -A x86_64 -n "linux-xanmod-${ver}_1" \
        -m "converted from Chaotic-AUR" -l "GPL-2.0-only" "$kdestdir"
      xbps-create -A x86_64 -n "linux-xanmod-headers-${ver}_1" \
        -m "converted from Chaotic-AUR" -l "GPL-2.0-only" "$hdestdir"
      xbps-rindex -f -a ./*.xbps
      xbps-install --repository="$PWD" -f -y "linux-xanmod-${ver}" "linux-xanmod-headers-${ver}"
    ) || echo "Kernel is installed and bootable, but could not fold the initramfs into the tracked package files; xbps-remove will leave it behind." >&2
  )
  local result=$?
  rm -rf "$build_dir"

  if [ "$result" -eq 0 ]; then
    echo -e "\e[1mXanMod kernel installed; removing the stock kernel so XanMod takes priority...\e[0m" >&2
    if [ -n "$KVER" ] && xbps-remove -y "linux${KVER}" "linux${KVER}-headers"; then
      echo -e "\e[1mStock kernel linux${KVER} removed; XanMod is now the only installed kernel.\e[0m" >&2
    else
      echo -e "\e[1mCould not remove stock kernel linux${KVER}; both kernels remain installed, pick XanMod from the GRUB menu.\e[0m" >&2
    fi
  else
    echo -e "\e[1mXanMod conversion failed, continuing with the stock kernel only.\e[0m" >&2
  fi
  return "$result"
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
for pkg in pulseaudio nvidia390 nvidia470 nvidia470-libs-32bit ModemManager xf86-video-intel; do
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
  fwupd chrony dnsmasq mesa mesa-32bit tk nix

# Headers for the currently running/installed kernel (needed by DKMS drivers like NVIDIA
# to build their initial module before XanMod is in place). install_xanmod_void() above
# removes this exact stock kernel and its headers once the XanMod build succeeds, so
# XanMod takes priority as the only installed kernel; if the conversion fails, this stock
# kernel is left alone as the fallback.
KVER=$(uname -r | cut -d. -f1-2)
if [ -n "$KVER" ]; then
  careful_install "linux${KVER}-headers"
fi

### SET UP NIX
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
  python3-piexif python3-websockets \

# INSTALL XFCE PACKAGES
if xbps-query thunar &>/dev/null; then
    careful_install \
      NetworkManager seahorse ffmpegthumbnailer \
else
    echo "Thunar not detected, skipping XFCE packages."
fi

# NIX PACKAGES
nix_install scx

# AMD-DESKTOP CHOICE
if [ "$choice" = "1" ]; then
  install_xanmod_void
  if xbps-query thunar &>/dev/null; then
    xbps-remove -y xfce4-power-manager xfce4-battery-plugin || true
  fi
  careful_install \
    mesa-vulkan-radeon mesa-vulkan-radeon-32bit libva-utils \
    fail2ban cpupower
fi

# AMD-LAPTOP CHOICE
if [ "$choice" = "2" ]; then
  install_xanmod_void
  careful_install \
    mesa-vulkan-radeon mesa-vulkan-radeon-32bit libva-utils \
    tlp blueman bluez brightnessctl
  nix_install throttled
fi

# INTEL-DESKTOP CHOICE
if [ "$choice" = "3" ]; then
  install_xanmod_void
  if xbps-query thunar &>/dev/null; then
    xbps-remove -y xfce4-power-manager xfce4-battery-plugin || true
  fi
  careful_install \
    mesa-vulkan-intel mesa-vulkan-intel-32bit libva-utils \
    fail2ban cpupower
fi

# INTEL-LAPTOP CHOICE
if [ "$choice" = "4" ]; then
  install_xanmod_void
  careful_install \
    mesa-vulkan-intel mesa-vulkan-intel-32bit libva-utils \
    tlp blueman bluez brightnessctl
  nix_install throttled
fi

# NVIDIA-OPENSOURCE-DESKTOP CHOICE
if [ "$choice" = "5" ]; then
  if xbps-query thunar &>/dev/null; then
    xbps-remove -y xfce4-power-manager xfce4-battery-plugin || true
  fi
  careful_install \
    nvidia nvidia-libs-32bit \
    fail2ban cpupower
  # xanmod goes in after nvidia so nvidia is already DKMS-registered by the time
  # the xanmod install runs the dkms kernel.d hook, which then rebuilds the nvidia
  # module for xanmod automatically instead of only ever targeting the stock kernel.
  install_xanmod_void
fi

# NVIDIA-PROPRIETARY-DESKTOP CHOICE
if [ "$choice" = "6" ]; then
  if xbps-query thunar &>/dev/null; then
    xbps-remove -y xfce4-power-manager xfce4-battery-plugin || true
  fi
  careful_install \
    nvidia580 nvidia580-libs-32bit \
    fail2ban cpupower
  install_xanmod_void
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

# INSTALL UNIVERSAL RC.LOCAL
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
