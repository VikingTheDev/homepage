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

# Create namespace if it doesn't exist
echo "📦 Creating namespace if needed..."
if [ "$ENVIRONMENT" = "dev" ]; then
  kubectl create namespace homepage-dev --dry-run=client -o yaml | kubectl apply -f -
  NAMESPACE="homepage-dev"
else
  kubectl create namespace homepage --dry-run=client -o yaml | kubectl apply -f -
  NAMESPACE="homepage"
fi

# Deploy using kustomize
echo "📦 Deploying resources using Kustomize..."
kubectl apply -k k8s/overlays/$ENVIRONMENT

# Apply cert-manager ClusterIssuers if file exists
if [ -f "scripts/cert-manager-issuers.yaml" ]; then
  echo "🔐 Setting up cert-manager ClusterIssuers..."
  kubectl apply -f scripts/cert-manager-issuers.yaml
else
  echo "⚠️  scripts/cert-manager-issuers.yaml not found, skipping"
fi

# Apply ArgoCD applications if file exists and ArgoCD is installed
if kubectl get namespace argocd >/dev/null 2>&1 && [ -f "scripts/argocd-apps.yaml" ]; then
  echo "🔄 Setting up ArgoCD applications..."
  kubectl apply -f scripts/argocd-apps.yaml
  
  # Wait for ArgoCD to sync
  echo "⏳ Waiting for ArgoCD to sync (this may take a few minutes)..."
  kubectl wait --for=condition=synced --timeout=600s \
    application/homepage-$ENVIRONMENT -n argocd || echo "⚠️  ArgoCD sync timed out or not configured"
else
  echo "⚠️  ArgoCD not installed or argocd-apps.yaml not found, skipping ArgoCD setup"
fi

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
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get ingress -n $NAMESPACE"
echo ""
echo "🔍 View logs:"
echo "  kubectl logs -n $NAMESPACE -l app=backend -f"
echo "  kubectl logs -n $NAMESPACE -l app=frontend -f"
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
echo "⚠️  Next steps:"
echo "  1. Initialize Vault: ./scripts/vault-init.sh $NAMESPACE"
echo "  2. Update GitHub OAuth credentials (if using Grafana OAuth)"
echo "  3. Verify DNS records are pointing to your server"
echo "  4. Check certificate status: kubectl get certificates -n $NAMESPACE"
