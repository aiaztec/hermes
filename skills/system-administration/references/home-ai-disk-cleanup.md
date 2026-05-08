# Disk Cleanup for /home/ai User (Hermes Agent Environment)

Commands for safe cleanup of cache directories that can consume large amounts of space.

## Cache Directories (Safe to Remove)

These directories can be safely removed. They will be regenerated automatically when needed.

### uv Cache (Python package manager)
```bash
rm -rf /home/ai/.cache/uv
```
**Typical size:** 2–6 GB
**Purpose:** Caches downloads for the `uv` Python package manager.

### Camoufox Cache (Browser)
```bash
rm -rf /home/ai/.cache/camoufox
```
**Typical size:** 500 MB – 2 GB
**Purpose:** Browser cache for Camoufox (headless browser testing).

### Playwright Browser Binaries
```bash
rm -rf /home/ai/.cache/ms-playwright
```
**Typical size:** 300 MB – 1 GB
**Purpose:** Downloaded browser binaries for Playwright automation.

### pip Cache (Small)
```bash
rm -rf /home/ai/.cache/pip
```
**Typical size:** < 10 MB
**Purpose:** Cache for pip (Python package installer).

## NPM Cache (Safe to Clean)

```bash
sudo -u ai npm cache clean --force
```
**Typical size:** 100–200 MB
**Purpose:** npm package cache (Node.js).

## Hermes Agent Directory (⚠️ Do NOT remove)

**Critical directories to preserve:**
- `/home/ai/.hermes/hermes-agent/venv` — Python virtual environment (1–2 GB)
- `/home/ai/.hermes/hermes-agent/ui-tui/node_modules` — UI dependencies (150+ MB)
- `/home/ai/.hermes/hermes-agent/node_modules` — Main dependencies (150+ MB)

**Safe to clean (small):**
- Session logs: `/home/ai/.hermes/sessions/*`
- Cron files: `/home/ai/.hermes/cron/*`
- Checkpoints: `/home/ai/.hermes/checkpoints/*`

## Quick Full Cleanup Script

Run as root (assumes all caches are safe to delete):

```bash
# uv cache
rm -rf /home/ai/.cache/uv

# camoufox browser cache
rm -rf /home/ai/.cache/camoufox

# Playwright browser binaries
rm -rf /home/ai/.cache/ms-playwright

# pip cache
rm -rf /home/ai/.cache/pip

# NPM cache
sudo -u ai npm cache clean --force

# Verify disk usage
df -h / | grep -v Filesystem
```

## Check Current Space Usage

```bash
# By directory
sudo du -h --max-depth=1 /home/ai 2>/dev/null | sort -hr

# By cache type
sudo du -h --max-depth=1 /home/ai/.cache 2>/dev/null | sort -hr

# NPM cache breakdown
sudo du -h --max-depth=1 /home/ai/.npm 2>/dev/null | sort -hr
```