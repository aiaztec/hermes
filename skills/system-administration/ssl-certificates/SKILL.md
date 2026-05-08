---
name: ssl-certificates
description: "SSL/TLS certificate management for nginx and other services. Covers certificate chains, .pem vs .crt files, and verification techniques."
version: 1.0.0
author: Hermes-TT + Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [ssl, tls, certificates, nginx, pem, crt, chain]
    related_skills: [system-administration]
---

# SSL/TLS Certificates Management

Best practices for managing SSL/TLS certificates on Linux servers, specifically for nginx reverse proxy setups.

## Critical Rule: Use .pem Files (Full Chain) Not .crt (Leaf Only)

**User correction (session 2026-05-08):** *"pouzil si takacs.sk.crt miesto takacs.sk.pem, takze tam chyba intermediate certifikat"*

### The Problem
- `.crt` files typically contain only the **leaf certificate** (end-entity)
- Clients (browsers, curl, applications) need the **full chain** (leaf + intermediate) for proper validation
- Using `.crt` causes: `NET::ERR_CERT_AUTHORITY_INVALID`, "unable to get local issuer certificate"

### The Solution
Always use `.pem` files for nginx `ssl_certificate` directive:
```nginx
# CORRECT - .pem contains leaf + intermediate certificates
ssl_certificate /etc/ssl/private/example.com.pem;
ssl_certificate_key /etc/ssl/private/example.com.key;

# WRONG - .crt often contains leaf certificate only
# ssl_certificate /etc/ssl/private/example.com.crt;
```

## How to Verify Certificate Chain

### Check with openssl
```bash
# Should show multiple certificates in chain (leaf + intermediate)
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | grep 's:'

# Example output showing full chain:
#  0 s:CN=*.example.com          # Leaf certificate
#  1 s:C=US, O=Let's Encrypt, CN=R3  # Intermediate certificate
```

### Check with curl
```bash
# Should return 200 without certificate errors
curl -s https://example.com -o /dev/null -w "%{http_code}\n"

# If using self-signed or incomplete chain, use -k flag:
curl -sk https://example.com -o /dev/null -w "%{http_code}\n"
```

## Creating .pem Files

### Let's Encrypt (certbot)
- Automatic: `/etc/letsencrypt/live/example.com/fullchain.pem` (already contains full chain)
- Use this path directly in nginx config

### Manual Creation
```bash
# Concatenate leaf + intermediate into .pem
cat leaf.crt intermediate.crt > example.com.pem

# Verify chain
openssl crl2pkcs7 -nocrl -certfile example.com.pem | openssl pkcs7 -print_certs -noout
```

## File Extensions Guide
- `.pem` - Usually contains full chain (leaf + intermediate concatenated)
- `.crt` - Often leaf certificate only (depends on creation method)
- `.cer` - Often leaf certificate only (Windows format)
- Always verify chain with `openssl` command above after configuring

## Common Symptoms of Missing Intermediate
- Browsers show "NET::ERR_CERT_AUTHORITY_INVALID" or "unable to get local issuer certificate"
- Mobile devices and some clients fail to validate the certificate
- Online SSL checkers report "Chain issues: Incomplete"
- `curl` works (uses system CA store) but browsers fail

## Nginx SSL Configuration Workflow

1. **Obtain certificate** (Let's Encrypt or manual):
   ```bash
   # Let's Encrypt - automatically creates full chain
   sudo certbot --nginx -d example.com
   # Chain location: /etc/letsencrypt/live/example.com/fullchain.pem
   
   # Manual - concatenate leaf + intermediate into .pem
   cat leaf.crt intermediate.crt > example.com.pem
   ```

2. **Configure nginx** with `.pem` file:
   ```bash
   sudo sed -i 's|ssl_certificate .*|ssl_certificate /etc/ssl/private/example.com.pem;|' /etc/nginx/sites-available/example-ssl
   ```

3. **Test and reload:**
   ```bash
   sudo nginx -t && sudo systemctl reload nginx
   ```

4. **Verify chain from client:**
   ```bash
   curl -s https://example.com > /dev/null && echo "SSL OK" || echo "SSL Failed"
   ```

## Verification After Configuration
```bash
# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# Verify from client (should show 200, not certificate errors)
curl -s https://example.com -o /dev/null -w "%{http_code}\n"

# Full chain verification
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | openssl x509 -noout -text | grep -A2 'Subject:\|Issuer:'
```

## Files Modified
- `/etc/nginx/sites-available/*ssl*` (nginx SSL configs)
- `/etc/ssl/private/*.pem` (SSL certificates)
- `/etc/letsencrypt/live/*/fullchain.pem` (Let's Encrypt)

## References
- See system-administration skill for nginx setup and IPv6 pitfalls
- See shared-skills for shared skill management workflows
