---
name: nginx-reverse-proxy-virtual-hosts
description: Nginx reverse proxy configuration for virtual hosts with SSL/TLS hardening, path-based rewrites, and sub_filter for dashboard base path adjustment (e.g., /dash -> localhost:9119/dashboard)
version: 1.0.0
author: Hermes-TT
license: MIT
metadata:
  hermes:
    tags: [nginx, ssl, virtual-host, reverse-proxy, path-rewrite]
---

# Nginx Reverse Proxy Virtual Hosts Configuration

This skill provides templates and best practices for configuring Nginx reverse proxy with:
- **SSL/TLS hardening** (TLS 1.3, Perfect Forward Secrecy, HSTS)
- **Path-based rewrites** (`/dash/`, `/gw/`, etc.)
- **`sub_filter` for base path injection** (fixes frontend assets when behind reverse proxy)
- **Security headers** (X-Frame-Options, X-Content-Type-Options, etc.)

## Overview

When serving web applications behind an Nginx reverse proxy, you need to handle:
1. Path prefix removal (`/dash/` → `/`)
2. Host header rewriting (`Host: 10.19.20.55` → `Host: localhost`)
3. Asset path adjustment (e.g., `href="/assets/..."` → `href="/dash/assets/..."`)
4. Base path configuration (e.g., `window.__HERMES_BASE_PATH__="/dash/"`)

This skill provides working configurations for common scenarios.

## Requirements

- Nginx 1.25+ (for modern TLS/H2 syntax)
- `nginx-extras` package (for `sub_filter` module)
- SSL certificate (self-signed or CA-signed)

## Quick Start: Single Domain with Multiple Paths

### Example: `/gw` → Gateway (port 8642) and `/dash` → Dashboard (port 9119)

```nginx
upstream gateway {
    server 127.0.0.1:8642;
}

upstream dashboard {
    server 127.0.0.1:9119;
}

server {
    listen 443 ssl http2;
    server_name 10.19.20.55;

    # SSL Configuration – TLS 1.3 + TLS 1.2, Perfect Forward Secrecy
    ssl_certificate /etc/nginx/ssl/nginx.pem;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;

    # SSL Session Configuration
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gateway reverse proxy
    location /gw/ {
        proxy_pass http://127.0.0.1:8642/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Dashboard reverse proxy with sub_filter
    location /dash/ {
        sub_filter 'crossorigin src="/' 'crossorigin src="/dash/';
        sub_filter 'crossorigin href="/' 'crossorigin href="/dash/';
        sub_filter 'src="/' 'src="/dash/';
        sub_filter 'href="/' 'href="/dash/';
        sub_filter 'window.__HERMES_BASE_PATH__=""' 'window.__HERMES_BASE_PATH__="/dash/"';
        sub_filter_once off;
        sub_filter_types text/html;
        proxy_pass http://127.0.0.1:9119/;
        proxy_http_version 1.1;
        proxy_set_header Host localhost;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name 10.19.20.55;
        return 301 https://$host$request_uri;
    }
}
```

## Path Rewrite with `sub_filter`

When the upstream application doesn't know it's behind a path prefix (e.g., `/dash/`), use `sub_filter` to inject the prefix:

| Pattern | Replacement |
|---------|-------------|
| `crossorigin src="/` | `crossorigin src="/dash/` |
| `crossorigin href="/` | `crossorigin href="/dash/` |
| `src="/` | `src="/dash/` |
| `href="/` | `href="/dash/` |
| `window.__HERMES_BASE_PATH__=""` | `window.__HERMES_BASE_PATH__="/dash/"` |

**Key points:**
- Order matters: Match longest patterns first (`crossorigin` before plain `src`/`href`)
- Use `sub_filter_once off` to apply to all occurrences
- Set `sub_filter_types text/html` to target HTML content

## Host Header Configuration

Some applications (like Hermes Dashboard) require specific `Host` headers:

```nginx
proxy_set_header Host localhost;  # Instead of $host
```

## SSL/TLS Best Practices

### Modern Cipher Suites (Mozilla Intermediate)

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers off;
```

**Note:** TLS 1.3 ciphers are managed by OpenSSL and cannot be configured in Nginx.

### HSTS Header

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

**Warning:** Only add `preload` after confirming all subdomains support HTTPS.

### OCSP Stapling (for CA-signed certs only)

```nginx
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 1.1.1.1 valid=300s;
resolver_timeout 5s;
```

**Note:** OCSP stapling doesn't work with self-signed certificates (issuer certificate not found).

## File Backup Rule

**ALWAYS create a backup before modifying any Nginx config file.** Use date format: `filename.YYYYMMDD_HHMM`

```bash
cp /etc/nginx/sites-available/example /etc/nginx/sites-available/example.$(date +%Y%m%d_%H%M)
```

See `nginx-config-practices` skill for more details.

## Testing

### Verify Configuration
```bash
sudo nginx -t
sudo systemctl restart nginx
```

### Test Endpoints
```bash
# Gateway health check
curl -sk https://10.19.20.55/gw/health

# Dashboard
curl -sk https://10.19.20.55/dash/

# General health check
curl -sk https://10.19.20.55/health
```

## Troubleshooting

### Issue: "conflicting server name" warning
**Cause:** Multiple `server` blocks with same `server_name` on same port.

**Fix:** Ensure each `server_name:listen_port` combination is unique.

### Issue: Dashboard shows blank screen or assets 404
**Cause:** Frontend asset paths not adjusted for reverse proxy path prefix.

**Fix:** Use `sub_filter` to inject path prefix (see section above).

### Issue: "Host header not valid" error
**Cause:** Upstream application requires specific `Host` header (e.g., `localhost`).

**Fix:** Set `proxy_set_header Host localhost;` in the location block.

## Related Skills

- `nginx-config-practices` – Nginx best practices and SSL/TLS configuration
- `ssl-certificates` – SSL/TLS certificate management
- `system-administration` – General Linux system administration tasks

## References

- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [Nginx HTTP/2 Documentation](https://nginx.org/en/docs/http/ngx_http_v2_module.html)
- [Nginx sub_filter Module](http://nginx.org/en/docs/http/ngx_http_sub_module.html)
