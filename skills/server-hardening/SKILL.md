---
name: server-hardening
description: Hardening Linux servers (Debian/Ubuntu/RHEL) — OS, firewall, audit, SSH, systemd, monitoring. Security-first approach.
category: devops
tags: [security, hardening, debian, ubuntu, rhel, firewall, auditd, ssh, systemd]
---

# Server Hardening Skill

Class-level skill for securing Linux servers. Covers OS hardening, firewall (UFW/nftables/iptables), auditd, SSH, systemd service hardening, and monitoring.

## When to Use

- New server provisioning (bare metal, VM, container host)
- Security baseline enforcement
- Compliance hardening (CIS, STIG, custom)
- Ongoing security maintenance

## Triggers

- User mentions "hardening", "secure server", "firewall", "auditd", "SSH hardening"
- New Debian/Ubuntu/RHEL server setup
- Security-first requirements

## Workflow

### 1. OS Hardening (sysctl)

Apply kernel parameters via `/etc/sysctl.d/99-hardening.conf`:

```bash
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
fs.suid_dumpable=0
```

Apply: `sysctl --system`

### 2. Firewall — UFW (VPN-only access)

**Default policies:**
```bash
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed
```

**Allow specific networks:**
```bash
ufw allow from 192.168.22.0/24
ufw allow from 192.168.14.64/28
ufw allow from 192.168.114.11
```

**ICMP/ping — restrict to trusted networks only** (edit `/etc/ufw/before.rules`):
- Allow echo-request (ping) only from allowed networks
- Drop echo-request from all other sources → server invisible on LAN
- Allow essential ICMP (destination-unreachable, time-exceeded, parameter-problem) for MTU/path MTU discovery
- Disable mDNS (5353) and UPnP (1900) — comment out in before.rules
- Disable IPv6 in `/etc/default/ufw` (IPV6=no)

**Enable:** `ufw --force enable`

### 3. auditd — Security Auditing

Install: `apt install -y auditd` (Debian/Ubuntu) or `dnf install -y audit` (RHEL)

Rules file: `/etc/audit/rules.d/audit.rules`

**Key rule categories:**
| Key | Coverage |
|-----|----------|
| `modules` | Kernel module load/unload |
| `exec` | All execve calls |
| `access_denied` | EACCES/EPERM on file open |
| `mounts` | Mount/umount |
| `identity` | passwd, group, shadow, gshadow, login.defs |
| `sudoers` | /etc/sudoers, /etc/sudoers.d |
| `sshd_config` | SSH daemon config |
| `network_config` | Network configuration files |
| `firewall_config` | UFW, nftables, iptables |
| `audit_config` | auditd self-monitoring |
| `hermes_config` | Service unit files |
| `cron_config` | Cron jobs |
| `pam_config` | PAM configuration |
| `auth_log` | Authentication logs |
| `priv_esc` | setuid, setgid, ptrace, capset |
| `time_change` | Time adjustments |
| `kernel_param` | sysctl changes |
| `audit_log` | Audit log files |

Load rules: `auditctl -R /etc/audit/rules.d/audit.rules`
Verify: `auditctl -l`
Restart service: `systemctl restart auditd`

### 4. SSH Hardening

Create `/etc/ssh/sshd_config.d/99-hardening.conf`:

```
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
LoginGraceTime 30
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
```

Reload: `systemctl reload ssh`

### 5. Systemd Service Hardening (least privilege)

Example `/etc/systemd/system/<service>.service`:

```ini
[Service]
User=<dedicated-user>
Group=<dedicated-group>
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
```

### 6. Integrity Monitoring (AIDE)

```bash
apt install -y aide
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
# Cron: 0 3 * * * /usr/bin/aide --check
```

### 7. Automatic Security Updates

```bash
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

## Pitfalls

- **UFW before.rules ownership**: After editing, ensure `root:root` and `640` permissions, else UFW warns on enable
- **auditd rules with wildcards**: `-w /etc/cron*` fails — expand to individual directories
- **auditd restart vs rule reload**: Use `auditctl -R` for live reload; rules file persists across reboots
- **IPv6 with UFW**: If not needed, disable in `/etc/default/ufw` to avoid dual-stack confusion
- **ICMP blocking**: Blocking all echo-request breaks path MTU discovery — allow essential ICMP types globally
- **SSH lockout**: Test SSH config before reload; keep a console session open
- **systemd hardening**: Over-restrictive `SystemCallFilter` breaks services — start with `@system-service`, add capabilities only as needed

## Verification Checklist

- [ ] `ufw status verbose` — correct policies and allowed networks
- [ ] `iptables -L ufw-before-input -v -n` — ICMP rules present
- [ ] `auditctl -l` — all expected keys loaded
- [ ] `systemctl status auditd` — active (running)
- [ ] `sshd -t` — config syntax OK
- [ ] `sysctl -a | grep -E 'rp_filter|icmp|ipv6|kptr|dmesg|suid'` — params applied
- [ ] `systemd-analyze security <service>` — hardening score

## References

- `references/ufw-before-rules-template.md` — Hardened before.rules with ICMP restrictions
- `references/auditd-rules-template.md` — Complete audit.rules with all key categories
- `references/ssh-hardening-template.conf` — SSH daemon hardening config
- `references/systemd-hardening-template.service` — Least-privilege systemd unit template
- `references/sysctl-hardening.conf` — Kernel hardening parameters

## Templates

- `templates/ufw-before.rules` — Ready-to-use before.rules with trusted-network ICMP
- `templates/audit.rules` — Complete auditd rules file
- `templates/sshd-hardening.conf` — SSH hardening drop-in
- `templates/hardened-service.service` — Systemd unit with full hardening
- `templates/sysctl-hardening.conf` — Kernel params drop-in
