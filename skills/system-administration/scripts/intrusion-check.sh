#!/bin/bash
# Intrusion Detection Script - Automated security monitoring
# Sets up cron job to check logs for intrusion attempts daily at 2:00 AM
# Reports saved to /home/ai/reports/

REPORT_DIR="/home/ai/reports"
DATE=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/intrusion_report_${DATE}.txt"

echo "=== INTRUSION DETECTION REPORT ===" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 1. Check for failed SSH login attempts (last 24 hours)
echo "=== FAILED SSH LOGIN ATTEMPTS (last 24h) ===" >> "$REPORT_FILE"
if [ -f /var/log/auth.log ]; then
    sudo grep "Failed password" /var/log/auth.log | tail -20 >> "$REPORT_FILE" 2>&1
else
    sudo journalctl -u ssh --since "24 hours ago" | grep -i "failed\|invalid" | tail -20 >> "$REPORT_FILE" 2>&1
fi
echo "" >> "$REPORT_FILE"

# 2. Check fail2ban status
echo "=== FAIL2BAN STATUS ===" >> "$REPORT_FILE"
if command -v fail2ban-client &> /dev/null; then
    sudo fail2ban-client status >> "$REPORT_FILE" 2>&1
    sudo fail2ban-client status sshd >> "$REPORT_FILE" 2>&1
else
    echo "fail2ban not installed" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 3. Check UFW blocked attempts (use full path)
echo "=== UFW BLOCKED ATTEMPTS (last 24h) ===" >> "$REPORT_FILE"
if [ -x /usr/sbin/ufw ]; then
    sudo /usr/sbin/ufw status numbered >> "$REPORT_FILE" 2>&1
    sudo grep -i "block" /var/log/ufw.log 2>/dev/null | tail -20 >> "$REPORT_FILE" 2>&1
else
    echo "UFW not installed" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 4. Check for suspicious nginx access attempts
echo "=== NGINX SUSPICIOUS REQUESTS (last 24h) ===" >> "$REPORT_FILE"
if [ -f /var/log/nginx/access.log ]; then
    sudo grep -E "union|select|<|>|\\.\\.\\/|\\/etc\\/passwd" /var/log/nginx/access.log 2>/dev/null | tail -20 >> "$REPORT_FILE" 2>&1
else
    echo "nginx access log not found" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 5. Check current network connections (top talkers)
echo "=== TOP IPs CONNECTED (current) ===" >> "$REPORT_FILE"
sudo ss -tn | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10 >> "$REPORT_FILE" 2>&1
echo "" >> "$REPORT_FILE"

# 6. System resource check
echo "=== SYSTEM RESOURCE CHECK ===" >> "$REPORT_FILE"
echo "Load average: $(uptime | awk -F'load average:' '{print $2}')" >> "$REPORT_FILE"
echo "Memory usage:" >> "$REPORT_FILE"
free -h >> "$REPORT_FILE" 2>&1
echo "" >> "$REPORT_FILE"

echo "=== END OF REPORT ===" >> "$REPORT_FILE"

chown ai:ai "$REPORT_FILE"
chmod 600 "$REPORT_FILE"

echo "Report saved to: $REPORT_FILE"
