# Homepage Project

## Quick Links

- **Repository**: https://github.com/VikingTheDev/homepage
- **Production**: https://vikingthe.dev
- **Development**: https://dev.vikingthe.dev
- **Monitoring**: https://grafana.vikingthe.dev

## Development

### Quick Start
```bash
./scripts/setup-dev.sh
```

### Manual Start
```bash
# Start with hot reload
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# View logs
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Stop
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down
```

### Testing Backend
```bash
cd backend
cargo test
cargo clippy
```

### Testing Frontend
```bash
cd frontend
pnpm run check
pnpm run build
```

## Deployment

### Prerequisites
1. K3s installed on VPS
2. kubectl configured
3. cert-manager installed
4. ArgoCD installed

### Deploy
```bash
# Deploy to dev
./scripts/deploy-k8s.sh dev

# Deploy to prod
./scripts/deploy-k8s.sh prod
```

### Initialize Vault
```bash
kubectl port-forward -n homepage svc/vault 8200:8200
export VAULT_ADDR=http://localhost:8200
./scripts/vault-init.sh
```

## CI/CD Workflow

1. **Development**: Push to `dev` branch → Auto-deploy to dev.vikingthe.dev
2. **Production**: Push to `prod` branch → Auto-deploy to vikingthe.dev

## Tech Stack

- **Backend**: Rust (Axum)
- **Frontend**: Svelte + TypeScript
- **Database**: PostgreSQL
- **Cache**: ValKey
- **Secrets**: HashiCorp Vault
- **Storage**: MinIO
- **Monitoring**: Prometheus + Grafana
- **Orchestration**: Kubernetes (K3s)
- **CI/CD**: GitHub Actions + ArgoCD

## Project Structure

```
.
├── backend/         - Rust Axum API
├── frontend/        - Svelte frontend
├── k8s/            - Kubernetes manifests
├── .github/        - CI/CD workflows
├── monitoring/     - Prometheus rules
├── scripts/        - Utility scripts
└── nginx/          - Nginx configuration
```

## Useful Commands

### Docker Compose
```bash
# Dev environment
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

# Production build test
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build
```

### Kubernetes
```bash
# Get pods
kubectl get pods -n homepage

# View logs
kubectl logs -n homepage -l app=backend -f

# Port forward
kubectl port-forward -n homepage svc/backend 8000:8000

# Check Vault status
kubectl exec -n homepage vault-0 -- vault status
```

### Backup & Restore
```bash
# List backups
kubectl exec -n homepage postgres-0 -- \
  aws --endpoint-url http://minio:9000 s3 ls s3://postgres-backups/

# Restore backup
kubectl exec -n homepage postgres-0 -- \
  /backup-restore-script/restore.sh backup-YYYYMMDD-HHMMSS.sql.gz
```

## Monitoring

- **Prometheus**: http://localhost:9090 (when port-forwarded)
- **Grafana**: https://grafana.vikingthe.dev (GitHub OAuth required)

## Security

- All secrets stored in Vault
- mTLS between services (prod)
- Let's Encrypt TLS certificates
- GitHub OAuth for Grafana
- Regular security scans with Trivy

## License

MIT
