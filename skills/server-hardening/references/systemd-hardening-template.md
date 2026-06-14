# Systemd Service Hardening Template

Least-privilege systemd unit template. Copy and customize for your service.

```bash
sudo cp templates/hardened-service.service /etc/systemd/system/<your-service>.service
sudo systemctl daemon-reload
sudo systemctl enable --now <your-service>
```

## Template

```ini
[Unit]
Description=<Your Service>
After=network-online.target
Wants=network-online.target
# Add service-specific dependencies

[Service]
Type=simple
User=<dedicated-user>
Group=<dedicated-group>
WorkingDirectory=<working-dir>
ExecStart=<command>
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=<service-name>

# === HARDENING (apply all, remove only if proven necessary) ===

# No privilege escalation
NoNewPrivileges=yes

# Filesystem isolation
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
# ReadWritePaths=/var/lib/<service>  # Add if service needs write access

# Network restriction
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
# Remove AF_INET6 if IPv6 not used

# Namespaces & capabilities
RestrictNamespaces=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM

# Capabilities (minimal set)
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
# Add only required capabilities:
# CAP_DAC_OVERRIDE, CAP_CHOWN, CAP_SETUID, CAP_SETGID, etc.

# Optional: further restrictions
# PrivateDevices=yes
# PrivateNetwork=yes          # If no network needed
# ProtectProc=invisible       # Hide other processes
# ProcSubset=pid              # Minimal /proc

[Install]
WantedBy=multi-user.target
```

## Capability Reference

| Capability | Purpose | Common Need |
|------------|---------|-------------|
| `CAP_NET_BIND_SERVICE` | Bind to ports < 1024 | Web servers, proxies |
| `CAP_DAC_OVERRIDE` | Bypass file permissions | Rarely needed |
| `CAP_CHOWN` | Change file ownership | Rarely needed |
| `CAP_SETUID`/`CAP_SETGID` | Change UID/GID | Daemons dropping privs |
| `CAP_SYS_RESOURCE` | Override resource limits | Rarely needed |

## Testing Hardening

```bash
# Analyze service hardening
systemd-analyze security <service-name>

# Expected: score > 8.0 for well-hardened service

# Test service starts
systemctl start <service-name>
journalctl -u <service-name> -f
```

## Common Adjustments

**Service needs to write to specific paths:**
```ini
ReadWritePaths=/var/lib/myapp /var/log/myapp /run/myapp
```

**Service needs specific syscalls:**
```ini
SystemCallFilter=@system-service @network-io
# Or add individual: SystemCallFilter=@system-service open close read write ...
```

**Service needs raw sockets (e.g., ICMP):**
```ini
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_RAW
```

**Service runs as root (avoid if possible):**
```ini
User=root
# Still apply all other hardening
```

## Verification Checklist

- [ ] `systemd-analyze security <service>` score ≥ 8.0
- [ ] Service starts without errors
- [ ] Logs show no permission denied (except expected)
- [ ] No unexpected capabilities in `ps -o cap= -p <pid>`