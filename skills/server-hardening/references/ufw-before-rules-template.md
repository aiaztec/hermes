# Hardened UFW before.rules Template

This template restricts ICMP (ping) to trusted networks only, making the server invisible on LAN while preserving essential ICMP for MTU/path MTU discovery.

## Usage

Copy to `/etc/ufw/before.rules` and adjust trusted networks in the ICMP section.

```bash
sudo cp templates/ufw-before.rules /etc/ufw/before.rules
sudo chown root:root /etc/ufw/before.rules
sudo chmod 640 /etc/ufw/before.rules
sudo ufw --force enable
```

## Key Sections

### 1. Loopback & Established Connections (unchanged)
```nft
-A ufw-before-input -i lo -j ACCEPT
-A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

### 2. ICMP — Trusted Networks Only (MODIFY THESE)

Replace these CIDRs with your allowed networks:

```nft
# Trusted network 1
-A ufw-before-input -s 192.168.22.0/24 -p icmp --icmp-type echo-request -j ACCEPT
-A ufw-before-input -s 192.168.22.0/24 -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -s 192.168.22.0/24 -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -s 192.168.22.0/24 -p icmp --icmp-type parameter-problem -j ACCEPT

# Trusted network 2
-A ufw-before-input -s 192.168.14.64/28 -p icmp --icmp-type echo-request -j ACCEPT
...

# Trusted host
-A ufw-before-input -s 192.168.114.11 -p icmp --icmp-type echo-request -j ACCEPT
...
```

### 3. Drop All Other Echo-Requests
```nft
-A ufw-before-input -p icmp --icmp-type echo-request -j DROP
```

### 4. Essential ICMP Globally (for MTU discovery)
```nft
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT
```

### 5. FORWARD Chain (same logic)
Apply same trusted-network rules to `ufw-before-forward`.

### 6. mDNS/UPnP DISABLED
```nft
# -A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT
# -A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT
```

## Verification

```bash
sudo iptables -L ufw-before-input -v -n | grep icmp
# Should show ACCEPT for trusted networks, DROP for 0.0.0.0/0 echo-request
```