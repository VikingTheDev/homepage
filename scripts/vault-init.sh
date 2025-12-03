#!/bin/bash
set -e

echo "Initializing Vault..."

# Set Vault address
export VAULT_ADDR='http://localhost:8200'

# Wait for Vault to be ready
until vault status > /dev/null 2>&1; do
  echo "Waiting for Vault to be ready..."
  sleep 2
done

# Initialize Vault (skip if already initialized)
if vault status | grep -q "Initialized.*false"; then
  echo "Initializing Vault for the first time..."
  vault operator init -key-shares=5 -key-threshold=3 > vault-keys.txt
  echo "Vault keys saved to vault-keys.txt - STORE THESE SECURELY!"
  
  # Unseal Vault
  echo "Unsealing Vault..."
  vault operator unseal $(grep 'Key 1:' vault-keys.txt | awk '{print $NF}')
  vault operator unseal $(grep 'Key 2:' vault-keys.txt | awk '{print $NF}')
  vault operator unseal $(grep 'Key 3:' vault-keys.txt | awk '{print $NF}')
  
  # Get root token
  ROOT_TOKEN=$(grep 'Initial Root Token:' vault-keys.txt | awk '{print $NF}')
  export VAULT_TOKEN=$ROOT_TOKEN
else
  echo "Vault already initialized"
  echo "Please provide root token:"
  read -s ROOT_TOKEN
  export VAULT_TOKEN=$ROOT_TOKEN
fi

# Enable secrets engines
echo "Configuring secrets engines..."
vault secrets enable -path=secret kv-v2 || true

# Enable PKI for mTLS
echo "Setting up PKI..."
vault secrets enable pki || true
vault secrets tune -max-lease-ttl=87600h pki || true

# Generate root CA
vault write -field=certificate pki/root/generate/internal \
  common_name="vikingthe.dev" \
  ttl=87600h || true

# Configure CA and CRL URLs
vault write pki/config/urls \
  issuing_certificates="http://vault:8200/v1/pki/ca" \
  crl_distribution_points="http://vault:8200/v1/pki/crl" || true

# Enable intermediate PKI
vault secrets enable -path=pki_int pki || true
vault secrets tune -max-lease-ttl=43800h pki_int || true

# Create intermediate CSR
vault write -format=json pki_int/intermediate/generate/internal \
  common_name="vikingthe.dev Intermediate Authority" \
  | jq -r '.data.csr' > pki_intermediate.csr

# Sign intermediate certificate
vault write -format=json pki/root/sign-intermediate \
  csr=@pki_intermediate.csr \
  format=pem_bundle ttl="43800h" \
  | jq -r '.data.certificate' > intermediate.cert.pem

# Set signed certificate
vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem

# Create role for backend
vault write pki_int/roles/backend \
  allowed_domains="backend,backend.homepage.svc.cluster.local" \
  allow_subdomains=true \
  max_ttl="720h"

# Create role for postgres
vault write pki_int/roles/postgres \
  allowed_domains="postgres,postgres.homepage.svc.cluster.local" \
  allow_subdomains=true \
  max_ttl="720h"

# Enable AppRole auth
echo "Setting up AppRole authentication..."
vault auth enable approle || true

# Create policy for backend
vault policy write backend - <<EOF
path "secret/data/database/*" {
  capabilities = ["read"]
}

path "pki_int/issue/backend" {
  capabilities = ["create", "update"]
}
EOF

# Create AppRole for backend
vault write auth/approle/role/backend \
  token_policies="backend" \
  token_ttl=1h \
  token_max_ttl=4h

# Get role ID and secret ID
ROLE_ID=$(vault read -field=role_id auth/approle/role/backend/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/backend/secret-id)

echo "================================================"
echo "Vault initialization complete!"
echo "================================================"
echo ""
echo "Backend AppRole credentials:"
echo "Role ID: $ROLE_ID"
echo "Secret ID: $SECRET_ID"
echo ""
echo "Store these in your Kubernetes secrets:"
echo "kubectl create secret generic backend-vault-auth -n homepage \\"
echo "  --from-literal=role-id=$ROLE_ID \\"
echo "  --from-literal=secret-id=$SECRET_ID"
echo ""
echo "Root token and unseal keys are in vault-keys.txt"
echo "KEEP THIS FILE SECURE AND BACKED UP!"
