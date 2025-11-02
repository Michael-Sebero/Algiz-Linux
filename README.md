<p align="center">
  <img src="https://i.postimg.cc/TYCbKN6L/Life.png" alt="Algiz Linux Logo" width="160">
</p>

<h1 align="center">Algiz Linux</h1>

<p align="center">
  A High-Performance, Security-Focused Meta-Distribution of Artix Linux
</p>

---

## Overview
Algiz Linux is a script-based meta-distribution designed for performance, reliability, and system hardening.  
It integrates advanced kernel tuning, security frameworks, and optimized configuration presets for modern hardware.

---

## Included Components

### High Performance Kernel & Utilities
- [SCX](https://github.com/sched-ext/scx) – Dynamic Scheduler Extension Framework  
- [XanMod](https://xanmod.org/) – Custom Linux Kernel optimized for responsiveness and desktop performance  

### Security Software
- [AppArmor](https://en.wikipedia.org/wiki/AppArmor) – Mandatory Access Control framework  
- [Chkrootkit](https://en.wikipedia.org/wiki/Chkrootkit) – Rootkit detection utility  
- [ClamAV](https://github.com/Cisco-Talos/clamav) – Open-source antivirus engine  
- [DNSCrypt](https://github.com/DNSCrypt/dnscrypt-protocol) – DNS encryption protocol  
- [DNSMasq](https://thekelleys.org.uk/dnsmasq/doc.html) – Lightweight DNS and DHCP server  
- [Fail2Ban](https://github.com/fail2ban/fail2ban) – Intrusion prevention and IP banning tool  
- [Linux Hardening Script](https://github.com/Michael-Sebero/Linux-Hardening-Script) – Automated security configuration  
- [Lynis](https://github.com/CISOfy/lynis) – Security auditing and compliance tool  
- [USBGuard](https://github.com/USBGuard/usbguard) – USB device authorization policy framework  
- [UFW](https://en.wikipedia.org/wiki/Uncomplicated_Firewall) – Simplified firewall configuration utility  

### Additional Features
- Integrated [Manual](https://raw.githubusercontent.com/Michael-Sebero/Algiz-Linux/refs/heads/main/files/algiz-manual/Manual)  
- MAC address randomization via [Macchanger](https://www.kali.org/tools/macchanger/)  
- Low-latency [PipeWire](https://github.com/PipeWire/pipewire) audio system  
- Support for [ALHP](https://wiki.archlinux.org/title/Unofficial_user_repositories#ALHP), [Chaotic AUR](https://github.com/chaotic-aur/packages), and [Flatpak](https://flatpak.org/) repositories  
- Steam [Proton GE](https://github.com/GloriousEggroll/proton-ge-custom) integration  
- [Booster](https://github.com/anatol/booster) – Fast mkinitcpio replacement  
- Laptop power management via [TLP](https://github.com/linrunner/TLP)  
- [System Tuner](https://github.com/Michael-Sebero/System-Tuner) – Performance manager  
- [Mimalloc](https://github.com/microsoft/mimalloc) – High-performance memory allocator  
- [Ephemeral Overlay](https://github.com/Michael-Sebero/Ephemeral-Overlay) – RAM-based overlay for temporary directories  
- [GameMode](https://github.com/FeralInteractive/gamemode) – Dynamic performance scaling for games  
- [Game Focus](https://github.com/Michael-Sebero/Game-Focus) – Lightweight gaming session launcher  
- [Arch Package Dictionary](https://github.com/Michael-Sebero/Arch-Package-Dictionary) – Search interface for Pacman, AUR, and Flatpak  
- Productivity suite: [Archivist Tools](https://github.com/Michael-Sebero/Archivist-Tools), [Audio Frequency Tools](https://github.com/Michael-Sebero/Audio-Frequency-Tools), [Document Tools](https://github.com/Michael-Sebero/Document-Tools), [Media Tools](https://github.com/Michael-Sebero/Media-Tools)  
- [EarlyOOM](https://github.com/rfjakob/earlyoom) – Early out-of-memory daemon  
- [Fix Arch Linux](https://github.com/Michael-Sebero/Fix-Arch-Linux) – Diagnostic toolkit  

---

## Summary
Algiz Linux combines structural system enhancements and targeted micro-optimizations.  
All system parameters are tuned to maximize hardware utilization while maintaining strict security posture.

System presets are available for multiple environments: **AMD/Intel**, **NVIDIA**, **Laptop**, **Performance**, **Server**, and **AI**.  
Each preset applies custom kernel, scheduler, and resource configurations.  
Installation and post-installation customization are managed through script execution rather than ISO deployment.

---

## Kernel and Security Configuration

### Kernel Hardening
The kernel is built with a comprehensive security and performance profile:
- Restricted ptrace and disabled unprivileged BPF operations  
- Disabled kexec and SysRq for integrity protection  
- ASLR enabled for address space randomization  
- Pointer exposure protection enabled  
- Core dump generation disabled  
- NUMA balancing disabled to eliminate migration overhead  

### XanMod Kernel
A custom XanMod build optimized for x86-64-v3 architecture.  
Default CFS is replaced with the SCX scheduler to improve responsiveness and task distribution.

### Scheduler Configuration
- **Desktop:** LAVD scheduler with dynamic 250 µs slicing (~1000 Hz responsiveness)  
- **Laptop:** BPFLand scheduler with balanced latency and efficiency  
Schedulers are configurable in `rc.local` under the scheduler section.  

---

## Memory Management
RAM is prioritized over swap to minimize latency and drive wear.  
Swapping is used only under high memory pressure.

**ZRAM Integration**  
- `/dev/zram0` configured as compressed swap (25% of total RAM)  

**Tmpfs Overlays**  
- `/tmp` – 5 GB  
- `/var/tmp` – 1 GB  
- `/var/cache` – 2 GB  
- `/home/$USER/.cache` – 2 GB  

**Overlay Root Filesystem**  
- Root (`/`) overlaid in RAM with changes synchronized on shutdown  
- Persistent directories: `/home`, `/tmp`, `/var/tmp`, `/var/cache`, `/proc`, `/sys`, `/dev`, `/run`, `/mnt`, `/media`, `/boot`  

Garbage collection periodically removes inactive temporary files.

---

## Network Configuration
Network stack tuned for throughput and latency:
- BBR congestion control  
- Cake queue management  
- Expanded TCP buffers  
- IPv6 routing limited with ICMP restrictions  
- DNS encrypted through [Mullvad](https://mullvad.net/en) integration  
- DHCP handled via NetworkManager with `dhclient` backend  

---

## Filesystem and I/O
- SSD: `mq-deadline` scheduler  
- HDD: `bfq` scheduler  
- NVMe: `none` scheduler  
- Read-ahead buffer: 4096 KB  
- I/O queue depth: 128 (SATA) / 512 (NVMe)  
- Request merging enabled  

**F2FS Optimization**  
- Background garbage collection and idle tuning enabled  
- Weekly TRIM operations for SSD maintenance  

---

## Architecture and Repository Integration
Automatic CPU architecture detection ensures optimal package builds.  
Selected [ALHP](https://wiki.archlinux.org/title/Unofficial_user_repositories#ALHP) repositories provide architecture-specific packages while maintaining Artix compatibility.

---

## Preset Configurations

**AMD/Intel** – Performance and security balance  
**NVIDIA** – Optimized for visual performance and latency  
**Laptop** – Adaptive power and performance management  

Optional workload presets:

| Preset | Description |
|---------|-------------|
| **Performance** | Maximum performance, mitigations disabled |
| **Server** | Optimized network stack, large buffer limits, enhanced scalability |
| **AI** | Expanded HugePages, security mitigations disabled |

---

<p align="center">
  <img src="https://i.postimg.cc/C53HDLTZ/ksnip-20240224-100057.png" width="700">
</p>

---

## Contact and Support
- Email: [michaelsebero@disroot.org](mailto:michaelsebero@disroot.org)  
- Matrix: [#algiz-linux:matrix.org](https://matrix.to/#/#algiz-linux:matrix.org)  
- PayPal: [Donation Link](https://www.paypal.com/donate/?cmd=_donations&business=YYGU9JWJEE2AG)  

---

<p align="center">
  Algiz Linux — Precision. Performance. Security.
</p>
