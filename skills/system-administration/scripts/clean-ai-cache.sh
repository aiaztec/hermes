#!/bin/bash
# Clean cache directories for /home/ai (Hermes Agent environment)
# Safe to run regularly to reclaim disk space

set -e

echo "=== Disk Cleanup for /home/ai ==="
echo "Starting at: $(date)"

# Track disk usage before
echo -e "\n--- DISK USAGE BEFORE ---"
df -h / | grep -v Filesystem

# Clean uv cache (Python package manager)
if [ -d "/home/ai/.cache/uv" ]; then
  echo -e "\n--- REMOVING UV CACHE ---"
  rm -rf /home/ai/.cache/uv
  echo "uv cache removed"
fi

# Clean camoufox cache (browser)
if [ -d "/home/ai/.cache/camoufox" ]; then
  echo -e "\n--- REMOVING CAMOUFOX CACHE ---"
  rm -rf /home/ai/.cache/camoufox
  echo "camoufox cache removed"
fi

# Clean Playwright cache
if [ -d "/home/ai/.cache/ms-playwright" ]; then
  echo -e "\n--- REMOVING PLAYWRIGHT CACHE ---"
  rm -rf /home/ai/.cache/ms-playwright
  echo "playwright cache removed"
fi

# Clean pip cache
if [ -d "/home/ai/.cache/pip" ]; then
  echo -e "\n--- REMOVING PIP CACHE ---"
  rm -rf /home/ai/.cache/pip
  echo "pip cache removed"
fi

# Clean NPM cache
echo -e "\n--- CLEANING NPM CACHE ---"
sudo -u ai npm cache clean --force
echo "npm cache cleaned"

# Clean Hermes Agent logs (small but safe)
if [ -d "/home/ai/.hermes/logs" ]; then
  echo -e "\n--- CLEANING HERMES LOGS ---"
  find /home/ai/.hermes/logs -type f -mtime +7 -delete 2>/dev/null || echo "No old logs to delete"
fi

# Verify disk usage after
echo -e "\n--- DISK USAGE AFTER ---"
df -h / | grep -v Filesystem

echo -e "\n=== Cleanup Complete ==="
echo "Finished at: $(date)"