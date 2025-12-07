#!/bin/bash
set -e

# Usage: ./vault-unseal.sh [namespace] [port]
# Default namespace is 'homepage', use 'homepage-dev' for dev
# Default port is 8200

NAMESPACE=${1:-homepage}
VAULT_PORT=${2:-8200}

echo "🔓 Unsealing Vault in namespace: $NAMESPACE"
echo "================================================"

# Check prerequisites
command -v vault >/dev/null 2>&1 || { echo "❌ vault CLI is required but not installed. Aborting." >&2; exit 1; }

# Check if vault-keys.txt exists
if [ ! -f "vault-keys.txt" ]; then
  echo "❌ vault-keys.txt not found!"
  echo "Please make sure you have the unseal keys file in the current directory."
  exit 1
fi

# Set Vault address
export VAULT_ADDR="http://localhost:$VAULT_PORT"
echo "📡 Connecting to Vault at $VAULT_ADDR"

# Check if port-forward is running
if ! nc -z localhost $VAULT_PORT 2>/dev/null; then
  echo "⚠️  Port-forward to Vault is not detected on port $VAULT_PORT"
  echo "Please run in another terminal:"
  echo "  kubectl port-forward -n $NAMESPACE svc/vault $VAULT_PORT:8200"
  echo ""
  read -p "Press Enter once port-forward is running..."
fi

# Check Vault status
echo "⏳ Checking Vault status..."
if ! vault status >/dev/null 2>&1; then
  echo "❌ Cannot connect to Vault. Check that port-forward is running."
  exit 1
fi

# Check if already unsealed
if vault status | grep -q "Sealed.*false"; then
  echo "✅ Vault is already unsealed!"
  exit 0
fi

echo "🔑 Unsealing Vault with keys from vault-keys.txt..."

# Extract unseal keys and unseal
UNSEAL_KEY_1=$(grep 'Unseal Key 1:' vault-keys.txt | awk '{print $NF}')
UNSEAL_KEY_2=$(grep 'Unseal Key 2:' vault-keys.txt | awk '{print $NF}')
UNSEAL_KEY_3=$(grep 'Unseal Key 3:' vault-keys.txt | awk '{print $NF}')

if [ -z "$UNSEAL_KEY_1" ] || [ -z "$UNSEAL_KEY_2" ] || [ -z "$UNSEAL_KEY_3" ]; then
  echo "❌ Could not extract unseal keys from vault-keys.txt"
  echo "Please unseal manually with:"
  echo "  vault operator unseal"
  exit 1
fi

vault operator unseal "$UNSEAL_KEY_1"
vault operator unseal "$UNSEAL_KEY_2"
vault operator unseal "$UNSEAL_KEY_3"

# Verify unsealed
if vault status | grep -q "Sealed.*false"; then
  echo "✅ Vault successfully unsealed!"
else
  echo "❌ Vault is still sealed. Please check manually."
  exit 1
fi
