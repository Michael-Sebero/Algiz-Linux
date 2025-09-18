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
* MAC address randomization via [Macchanger](https://www.kali.org/tools/macchanger/).
* Low latency [PipeWire](https://github.com/PipeWire/pipewire) audio processing.
* [ALHP](https://wiki.archlinux.org/title/Unofficial_user_repositories#ALHP), [Chaotic AUR](https://github.com/chaotic-aur/packages) and [Flatpak](https://flatpak.org/) repositories.
* Steam [Proton GE](https://github.com/GloriousEggroll/proton-ge-custom) prefix.
* [ZFS](https://github.com/openzfs/zfs) compatiblity (for server preset only).
* [Booster](https://github.com/anatol/booster) (mkinitcpio replacement).
* Battery life optimizations for laptops via [TLP](https://github.com/linrunner/TLP).
* [Power Manager](https://github.com/Michael-Sebero/Power-Manager) (laptop battery manager).
* [Mimalloc](https://github.com/microsoft/mimalloc) (high-performance memory allocator).
* [Tmpfs Overlay](https://github.com/Michael-Sebero/Tmpfs-Overlay) speeds up temporary directories and reduces disk I/O.
* [Real-time](https://gitlab.archlinux.org/archlinux/packaging/packages/realtime-privileges) audio processing.
* A [Lynis](https://github.com/CISOfy/lynis) system hardening rating of **80** on desktop and **78** for laptop.

## Summary / TLDR
This project is a combination of significant upgrades and micro-optimizations. I've implemented most of the known & esoteric Linux performance tweaks along with some original implementations. The philosophy behind this "meta-distribution" is to utilize current hardware features and resources generously (when needed) while increasing system hardness greatly beyond the default.

Originally I was inspired by Luke Smith's [LARBS](https://github.com/LukeSmithxyz/LARBS) which is why Algiz's installer is script-based rather than an ISO. This project is packaged similarly to an ISO due to the configurations and content being stored inside various archives. If you want to see what changes I've made you can view them [here](https://github.com/Michael-Sebero/Algiz-Linux/tree/main/files/algiz-packages).

## How Algiz Linux Works

### Kernel & Security Hardening
Algiz Linux implements kernel hardening which increases security and performance. The system prevents privilege escalation attacks through restricted ptrace access and disabled unprivileged BPF operations, while eliminating core dump generation to reduce attack surface. Process handling is optimized for high-concurrency workloads with expanded PID limits and disabled automatic NUMA balancing.

### Memory Management
RAM usage has the highest priority over swapping, keeping active data in memory reduces wear on the drive and increases system responsiveness. Swapping is still possible but only used when RAM is nearly filled. The VM subsystem is configured to reduce unnecessary memory compaction overhead while maintaining balanced VFS cache pressure for responsive file operations. HugePages are dynamically allocated on demand, providing up to 3968 large pages to reduce overhead and memory fragmentation for large memory workloads without consuming RAM upfront.

**Zram Integration:** The system configures a zram-based swap device `/dev/zram0` to provide fast, compressed virtual memory. Its size is dynamically set to 25% of total RAM. The device is initialized with `mkswap` and immediately activated with `swapon`. Compression is set to `lz4`, prioritizing low CPU overhead and high performance over maximum compression ratio.

**Tmpfs Overlay Integration:** Temporary directories `/tmp`, `/var/tmp`, `/var/log`, `/var/cache`, `/home/$USER/.cache/` are mounted as tmpfs to leverage RAM for high-speed file storage. Each mount has a predefined limit `/tmp` = 5G, `/var/tmp` = 1G, `/var/log` = 512M, `/var/cache` = 2G, `/home/$USER/.cache` = 2G. Essential directories `/var/cache/pacman`, `/home/$USER/.cache/paru`, `/home/$USER/.cache/nvidia`, `/home/$USER/.cache/mesa_shader_cache`, `/home/$USER/.cache/mesa_shader_cache_db` are excluded and bind-mounted on local storage.

* Periodic cleanup: Removes files older than 10 minutes.

* Safe removal: Ensures files in use are never deleted.

### Network Management
Network performance leverages `BBR` congestion control and `fq_codel` queue management to improve performance and reduce latency. The TCP stack uses expanded buffer sizes and enables fast connection establishment. IPv6 is configured with privacy extensions but with restrictive security settings that prioritize security over performance. NetworkManager is set to use `dhclient` for DHCP with hostname handling disabled along with DNS encryption via [Mullvad](https://mullvad.net/en).

### Filesystem & I/O Optimization
Disk and SSD performance is tuned through scheduler and queue optimizations. SSDs use the `mq-deadline` scheduler for predictable low-latency I/O, while HDDs default to `BFQ` to balance performance under heavy multi-process workloads. Read-ahead is increased to 4096 KB, improving sequential file access, while I/O queue depth is raised—128 for SATA and 512 for NVMe for higher parallelism without introducing latency spikes. Write throttling is disabled to prevent artificial slowdowns and Native Command Queuing (NCQ) is enabled for SATA drives to improve multi-request handling.

**F2FS:** Drives formatted to F2FS are optimized with aggressive background garbage collection, shorter idle intervals and faster urgency triggers ensuring flash-based storage maintains performance consistency over time. To preserve SSD longevity and prevent write performance degradation the system runs weekly TRIM operations which reclaim unused blocks. Together these adjustments ensure sustained high performance and efficient resource use.

### CPU Architecture Detection & ALHP Repository Integration
CPU architecture is automatically detected on installation to ensure optimal package installation. The system integrates some of ALHP's repositories which provide architecture-specific builds optimized for modern processor capabilities while keeping Artix's core system packages.

### Hardware-Specific Presets
* **AMD/Intel** - Configured for maximum performance.

* **NVIDIA** - Tweaked for maximum visual fidelity and performance.

* **Laptop** - Balanced between power saving and performance, at 79% battery + AC connection performance is increased and reduced at 10%.

### Optional Workload-Specific Presets
* **Performance** - Maximum performance configuration with reduced security mitigations, aggressive CPU scheduling and expanded memory limits.

* **Server** - The system expands TCP/UDP buffer sizes up to 16MB for high-performance connections. TCP stack handling is tuned for scalability with up to 2 million `TIME_WAIT` sockets, window scaling and reuse enabled for faster turnaround. Security and stability are reinforced with SYN cookies, strict reverse path filtering, martian packet logging, disabled source routing and ICMP redirects. IPv4/IPv6 are both hardened with rate limiting for ICMP, challenge ACK limits and disabled router advertisements. These settings balance low latency with resilience against common network abuse patterns.

* **AI** - Specialized for AI workloads with larger HugePages allocation and reduced security mitigations.

<p align="center">
	<img src="https://i.postimg.cc/C53HDLTZ/ksnip-20240224-100057.png" />

## Donations and Contact
* [PayPal](https://www.paypal.com/donate/?cmd=_donations&business=YYGU9JWJEE2AG)
* [Email](michaelsebero@disroot.org)
