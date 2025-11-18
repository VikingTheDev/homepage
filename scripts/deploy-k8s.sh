#!/bin/bash
set -e

echo "🚀 Deploying to K3s cluster..."

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed. Aborting." >&2; exit 1; }

ENVIRONMENT=${1:-prod}

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
  echo "❌ Invalid environment. Use 'dev' or 'prod'"
  exit 1
fi

echo "📦 Deploying to $ENVIRONMENT environment..."

# Apply cert-manager ClusterIssuers
echo "🔐 Setting up cert-manager ClusterIssuers..."
kubectl apply -f scripts/cert-manager-issuers.yaml

# Apply ArgoCD applications
echo "🔄 Setting up ArgoCD applications..."
kubectl apply -f scripts/argocd-apps.yaml

# Wait for ArgoCD to sync
echo "⏳ Waiting for ArgoCD to sync (this may take a few minutes)..."
kubectl wait --for=condition=synced --timeout=600s \
  application/homepage-$ENVIRONMENT -n argocd || true

echo ""
echo "================================================"
echo "✅ Deployment initiated!"
echo "================================================"
echo ""
echo "📍 Monitor deployment:"
echo "  ArgoCD UI:     kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "                 Then visit: https://localhost:8080"
echo "  Get password:  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "📊 Check status:"
echo "  kubectl get pods -n homepage"
echo "  kubectl get ingress -n homepage"
echo ""
echo "🔍 View logs:"
echo "  kubectl logs -n homepage -l app=backend -f"
echo "  kubectl logs -n homepage -l app=frontend -f"
echo ""

if [ "$ENVIRONMENT" = "prod" ]; then
  echo "🌐 Your site will be available at:"
  echo "  https://vikingthe.dev"
  echo "  https://grafana.vikingthe.dev"
else
  echo "🌐 Your site will be available at:"
  echo "  https://dev.vikingthe.dev"
  echo "  https://grafana-dev.vikingthe.dev"
fi

echo ""
echo "⚠️  Don't forget to:"
echo "  1. Initialize Vault: ./scripts/vault-init.sh"
echo "  2. Update GitHub OAuth credentials in oauth2-proxy secret"
echo "  3. Update email in cert-manager-issuers.yaml"
