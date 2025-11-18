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

1. **Set up K3s on your VPS**:
   ```bash
   curl -sfL https://get.k3s.io | sh -
   ```

2. **Install cert-manager**:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

3. **Install ArgoCD**:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

4. **Create ArgoCD Application for prod**:
   ```bash
   kubectl apply -f scripts/argocd-app-prod.yaml
   ```

5. **Configure DNS**:
   - Point `vikingthe.dev` to your VPS IP
   - Point `grafana.vikingthe.dev` to your VPS IP
   - Point `dev.vikingthe.dev` to your VPS IP (for dev environment)

6. **Initialize Vault**:
   ```bash
   # Port-forward to Vault
   kubectl port-forward -n homepage svc/vault 8200:8200
   
   # Initialize Vault (follow prompts)
   ./scripts/vault-init.sh
   ```

7. **Set up GitHub OAuth for Grafana**:
   - Create GitHub OAuth App at https://github.com/settings/developers
   - Set Authorization callback URL: `https://grafana.vikingthe.dev/oauth2/callback`
   - Update `k8s/base/oauth2-proxy.yaml` with client ID/secret

## 📁 Project Structure

```
homepage/
├── backend/                 # Rust Axum API
│   ├── src/
│   │   ├── main.rs         # Server entrypoint
│   │   ├── config.rs       # Configuration management
│   │   ├── vault.rs        # Vault integration
│   │   ├── db.rs           # PostgreSQL connection pool
│   │   └── cert_watcher.rs # Certificate hot-reload
│   ├── Cargo.toml
│   └── Dockerfile          # Multi-stage build
├── frontend/               # Svelte + TypeScript
│   ├── src/
│   │   ├── App.svelte     # Main component
│   │   └── main.ts        # App entrypoint
│   ├── vite.config.ts
│   └── Dockerfile
├── k8s/                    # Kubernetes manifests
│   ├── base/              # Base resources
│   │   ├── vault.yaml
│   │   ├── postgres.yaml
│   │   ├── backend.yaml
│   │   └── ...
│   └── overlays/
│       ├── dev/           # Development overrides
│       └── prod/          # Production overrides
├── .github/
│   └── workflows/
│       ├── dev.yml        # CI/CD for dev branch
│       └── prod.yml       # CI/CD for prod branch
├── monitoring/            # Prometheus rules & dashboards
├── scripts/              # Utility scripts
├── docker-compose.yml    # Base compose file
├── docker-compose.dev.yml # Development overrides
└── docker-compose.prod.yml
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

## 📝 License

MIT License - see LICENSE file for details

## 👤 Author

August H. (VikingTheDev)

## 🤝 Contributing

This is a personal project, but issues and suggestions are welcome!
