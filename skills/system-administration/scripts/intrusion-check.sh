#!/bin/bash
# Intrusion detection and security analysis script
# Analyzes authentication logs and system security status

echo "=========================================="
echo "   SECURITY ANALYSIS REPORT"
echo "   Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 1. SSH Authentication Analysis
echo "--- SSH AUTHENTICATION ANALYSIS ---"
echo "Recent SSH failed attempts (last 50 lines):"
sudo journalctl -u sshd --no-pager -n 50 2>/dev/null | grep -E "Failed|Invalid|error" | tail -20 || echo "No recent SSH failures in journalctl"

if [ -f /var/log/auth.log ]; then
    echo ""
    echo "From /var/log/auth.log (last 20 failures):"
    sudo grep -E "Failed|Invalid|error" /var/log/auth.log 2>/dev/null | tail -20
else
    echo "/var/log/auth.log not available"
fi

echo ""
echo "Successful SSH logins (last 10):"
sudo journalctl -u sshd --no-pager 2>/dev/null | grep "Accepted" | tail -10 || echo "No recent successful SSH logins"

# 2. Current SSH Connections
echo ""
echo "--- ACTIVE SSH CONNECTIONS ---"
ss -tnp | grep sshd || echo "No active SSH connections"

# 3. Listening Ports (Security Risk Check)
echo ""
echo "--- LISTENING PORTS (Security Review) ---"
ss -tuln | grep LISTEN | sort -k4

# 4. Firewall Status
echo ""
echo "--- FIREWALL STATUS ---"
if command -v ufw &>/dev/null; then
    sudo ufw status verbose 2>/dev/null || echo "UFW not active"
else
    echo "UFW not installed"
fi

if command -v iptables &>/dev/null; then
    echo ""
    echo "IPTables rules (filter table):"
    sudo iptables -L -n 2>/dev/null | head -30
fi

# 5. Recent Sudo Usage
echo ""
echo "--- RECENT SUDO USAGE ---"
sudo grep sudo /var/log/auth.log 2>/dev/null | tail -10 || echo "No sudo entries in auth.log"

# 6. Users with Sudo Access
echo ""
echo "--- SUDOERS (Users with sudo access) ---"
grep -E "^[^#].*ALL.*NOPASSWD|^[^#].*sudo" /etc/sudoers 2>/dev/null
if [ -d /etc/sudoers.d ]; then
    echo "Additional sudoers files:"
    ls -la /etc/sudoers.d/ 2>/dev/null
fi

# 7. Failed Login Attempts by IP (Top attackers)
echo ""
echo "--- TOP ATTACKER IPS (from auth.log) ---"
sudo grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -10 || echo "No failed password attempts in auth.log"

# 8. System Updates Pending
echo ""
echo "--- SYSTEM UPDATES ---"
if command -v apt &>/dev/null; then
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing" | wc -l)
    echo "Pending updates: $UPDATES"
    if [ "$UPDATES" -gt 0 ]; then
        apt list --upgradable 2>/dev/null | grep -v "Listing" | head -10
    fi
else
    echo "APT not available"
fi

# 9. Security Recommendations
echo ""
echo "--- SECURITY RECOMMENDATIONS ---"
echo "1. Disable SSH password auth: 'PasswordAuthentication no' in sshd_config"
echo "2. Enable firewall: sudo ufw enable"
echo "3. Install fail2ban: sudo apt install fail2ban"
echo "4. Keep system updated: sudo apt update && sudo apt upgrade"
echo "5. Review users with sudo access regularly"

echo ""
echo "=========================================="
echo "   END OF SECURITY REPORT"
echo "=========================================="
