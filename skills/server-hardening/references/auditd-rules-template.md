# Complete auditd Rules Template

Copy to `/etc/audit/rules.d/audit.rules` and adjust paths as needed.

```bash
sudo cp templates/audit.rules /etc/audit/rules.d/audit.rules
sudo auditctl -R /etc/audit/rules.d/audit.rules
sudo systemctl restart auditd
```

## Rule Categories

### Kernel Modules
```audit
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
```

### Process Execution
```audit
-a always,exit -F arch=b64 -S execve -k exec
```

### Permission Denied (Access Control Failures)
```audit
-a always,exit -F arch=b64 -S open -S openat -S creat -S truncate -S ftruncate -F exit=-EACCES -k access_denied
-a always,exit -F arch=b64 -S open -S openat -S creat -S truncate -S ftruncate -F exit=-EPERM -k access_denied
```

### Filesystem Mounts
```audit
-a always,exit -F arch=b64 -S mount -S umount2 -k mounts
```

### Identity Management
```audit
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/login.defs -p wa -k identity
```

### Sudo Configuration
```audit
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
```

### SSH Configuration
```audit
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/sshd_config.d/ -p wa -k sshd_config
```

### Network Configuration
```audit
-w /etc/network/ -p wa -k network_config
-w /etc/netplan/ -p wa -k network_config
-w /etc/hosts -p wa -k network_config
-w /etc/hostname -p wa -k network_config
-w /etc/resolv.conf -p wa -k network_config
-w /etc/systemd/network/ -p wa -k network_config
-w /etc/systemd/resolved.conf -p wa -k network_config
-w /etc/systemd/resolved.conf.d/ -p wa -k network_config
```

### Firewall Configuration
```audit
-w /etc/ufw/ -p wa -k firewall_config
-w /etc/nftables.conf -p wa -k firewall_config
-w /etc/iptables/ -p wa -k firewall_config
```

### Audit Self-Monitoring
```audit
-w /etc/audit/ -p wa -k audit_config
-w /etc/audit/rules.d/ -p wa -k audit_config
-w /etc/audisp/ -p wa -k audit_config
```

### Application-Specific (add your services)
```audit
# Hermes example
-w /etc/systemd/system/hermes.service -p wa -k hermes_config
# Add your service units here
```

### Cron Configuration
```audit
-w /etc/cron.d -p wa -k cron_config
-w /etc/cron.daily -p wa -k cron_config
-w /etc/cron.hourly -p wa -k cron_config
-w /etc/cron.monthly -p wa -k cron_config
-w /etc/cron.weekly -p wa -k cron_config
-w /etc/crontab -p wa -k cron_config
-w /var/spool/cron/ -p wa -k cron_config
```

### PAM & Security
```audit
-w /etc/pam.d/ -p wa -k pam_config
-w /etc/security/ -p wa -k pam_config
```

### Authentication Logs
```audit
-w /var/log/auth.log -p wa -k auth_log
-w /var/log/secure -p wa -k auth_log
```

### Privilege Escalation
```audit
-a always,exit -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -k priv_esc
-a always,exit -F arch=b64 -S ptrace -k ptrace
-a always,exit -F arch=b64 -S capset -k capset
```

### Time Changes
```audit
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time_change
-w /etc/localtime -p wa -k time_change
```

### Kernel Parameters
```audit
-w /etc/sysctl.conf -p wa -k kernel_param
-w /etc/sysctl.d/ -p wa -k kernel_param
```

### Audit Logs
```audit
-w /var/log/audit/ -p wa -k audit_log
```

## Buffer Settings (top of file)

```audit
-D
-b 8192
--backlog_wait_time 60000
-f 1
```

## Searching Logs

```bash
# By key
ausearch -k sshd_config
ausearch -k priv_esc

# Recent events
ausearch -ts today

# Raw output
ausearch -k exec --raw | aureport -f
```

## Pitfalls

- **Wildcards not supported**: `-w /etc/cron*` fails — expand to individual dirs
- **Directory watches**: Recursive; `-w /etc/ssh/` watches all files under it
- **Rule order matters**: First match wins for `-a` rules; `-w` are additive
- **Restart vs reload**: `auditctl -R` reloads live; rules file persists reboot
- **No plugins warning**: "No plugins found" is normal unless audispd-plugins installed