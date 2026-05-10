#!/bin/bash
# Intrusion Detection Script
# Checks logs for intrusion attempts and saves report to $HOME/reports/

REPORT_DIR="$HOME/reports"
mkdir -p "$REPORT_DIR"
DATE=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/intrusion_report_${DATE}.txt"

echo "=== INTRUSION DETECTION REPORT ===" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 1. Check for failed SSH login attempts (last 24 hours)
echo "=== FAILED SSH LOGIN ATTEMPTS (last 24h) ===" >> "$REPORT_FILE"
sudo journalctl -u ssh --since "24 hours ago" | grep -i "failed\\|invalid" | tail -20 >> "$REPORT_FILE" 2>&1
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

# 3. Check UFW blocked attempts
echo "=== UFW BLOCKED ATTEMPTS (last 24h) ===" >> "$REPORT_FILE"
if command -v ufw &> /dev/null || [ -x /usr/sbin/ufw ]; then
    sudo /usr/sbin/ufw status numbered >> "$REPORT_FILE" 2>&1
    sudo grep -i "block" /var/log/ufw.log 2>/dev/null | tail -20 >> "$REPORT_FILE" 2>&1
else
    echo "UFW not installed" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 4. Check for suspicious nginx access attempts (if nginx running)
echo "=== NGINX SUSPICIOUS REQUESTS (last 24h) ===" >> "$REPORT_FILE"
if [ -f /var/log/nginx/access.log ]; then
    # Look for common attack patterns: SQL injection, XSS, directory traversal, etc.
    sudo grep -E "union|select|<|>|\\.\\.\\.\\./|/etc/passwd" /var/log/nginx/access.log 2>/dev/null | tail -20 >> "$REPORT_FILE" 2>&1
else
    echo "nginx access log not found" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 5. Check current network connections (suspicious only)
echo "=== SUSPICIOUS TCP CONNECTIONS (non-standard ports / unexpected IPs) ===" >> "$REPORT_FILE"
echo "Method: ss -tn filtered for:" >> "$REPORT_FILE"
echo "  - Remote port NOT in {80,443,22,53,8080,8443}" >> "$REPORT_FILE"
echo "  - Remote IP NOT in private ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)" >> "$REPORT_FILE"
echo "Legend: ESTAB=established, CLOSE-WAIT=waiting for app to close, TIME-WAIT=connection closed but socket reserved." >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
# Define safe ports
SAFE_PORTS="80|443|22|53|8080|8443"
# Use awk to filter
sudo ss -tn | awk -v safe="$SAFE_PORTS" '
{
    split($5, a, ":");
    ip = a[1];
    port = a[2];
    # Skip if port matches safe list
    if (port ~ "^(" safe ")$") next;
    # Skip if IP is private
    if (ip ~ /^10\\./ || ip ~ /^172\\.(1[6-9]|2[0-9]|3[0-1])\\./ || ip ~ /^192\\.168\\./) next;
    # Otherwise count
    count[ip]++
}
END {
    for (ip in count) {
        printf "%4d %s\\n", count[ip], ip
    }
}
' | sort -nr | head -10 >> "$REPORT_FILE" 2>&1
echo "" >> "$REPORT_FILE"

# 6. Check for suspicious processes or high resource usage
echo "=== SYSTEM RESOURCE CHECK ===" >> "$REPORT_FILE"
echo "Load average: $(uptime | awk -F'load average:' '{print $2}')" >> "$REPORT_FILE"
echo "Memory usage:" >> "$REPORT_FILE"
free -h >> "$REPORT_FILE" 2>&1
echo "" >> "$REPORT_FILE"

echo "=== END OF REPORT ===" >> "$REPORT_FILE"

# Make report readable only by the user who ran the script
chown "$(whoami):$(whoami)" "$REPORT_FILE"
chmod 600 "$REPORT_FILE"

echo "Report saved to: $REPORT_FILE"