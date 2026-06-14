# SSH Daemon Hardening Template

Drop-in for `/etc/ssh/sshd_config.d/99-hardening.conf`.

```bash
sudo cp templates/sshd-hardening.conf /etc/ssh/sshd_config.d/99-hardening.conf
sudo sshd -t && sudo systemctl reload ssh
```

## Configuration

```ssh
# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# Forwarding & Tunneling
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no

# Session Limits
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
LoginGraceTime 30

# Cryptography (modern, secure defaults)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# Optional: restrict users/groups
# AllowUsers admin@192.168.22.0/24
# AllowGroups sshusers
```

## Compatibility Notes

- **Ciphers/MACs/KEX**: Require OpenSSH 7.4+ (Debian 10+, Ubuntu 18.04+, RHEL 8+)
- **Older clients**: May need `aes128-ctr,aes192-ctr,aes256-ctr` added to Ciphers
- **Test first**: `sshd -t` validates syntax before reload

## Verification

```bash
ssh -o PreferredAuthentications=publickey user@host
# Should work with key only

ssh -o PubkeyAuthentication=no user@host
# Should fail (password auth disabled)
```