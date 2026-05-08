---
name: system-cleanup
description: "Use when user asks to clean system, remove unnecessary files, free disk space, or optimize system by deleting redundant files (cache, logs, old kernels). Covers safety checks and verification."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [system, cleanup, disk, cache, logs, optimization]
    related_skills: [plan, writing-plans]
---

# System Cleanup

## Overview

Systematic cleanup of redundant files on Linux systems to free disk space and optimize performance. Handles cache directories, package manager leftovers, old kernels, and log files while protecting critical components (like Hermes Agent's venv).

## When to Use

- User says: "vyčisti systém", "clean system", "remove unnecessary files"
- User asks to free up disk space or optimize storage
- User mentions deleting redundant files, cache, or logs
- **Don't use for:** Security hardening (use dedicated security skills) or application-specific cleanup (unless part of system-wide cleanup)

## Workflow

### 1. System Survey (Safety First)

Before any deletion, gather system state:

```bash
# Disk usage overview
df -h | grep -E "Filesystem|/dev/"

# Largest directories in /var and /home
sudo du -h --max-depth=1 /var 2>/dev/null | sort -hr | head -10
sudo du -h --max-depth=1 /home/ai 2>/dev/null | sort -hr | head -20

# Check for large cache directories
sudo du -h --max-depth=1 /home/ai/.cache 2>/dev/null | sort -hr | head -10
```

**Always present findings** to user with estimated savings before proceeding.

### 2. Safe-to-Delete Candidates

| Location | Size check command | Deletion command | Safety |
|----------|-------------------|------------------|---------|
| APT cache | `sudo du -sh /var/cache/apt` | `sudo apt clean` | ✅ Always safe |
| Installer logs | `sudo du -sh /var/log/installer` | `sudo rm -rf /var/log/installer` | ✅ Safe (historical logs) |
| Old kernels | `dpkg --list \| grep linux-image` | `sudo apt remove --purge linux-image-<old>` | ⚠️ Keep current kernel |
| Journal logs | `sudo journalctl --disk-usage` | `sudo journalctl --vacuum-size=50M` | ✅ Safe (reduces size) |
| Python/pip cache | `sudo du -sh /home/ai/.cache/pip` | `rm -rf /home/ai/.cache/pip` | ✅ Safe |
| NPM cache | `sudo du -sh /home/ai/.npm` | `sudo -u ai npm cache clean --force` | ✅ Safe |
| Browser caches | Check `/home/ai/.cache/uv`, `camoufox`, `ms-playwright` | `rm -rf` individual dirs | ✅ Safe |

### 3. Critical Protection Rules

🛑 **NEVER DELETE:**
- `/home/ai/.hermes/hermes-agent/venv` (1.5 GB) — **CRITICAL** for Hermes Agent operation
- `/home/ai/.hermes/hermes-agent/.git` — unless user explicitly requests
- Any file under `/etc/nginx/` without explicit user confirmation
- System binaries or libraries

### 3b. UFW Path Pitfall

**Problem:** The `ufw` binary may be installed but not in PATH for non-root users. `command -v ufw` returns empty even when `/usr/sbin/ufw` exists.

**Solution:** Always use full path for UFW commands:
```bash
# Wrong:
sudo ufw status  # May fail with "command not found"

# Right:
sudo /usr/sbin/ufw status numbered
```

**Check:** `dpkg -l | grep ufw` confirms package is installed even when `which ufw` fails.

### 4. Cleanup Execution Steps

Present a numbered list of proposed actions with estimated space savings. **Always ask user confirmation** (via clarify or text) before each major step.

Example sequence:
1. Clean APT cache (estimated saving: X MB)
2. Remove old installer logs (X MB)
3. Remove old kernels (X MB) — show which kernels to remove
4. Vacuum journal logs
5. Clean user caches (.cache/uv, .cache/camoufox, etc.)
6. Clean NPM cache
7. Run `sudo apt autoremove --purge`

### 5. Verification

After cleanup, verify results:

```bash
# Check disk space improvement
df -h / | grep -v Filesystem

# Confirm services still running
sudo systemctl status nginx --no-pager
sudo systemctl status fail2ban --no-pager

# Show summary
echo "Cleanup complete. Disk usage reduced from X% to Y%."
```

## Common Pitfalls

1. **Deleting current kernel** — Always check `uname -r` before removing kernels. Only remove versions that don't match current.
2. **Breaking Hermes Agent** — Never delete `venv` directory. If unsure about any `.hermes` subdirectory, skip it.
3. **Running out of disk during cleanup** — If disk is >95% full, prioritize APT cache and large caches first.
4. **Permission issues** — Some cache dirs owned by root, some by ai user. Use `sudo -u ai` for user-specific commands.
5. **Deleted file recovery** — These deletions are permanent. Warn user appropriately.

## Verification Checklist

- [ ] Disk usage checked and presented to user
- [ ] Proposed deletions listed with size estimates
- [ ] User confirmed each major deletion step
- [ ] Critical directories (venv, nginx config) protected
- [ ] Cleanup executed successfully
- [ ] Disk usage re-checked post-cleanup
- [ ] Services verified running (nginx, fail2ban if installed)
- [ ] Summary presented to user

## One-Shot Recipes

### Recipe A: Emergency Cleanup (>90% disk full)
1. `sudo apt clean` (fastest win)
2. `rm -rf /home/ai/.cache/uv` (often biggest)
3. `sudo journalctl --vacuum-size=50M`
4. `sudo apt autoremove --purge`

### Recipe B: Routine Maintenance
1. All steps in Workflow section 4
2. Check for new large files in `/var/log`
3. Verify no orphaned packages with `apt autoremove --dry-run`
