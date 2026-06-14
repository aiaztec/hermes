#!/bin/bash
# Complete TPM 2.0 PKCS#11 Setup for Hardware-Backed SSH Keys
# Run as user who needs TPM access (after usermod -aG tss <user> and re-login/newgrp tss)

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────
TOKEN_LABEL="ssh-keys"
KEY_LABEL="ssh-p256"
ALGORITHM="ecc256"        # NIST P-256 (ed25519 not supported in TPM 2.0)
USER_PIN="${TPM_USER_PIN:-}"    # Set via env var or prompt
SO_PIN="${TPM_SO_PIN:-}"        # Set via env var or prompt
# ────────────────────────────────────────────────────────────────

# Check tss group
if ! groups | grep -q '\btss\b'; then
    echo "ERROR: User not in 'tss' group. Run: sudo usermod -aG tss \$USER && newgrp tss"
    exit 1
fi

# Check TPM device
if [[ ! -c /dev/tpmrm0 ]]; then
    echo "ERROR: /dev/tpmrm0 not found. TPM 2.0 not available."
    exit 1
fi

# Check tpm2-abrmd
if ! systemctl is-active --quiet tpm2-abrmd; then
    echo "Starting tpm2-abrmd..."
    sudo systemctl enable --now tpm2-abrmd
fi

# Configure tabrmd for pkcs11
sudo tee /etc/tpm2_pkcs11.conf > /dev/null <<'EOF'
[tcti]
name = "tabrmd"
EOF

# Prompt for PINs if not set
if [[ -z "$USER_PIN" ]]; then
    read -rsp "Enter User PIN (for key operations): " USER_PIN
    echo
fi
if [[ -z "$SO_PIN" ]]; then
    read -rsp "Enter SO PIN (admin, store in password manager): " SO_PIN
    echo
fi

export TPM2_PKCS11_STORE="$HOME/.tpm2_pkcs11"

echo "Initializing PKCS#11 store..."
tpm2_ptool init

echo "Creating token: $TOKEN_LABEL"
tpm2_ptool addtoken --pid=1 --label="$TOKEN_LABEL" --userpin="$USER_PIN" --sopin="$SO_PIN"

echo "Generating $ALGORITHM key: $KEY_LABEL"
tpm2_ptool addkey --label="$TOKEN_LABEL" --algorithm="$ALGORITHM" --userpin="$USER_PIN" --key-label="$KEY_LABEL"

echo ""
echo "Objects created:"
tpm2_ptool listobjects --label="$TOKEN_LABEL"

echo ""
echo "Exporting SSH public key..."
GNUTLS_PIN="$USER_PIN" p11tool --export-pubkey --login \
    --outfile="$HOME/.ssh/tpm_key.pub" \
    "pkcs11:token=$TOKEN_LABEL;object=;type=public"

ssh-keygen -f "$HOME/.ssh/tpm_key.pub" -i -m PKCS8 > "$HOME/.ssh/tpm_key_ssh.pub"

echo ""
echo "=== SSH Public Key (add to ~/.ssh/authorized_keys on servers) ==="
cat "$HOME/.ssh/tpm_key_ssh.pub"

echo ""
echo "=== Usage ==="
echo "  # Direct SSH with PIN:"
echo "  ssh -I /usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so user@host"
echo ""
echo "  # Via ssh-agent (PIN once per session):"
echo "  eval \$(ssh-agent -s)"
echo "  ssh-add -s /usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so <<< \"$USER_PIN\""
echo "  ssh user@host  # No PIN prompt"
echo ""
echo "  # SSH config:"
echo "  Host myserver"
echo "      HostName server.example.com"
echo "      User rene"
echo "      PKCS11Provider /usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so"