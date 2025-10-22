<p align="center">
	<img src="https://i.postimg.cc/TYCbKN6L/Life.png" width="25%" />
</p>

<p align="center"><strong><font size="12">Algiz Linux</font></strong> is a High-Performance, Security-Focused Meta-Distribution of Artix Linux</p>

## **Includes:**

### **A Modified Kernel & Performance Utilities**
* [Game Focus](https://github.com/Michael-Sebero/Game-Focus)
* [GameMode](https://github.com/FeralInteractive/gamemode)
* [SCX Schedulers](https://github.com/sched-ext/scx)
* [XanMod](https://xanmod.org/)

### **Security Software**
* [AppArmor](https://en.wikipedia.org/wiki/AppArmor)
* [Chkrootkit](https://en.wikipedia.org/wiki/Chkrootkit)
* [ClamAV](https://github.com/Cisco-Talos/clamav)
* [DNSCrypt](https://github.com/DNSCrypt/dnscrypt-protocol)
* [DNSMasq](https://thekelleys.org.uk/dnsmasq/doc.html)
* [Fail2Ban](https://github.com/fail2ban/fail2ban)
* [Linux Hardening Script](https://github.com/Michael-Sebero/Linux-Hardening-Script)
* [Lynis](https://github.com/CISOfy/lynis)
* [USBGuard](https://github.com/USBGuard/usbguard)
* [UFW](https://en.wikipedia.org/wiki/Uncomplicated_Firewall)

### **Misc Tools & Utilities**
* [Arch Package Dictionary](https://github.com/Michael-Sebero/Arch-Package-Dictionary)
* [Archivist Tools](https://github.com/Michael-Sebero/Archivist-Tools)
* [Audio Frequency Tools](https://github.com/Michael-Sebero/Audio-Frequency-Tools)
* [Document Tools](https://github.com/Michael-Sebero/Document-Tools)
* [Earlyoom](https://github.com/rfjakob/earlyoom)
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
* [System Tuner](https://github.com/Michael-Sebero/System-Tuner) (laptop performance manager).
* [Mimalloc](https://github.com/microsoft/mimalloc) (high-performance memory allocator).
* [Tmpfs Overlay](https://github.com/Michael-Sebero/Tmpfs-Overlay) speeds up temporary directories and reduces disk I/O.
* [Real-time](https://gitlab.archlinux.org/archlinux/packaging/packages/realtime-privileges) audio processing.
* A [Lynis](https://github.com/CISOfy/lynis) system hardening rating of **80**.

## Summary / TLDR
This project is a combination of significant upgrades and micro-optimizations. I've implemented most of the known & esoteric Linux performance tweaks along with some original implementations. The philosophy behind this "meta-distribution" is to utilize current hardware features and resources generously (when needed) while increasing system hardness greatly beyond the default.

The configuration files `sysctl.conf`, `limits.conf` and `grub` are pre-configured for specific workloads. Depending on the variant chosen there's specific changes tailored for each. These presets are **AMD/Intel**, **NVIDIA**, **Laptop**, **Performance**, **Server** and **AI**. They can be chosen in the installer and by running the `optional` command post-installation.

Originally I was inspired by Luke Smith's [LARBS](https://github.com/LukeSmithxyz/LARBS) which is why Algiz's installer is script-based rather than an ISO. This project is packaged similarly to an ISO due to the configurations and content being stored inside various archives. If you want to see what changes I've made you can view them [here](https://github.com/Michael-Sebero/Algiz-Linux/tree/main/files/algiz-packages).

## How Algiz Linux Works

### Kernel & Security Hardening
Algiz Linux implements comprehensive kernel hardening which increases security and performance. The system prevents privilege escalation attacks through restricted ptrace access and disabled unprivileged BPF operations, while eliminating core dump generation to prevent information leakage. Kernel debugging is restricted through pointer exposure protection and disabled SysRq functionality, with kexec disabled to prevent unauthorized kernel replacement. `ASLR` is enabled for memory protection against exploitation. NUMA balancing is disabled to eliminate automatic memory migration overhead.

### XanMod Kernel
The kernel which comes with the configuration is a custom build of XanMod which is tailored for x86-64-v3 CPU architecture. I've picked XanMod due to it's reliability and mature foundation, it performs more compared to baseline Linux. XanMod's **CFS** scheduler is replaced with a SCX Scheduler.

### Kernel Scheduler
The desktop scheduler is set to `LAVD` and laptops use `BPFLand` which provide high performance and low system latency. `LAVD` is configured for high performance with dynamic 250 µs slicing (1000 Hz+-equivalent responsiveness) and `BPFLand` is left default for simplicity. High intensity workloads and gaming are more enhanced by `LAVD` compared to `CFS` or `BORE`. If you want to change the scheduler it can be modified in `rc.local` under the scheduler section.

### Memory Management
RAM usage has the highest priority over swapping, keeping active data in memory reduces wear on the drive and increases system responsiveness. Swapping is still possible but only used when RAM is nearly filled. The VM subsystem is configured to reduce unnecessary memory compaction overhead while maintaining balanced VFS cache pressure for responsive file operations. HugePages are dynamically allocated on demand, providing up to 3968 large pages to reduce overhead and fragmentation for large memory workloads.

**Zram Integration:** The system configures a zram-based swap device `/dev/zram0` to provide fast, compressed virtual memory. Zram allocation is dynamically set to 25% of total RAM. The device is initialized with `mkswap` and immediately activated with `swapon`. Compression is set to `lz4`, prioritizing high performance over maximum compression.

**Tmpfs Overlay:** Temporary directories are mounted as tmpfs with the following size limits:
- `/tmp` – 5 GB
- `/var/tmp` – 1 GB
- `/var/cache` – 2 GB
- `/home/$USER/.cache` – 2 GB

**Bind-mounted Directories:** Essential directories are bind-mounted and remain on local storage:
- `/var/cache/pacman`
- `/home/$USER/.cache/paru`
- `/home/$USER/.cache/nvidia`
- `/home/$USER/.cache/mesa_shader_cache`
- `/home/$USER/.cache/mesa_shader_cache_db`

**Specified directories can be added in** `/bin/tmpfs-overlay`

**Garbage Collection:**
* Periodic cleanup: Removes files older than 10 minutes.

* Safe removal: Ensures files in use are never deleted.

### Network Management
Network performance leverages `BBR` congestion control and `cake` queue management to improve performance and reduce latency. The TCP stack uses expanded buffer sizes and enables fast connection establishment. IPv6 is limited through restrictive ICMP and routing settings. NetworkManager is set to use `dhclient` for DHCP with hostname handling disabled along with DNS encryption via [Mullvad](https://mullvad.net/en).

### Filesystem & I/O Optimization
Disk and SSD performance is tuned through scheduler and queue optimizations. SSDs use the `mq-deadline` scheduler for low-latency I/O, while HDDs use `bfq` for better fairness under mixed workloads. NVMe drives bypass the scheduler entirely (none) for maximum throughput. Read-ahead is increased to 4096 KB for improved sequential performance, while I/O queue depth is raised to 128 for SATA and 512 for NVMe, enabling higher parallelism. I/O request merging is enabled to combine adjacent requests for efficiency.

**F2FS:** Root and home partitions formatted with F2FS are optimized with background garbage collection enabled and tuned idle detection intervals to maintain flash-based storage performance consistency. To preserve SSD longevity and prevent write performance degradation, the system runs TRIM operations once every 7 days, reclaiming unused blocks. These processes ensure efficient resource use across F2FS filesystems.

### CPU Architecture Detection & ALHP Repository Integration
CPU architecture is automatically detected on installation to ensure optimal package installation. The system integrates some of ALHP's repositories which provide architecture-specific builds optimized for modern processor capabilities while keeping Artix's core system packages.

### Hardware-Specific Presets
* **AMD/Intel** - Configured for high performance and security.

* **NVIDIA** - Tweaked for maximum visual fidelity, high performance and security.

* **Laptop** - Balanced between power saving, performance and security, at 85% battery + AC connection performance is increased and reduced at 10%.

### Optional Workload-Specific Presets
* **Performance** - Maximum performance configuration with no security mitigations, CPU scheduling and expanded memory limits.

* **Server** - The system expands TCP/UDP buffer sizes up to 16MB for high-performance connections. TCP stack handling is tuned for scalability with up to 2 million `TIME_WAIT` sockets, window scaling and reuse enabled for faster turnaround. Security and stability are reinforced with SYN cookies, strict reverse path filtering, martian packet logging, disabled source routing and ICMP redirects. IPv4/IPv6 are both hardened with rate limiting for ICMP and disabled router advertisements. These settings balance low latency with resilience against network abuse patterns.

* **AI** - Specialized for AI workloads with larger HugePages allocation and no security mitigations.

<p align="center">
	<img src="https://i.postimg.cc/C53HDLTZ/ksnip-20240224-100057.png" />

## Donations and Contact
* [PayPal](https://www.paypal.com/donate/?cmd=_donations&business=YYGU9JWJEE2AG)
* [Email](michaelsebero@disroot.org)
