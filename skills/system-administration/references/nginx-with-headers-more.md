# Nginx with Headers-More Filter Module (Debian/Ubuntu)

Full workflow for installing and configuring nginx with the `headers-more` module.

## Problem Context

- **Issue:** Official nginx.org repo provides nginx 1.30.0 but `headers-more` module is not included
- **Debian repo:** Provides `libnginx-mod-http-headers-more-filter` but only for nginx 1.26.3
- **Solution:** Downgrade to Debian's nginx version for module compatibility, or compile module from source

## Option 1: Use Debian nginx (1.26.3) with Module

**Best for most users** — simplicity and module availability.

### Step 1: Remove nginx.org Repo

```bash
sudo rm /etc/apt/sources.list.d/nginx.list
sudo rm /etc/apt/preferences.d/99nginx
sudo rm /usr/share/keyrings/nginx-archive-keyring.gpg
```

### Step 2: Update and Downgrade

```bash
sudo apt update
sudo apt install -y --allow-downgrades nginx=1.26.3-3+deb13u2 nginx-common=1.26.3-3+deb13u2
```

### Step 3: Install headers-more Module

```bash
sudo apt install -y libnginx-mod-http-headers-more-filter
```

The module is automatically loaded via symlink:
```
/etc/nginx/modules-enabled/50-mod-http-headers-more-filter.conf
```

### Step 4: Fix sites-enabled Symlink

Nginx includes sites with `*.conf` pattern, so ensure your default site has `.conf` extension:

```bash
ls -la /etc/nginx/sites-enabled/
# If missing .conf, create:
sudo ln -s ../sites-available/default /etc/nginx/sites-enabled/default.conf
```

### Step 5: Verify Configuration

```bash
sudo nginx -t
sudo systemctl restart nginx
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:80
```

### Usage

In your nginx server/location blocks:

```nginx
location / {
    more_set_headers "X-MyHeader: Hello";
    more_clear_headers "X-Old-Header";
}
```

## Option 2: Compile Module from Source (Advanced)

**Best if you need nginx 1.30.0+ features**, but requires compilation.

### Step 1: Get Source

```bash
# Get nginx source matching your version
wget https://nginx.org/download/nginx-1.30.0.tar.gz
tar -xzf nginx-1.30.0.tar.gz

# Get headers-more module source
git clone https://github.com/openresty/headers-more-nginx-module.git
```

### Step 2: Compile

```bash
cd nginx-1.30.0
./configure \
  --prefix=/usr/share/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --user=nginx \
  --group=nginx \
  --with-http_ssl_module \
  --with-http_v2_module \
  --add-dynamic-module=/path/to/headers-more-nginx-module

make
sudo make install
```

### Step 3: Configure

Add to `/etc/nginx/nginx.conf`:
```nginx
load_module modules/ngx_http_headers_more_filter_module.so;
```

And use in server/location blocks as usual.

## Verification

After installation:

```bash
# Module loaded?
sudo nginx -t

# Module active?
sudo nginx -V 2>&1 | grep -i headers

# Module actually works?
sudo systemctl restart nginx
curl -s -H "X-Test: 1" http://localhost:80 -o /dev/null -w "%{http_code}"
```

## Troubleshooting

**"undefined symbol" error:** Module compiled against different nginx version — recompile for exact version.

**"module not found" error:** Check:
1. `load_module` line in `/etc/nginx/nginx.conf`
2. Module file exists: `/usr/lib/nginx/modules/ngx_http_headers_more_filter_module.so`
3. File permissions: `ls -la /usr/lib/nginx/modules/`

**Infinite redirect loop:** Check for conflicting headers in module directives.

See `references/nginx-ipv6-fix.md` for common IPv6-related issues when installing nginx.