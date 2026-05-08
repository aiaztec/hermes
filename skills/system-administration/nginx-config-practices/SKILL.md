---
name: nginx-config-practices
description: Nginx configuration best practices for modern nginx (1.25+), including HTTP/2 syntax, SSL/TLS hardening, security headers, and file backup rules.
trigger:
  - nginx configuration for version 1.25 or newer
  - HTTP/2 setup or warning about deprecated syntax
  - SSL/TLS hardening (HSTS, OCSP, ciphers)
  - User mentions backup rule for nginx config files
  - nginx security headers (HSTS, X-Frame-Options, etc.)
---

# Nginx Configuration Practices (Modern Nginx 1.25+)

Best practices for nginx configuration, focusing on version 1.25+ changes, SSL/TLS hardening, and the user's specific workflow preferences.

## Critical Practices

### File Modification Backup Rule
**ALWAYS create a backup before modifying any nginx config file.** Use date format: `filename.YYYYMMDD_HHMM`

```bash
cp /etc/nginx/sites-available/example-ssl /etc/nginx/sites-available/example-ssl.$(date +%Y%m%d_%H%M)
```

**User rule (session 2026-05-08):** "ked menis subor v systeme, vzdy sprav backup s datumom" — this is mandatory for ALL system file changes.

**Applies to:** `/etc/nginx/sites-available/`, `/etc/nginx/nginx.conf`, `/etc/ssh/sshd_config`, `/etc/hosts`, any `/etc/` modifications.

### Change Permission Protocol
**Do NOT modify nginx configs until explicitly instructed.** Wait for clear, direct instructions like "uprav to" or "zmen to". If unsure, ask first.

---

## Nginx 1.25+ HTTP/2 Syntax Change

**Problem:** Warnings like `nginx: [warn] the "listen ... http2" directive is deprecated, use the "http2" directive instead`

**Root cause:** Nginx 1.25.1+ changed HTTP/2 configuration. The `http2` parameter in `listen` directive is deprecated.

### Wrong (deprecated in 1.25+):
```nginx
server {
    listen 443 ssl http2;
    server_name example.com;
    ...
}
```

### Correct (nginx 1.25+):
```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name example.com;
    ...
}
```

**Important:** Both `listen 443 ssl;` and `http2 on;` must be in the same `server` block.

**Verification:**
```bash
sudo nginx -t  # Should pass without warnings
```

---

## SSL/TLS Best Practices

### Use .pem Files (Full Chain) Not .crt (Leaf Only)

**User correction:** Always use `.pem` files (contains full chain: leaf + intermediate certificates) not `.crt` files (leaf only) for nginx SSL configuration.

```nginx
# CORRECT - .pem contains leaf + intermediate certificates
ssl_certificate /etc/ssl/private/example.com.pem;
ssl_certificate_key /etc/ssl/private/example.com.key;

# WRONG - .crt often contains leaf certificate only
# ssl_certificate /etc/ssl/private/example.com.crt;
```

### Modern Cipher Suites (Mozilla Intermediate)

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers off;
```

**Note:** TLS 1.3 ciphers are managed by OpenSSL and cannot be configured in nginx.

### OCSP Stapling

```nginx
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 1.1.1.1 valid=300s;
resolver_timeout 5s;
```

**Verify:**
```bash
echo | openssl s_client -connect example.com:443 -status 2>&1 | grep -i "OCSP"
```

### DH Parameters

```bash
# Generate (one-time setup)
sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048
```

```nginx
ssl_dhparam /etc/nginx/dhparam.pem;
```

### Session Configuration

```nginx
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;  # More secure, but slightly slower
```

---

## Security Headers

### HSTS (HTTP Strict Transport Security)

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

**Warning:** Only add `preload` after confirming all subdomains support HTTPS.

### Additional Security Headers

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

---

## Server Header Modification

**Module:** `nginx-extras` (provides `headers-more-filter`)

```bash
# Install on Debian/Ubuntu
sudo apt install -y nginx-extras
```

```nginx
# Hide nginx version (in /etc/nginx/nginx.conf: server_tokens off;)
# Then change server header with:
more_set_headers 'Server: CustomServer/1.0';
```

**Load module:**
```bash
ls -la /etc/nginx/modules-enabled/*headers-more*
```

---

## Testing with `--resolve` Flag

**Problem:** When testing nginx configs with `curl`, DNS might resolve to wrong IP (internet vs local proxy).

**Solution:** Use `--resolve` to bypass DNS:

```bash
# Test HTTPS with specific IP
curl -sI https://example.com --resolve example.com:443:10.19.20.51 -k

# Test HTTP
curl -sI http://example.com --resolve example.com:80:10.19.20.51
```

This ensures curl connects to the intended server even if `/etc/hosts` has wrong entries.

---

## References

- See `system-administration` skill for general Linux admin tasks
- See `ssl-certificates` skill for SSL certificate management
- Nginx 1.25+ changelog: https://nginx.org/en/CHANGES
- Mozilla SSL Configuration Generator: https://ssl-config.mozilla.org/
