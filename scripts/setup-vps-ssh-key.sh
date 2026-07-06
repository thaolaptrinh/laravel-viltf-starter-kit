#!/usr/bin/env bash
set -euo pipefail

# ─── setup-vps-ssh-key.sh ─────────────────────────────────────────────────────
# Generate project-specific SSH keypair if missing, push pubkey to VPS, and
# register Host entry in ~/.ssh/config so subsequent ssh/scp uses it automatically.
#
# Key location: ~/.ssh/${KEY_NAME} (+ .pub)
# Key type:     ed25519 (no passphrase — automation-friendly)
#
# Usage:
#   make setup-vps-ssh-key SSH_USER=root SSH_HOST=...
#   make setup-vps-ssh-key SSH_USER=root SSH_HOST=... KEY_NAME=foo SSH_ALIAS=bar

SSH_USER="${SSH_USER:-}"
SSH_HOST="${SSH_HOST:-}"
KEY_NAME="${KEY_NAME:-laravel-viltf}"
SSH_ALIAS="${SSH_ALIAS:-laravel-viltf}"

[ -z "$SSH_USER" ] && { read -rp "👤 SSH user (e.g., root): " SSH_USER; }
[ -z "$SSH_HOST" ] && { read -rp "🌐 VPS host: " SSH_HOST; }
[ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ] && { echo "❌ SSH_USER and SSH_HOST required"; exit 1; }

SSH_TARGET="${SSH_USER}@${SSH_HOST}"
KEY_PATH="$HOME/.ssh/${KEY_NAME}"
PUBKEY_PATH="${KEY_PATH}.pub"

# ─── 1. Generate keypair if missing ──────────────────────────────────────────
if [ ! -f "$KEY_PATH" ]; then
    echo "🔑 Generating ed25519 keypair: $KEY_PATH"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -N "" -C "${SSH_ALIAS}-${USER}@$(hostname -s)" -f "$KEY_PATH" >/dev/null
    chmod 600 "$KEY_PATH"
    chmod 644 "$PUBKEY_PATH"
    echo "✅ Keypair generated"
else
    echo "🔑 Reusing existing key: $KEY_PATH"
fi

SSH_PUBKEY=$(cat "$PUBKEY_PATH")
KEY_BODY=$(echo "$SSH_PUBKEY" | awk '{print $1, $2}')

# ─── 2. Push pubkey to VPS (initial auth still via password) ─────────────────
echo "🚀 Adding pubkey to ${SSH_TARGET}..."
ssh -o PubkeyAuthentication=no "$SSH_TARGET" "
    set -e
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
    grep -vF '${KEY_BODY}' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp 2>/dev/null || true
    mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys
    echo '${SSH_PUBKEY}' >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
"

# ─── 3. Register SSH alias in ~/.ssh/config ──────────────────────────────────
# Lets all subsequent `ssh $SSH_ALIAS` / `ssh $SSH_HOST` auto-use this key.
CONFIG_FILE="$HOME/.ssh/config"
touch "$CONFIG_FILE" && chmod 600 "$CONFIG_FILE"

# Remove any stale block for this alias, then append fresh
python3 - "$CONFIG_FILE" "$SSH_ALIAS" "$SSH_HOST" "$KEY_PATH" "$SSH_USER" << 'PY'
import re, sys
config_path, alias, host, keypath, user = sys.argv[1:6]
with open(config_path) as f:
    content = f.read()
# Drop any existing Host block whose name is the alias OR the host IP
pattern = re.compile(
    r'^Host\s+(' + re.escape(alias) + r'|' + re.escape(host) + r')\b.*?(?=\nHost\s|\Z)',
    re.S | re.M
)
content = pattern.sub('', content).rstrip() + '\n'
new_block = (
    f"\nHost {alias} {host}\n"
    f"    HostName {host}\n"
    f"    User {user}\n"
    f"    IdentityFile {keypath}\n"
    f"    IdentitiesOnly yes\n"
)
with open(config_path, 'w') as f:
    f.write(content + new_block)
print(f"✅ SSH alias '{alias}' → {user}@{host} registered in {config_path}")
PY

# ─── 4. Test key auth (must work without password) ───────────────────────────
echo ""
echo "🧪 Testing key auth..."
if ssh -o BatchMode=yes -o PreferredAuthentications=publickey "$SSH_ALIAS" 'true' 2>/dev/null; then
    echo "✅ Key auth works for ${SSH_ALIAS}"
else
    echo "⚠️  Key auth failed. Password auth still works as fallback."
    echo "   Debug: ssh -v ${SSH_ALIAS}"
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "✅ Done. From now on:"
echo "   ssh ${SSH_ALIAS}                          # login via key"
echo "   ssh ${SSH_USER}@${SSH_HOST}               # also works (config alias)"
echo "═══════════════════════════════════════════════════"
