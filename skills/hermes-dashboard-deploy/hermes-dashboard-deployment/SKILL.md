---
name: hermes-dashboard-deployment
description: "Deploy and manage Hermes Dashboard as a systemd user service with proper security and networking configuration."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [hermes, dashboard, systemd, user-service, deployment, ufw, zerotier]
    related_skills: [hermes-agent, linux-server-hardening]
---

# Hermes Dashboard Deployment

Guide for running Hermes Dashboard as a persistent systemd user service on Linux servers, with proper security hardening and network access control.

## Dashboard Binding Quirk (Critical)

**Hermes Dashboard refuses to bind to non-loopback addresses (0.0.0.0) without authentication.**

When running `hermes dashboard --host 0.0.0.0`, the built-in OAuth auth gate engages and blocks startup if no auth providers are registered:

```
Refusing to bind dashboard to 0.0.0.0 — the OAuth auth gate engages on non-loopback binds, but no auth providers are registered...
Install a DashboardAuthProvider plugin, or pass --insecure to skip the auth gate (NOT recommended on untrusted networks).
```

### Workaround Options

| Option | Command | Security | Use Case |
|--------|---------|----------|----------|
| **Insecure (dev/VPN only)** | `hermes dashboard --host 0.0.0.0 --insecure --no-open` | ⚠️ No auth | Internal networks with firewall restrictions (VPN, ZeroTier) |
| **OAuth (production)** | `hermes dashboard register` then `hermes dashboard --host 0.0.0.0 --no-open` | ✅ Full auth | Public/exposed interfaces |
| **Localhost only** | `hermes dashboard --host 127.0.0.1 --no-open` | ✅ Local only | SSH tunnel access |

**Recommendation for VPN/ZeroTier environments:** Use `--insecure` combined with strict UFW rules limiting access to VPN CIDR only.

## Systemd User Service Setup

### Service File Template

```ini
# ~/.config/systemd/user/hermes-dashboard.service
[Unit]
Description=Hermes Agent Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/home/cerberus/.local/bin/hermes dashboard --host 0.0.0.0 --port 9119 --insecure --no-open
Restart=on-failure
RestartSec=5
Environment=HERMES_HOME=/home/cerberus/.hermes
Environment=PATH=/home/cerberus/.local/bin:/usr/local/bin:/usr/bin:/bin
WorkingDirectory=/home/cerberus

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/cerberus/.hermes

[Install]
WantedBy=default.target
```

### Enable Persistence Across Reboots

```bash
# Enable user service persistence (survives logout)
loginctl enable-linger cerberus

# Enable and start service
systemctl --user daemon-reload
systemctl --user enable hermes-dashboard.service
systemctl --user start hermes-dashboard.service
```

### Verify Deployment

```bash
# Check service status
systemctl --user status hermes-dashboard.service

# Verify listening port
ss -ltnp | grep 9119

# Test HTTP response
curl -s http://127.0.0.1:9119 | head -5
```

## UFW Integration

### Dashboard Port Access (VPN/ZeroTier)

**Rule:** Never invent a CIDR for a VPN network. Show the exact `ufw` command and stop if the user's network range is not already known. If new exposure is needed, ask the user for the trusted CIDR or whether existing UFW access is enough.

```bash
# Pending approval — do not run blindly
sudo ufw allow from <TRUSTED_CIDR> to any port 9119 proto tcp comment 'Hermes Dashboard VPN access'
```

Do not add complementary explicit `ALLOW OUT` rules for interfaces such as `zt+`; the `default allow outgoing` policy already covers return traffic.

### Critical Rules

1. **EXPLICIT APPROVAL REQUIRED** — Before ANY system command (`ufw`, `systemctl`, `ip`, etc.), show the complete command and ask the user for permission and any corrections. No autonomous execution.
2. **NEVER assume a VPN CIDR** — if the user's network range is not known, ask directly or skip the rule.
3. **Default deny incoming** — dashboard port should be reachable only through rules the user approved.
4. **Document rules** — use descriptive comments for auditability.

## ZeroTier Integration

### Check ZeroTier Status

```bash
# List networks (requires root for auth token)
sudo /usr/sbin/zerotier-cli listnetworks

# Check service status
systemctl status zerotier-one

# Show virtual interfaces
ip link show | grep -i zt
```

### UFW Rules for ZeroTier

```bash
# Allow all traffic on ZeroTier interfaces (when networks are joined)
# IN only — OUT is covered by default 'allow outgoing' policy
sudo ufw allow in on zt+ comment 'ZeroTier interfaces in'

# Allow ZeroTier control port (TCP+UDP) if this node accepts connections
sudo ufw allow 9993 comment 'ZeroTier primary port (TCP+UDP)'
```

## Common Pitfalls

| Issue | Cause | Fix |
|-------|-------|-----|
| Service fails immediately | `--host 0.0.0.0` without `--insecure` or OAuth | Add `--insecure` or run `hermes dashboard register` |
| Service starts but no access | UFW blocking port | Add UFW allow rule for correct CIDR/interface |
| Service doesn't persist after reboot | `loginctl enable-linger` not set | Run `loginctl enable-linger <user>` |
| Dashboard shows blank page | Web UI not built | Run without `--skip-build` or pre-build with `cd web && npm run build` |
| Port already in use | Another service on 9119 | Change port with `--port` or stop conflicting service |

## Management Commands

```bash
# Service control
systemctl --user start hermes-dashboard.service
systemctl --user stop hermes-dashboard.service
systemctl --user restart hermes-dashboard.service
systemctl --user status hermes-dashboard.service

# Logs
journalctl --user -u hermes-dashboard.service -f
journalctl --user -u hermes-dashboard.service -n 50 --no-pager

# Config changes require daemon-reload + restart
systemctl --user daemon-reload
systemctl --user restart hermes-dashboard.service
```

## Security Checklist

- [ ] Dashboard binds to `0.0.0.0` only with `--insecure` + UFW restriction
- [ ] UFW default deny incoming, explicit allow for VPN/ZeroTier CIDR
- [ ] `loginctl enable-linger` set for user persistence
- [ ] Systemd hardening: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`
- [ ] `HERMES_HOME` and `ReadWritePaths` scoped to user's `.hermes` only
- [ ] Dashboard port not exposed to public internet
- [ ] Regular `hermes update` via cron (see hermes-agent skill)

## References

- [Hermes Dashboard Docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/dashboard)
- [systemd User Services](https://wiki.archlinux.org/title/Systemd/User)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [ZeroTier Linux Setup](https://docs.zerotier.com/zerotier/linux)