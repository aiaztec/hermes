#!/bin/bash
# Clean cache directories for $HOME (Hermes Agent environment)
# Safe to run regularly to reclaim disk space

set -e

echo "=== Disk Cleanup for $HOME ==="
echo "Starting at: $(date)"

# Track disk usage before
echo -e "\n--- DISK USAGE BEFORE ---"
df -h / | grep -v Filesystem

# Clean uv cache (Python package manager)
if [ -d "$HOME/.cache/uv" ]; then
  echo -e "\n--- REMOVING UV CACHE ---"
  rm -rf $HOME/.cache/uv
  echo "uv cache removed"
fi

# Clean camoufox cache (browser)
if [ -d "$HOME/.cache/camoufox" ]; then
  echo -e "\n--- REMOVING CAMOUFOX CACHE ---"
  rm -rf $HOME/.cache/camoufox
  echo "camoufox cache removed"
fi

# Clean Playwright cache
if [ -d "$HOME/.cache/ms-playwright" ]; then
  echo -e "\n--- REMOVING PLAYWRIGHT CACHE ---"
  rm -rf $HOME/.cache/ms-playwright
  echo "playwright cache removed"
fi

# Clean pip cache
if [ -d "$HOME/.cache/pip" ]; then
  echo -e "\n--- REMOVING PIP CACHE ---"
  rm -rf $HOME/.cache/pip
  echo "pip cache removed"
fi

# Clean NPM cache
echo -e "\n--- CLEANING NPM CACHE ---"
sudo -u ${SUDO_USER:-$USER} npm cache clean --force
echo "npm cache cleaned"

# Clean Hermes Agent logs (small but safe)
if [ -d "$HOME/.hermes/logs" ]; then
  echo -e "\n--- CLEANING HERMES LOGS ---"
  find $HOME/.hermes/logs -type f -mtime +7 -delete 2>/dev/null || echo "No old logs to delete"
fi

# Verify disk usage after
echo -e "\n--- DISK USAGE AFTER ---"
df -h / | grep -v Filesystem

echo -e "\n=== Cleanup Complete ==="
echo "Finished at: $(date)"