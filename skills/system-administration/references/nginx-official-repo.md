# Official Nginx Repository Setup (Debian/Ubuntu)

Full workflow for adding nginx.org official repos to get latest nginx builds.

## Prerequisites Check
```bash
# Verify package manager (must be apt for Debian/Ubuntu)
which apt
```

## Step 1: Install Prerequisites
```bash
sudo apt install -y curl gnupg2 ca-certificates lsb-release
```

## Step 2: Add Official GPG Key
```bash
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
```

## Step 3: Add Repo to Sources
```bash
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
```

## Step 4: Set Repo Priority (Pinning)
Forces nginx.org packages to take priority over Debian defaults (priority 900):
```bash
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900" | sudo tee /etc/apt/preferences.d/99nginx
```

## Step 5: Update & Upgrade
```bash
sudo apt update && sudo apt install -y nginx
```

## Post-Upgrade Check
Official repo upgrades overwrite config files - re-check IPv6 settings:
```bash
grep -n "listen \[::\]" /etc/nginx/sites-enabled/default
# Re-comment IPv6 lines if needed (see nginx-ipv6-fix.md)
```

## Verify Installation
```bash
nginx -v  # Should show nginx/1.30.0+ from nginx.org
apt-cache madison nginx | grep nginx.org  # Confirm repo origin
```
