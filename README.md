# Homepage - Containerized Fullstack Application

A production-ready, fully containerized fullstack application built with Rust (Axum), Svelte, and deployed on Kubernetes (K3s).

## 🏗️ Architecture

### Technology Stack

- **Backend**: Rust with Axum framework
- **Frontend**: Svelte with TypeScript and Vite
- **Database**: PostgreSQL with automated backups
- **Cache**: ValKey (Redis-compatible)
- **Secrets Management**: HashiCorp Vault with Transit auto-unseal
- **Storage**: MinIO (S3-compatible) for backups
- **Monitoring**: Prometheus + Grafana with OAuth2 authentication
- **Orchestration**: Kubernetes (K3s)
- **CI/CD**: GitHub Actions + ArgoCD (GitOps)
- **Certificates**: cert-manager with Let's Encrypt
- **Container Images**: Chainguard (minimal, secure base images)

### Infrastructure

- **Deployment Environments**: 
  - Development: `dev.vikingthe.dev`
  - Production: `vikingthe.dev`
  - Monitoring: `grafana.vikingthe.dev`

- **Security Features**:
  - mTLS between services (production)
  - Vault PKI for certificate management
  - OAuth2 (GitHub) for Grafana access
  - Network isolation with Kubernetes NetworkPolicies
  - Automated security scanning with Trivy

## 🚀 Quick Start

### Prerequisites

- Docker Desktop with WSL2 (for local development)
- kubectl
- Node.js 20+ and npm
- Rust 1.70+

### Local Development

1. **Clone the repository**:
   ```bash
   git clone https://github.com/VikingTheDev/homepage.git
   cd homepage
   ```

2. **Start development environment**:
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
   ```

3. **Access services**:
   - Frontend: http://localhost:5173 (with HMR)
   - Backend: http://localhost:8000
   - Vault: http://localhost:8200 (token: `dev-root-token`)
   - PostgreSQL: localhost:5432
   - MinIO Console: http://localhost:9001

4. **Hot reload is enabled**:
   - Backend: Changes to `backend/src/**` trigger automatic rebuild
   - Frontend: Vite HMR for instant updates

### Production Deployment (K3s)

## 📦 Kubernetes Deployment Guide

### Prerequisites

- Linux server (VPS) with:
  - 2+ CPU cores
  - 4GB+ RAM
  - 20GB+ disk space
  - Ubuntu 20.04+ or similar
- Domain name with DNS control
- SSH access to the server

### Part 1: Server Preparation

#### 1.1 Update System and Install Dependencies

```bash
# SSH into your server
ssh user@your-server-ip

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required tools
sudo apt install -y curl git wget jq netcat-openbsd

# Install Vault CLI (for initialization)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

#### 1.2 Install K3s

```bash
# Install K3s (lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready (may take 1-2 minutes)
sudo systemctl status k3s

# Set up kubectl access for current user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config

# Verify K3s is running
kubectl get nodes
# Should show: STATUS = Ready
```

#### 1.3 Configure DNS Records

Point the following DNS A records to your server's IP address:
- `vikingthe.dev` → Your server IP
- `dev.vikingthe.dev` → Your server IP
- `grafana.vikingthe.dev` → Your server IP

Verify DNS propagation:
```bash
dig vikingthe.dev +short
dig dev.vikingthe.dev +short
dig grafana.vikingthe.dev +short
```

### Part 2: Install Core Dependencies

#### 2.1 Install cert-manager (for SSL certificates)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Verify installation
kubectl get pods -n cert-manager
# All pods should be Running
```

#### 2.2 Install ArgoCD (for GitOps deployments)

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready (may take 2-3 minutes)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"

# Port-forward to access ArgoCD UI (optional, for setup)
# In a separate terminal: kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080 (username: admin, password from above)
```

### Part 3: Deploy Production Environment

#### 3.1 Clone Repository and Prepare

```bash
# Clone your repository
cd ~
git clone https://github.com/VikingTheDev/homepage.git
cd homepage

# Make scripts executable
chmod +x scripts/*.sh
# Or use the helper script:
# bash scripts/make-executable.sh

# Create namespace
kubectl create namespace homepage
```

#### 3.2 Deploy Production Stack

```bash
# Deploy all production resources EXCEPT Vault (managed separately)
kubectl apply -k k8s/overlays/prod

# Deploy Vault manually (not managed by ArgoCD to prevent restart loops)
kubectl apply -f k8s/base/vault.yaml
kubectl apply -f k8s/base/vault-ingress.yaml

# Monitor deployment (may take 3-5 minutes for all pods to start)
watch kubectl get pods -n homepage
# Press Ctrl+C when all pods show Running or Completed status
```

**Important**: Vault is deployed manually (not via ArgoCD) because:
- Vault's sealed/unsealed state causes ArgoCD to detect drift
- ArgoCD's self-heal would constantly restart the pod
- Manual deployment ensures Vault stays running while sealed

#### 3.3 Initialize Vault

**Option A: Web UI (Recommended)**

1. **Access Vault UI**: Open `https://vault.vikingthe.dev` in your browser

2. **Initialize Vault**:
   - Click "Initialize"
   - Key shares: `5`
   - Key threshold: `3`
   - Click "Initialize"
   - **CRITICAL**: Download the keys JSON file and store it securely!

3. **Unseal Vault**:
   - Enter any 3 of the 5 `keys_base64` values from your downloaded file
   - Click "Continue to Unseal" after each key
   - After the 3rd key, Vault will be unsealed

4. **Login**:
   - Use the `root_token` from your downloaded keys file
   - You're now in the Vault UI!

5. **Set up AppRole for Backend**:
   ```bash
   # On your VPS, port-forward to Vault
   kubectl port-forward -n homepage svc/vault 8200:8200
   
   # In another terminal, run the initialization script
   # It will prompt for your root token from the downloaded keys
   cd ~/code/homepage
   ./scripts/vault-init.sh homepage
   
   # The script will:
   # - Set up PKI for mTLS certificates
   # - Create AppRole for backend authentication
   # - Display Role ID and Secret ID
   # - Offer to create the Kubernetes secret automatically
   
   # IMPORTANT: When prompted, choose 'y' to create the secret
   ```

**Option B: CLI Only**

```bash
# In one terminal: Port-forward to Vault
kubectl port-forward -n homepage svc/vault 8200:8200

# In another terminal: Run Vault initialization script
./scripts/vault-init.sh homepage

# The script will:
# - Wait for Vault to be ready
# - Initialize Vault with Shamir seal (5 unseal keys, threshold of 3)
# - Automatically unseal Vault with the generated keys
# - Set up PKI for mTLS certificates
# - Create AppRole for backend authentication
# - Optionally create the Kubernetes secret

# IMPORTANT: Save the output! You'll see:
# - vault-keys.txt (contains 5 unseal keys and root token)
# - Backend AppRole credentials (Role ID and Secret ID)

# CRITICAL: Back up vault-keys.txt to a secure location!
# You'll need these keys to unseal Vault after pod restarts.

# The script will offer to create the secret automatically
# Or manually create it:
# kubectl create secret generic backend-vault-auth -n homepage \
#   --from-literal=role-id=<ROLE_ID> \
#   --from-literal=secret-id=<SECRET_ID>
```

**Note on Vault Unsealing**: 

After a pod restart, Vault will be sealed and needs to be unsealed before the backend can access it.

**Unseal via Web UI:**
1. Go to `https://vault.vikingthe.dev`
2. Enter any 3 of your 5 `keys_base64` values
3. Vault is now unsealed and ready

**Unseal via CLI:**
```bash
# Port-forward to Vault
kubectl port-forward -n homepage svc/vault 8200:8200

# Unseal manually with vault CLI
export VAULT_ADDR=http://localhost:8200
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>

# Or use the helper script (requires vault-keys.txt in current directory)
./scripts/vault-unseal.sh homepage
```

**Verify Backend Can Connect:**
```bash
# Check backend logs after Vault is unsealed
kubectl logs -n homepage -l app=backend --tail=50

# You should see successful Vault authentication
# If you see "Vault is sealed" errors, unseal Vault first
```

#### 3.4 Configure Let's Encrypt (SSL Certificates)

```bash
# Update the ClusterIssuer with your email
# Edit scripts/cert-manager-issuers.yaml and replace email address

# Apply the issuer
kubectl apply -f scripts/cert-manager-issuers.yaml

# Verify certificates are being issued
kubectl get certificates -n homepage
# Wait until READY = True (may take 1-2 minutes)
```

#### 3.5 Set up GitHub OAuth for Grafana (Optional)

```bash
# 1. Go to https://github.com/settings/developers
# 2. Click "New OAuth App"
# 3. Fill in:
#    - Application name: "Homepage Grafana"
#    - Homepage URL: "https://grafana.vikingthe.dev"
#    - Authorization callback URL: "https://grafana.vikingthe.dev/oauth2/callback"
# 4. Click "Register application"
# 5. Copy the Client ID and generate a Client Secret

# 6. Create Kubernetes secret
kubectl create secret generic grafana-oauth -n homepage \
  --from-literal=client-id=<your-github-client-id> \
  --from-literal=client-secret=<your-github-client-secret>

# 7. Restart Grafana
kubectl rollout restart deployment/grafana -n homepage
```

#### 3.6 Verify Production Deployment

```bash
# Check all pods are running
kubectl get pods -n homepage

# Check services
kubectl get svc -n homepage

# Check ingress
kubectl get ingress -n homepage

# Test backend health (from VPS, use HTTP for internal testing)
curl http://localhost/api/example

# Access frontend from browser (Cloudflare provides HTTPS)
# Open browser: https://vikingthe.dev

# Access Grafana (if OAuth configured)
# Open browser: https://grafana.vikingthe.dev
```

### Part 4: Deploy Development Environment

#### 4.1 Create Dev Namespace and Deploy

```bash
# Create dev namespace
kubectl create namespace homepage-dev

# Deploy dev environment
kubectl apply -k k8s/overlays/dev

# Monitor dev pods
watch kubectl get pods -n homepage-dev
```

#### 4.2 Initialize Dev Vault

```bash
# In one terminal: Port-forward to dev Vault (use different port)
kubectl port-forward -n homepage-dev svc/vault 8201:8200

# In another terminal: Run initialization for dev environment
./scripts/vault-init.sh homepage-dev 8201

# The script handles everything including secret creation
```

#### 4.3 Verify Dev Deployment

```bash
# Check dev pods
kubectl get pods -n homepage-dev

# Test dev backend
curl https://dev.vikingthe.dev/api/example

# Access dev frontend
# Open browser: https://dev.vikingthe.dev
```

### Part 5: Set up ArgoCD Auto-Sync (GitOps)

#### 5.1 Configure ArgoCD Applications

```bash
# Apply production ArgoCD application
kubectl apply -f scripts/argocd-app-prod.yaml

# Apply dev ArgoCD application  
kubectl apply -f scripts/argocd-app-dev.yaml

# Check ArgoCD applications
kubectl get applications -n argocd

# Access ArgoCD UI to monitor deployments
# Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443
# URL: https://localhost:8080
# Login: admin / <password from step 2.2>
```

#### 5.2 Enable Auto-Sync

From ArgoCD UI or CLI:
```bash
# Enable auto-sync for production
argocd app set homepage-prod --sync-policy automated --auto-prune --self-heal

# Enable auto-sync for dev
argocd app set homepage-dev --sync-policy automated --auto-prune --self-heal
```

### Part 6: Post-Deployment Tasks

#### 6.1 Set up Monitoring

```bash
# Check Prometheus is running
kubectl get pods -n homepage -l app=prometheus

# Check Grafana is accessible
curl -I https://grafana.vikingthe.dev

# Import dashboards (in Grafana UI):
# 1. Login to Grafana
# 2. Go to Dashboards → Import
# 3. Upload JSON files from monitoring/ directory
```

#### 6.2 Configure Backups

```bash
# Verify backup CronJob is created
kubectl get cronjobs -n homepage

# Manually trigger a test backup
kubectl create job --from=cronjob/postgres-backup test-backup-$(date +%s) -n homepage

# Check backup job
kubectl get jobs -n homepage

# Verify backup in MinIO
kubectl port-forward -n homepage svc/minio 9001:9001 &
# Access MinIO console: http://localhost:9001
# Login: minioadmin / minioadmin
# Check postgres-backups bucket
```

#### 6.3 Security Hardening

```bash
# Apply NetworkPolicies (if not already in manifests)
kubectl apply -f k8s/base/network-policies.yaml

# Enable Pod Security Standards
kubectl label namespace homepage pod-security.kubernetes.io/enforce=restricted
kubectl label namespace homepage-dev pod-security.kubernetes.io/enforce=baseline

# Verify secrets are encrypted
kubectl get secrets -n homepage
```

### Part 7: Ongoing Operations

#### 7.1 Update Deployments

Production updates happen automatically via GitOps:
```bash
# 1. Make changes locally
# 2. Commit and push to prod branch
git checkout prod
git add .
git commit -m "Update feature"
git push origin prod

# 3. GitHub Actions builds and updates manifests
# 4. ArgoCD automatically syncs changes
# 5. Monitor in ArgoCD UI
```

#### 7.2 View Logs

```bash
# Backend logs
kubectl logs -n homepage -l app=backend -f

# Frontend logs
kubectl logs -n homepage -l app=frontend -f

# Database logs
kubectl logs -n homepage -l app=postgres -f

# All pods in namespace
kubectl logs -n homepage --all-containers=true -f
```

#### 7.3 Troubleshooting

```bash
# Check pod status
kubectl describe pod <pod-name> -n homepage

# Check events
kubectl get events -n homepage --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n homepage
kubectl top nodes

# Restart a deployment
kubectl rollout restart deployment/<deployment-name> -n homepage

# Scale a deployment
kubectl scale deployment/<deployment-name> -n homepage --replicas=3
```

### Part 8: Cleanup (if needed)

```bash
# Delete dev environment
kubectl delete namespace homepage-dev

# Delete production environment
kubectl delete namespace homepage

# Uninstall ArgoCD
kubectl delete namespace argocd

# Uninstall cert-manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Uninstall K3s
/usr/local/bin/k3s-uninstall.sh
```

## 🔧 Configuration

### Environment Variables

Create `.env` file for local development:

```bash
cp .env.example .env
```

Key variables:
- `VAULT_ADDR` - Vault server address
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - ValKey connection string

### GitHub Secrets

Required for CI/CD:
- `GITHUB_TOKEN` - Automatically provided
- (OAuth credentials are in Vault for production)

## 🔐 Secrets Management

All secrets are managed through HashiCorp Vault:

1. **Local Development**: Vault runs in dev mode with root token
2. **Production**: Vault uses Transit auto-unseal and AppRole authentication

### Adding Secrets

```bash
# Write database credentials
vault kv put secret/database/homepage username=dbuser password=secret

# Enable PKI for mTLS
vault secrets enable pki
vault write pki/root/generate/internal common_name=vikingthe.dev ttl=87600h
```

## 📊 Monitoring

### Prometheus Metrics

All services expose Prometheus metrics:
- Backend: `/metrics` endpoint
- PostgreSQL: via `postgres_exporter` sidecar
- ValKey: via `redis_exporter` sidecar

### Grafana Dashboards

Access Grafana at `https://grafana.vikingthe.dev` (requires GitHub account with write access to repository).

Pre-configured dashboards:
- Kubernetes cluster overview
- PostgreSQL performance metrics
- Backend API latency and throughput
- ValKey cache hit rates
- Certificate expiration monitoring

### Alerts

Prometheus alerts are configured for:
- Certificate expiration (7 days warning, 3 days critical)
- High error rates
- Service downtime
- Database connection issues
- High resource usage

## 💾 Backup & Restore

### Automated Backups

PostgreSQL backups run every 6 hours via Kubernetes CronJob:
- Compressed with gzip
- Stored in MinIO (S3-compatible)
- 7-day retention policy
- Automatic cleanup of old backups

### Manual Restore

```bash
# List available backups
kubectl exec -n homepage -it postgres-0 -- \
  aws --endpoint-url http://minio:9000 s3 ls s3://postgres-backups/

# Restore from backup
kubectl create job --from=cronjob/postgres-backup restore-$(date +%s) -n homepage
kubectl exec -n homepage -it restore-<job-name> -- /backup-restore-script/restore.sh backup-20241113-120000.sql.gz
```

## 🚢 Deployment Workflow

### Development (dev branch)

1. Push to `dev` branch
2. GitHub Actions:
   - Runs tests
   - Builds Docker images (multi-arch)
   - Security scan with Trivy
   - Pushes to GHCR with `dev` tag
   - Updates `k8s/overlays/dev/kustomization.yaml`
3. ArgoCD auto-syncs changes to dev environment
4. Changes deployed to `dev.vikingthe.dev`

### Production (prod branch)

1. Merge to `prod` branch
2. GitHub Actions:
   - Runs comprehensive tests
   - Builds optimized Docker images
   - Security scan (fails on critical vulnerabilities)
   - Pushes to GHCR with `prod` and `latest` tags
   - Updates `k8s/overlays/prod/kustomization.yaml`
3. ArgoCD auto-syncs to production
4. Changes deployed to `vikingthe.dev`
5. mTLS enabled between services
6. Let's Encrypt production certificates issued

## 🛠️ Development

### Backend (Rust)

```bash
cd backend

# Run with hot reload
cargo watch -x run

# Run tests
cargo test

# Check code
cargo clippy

# Format code
cargo fmt
```

### Frontend (Svelte)

```bash
cd frontend

# Install dependencies
pnpm install

# Dev server with HMR
pnpm run dev

# Type check
pnpm run check

# Build for production
pnpm run build
```

## 🔧 Troubleshooting

### Script Issues

#### Scripts show "Permission denied"
```bash
# Make scripts executable
chmod +x scripts/*.sh
# Or use:
bash scripts/make-executable.sh
```

#### vault-init.sh stuck on "Waiting for Vault to be ready"
```bash
# Check if port-forward is running
lsof -i :8200  # or netstat -tuln | grep 8200

# Verify Vault pod is running
kubectl get pods -n homepage -l app=vault

# Try restarting port-forward
kubectl port-forward -n homepage svc/vault 8200:8200
```

#### "nc: command not found" error
```bash
# Install netcat
sudo apt install -y netcat-openbsd
```

#### "jq: command not found" error
```bash
# Install jq
sudo apt install -y jq
```

### Deployment Issues

#### Pods stuck in "Pending" state
```bash
# Check node resources
kubectl describe nodes

# Check events
kubectl get events -n homepage --sort-by='.lastTimestamp'

# Check pod details
kubectl describe pod <pod-name> -n homepage
```

#### Certificate not being issued
```bash
# Check cert-manager is running
kubectl get pods -n cert-manager

# Check certificate status
kubectl describe certificate <cert-name> -n homepage

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f
```

#### Can't connect to ArgoCD
```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward to ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# Username: admin
```

#### Vault unsealed keys lost
```bash
# If vault-keys.txt is lost and Vault is sealed, you need to:
# 1. Delete the Vault pod to restart with new data (WARNING: loses all secrets)
# 2. Or restore from backup if you backed up the keys

# To prevent this: ALWAYS backup vault-keys.txt to a secure location
```

### Network Issues

#### Can't access services via domain
```bash
# Verify DNS is resolving correctly
dig vikingthe.dev +short

# Check ingress configuration
kubectl get ingress -n homepage
kubectl describe ingress <ingress-name> -n homepage

# Verify cert-manager certificate
kubectl get certificates -n homepage

# Check if services are running
kubectl get svc -n homepage
```

#### Backend can't connect to database
```bash
# Check PostgreSQL pod
kubectl get pods -n homepage -l app=postgres

# Check backend logs
kubectl logs -n homepage -l app=backend -f

# Verify database secret exists
kubectl get secret -n homepage | grep database
```

## 📝 License

MIT License - see LICENSE file for details

## 👤 Author

August H. (VikingTheDev)

## 🤝 Contributing

This is a personal project, but issues and suggestions are welcome!
