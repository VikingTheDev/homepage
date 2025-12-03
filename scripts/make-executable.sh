#!/bin/bash
# Make all scripts executable
# Run this after cloning the repository on Linux

echo "🔧 Making scripts executable..."

chmod +x scripts/vault-init.sh
chmod +x scripts/setup-dev.sh
chmod +x scripts/deploy-k8s.sh
chmod +x scripts/make-executable.sh

echo "✅ All scripts are now executable"
echo ""
echo "Available scripts:"
echo "  ./scripts/setup-dev.sh         - Set up local development environment"
echo "  ./scripts/deploy-k8s.sh prod   - Deploy to production K8s"
echo "  ./scripts/deploy-k8s.sh dev    - Deploy to dev K8s"
echo "  ./scripts/vault-init.sh        - Initialize Vault (prod)"
echo "  ./scripts/vault-init.sh homepage-dev - Initialize Vault (dev)"
