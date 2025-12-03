#!/bin/bash
set -e

# Usage: ./setup-vault-bootstrap.sh [namespace]
# Default namespace is 'homepage' (prod), use 'homepage-dev' for dev

NAMESPACE=${1:-homepage}

echo "🔐 Setting up Vault Bootstrap transit engine in namespace: $NAMESPACE"
echo "================================================"

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed. Aborting." >&2; exit 1; }

echo "✅ Prerequisites check passed"

# Check if vault-bootstrap pod exists
if ! kubectl get deployment/vault-bootstrap -n $NAMESPACE >/dev/null 2>&1; then
  echo "❌ vault-bootstrap deployment not found in namespace $NAMESPACE"
  echo "Make sure you've deployed the Kubernetes manifests first:"
  echo "  kubectl apply -k k8s/overlays/prod"
  exit 1
fi

echo "📡 Waiting for vault-bootstrap to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/vault-bootstrap -n $NAMESPACE

echo "🔧 Configuring transit engine in vault-bootstrap..."

# Run commands inside the vault-bootstrap pod
kubectl exec -n $NAMESPACE deployment/vault-bootstrap -- sh -c '
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="dev-root-token"

echo "Enabling transit secrets engine..."
vault secrets enable transit || echo "Transit engine already enabled"

echo "Creating autounseal key..."
vault write -f transit/keys/autounseal || echo "Autounseal key already exists"

echo "Verifying autounseal key..."
vault read transit/keys/autounseal
'

if [ $? -eq 0 ]; then
  echo ""
  echo "================================================"
  echo "✅ Vault Bootstrap configuration complete!"
  echo "================================================"
  echo ""
  echo "Next steps:"
  echo "  1. Restart the main Vault pod:"
  echo "     kubectl delete pod vault-0 -n $NAMESPACE"
  echo ""
  echo "  2. Wait for Vault to be ready:"
  echo "     kubectl wait --for=condition=ready pod/vault-0 -n $NAMESPACE --timeout=120s"
  echo ""
  echo "  3. Initialize Vault:"
  echo "     ./scripts/vault-init.sh $NAMESPACE"
  echo ""
  echo "The main Vault will now auto-unseal using the bootstrap Vault's transit engine!"
else
  echo ""
  echo "❌ Failed to configure vault-bootstrap"
  echo "Check the pod logs:"
  echo "  kubectl logs -n $NAMESPACE deployment/vault-bootstrap"
  exit 1
fi
