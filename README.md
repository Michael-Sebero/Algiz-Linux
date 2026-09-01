<p align="center">
	<img src="https://i.postimg.cc/90gfzGTT/tux-glasses.png" width="25%" />
</p>
<br>

<p align="center">
	<img src="https://i.postimg.cc/fbvDJcnG/740019dcf9a94a804d725079cedf0e2f250ea164da39a3ee5e6b4b0d3255bfef95601890afd80709da39a3ee5e6b4b0d3255.png" width="65%" />
</p>

## Summary / TLDR
This project is a combination of significant upgrades and micro-optimizations. I've implemented most of the known and esoteric Linux performance tweaks along with some original implementations. The philosophy behind this "meta-distribution" is to utilize current hardware features and resources generously (when needed) while increasing system hardness greatly beyond the default.

The configuration files `sysctl.conf`, `limits.conf` and `grub` are pre-configured for specific workloads. Depending on the variant chosen, there are specific changes tailored for each. These presets are **AMD/Intel**, **NVIDIA**, **Laptop**, **Performance**, **Low RAM**, **Server** and **LLM**. They can be chosen in the installer and by running the `optional` command post-installation.

Originally, I was inspired by Luke Smith's [LARBS](https://github.com/LukeSmithxyz/LARBS), which is why ULU's installer is script-based rather than an ISO. This project is packaged similarly to an ISO due to the configurations and content being stored inside various archives. If you want to see what changes I've made, you can view them [here](https://github.com/Michael-Sebero/ULU/tree/main/files/ulu-packages).

## Compatibility
* Artix Linux **100%**
* Void Linux -
* Linux Mint
* Ubuntu
* Fedora
* OpenSUSE

## **Core Components**

### **High Performance Kernel & Schedulers**
* [XanMod](https://xanmod.org/) - Custom Linux kernel optimized for speed, responsiveness and desktop performance
* [SCX-AURA](https://github.com/Michael-Sebero/SCX-AURA) - Laptop CPU scheduler based off [scx_bpfland](https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_bpfland)
* [SCX-IMPERATOR](https://github.com/Michael-Sebero/SCX-IMPERATOR) - Gaming CPU scheduler based off [scx_cake](https://github.com/RitzDaCat/scx_cake) and [scx_lavd](https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_lavd)

### **Security Software**
* [AppArmor](https://en.wikipedia.org/wiki/AppArmor) - Mandatory access control framework for process-level security
* [Chkrootkit](https://en.wikipedia.org/wiki/Chkrootkit) - Rootkit detection tool that scans for common signs of system compromise
* [ClamAV](https://github.com/Cisco-Talos/clamav) - Antivirus engine for detecting malware and trojans
* [DNSCrypt](https://github.com/DNSCrypt/dnscrypt-protocol) - Protocol that encrypts DNS traffic to prevent spoofing and eavesdropping
* [DNSMasq](https://thekelleys.org.uk/dnsmasq/doc.html) - Lightweight DNS and DHCP server for local networks
* [Fail2Ban](https://github.com/fail2ban/fail2ban) - Intrusion prevention tool that bans IPs showing malicious signs
* [Linux Hardening Script](https://github.com/Michael-Sebero/Linux-Hardening-Script) - Automated system security and configuration hardening script
* [Lynis](https://github.com/CISOfy/lynis) - Security auditing tool
* [USBGuard](https://github.com/USBGuard/usbguard) - Framework for implementing USB device authorization policies
* [UFW](https://en.wikipedia.org/wiki/Uncomplicated_Firewall) - Interface for managing iptables-based firewalls

### **Additional Features**
* Includes a comprehensive [manual](https://raw.githubusercontent.com/Michael-Sebero/ULU/refs/heads/main/files/ulu-manual/Manual)
* Machine ID and MAC address randomization
* [ALHP](https://wiki.archlinux.org/title/Unofficial_user_repositories#ALHP), [Chaotic AUR](https://github.com/chaotic-aur/packages) and [Flatpak](https://flatpak.org/) repositories
* Steam [Proton GE](https://github.com/GloriousEggroll/proton-ge-custom) prefix
* [Booster](https://github.com/anatol/booster) - Faster mkinitcpio replacement
* Battery life optimizations for laptops via [TLP](https://github.com/linrunner/TLP)
* Some processes are enhanced by [Mimalloc](https://github.com/microsoft/mimalloc), a high-performance memory allocator replacement
* [Ephemeral Overlay](https://github.com/Michael-Sebero/Ephemeral-Overlay) - Speeds up temporary/root directories and reduces disk I/O
* [Real-time](https://gitlab.archlinux.org/archlinux/packaging/packages/realtime-privileges) audio processing
* A [Lynis](https://github.com/CISOfy/lynis) system hardening rating of **82**
* [GameMode](https://github.com/FeralInteractive/gamemode) - Performance on demand utility for games
* [SCX](https://github.com/sched-ext/scx) - Dynamic scheduler extension framework
* [Game Focus](https://github.com/Michael-Sebero/Game-Focus) - A command that kills most system processes and launches Steam
* [Package Dictionary](https://github.com/Michael-Sebero/Package-Dictionary) - Package search tool
* A suite of optional productivity tools: [Archivist Tools](https://github.com/Michael-Sebero/Archivist-Tools), [Audio Frequency Tools](https://github.com/Michael-Sebero/Audio-Frequency-Tools), [Document Tools](https://github.com/Michael-Sebero/Document-Tools), [Media Tools](https://github.com/Michael-Sebero/Media-Tools)
* [Earlyoom](https://github.com/rfjakob/earlyoom) - Early OOM daemon
* [Nix](https://nixos.org/) - Universal package manager

---

## How ULU Works

### Kernel & Security Hardening
ULU implements kernel hardening that enhances both security and performance.

**Attack Surface Reduction:**
- Restricted ptrace access prevents privilege escalation attacks
- Disabled unprivileged BPF operations eliminate potential exploitation vectors
- Core dump generation disabled to prevent information leakage
- Kernel debugging restricted through pointer exposure protection
- Disabled SysRq functionality and kexec to prevent unauthorized kernel replacement
- ASLR enabled for protection against exploitation

### Custom Kernel
The kernel which comes with the desktop configuration is a custom build of XanMod tailored for [x86-64-v3](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels) CPU architecture. For laptops the default kernel is default but tailored for [x86-64-v3](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels), XanMod uses more energy which is why it's not used for this configuration. Linux's default `CFS` scheduler is replaced with a SCX-based scheduler for improved performance and responsiveness.

### Kernel Scheduler
The desktop scheduler is set to `IMPERATOR` and laptops use `AURA`. `IMPERATOR` is specialized for new processors (Zen 4-5 or CPUs with 3D V-Cache) and `AURA` is specialized for low-latency/high-responsiveness. If you want to change the scheduler it can be modified in `rc.local` under the scheduler section.

### Memory Management
RAM usage has the highest priority over swapping. Keeping active data in memory reduces wear on the drive and increases system responsiveness. Swapping is still possible but only used when RAM is nearly filled. The VM subsystem is configured to reduce unnecessary memory compaction overhead while maintaining balanced VFS cache pressure for responsive file operations. HugePages are dynamically allocated on demand, providing up to 3968 large pages to reduce overhead and fragmentation for large memory workloads.

**ZRAM Integration:** The system configures a zram-based swap device `/dev/zram0` to provide fast, compressed virtual memory utilizing the [LZ4](https://lz4.org/) compression algorithm. ZRAM allocation is dynamically set to 25% of total RAM. The device is initialized with `mkswap` and immediately activated with `swapon`.

### Ephemeral Overlay System

**Tmpfs Mounts:**
- `/tmp` - 5 GB
- `/var/tmp` - 1 GB
- `/var/cache` - 2 GB
- `/home/$USER/.cache` - 2 GB

**Persistent Cache Directories:**
- `/var/cache/pacman` - Package manager cache
- `/home/$USER/.cache/paru` - AUR helper cache
- `/home/$USER/.cache/nvidia` - NVIDIA shader cache
- `/home/$USER/.cache/mesa_shader_cache` - Mesa shader cache
- `/home/$USER/.cache/mesa_shader_cache_db` - Mesa shader database

*RAM Overlay of System Directories:*
- `/etc` - System configuration files
- `/var/log` - System logs
- Changes are stored in RAM and automatically synced to disk on logout

*Excluded Directories:*
- `/home` - User data
- `/tmp`, `/var/tmp`, `/var/cache` - Already on tmpfs
- `/proc`, `/sys`, `/dev`, `/run` - Virtual/runtime filesystems
- `/mnt`, `/media`, `/boot` - Mount points and boot files

**Automatic Garbage Collection:**
* Periodic cleanup every 60 seconds removes stale files older than 10 minutes from temporary directories
* File-in-use detection ensures active files are never deleted
* Reduces RAM pressure and maintains optimal overlay performance

### Network Management
Network performance leverages `BBR` congestion control and `cake` queue management to improve performance and reduce latency. The TCP stack uses expanded buffer sizes and enables fast connection establishment. IPv6 is limited through restrictive ICMP and routing settings. NetworkManager is set to use `dhclient` for DHCP with hostname handling disabled, along with DNS encryption via [LibreDNS](https://libredns.gr/).

### Filesystem & I/O Optimization
Disk and SSD performance is tuned through scheduler and queue optimizations. Both NVMe and SATA SSDs use the `none` scheduler to eliminate scheduling overhead and maximize throughput, while HDDs use `bfq` for fairness under mixed workloads. Read-ahead is set to 512 KB for SSDs and 2048 KB for HDDs to improve sequential read performance. I/O queue depth is configured at 2048 for NVMe drives, 1024 for SATA SSDs and 128 for HDDs, enabling optimal parallelism for each device type. I/O request merging is enabled to combine adjacent requests for improved efficiency.

**F2FS:** Root and home partitions formatted with F2FS are optimized with background garbage collection enabled and tuned idle detection intervals to maintain flash-based storage performance consistency. To preserve SSD longevity and prevent write performance degradation, the system runs TRIM operations once every 7 days, reclaiming unused blocks. These processes ensure efficient resource use across F2FS filesystems.

### CPU Architecture Detection & ALHP Package Integration
CPU architecture is automatically detected on installation to ensure optimal package installation. The system integrates some of ALHP's packages, which provide architecture-specific builds optimized for modern processor capabilities while keeping the system's core system packages.

## Hardware-Specific Presets

### AMD/Intel 
Configured for AMD hardware, tweaked for high performance and security.

### NVIDIA
Configured for NVIDIA hardware, tweaked for maximum visual fidelity, high performance and security.

### Laptop
Balanced between power saving, performance and security. At 85% battery + AC connection, performance is increased and reduced at 10%.

### Low RAM
Focused on swapping and ZRAM generation. This can make a system with 8G function like it has 10-12G.

## Optional Workload-Specific Presets

### Performance
Maximum performance configuration with no security mitigations and expanded memory limits.

### Server
Small-scale NAS configuration for file sharing and hosting.

### LLM
Specialized for LLM workloads with larger HugePages allocation and no security mitigations.

## Contact and Donations
* [Email](michaelsebero@disroot.org)
* [PayPal](https://www.paypal.com/donate/?cmd=_donations&business=YYGU9JWJEE2AG)
