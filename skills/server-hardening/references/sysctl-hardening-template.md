# Kernel Hardening sysctl Parameters

Drop-in for `/etc/sysctl.d/99-hardening.conf`.

```bash
sudo cp templates/sysctl-hardening.conf /etc/sysctl.d/99-hardening.conf
sudo sysctl --system
```

## Parameters

```ini
# === Network Security ===
# Reverse path filtering - validate source IP
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP echo requests to broadcast/multicast (smurf protection)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Do not accept source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Disable IPv6 if not used (reduces attack surface)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# TCP SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log packets with impossible addresses (Martians)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# === Kernel Security ===
# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Disable SysRq key (prevents low-level system manipulation)
kernel.sysrq = 0

# Restrict perf subsystem
kernel.perf_event_paranoid = 3

# Disable core dumps for setuid processes
fs.suid_dumpable = 0

# Protect hardlinks and symlinks from TOCTOU attacks
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

# Restrict following symlinks in sticky world-writable dirs
fs.protected_regular = 2
fs.protected_fifos = 2

# === Filesystem Protection ===
# Hide kernel symbols
kernel.kptr_restrict = 2

# Restrict access to kernel logs
kernel.dmesg_restrict = 1

# === User Namespace ===
# Restrict unprivileged user namespaces (if not needed for containers)
# user.max_user_namespaces = 0  # Uncomment if not using Docker/Podman rootless

# === ASLR ===
# Force ASLR for all processes
kernel.randomize_va_space = 2

# === BPF ===
# Restrict unprivileged BPF (if not needed)
# kernel.unprivileged_bpf_disabled = 1
```

## Per-Interface Tuning

For specific interfaces (e.g., VPN interface `wg0`):

```ini
# Allow forwarding on VPN interface only
net.ipv4.conf.wg0.forwarding = 1
# Disable on all others
net.ipv4.conf.eth0.forwarding = 0
net.ipv4.conf.all.forwarding = 0
```

## Apply & Verify

```bash
# Apply
sudo sysctl --system

# Verify
sysctl -a | grep -E 'rp_filter|icmp|ipv6|kptr|dmesg|sysrq|perf|suid|protected|syncookies|martians|randomize'
```

## Notes

- **IPv6 disable**: Comment out if IPv6 required. Prefer firewall rules over kernel disable.
- **user.max_user_namespaces**: Set to 0 breaks rootless containers (Docker/Podman rootless, Kubernetes kind). Keep enabled if using containers.
- **kernel.unprivileged_bpf_disabled**: Breaks some observability tools (bpftrace, cilium). Keep 0 if needed.
- **net.ipv4.conf.all.log_martians**: Generates logs; ensure logrotation configured.

## CIS Benchmark Mapping

| Parameter | CIS Benchmark |
|-----------|---------------|
| net.ipv4.conf.all.rp_filter | 3.1.1 |
| net.ipv4.icmp_echo_ignore_broadcasts | 3.2.1 |
| net.ipv4.icmp_ignore_bogus_error_responses | 3.2.2 |
| net.ipv4.conf.all.send_redirects | 3.2.3 |
| net.ipv4.conf.all.accept_source_route | 3.2.4 |
| net.ipv4.conf.all.log_martians | 3.2.5 |
| kernel.kptr_restrict | 1.7.1 |
| kernel.dmesg_restrict | 1.7.2 |
| kernel.sysrq | 1.7.3 |
| fs.suid_dumpable | 1.5.1 |
| kernel.randomize_va_space | 1.7.4 |