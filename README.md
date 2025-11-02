<p align="center">
	<img src="https://i.postimg.cc/TYCbKN6L/Life.png" width="25%" />
</p>

<h1 align="center">Algiz Linux</h1>
<p align="center"><em>A High-Performance, Security-Focused Meta-Distribution of Artix Linux</em></p>

<br>

---

## Table of Contents

- [Core Components](#core-components)
  - [High Performance Kernel & Utilities](#high-performance-kernel--utilities)
  - [Security Software](#security-software)
  - [Additional Features](#additional-features)
- [Overview](#overview)
- [Technical Deep Dive](#technical-deep-dive)
- [Hardware Presets](#hardware-presets)
- [Optional Workload Presets](#optional-workload-presets)
- [Community & Support](#community--support)

---

## Core Components

### High Performance Kernel & Utilities

| Component | Description |
|-----------|-------------|
| **[SCX](https://github.com/sched-ext/scx)** | Dynamic Scheduler Extension Framework |
| **[XanMod](https://xanmod.org/)** | Custom Linux Kernel Optimized for Speed, Responsiveness and Desktop Performance |

### Security Software

| Component | Description |
|-----------|-------------|
| **[AppArmor](https://en.wikipedia.org/wiki/AppArmor)** | Mandatory Access Control Framework for Process-Level Security |
| **[Chkrootkit](https://en.wikipedia.org/wiki/Chkrootkit)** | Rootkit Detection Tool That Scans for Common Signs of System Compromise |
| **[ClamAV](https://github.com/Cisco-Talos/clamav)** | Antivirus Engine for Detecting Malware and Trojans |
| **[DNSCrypt](https://github.com/DNSCrypt/dnscrypt-protocol)** | Protocol That Encrypts DNS Traffic to Prevent Spoofing and DNS Eavesdropping |
| **[DNSMasq](https://thekelleys.org.uk/dnsmasq/doc.html)** | Lightweight DNS and DHCP Server for Local Networks |
| **[Fail2Ban](https://github.com/fail2ban/fail2ban)** | Intrusion Prevention Tool That Bans IPs Showing Malicious Signs |
| **[Linux Hardening Script](https://github.com/Michael-Sebero/Linux-Hardening-Script)** | Automated System Security and Configuration Hardening Script |
| **[Lynis](https://github.com/CISOfy/lynis)** | Security Auditing and Compliance Tool |
| **[USBGuard](https://github.com/USBGuard/usbguard)** | Framework for Implementing USB Device Authorization Policies |
| **[UFW](https://en.wikipedia.org/wiki/Uncomplicated_Firewall)** | GUI for Managing Iptables-Based Firewalls |

### Additional Features

<table>
<tr>
<td width="50%" valign="top">

**System Performance**
- Low Latency [PipeWire](https://github.com/PipeWire/pipewire) Audio Processing
- [Booster](https://github.com/anatol/booster) - Faster Mkinitcpio Replacement
- [Mimalloc](https://github.com/microsoft/mimalloc) High-Performance Memory Allocator
- [Ephemeral Overlay](https://github.com/Michael-Sebero/Ephemeral-Overlay) - Reduces Disk I/O
- [Real-time](https://gitlab.archlinux.org/archlinux/packaging/packages/realtime-privileges) Audio Processing
- [Earlyoom](https://github.com/rfjakob/earlyoom) - Early OOM Daemon

</td>
<td width="50%" valign="top">

**Gaming & Productivity**
- [GameMode](https://github.com/FeralInteractive/gamemode) - Performance on Demand for Games
- [Game Focus](https://github.com/Michael-Sebero/Game-Focus) - Optimized Game Launcher
- Steam [Proton GE](https://github.com/GloriousEggroll/proton-ge-custom) Prefix
- [Archivist Tools](https://github.com/Michael-Sebero/Archivist-Tools) - Productivity Suite
- [Audio Frequency Tools](https://github.com/Michael-Sebero/Audio-Frequency-Tools)
- [Document Tools](https://github.com/Michael-Sebero/Document-Tools)
- [Media Tools](https://github.com/Michael-Sebero/Media-Tools)

</td>
</tr>
<tr>
<td width="50%" valign="top">

**Security & Privacy**
- MAC Address Randomization via [Macchanger](https://www.kali.org/tools/macchanger/)
- Lynis System Hardening Rating of **80**
- Comprehensive [Manual](https://raw.githubusercontent.com/Michael-Sebero/Algiz-Linux/refs/heads/main/files/algiz-manual/Manual)

</td>
<td width="50%" valign="top">

**Package Management**
- [ALHP](https://wiki.archlinux.org/title/Unofficial_user_repositories#ALHP) Repository
- [Chaotic AUR](https://github.com/chaotic-aur/packages) Repository
- [Flatpak](https://flatpak.org/) Support
- [Arch Package Dictionary](https://github.com/Michael-Sebero/Arch-Package-Dictionary) - Search Tool

</td>
</tr>
<tr>
<td width="50%" valign="top">

**Laptop Optimization**
- Battery Life Optimizations via [TLP](https://github.com/linrunner/TLP)
- [System Tuner](https://github.com/Michael-Sebero/System-Tuner) - Performance Manager

</td>
<td width="50%" valign="top">

**Maintenance & Recovery**
- [Fix Arch Linux](https://github.com/Michael-Sebero/Fix-Arch-Linux) - Diagnostic Toolset

</td>
</tr>
</table>

---

## Overview

Algiz Linux is a comprehensive enhancement of Artix Linux that combines significant performance upgrades with extensive security hardening. This meta-distribution implements both well-known and esoteric Linux optimization techniques alongside original implementations, creating a system that leverages modern hardware capabilities while maintaining robust security.

**Design Philosophy:** Utilize current hardware features and resources generously when needed, while significantly increasing system security beyond default configurations.

**Configuration:** The system includes pre-configured files for `sysctl.conf`, `limits.conf`, and `grub`, optimized for specific workloads. Hardware-specific variants include **AMD/Intel**, **NVIDIA**, **Laptop**, **Performance**, **Server**, and **AI** presets, selectable during installation or via the `optional` command post-installation.

**Installation Method:** Inspired by Luke Smith's [LARBS](https://github.com/LukeSmithxyz/LARBS), Algiz uses a script-based installer rather than an ISO. The project packages configurations and content in archives for easy deployment. View all system changes [here](https://github.com/Michael-Sebero/Algiz-Linux/tree/main/files/algiz-packages).

---

## Technical Deep Dive

### Kernel & Security Hardening

Algiz Linux implements comprehensive kernel hardening that enhances both security and performance through multiple layers of protection.

**Attack Surface Reduction:**
- Restricted ptrace access prevents privilege escalation attacks
- Disabled unprivileged BPF operations eliminate potential exploitation vectors
- Core dump generation disabled to prevent information leakage
- Kernel debugging restricted through pointer exposure protection
- Disabled SysRq functionality and kexec to prevent unauthorized kernel replacement

**Memory Protection:**
- ASLR enabled for protection against exploitation
- NUMA balancing disabled to eliminate automatic memory migration overhead

### XanMod Kernel

The system uses a custom build of XanMod tailored for x86-64-v3 CPU architecture. XanMod was selected for its reliability and demonstrated [performance advantages](https://www.phoronix.com/review/xanmod-liquorix-510/5) over the standard Linux kernel. The default CFS scheduler is replaced with an SCX-based scheduler for improved performance and responsiveness.

### Kernel Scheduler

**Desktop Configuration:** Uses `LAVD` scheduler with dynamic 250 µs slicing, providing 1000 Hz+ equivalent responsiveness for maximum desktop performance.

**Laptop Configuration:** Uses `BPFLand` scheduler with default settings for optimal balance between performance and power efficiency.

Scheduler configuration can be modified in `rc.local` under the scheduler section.

### Memory Management

**Priority Hierarchy:** RAM usage receives highest priority over swapping, keeping active data in memory to reduce drive wear and maximize system responsiveness. Swapping occurs only when RAM approaches capacity.

**VM Subsystem:** Configured to reduce unnecessary memory compaction overhead while maintaining balanced VFS cache pressure for responsive file operations. HugePages are dynamically allocated on demand, providing up to 3968 large pages to reduce overhead and fragmentation for large memory workloads.

#### Zram Integration

The system configures a zram-based swap device `/dev/zram0` to provide fast, compressed virtual memory:
- Dynamic allocation set to 25% of total RAM
- Initialized with `mkswap` and immediately activated with `swapon`

#### Tmpfs Overlay

Temporary directories are mounted as tmpfs with the following size limits:
- `/tmp` – 5 GB
- `/var/tmp` – 1 GB
- `/var/cache` – 2 GB
- `/home/$USER/.cache` – 2 GB

#### Bind-mounted Directories

Essential directories remain on local storage:
- `/var/cache/pacman`
- `/home/$USER/.cache/paru`
- `/home/$USER/.cache/nvidia`
- `/home/$USER/.cache/mesa_shader_cache`
- `/home/$USER/.cache/mesa_shader_cache_db`

#### RAM Overlay of Root Filesystem

- Root filesystem `/` is overlaid in RAM using an overlay filesystem
- Changes stored in RAM and synced back to disk on shutdown
- Excluded directories remain on disk: `/home`, `/tmp`, `/var/tmp`, `/var/cache`, `/proc`, `/sys`, `/dev`, `/run`, `/mnt`, `/media`, `/boot`

**Configuration:** Specified directories can be added in `/bin/ephemeral-overlay`

#### Garbage Collection

- **Periodic cleanup:** Removes files older than 10 minutes
- **Safe removal:** Ensures files in use are never deleted

### Network Management

Network performance leverages `BBR` congestion control and `cake` queue management to improve throughput and reduce latency. The TCP stack uses expanded buffer sizes and enables fast connection establishment. IPv6 is limited through restrictive ICMP and routing settings. NetworkManager uses `dhclient` for DHCP with hostname handling disabled, along with DNS encryption via [Mullvad](https://mullvad.net/en).

### Filesystem & I/O Optimization

Disk and SSD performance is tuned through scheduler and queue optimizations:

**Scheduler Selection:**
- **SSDs:** `mq-deadline` scheduler for low-latency I/O
- **HDDs:** `bfq` for better fairness under mixed workloads
- **NVMe:** Bypass scheduler entirely (none) for maximum throughput

**Performance Tuning:**
- Read-ahead increased to 4096 KB for improved sequential performance
- I/O queue depth raised to 128 for SATA and 512 for NVMe
- I/O request merging enabled to combine adjacent requests

#### F2FS Optimization

Root and home partitions formatted with F2FS are optimized with:
- Background garbage collection enabled
- Tuned idle detection intervals for consistent flash-based storage performance
- TRIM operations executed once every 7 days to preserve SSD longevity and prevent write performance degradation

### CPU Architecture Detection & ALHP Repository Integration

CPU architecture is automatically detected during installation to ensure optimal package installation. The system integrates ALHP's repositories, providing architecture-specific builds optimized for modern processor capabilities while maintaining Artix's core system packages.

---

## Hardware Presets

### AMD/Intel
Configured for high performance and security with optimizations for x86 processors.

### NVIDIA
Tweaked for maximum visual fidelity, high performance, and security with GPU-specific optimizations.

### Laptop
Balanced configuration between power saving, performance, and security:
- Performance increased at 85%+ battery with AC connection
- Power saving mode activated at 10% battery

---

## Optional Workload Presets

### Performance
Maximum performance configuration featuring:
- Disabled security mitigations for maximum speed
- Optimized CPU scheduling
- Expanded memory limits

### Server
High-performance network configuration with:
- TCP/UDP buffer sizes expanded up to 16MB
- TCP stack handling tuned for scalability with up to 2 million TIME_WAIT sockets
- Window scaling and reuse enabled for faster turnaround
- Security hardening with SYN cookies, strict reverse path filtering, martian packet logging
- Disabled source routing and ICMP redirects
- IPv4/IPv6 hardening with rate limiting for ICMP and disabled router advertisements

Balances low latency with resilience against network abuse patterns.

### AI
Specialized for AI workloads featuring:
- Larger HugePages allocation
- Disabled security mitigations for maximum computational performance

---

<p align="center">
	<img src="https://i.postimg.cc/C53HDLTZ/ksnip-20240224-100057.png" />
</p>

---

## Community & Support

### Get in Touch

**Email:** michaelsebero@disroot.org

**Matrix:** [#algiz-linux:matrix.org](https://matrix.to/#/#algiz-linux:matrix.org)

### Support Development

If you find Algiz Linux useful, consider supporting its development:

**[Donate via PayPal](https://www.paypal.com/donate/?cmd=_donations&business=YYGU9JWJEE2AG)**

---

<p align="center">
	<em>Built with performance and security in mind</em>
</p>
