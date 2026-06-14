---
name: tpm-ssh
description: SSH via TPM 2.0 ECDSA NIST P-256 key using ssh-agent + PKCS#11. Sources TPM_USER_PIN from Hermes .env, uses sg tss for group access, and handles agent lifecycle. Use this skill whenever an SSH connection to a remote host is required.
---

# TPM SSH Skill\n\n## Purpose\nProvide reliable passwordless SSH access to remote hosts using the ECDSA NIST P-256 key stored in TPM 2.0 (persistent handle `0x81010016`, token label `ssh-keys`).\n\n## Critical Rule\n\n**EXPLICIT APPROVAL REQUIRED** — Before ANY system command (ssh, sg, ssh-add, tpm2_ptool, etc.), show the complete command and ask user for permission. No autonomous execution.\n\n## Parameters
- `$1` = `user@host`, e.g. `ai@10.23.56.102`
- `$2` = remote command, optional; if omitted, opens an interactive shell

## Prerequisites
- `/home/cerberus/.hermes/.env` exists and contains `TPM_USER_PIN`
- User is in `tss` group
- PKCS#11 module: `/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so`
- Token label: `ssh-keys`
- Key label: `ssh-p256` (ECDSA NIST P-256)

## Procedure

1. **Start clean ssh-agent and load TPM key:**
   ```bash
   set -a; source /home/cerberus/.hermes/.env; set +a
   sg tss 'bash -lc "ssh-agent -k 2>/dev/null; eval \"$(ssh-agent -s)\"; ssh-add -s /usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so <<< \"${TPM_USER_PIN}\""'
   ```

2. **Run SSH command:**
   ```bash
   set -a; source /home/cerberus/.hermes/.env; set +a
   sg tss 'bash -lc "ssh <user@host> \"<remote command>\" 2>&1"'
   ```

## Environment and Group Access
- `.env` path is `/home/cerberus/.hermes/.env` (Hermes config directory), not the current working directory.
- Use `sg tss 'bash -lc "..."'` to execute commands in the `tss` group context. Do not use `newgrp tss` with flags like `-l`; it will fail in this environment.

## Notes
- `sg tss` is required for `/dev/tpmrm0` access.
- `ssh-agent` is killed and restarted each time to avoid stale sessions.
- PIN is provided once via stdin to `ssh-add`; subsequent SSH connections reuse the loaded agent key.
- If `TPM_USER_PIN` changes, the agent must be reloaded.

## Handling Unknown or Changed PIN
- If the user changed the PIN and the value in `.env` is unknown or incorrect, do **not** substitute placeholders. Ask the user for the current `TPM_USER_PIN` and update `.env` before proceeding.

## Failure Modes
- **Wrong PIN / DA lockout:** `tpm2_ptool listobjects --label=ssh-keys` shows token exists but `ssh-add` fails with "Wrong PIN". Requires token reset (`tpm2_ptool rmtoken --label=ssh-keys`, then `addtoken` + `addkey`) after reboot to clear DA counter.
- **Missing .env:** Abort and ask user where `TPM_USER_PIN` is stored.
- **Token missing:** Run `tpm2_ptool init`, then `addtoken` and `addkey`.
- **Agent reuse pitfall:** An old ssh-agent loaded in the session can keep a bad key. Always kill the agent (`ssh-agent -k`) before starting a new one.
