---
name: linux-server-hardening
description: Harden Linux servers (Debian/Ubuntu/RHEL) — firewall, auditd, SSH, kernel params, logging. Security-first baseline for infrastructure hosts.
category: devops
tags: [security, hardening, firewall, auditd, ufw, nftables, ssh, debian, ubuntu, compliance]
---

# Linux Server Hardening

Security-first baseline for infrastructure servers. Covers firewall (UFW/nftables), auditd, SSH, kernel sysctl, log rotation. Designed for VPN-only or restricted-network hosts.

## Trigger Conditions

- New server provisioning (bare metal, VM, container host)
- Security audit remediation
- Compliance hardening (CIS, STIG baselines)
- Pre-production checklist

## Prerequisites

- Root/sudo access
- Debian 12+/Ubuntu 22.04+/RHEL 9+ (adapt package names for other distros)
- Known trusted CIDRs for management access

---

## 1. Firewall — UFW (Debian/Ubuntu)

### Default Policies

```bash
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed
```

### Allow Trusted Networks (full access)

```bash
ufw allow from 192.168.22.0/24
ufw allow from 192.168.14.64/28
ufw allow from 192.168.114.11
```

### ICMP/Ping — Restrict to Trusted Only

Edit `/etc/ufw/before.rules` (IPv4) — see `references/ufw-before.rules.template`:

- Allow echo-request (ping) **only** from trusted CIDRs
- Allow essential ICMP (destination-unreachable, time-exceeded, parameter-problem) from trusted CIDRs
- **DROP** echo-request from all other sources → host invisible on LAN
- Keep essential ICMP from anywhere (MTU/path MTU discovery)
- Disable mDNS (5353) and UPnP (1900) — comment out default allow rules

### IPv6

Disable if not used:

```bash
sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw
```

### Silent DROP for mDNS/UPnP Log Spam

**Problem:** Default UFW allows mDNS (224.0.0.251:5353 UDP) and UPnP/SSDP (239.255.255.250:1900 UDP), causing `[UFW BLOCK]` log spam on servers.

**Fix:** Add explicit DROP rules in `/etc/ufw/before.rules` **before** the `ufw-not-local` chain:

```bash
# silently drop mDNS (multicast DNS) and UPnP/SSDP to stop log spam
-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j DROP
-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j DROP
```

Place after `ufw-not-local` chain returns and before final DROP. This prevents logging while dropping silently.

### Enable

```bash
ufw --force enable
chown root:root /etc/ufw/before.rules && chmod 640 /etc/ufw/before.rules
```

### Verify

```bash
ufw status verbose
iptables -L ufw-before-input -v -n | grep -E '(icmp|DROP|ACCEPT)'
```

---

## 2. Auditd — Comprehensive Rules

Install:

```bash
apt install -y auditd audispd-plugins  # Debian/Ubuntu
```

Deploy rules from `references/audit.rules.template` to `/etc/audit/rules.d/audit.rules`.

Key categories covered:

| Key | What It Watches |
|-----|-----------------|
| `modules` | Kernel module load/unload |
| `exec` | All `execve` calls |
| `access_denied` | EACCES/EPERM on file open |
| `mounts` | Mount/umount |
| `identity` | passwd, group, shadow, gshadow, login.defs |
| `sudoers` | /etc/sudoers, /etc/sudoers.d/ |
| `sshd_config` | SSH daemon config |
| `network_config` | Netplan, systemd-networkd, hosts, resolv.conf |
| `firewall_config` | UFW, nftables, iptables |
| `audit_config` | auditd self-monitoring |
| `hermes_config` | Hermes systemd unit (adapt path) |
| `cron_config` | Cron tabs and directories |
| `pam_config` | PAM config |
| `auth_log` | Auth logs |
| `priv_esc` | setuid/setgid, ptrace, capset |
| `time_change` | adjtimex, settimeofday, clock_settime |
| `kernel_param` | sysctl.conf, sysctl.d/ |
| `audit_log` | /var/log/audit/ |

### Load & Persist

```bash
auditctl -R /etc/audit/rules.d/audit.rules
systemctl restart auditd
systemctl enable auditd
```

### Verify

```bash
auditctl -l
```

---

## 3. Logrotate for Auditd

Deploy `references/audit-logrotate.template` to `/etc/logrotate.d/audit`:

```text
/var/log/audit/audit.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        /bin/systemctl reload auditd > /dev/null 2>&1 || true
    endscript
}
```

Set ownership:

```bash
chown root:root /etc/logrotate.d/audit && chmod 644 /etc/logrotate.d/audit
```

Test:

```bash
logrotate -d /etc/logrotate.d/audit
```

---

## 4. SSH Hardening (Reference)

Create `/etc/ssh/sshd_config.d/99-hardening.conf`:

```text
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

Reload:

```bash
systemctl reload ssh
```

---

## 5. Kernel Sysctl Hardening (Reference)

Create `/etc/sysctl.d/99-hardening.conf`:

```text
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

Apply:

```bash
sysctl --system
```

---

## 6. Hermes Systemd Unit — Least Privilege

See `references/hermes-systemd.template` for a hardened unit with:

- `NoNewPrivileges=yes`
- `PrivateTmp=yes`
- `ProtectSystem=strict`
- `ProtectHome=yes`
- `ProtectKernelTunables=yes`
- `ProtectKernelModules=yes`
- `ProtectControlGroups=yes`
- `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6`
- `RestrictNamespaces=yes`
- `LockPersonality=yes`
- `MemoryDenyWriteExecute=yes`
- `SystemCallFilter=@system-service`
- `CapabilityBoundingSet=CAP_NET_BIND_SERVICE`

---

## 7. Conntrack Tuning for Long-Lived HTTPS Connections

**Problem:** Long-lived HTTPS connections (Telegram long-polling, API providers) return `ACK`/`ACK FIN` packets **after local socket close**. If conntrack entry expired, return packets are blocked by default `deny (incoming)` policy.

**Symptoms:** `[UFW BLOCK]` logs showing `SRC=<provider IP> DPT=<ephemeral port> FLAGS=ACK/FIN` from legitimate API responses.

**Fix:** Tune conntrack timeouts in `/etc/sysctl.d/99-conntrack-tuning.conf`:

```bash
# Conntrack tuning for long-lived HTTPS connections
# Prevents return packets (ACK, ACK FIN) being blocked after local close

net.netfilter.nf_conntrack_tcp_timeout_established = 432000
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 300
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 300
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 180

# TCP keepalive defaults (application must enable SO_KEEPALIVE)
net.ipv4.tcp_keepalive_time = 7200
net.ipv4.tcp_keepalive_intvl = 75
net.ipv4.tcp_keepalive_probes = 9
```

Apply: `sysctl --system`

| Parameter | Default | Tuned | Purpose |
|-----------|---------|-------|---------|
| `nf_conntrack_tcp_timeout_time_wait` | 120s | **300s** | Return packets (ACK FIN) after local close pass |
| `nf_conntrack_tcp_timeout_fin_wait` | 120s | **300s** | Return packets in FIN_WAIT state pass |
| `nf_conntrack_tcp_timeout_close_wait` | 60s | **180s** | More time for HALF-CLOSE state |

**Note:** Application (e.g., Hermes gateway, aiogram) should enable `SO_KEEPALIVE` on sockets for best results.

---

## 8. TPM 2.0 — Hardware-Backed SSH Keys & Secrets

**Prerequisites:** TPM 2.0 device (`/dev/tpm0`, `/dev/tpmrm0`), `tss` group access.

### Install Packages (Debian/Ubuntu)

```bash
apt install -y tpm2-tools libtpm2-pkcs11-1 libtpm2-pkcs11-tools tpm2-abrmd gnutls-bin opensc pcscd
```

### Configure User Access

```bash
usermod -aG tss <user>   # logout/login or 'newgrp tss' after
udevadm control --reload-rules && udevadm trigger
```

### Initialize PKCS#11 Store

```bash
# Run as user in 'tss' group (newgrp tss)
export TPM2_PKCS11_STORE="$HOME/.tpm2_pkcs11"
tpm2_ptool init
tpm2_ptool addtoken --label=ssh-keys --userpin=<user-pin> --sopin=<so-pin>
tpm2_ptool addkey --label=ssh-keys --algorithm=rsa2048 --userpin=<user-pin>
```

### Export SSH Public Key

```bash
GNUTLS_PIN=<user-pin> p11tool --export-pubkey --login --outfile=~/.ssh/tpm_key.pub \
  "pkcs11:model=<model>;manufacturer=<mfr>;serial=<serial>;token=ssh-keys;object=;type=public"

# Convert to SSH format
ssh-keygen -f ~/.ssh/tpm_key.pub -i -m PKCS8 > ~/.ssh/tpm_key_ssh.pub
```

### Use with SSH

```bash
# Direct
ssh -I /usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so user@host

# Or ~/.ssh/config
Host myserver
    HostName server.example.com
    User rene
    PKCS11Provider /usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so
```

### PKCS#11 Module Path

```
/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so
```

### TPM2-abrmd Service

Ensure running for resource management:

```bash
systemctl enable --now tpm2-abrmd
```

### Configuration for tabrmd (optional but recommended)

Create `/etc/tpm2_pkcs11.conf`:

```ini
[tcti]
name = "tabrmd"
```

### TPM 2.0 ed25519 Limitation & Workaround

**Problem:** TPM 2.0 specification does not include Curve25519 (ed25519). Supported curves are NIST P-224, P-256, P-384, P-521, Brainpool, SM2.

**Workaround:** Use **NIST P-256 (secp256r1 / prime256v1)** — equivalent ~128-bit security level to ed25519, widely supported by OpenSSH.

```bash
# Generate NIST P-256 key in TPM (instead of ed25519)
tpm2_ptool addkey --label=ssh-keys --algorithm=ecc256 --userpin=<user-pin> --key-label=ssh-p256
```

**ssh-agent Integration (PIN once per session) — WORKING PATTERN:**

```bash
# Start agent + add TPM key (prompts for PIN once)
eval $(ssh-agent -s)
ssh-add -s /usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so <<< "USER_PIN"

# All subsequent SSH connections use agent — NO PIN PROMPT
ssh user@server1
ssh user@server2
scp file user@server:/path/
```

**Critical:** The heredoc `<<< "PIN"` syntax is required — interactive prompt may not work in all environments.

**SSH Config for automatic PKCS#11:**

```ssh
Host myserver
    HostName server.example.com
    User rene
    PKCS11Provider /usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so
    IdentitiesOnly yes
    PubkeyAuthentication yes
```

---

### TPM Diagnostic Commands

**Test key signing (verifies PIN + key health):**

```bash
# Requires newgrp tss (or tss group membership)
newgrp tss << 'EOF'
GNUTLS_PIN=<user-pin> p11tool --test-sign --login \
  --provider=/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so \
  "pkcs11:token=ssh-keys;object=ssh-p256;type=private"
EOF
```

**List tokens and objects:**

```bash
newgrp tss << 'EOF'
tpm2_ptool listtokens
tpm2_ptool listobjects --label=ssh-keys
EOF
```

**Direct SSH test with debugging:**

```bash
newgrp tss << 'EOF'
ssh -vvv -I /usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so \
  -o IdentitiesOnly=yes -o PubkeyAuthentication=yes \
  user@host "echo test"
EOF
```

---

### Common Error Signatures & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `login failed` + `pkcs11_get_key failed` | OpenSSH `-I` doesn't implement PIN prompt | Use **ssh-agent** pattern above, or `onepin-opensc-pkcs11.so` proxy |
| `agent refused operation` | ssh-agent PKCS#11 integration issue | Ensure `ssh-agent -k` first, then fresh agent; try explicit URI |
| `signing failed: error in libcrypto` | Token not logged in (no C_Login) | Use ssh-agent (handles login) or pre-login token |
| `Wrong PIN has been provided!` + `DA counter incremented` | Wrong PIN entered | Use correct PIN; after 3 failures → DA lockout |
| `TPM is in DA lockout mode` (0x921) | Too many failed PIN attempts | **Reboot** (resets DA counter) |
| `Could not add card: agent refused operation` | Agent state / URI issue | `ssh-agent -k` → fresh agent → `ssh-add -s <PKCS11_MOD> <<< PIN` |

---

### DA Lockout Recovery Procedure

```bash
# 1. Reboot (resets DA counter)
sudo reboot

# 2. After reboot, verify PIN works
newgrp tss << 'EOF'
GNUTLS_PIN=<user-pin> p11tool --test-sign --login \
  --provider=/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so \
  "pkcs11:token=ssh-keys;object=ssh-p256;type=private"
EOF

# 3. If PIN forgotten/changed — recreate token:
newgrp tss << 'EOF'
tpm2_ptool rmtoken --label=ssh-keys
tpm2_ptool init
tpm2_ptool addtoken --pid=1 --label=ssh-keys \
  --userpin=<NEW_USER_PIN> --sopin=<NEW_SO_PIN>
tpm2_ptool addkey --label=ssh-keys --algorithm=ecc256 \
  --userpin=<NEW_USER_PIN> --key-label=ssh-p256
tpm2_ptool listobjects --label=ssh-keys
EOF
```

---

### Alternative: onepin-opensc-pkcs11.so Proxy

If ssh-agent is not desired, use the onepin proxy (caches PIN in gnome-keyring/kwallet):

```bash
# First connection prompts for PIN, caches in system keyring
ssh -I /usr/lib/x86_64-linux-gnu/pkcs11/onepin-opensc-pkcs11.so user@host

# Subsequent connections use cached PIN — no prompt
```

---

### PKCS#11 URI Format (Explicit Key Selection)

```bash
# Full URI with PIN (for ssh -i or ssh-add -s)
pkcs11:token=ssh-keys;object=ssh-p256;type=private;pin-value=USER_PIN
```

Components:
- `token=` — token label from `tpm2_ptool addtoken --label`
- `object=` — key label from `tpm2_ptool addkey --key-label`
- `type=private` — required for private key operations
- `pin-value=` — optional, embeds PIN in URI (security risk if logged)

---

## 9. Hermes Gateway Operations

**User Preference:** Gateway restart **MUST** use `hermes gateway restart` — never `systemctl --user restart hermes-gateway`.

**Reason:** Hermes CLI handles proper shutdown sequences, session persistence, and service state management.

```bash
# Correct
hermes gateway restart

# Incorrect - bypasses Hermes shutdown logic
systemctl --user restart hermes-gateway
```

**Daily Maintenance Cron:** See `references/hermes-daily-maintenance.sh` for automated update sequence.

---

## 10. npm Audit Vulnerabilities — Dev Deps Only

**Finding:** `hermes doctor` reports 2 high vulnerabilities in `web` and `ui-tui` workspaces.

**Root Cause:** `esbuild` (0.17–0.28) and `vite` (depends on vulnerable esbuild) in **devDependencies** — build-time tooling only.

**Impact:** **Zero runtime risk.** Only affects `npm run build` / dev server on Windows.

**Fix Attempt:** `npm audit fix --force` → requires major version bump (breaking), fails due to [npm arborist bug](https://github.com/npm/cli/issues/4828).

**Resolution:** **Ignore.** Document as accepted risk. Add to CI: `npm audit --omit=dev` or `--audit-level=critical`.

---

## Pitfalls

| Issue | Fix |
|-------|-----|
| UFW `before.rules` owned by non-root | `chown root:root /etc/ufw/before.rules && chmod 640` |
| auditd fails to restart after rule changes | Load rules with `auditctl -R` first, then `systemctl restart auditd` |
| audit.rules wildcard `/etc/cron*` not supported | Expand to explicit paths: `/etc/cron.d`, `/etc/cron.daily`, etc. |
| logrotate ignores config due to permissions | `chown root:root /etc/logrotate.d/audit && chmod 644` |
| IPv6 rules leak if IPV6=yes but no v6 rules | Set `IPV6=no` in `/etc/default/ufw` |
| mDNS/UPnP enabled by default in UFW | Comment out in `before.rules` and `before6.rules` |
| Conntrack entry expiry blocks return packets | Tune `nf_conntrack_tcp_timeout_time_wait`/`fin_wait`/`close_wait` in `/etc/sysctl.d/99-conntrack-tuning.conf` |
| TPM pkcs11 requires tss group | `usermod -aG tss <user>` + `newgrp tss` or re-login |
| TPM2 pkcs11 C_Initialize fails with tabrmd | Create `/etc/tpm2_pkcs11.conf` with `[tcti] name = "tabrmd"` |
| Hermes gateway restart via systemctl | Use `hermes gateway restart` — CLI handles session persistence |

---

## Verification Checklist

- [ ] `ufw status verbose` shows only trusted CIDRs allowed
- [ ] `iptables -L ufw-before-input` shows ICMP DROP for non-trusted
- [ ] `auditctl -l` shows all keys loaded
- [ ] `systemctl status auditd` = active (running)
- [ ] `logrotate -d /etc/logrotate.d/audit` parses without error
- [ ] `ssh -G 2>&1 | grep -E '(password|pubkey)'` confirms key-only auth
- [ ] `sysctl -a | grep -E '(rp_filter|icmp_echo|ipv6.disable)'` confirms kernel params

---

## References

- `references/ufw-before.rules.template` — IPv4 ICMP-restricted rules
- `references/audit.rules.template` — Full auditd rule set
- `references/audit-logrotate.template` — logrotate config
- `references/hermes-systemd.template` — Hardened Hermes systemd unit
- `references/hermes-daily-maintenance.sh` — Daily update cron script (hermes update → doctor --fix → gateway restart)
- `references/tpm2-pkcs11-setup.sh` — Complete TPM 2.0 PKCS#11 setup for hardware-backed SSH keys