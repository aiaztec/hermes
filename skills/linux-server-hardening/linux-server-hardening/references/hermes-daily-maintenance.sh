#!/bin/bash
# Hermes Daily Maintenance Cron Script
# Runs: hermes update → hermes doctor --fix → hermes gateway restart
# Designed for systemd cron / hermes cronjob

set -euo pipefail

LOG_FILE="${HOME}/.hermes/logs/daily-maintenance-$(date +%Y%m%d).log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "Hermes Daily Maintenance - $(date)"
echo "=========================================="

# 1. hermes update
echo ""
echo "[1/3] Running 'hermes update'..."
if hermes update; then
    echo "✓ hermes update completed"
else
    echo "✗ hermes update FAILED (continuing)"
fi

# 2. hermes doctor --fix
echo ""
echo "[2/3] Running 'hermes doctor --fix'..."
if hermes doctor --fix; then
    echo "✓ hermes doctor --fix completed"
else
    echo "✗ hermes doctor --fix FAILED (continuing)"
fi

# 3. hermes gateway restart
echo ""
echo "[3/3] Running 'hermes gateway restart'..."
if hermes gateway restart; then
    echo "✓ hermes gateway restart completed"
else
    echo "✗ hermes gateway restart FAILED"
fi

echo ""
echo "=========================================="
echo "Maintenance completed - $(date)"
echo "Log: $LOG_FILE"
echo "=========================================="