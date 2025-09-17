<p align="center">
	<img src="https://i.postimg.cc/TYCbKN6L/Life.png" width="25%" />
</p>

<p align="center"><strong><font size="12">Algiz Linux</font></strong> is a High-Performance, Security-Focused Meta-Distribution of Artix Linux</p>

## **Includes:**

### **A Modified Kernel & Performance Tools**
* [CachyOS Kernel](https://wiki.cachyos.org/features/kernel/)
* [Earlyoom](https://github.com/rfjakob/earlyoom)
* [GameMode](https://github.com/FeralInteractive/gamemode)
* [Game Focus](https://github.com/Michael-Sebero/Game-Focus)

### **Security Software**
* [AppArmor](https://en.wikipedia.org/wiki/AppArmor)
* [Chkrootkit](https://en.wikipedia.org/wiki/Chkrootkit)
* [ClamAV](https://github.com/Cisco-Talos/clamav)
* [DNSCrypt](https://github.com/DNSCrypt/dnscrypt-protocol)
* [Fail2Ban](https://github.com/fail2ban/fail2ban)
* [Linux Hardening Script](https://github.com/Michael-Sebero/Linux-Hardening-Script)
* [Lynis](https://github.com/CISOfy/lynis)
* [USBGuard](https://github.com/USBGuard/usbguard)
* [UFW](https://en.wikipedia.org/wiki/Uncomplicated_Firewall)

### **Tools & Utilities**
* [Arch Package Dictionary](https://github.com/Michael-Sebero/Arch-Package-Dictionary)
* [Archivist Tools](https://github.com/Michael-Sebero/Archivist-Tools)
* [Audio Frequency Tools](https://github.com/Michael-Sebero/Audio-Frequency-Tools)
* [Data Recovery Tools](https://github.com/Michael-Sebero/Data-Recovery-Tools)
* [Document Tools](https://github.com/Michael-Sebero/Document-Tools)
* [Fix Arch Linux](https://github.com/Michael-Sebero/Fix-Arch-Linux)
* [Media Tools](https://github.com/Michael-Sebero/Media-Tools)

### **Additional Features**
* A comprehensive [manual](https://raw.githubusercontent.com/Michael-Sebero/Algiz-Linux/refs/heads/main/files/algiz-manual/Manual).
* MAC address randomization.
* Configured `sysctl` and `limits` for security enhancements, system performance and network efficiency.
* Low latency [PipeWire](https://github.com/PipeWire/pipewire) audio processing.
* [ALHP](https://wiki.archlinux.org/title/Unofficial_user_repositories#ALHP), [Chaotic AUR](https://github.com/chaotic-aur/packages) and [Flatpak](https://flatpak.org/) repositories.
* Steam [Proton GE](https://github.com/GloriousEggroll/proton-ge-custom) prefix.
* [ZFS](https://github.com/openzfs/zfs) compatiblity (for server preset only).
* Optional pre-configured PipeWire audio profiles.
* Custom Windows-like XFCE theme.
* [Booster](https://github.com/anatol/booster) (mkinitcpio replacement).
* Battery life optimizations for laptops via [TLP](https://github.com/linrunner/TLP).
* [Power Manager](https://github.com/Michael-Sebero/Power-Manager) (laptop battery manager).
* [Mimalloc](https://github.com/microsoft/mimalloc) (high-performance memory allocator).
* [Tmpfs Overlay](https://github.com/Michael-Sebero/Tmpfs-Overlay) speeds up temporary directories and reduces disk I/O.
* [Real-time](https://gitlab.archlinux.org/archlinux/packaging/packages/realtime-privileges) audio processing.
* A [Lynis](https://github.com/CISOfy/lynis) system hardening rating of **80** on desktop and **78** for laptop.

## Summary / TLDR
This project is a combination of significant upgrades and micro-optimizations. I've implemented most of the known/esoteric performance tweaks which can be implemented on Linux along with some original implementations. The philosophy behind this "meta-distribution" is to utilize modern hardware features and hardware resources generously (when needed) while increasing system hardness greatly beyond the default.

Algiz Linux isn't distributed as an ISO because I don't want to bother with hosting + costs, this project will always be on GitHub. I was inspired by Luke Smith's [LARBS](https://github.com/LukeSmithxyz/LARBS) which is why this is script-based. In a way this project is like an ISO because most of Algiz's configurations and original content are stored inside archives (for convenience & permission integrity). If you want to see what changes I've made you can view them [here](https://github.com/Michael-Sebero/Algiz-Linux/tree/main/files/algiz-packages).

## How Algiz Linux Works

### Kernel & Security Hardening
Algiz Linux implements kernel hardening which increases security and performance. The system prevents privilege escalation attacks through restricted ptrace access and disabled unprivileged BPF operations, while eliminating core dump generation to reduce attack surface. Process handling is optimized for high-concurrency workloads with expanded PID limits and disabled automatic NUMA balancing to prevent unnecessary CPU migrations that degrade cache locality.

### Memory Management Optimization
Aggressive memory tuning prioritizes RAM utilization over swap usage, keeping active data in memory while optimizing write-back behavior for sustained throughput. The VM subsystem is configured to reduce unnecessary memory compaction overhead while maintaining balanced VFS cache pressure for responsive file operations. HugePages are dynamically allocated on demand, providing up to 3968 large pages to reduce overhead and memory fragmentation for large memory workloads without consuming RAM upfront.

**Zram Integration:** The system configures a zram-based swap device `/dev/zram0` to provide fast, compressed virtual memory. It's size is dynamically set to 25% of total RAM. The device is initialized with mkswap and immediately activated with swapon. Compression prioritizes zstd when available, falling back to lzo to maintain low CPU overhead while efficiently storing inactive memory pages.

**TMPFS Overlay Integration:** Temporary directories `/tmp`, `/var/tmp`, `/var/log`, `/var/cache`, `/home/$USER/.cache/` are mounted as tmpfs to leverage RAM for high-speed file storage. Each mount has a predefined limit `/tmp` = 5G, `/var/tmp` = 1G, `/var/log` = 512M, `/var/cache` = 2G, `/home/$USER/.cache` = 2G. Essential directories `/var/cache/pacman`, `/home/$USER/.cache/paru`, `/home/$USER/.cache/nvidia`, `/home/$USER/.cache/mesa_shader_cache`, `/home/$USER/.cache/mesa_shader_cache_db` are excluded and bind-mounted on local storage.

* Periodic cleanup: Removes files older than 10 minutes.

* Safe removal: Ensures files in use are never deleted.

### Network Stack Enhancement
Network performance leverages BBR congestion control and fq_codel queue management to improve throughput and reduce latency. The TCP stack uses expanded buffer sizes and enables fast connection establishment. IPv6 is configured with privacy extensions but with restrictive security settings that prioritize security over performance convenience.

### Filesystem & I/O Optimization
Current I/O patterns are supported through expanded file descriptor limits and asynchronous operation capabilities. The filesystem layer includes enhanced inotify support for file monitoring applications while implementing security protections against symlink and hardlink attacks. These optimizations particularly benefit containerized applications and development environments that require extensive file access patterns.

### CPU Architecture Detection & ALHP Repository Integration
Algiz Linux automatically detects CPU architecture on installation to ensure optimal package selection. The system integrates some of ALHP's repositories which provide architecture-specific builds optimized for modern processor capabilities while keeping Artix's core system packages.

### Hardware-Specific Presets
* **AMD/Intel** - Configured for maximum performance.

* **NVIDIA** - Tweaked for maximum performance and increased visual fidelity.

* **Laptop** - Balanced between power saving and increased system performance when the system is at 79% battery life + AC connection.

### Workload-Specific Presets
* **Performance** - Maximum throughput configuration with reduced security mitigations, aggressive CPU scheduling and expanded memory limits.

* **Server** - Network enhancements tailored for server hardware. Features optimized TCP stack with BBR congestion control, aggressive connection handling (2M TIME_WAIT buckets, fast recycling), enhanced network buffers (16MB socket buffers), comprehensive IPv4/IPv6 filtering with martian packet logging and DDoS mitigation through rate limiting and connection flood protection while maintaining low-latency network performance for high-throughput server applications.

* **AI** - Specialized for AI workloads with larger HugePages allocation, reduced security mitigations, optimized memory bandwidth utilization and reduced kernel overhead for sustained computational tasks.

<p align="center">
	<img src="https://i.postimg.cc/C53HDLTZ/ksnip-20240224-100057.png" />

## Donations and Contact
* [PayPal](https://www.paypal.com/donate/?cmd=_donations&business=YYGU9JWJEE2AG)
* [Email](michaelsebero@disroot.org)
