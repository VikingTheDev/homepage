# Architecture Overview

## System Architecture (Production)

```
                                    Internet
                                       |
                                       | HTTPS (443)
                                       |
                              [Let's Encrypt TLS]
                                       |
                                       v
                        ┌──────────────────────────┐
                        │   Traefik Ingress        │
                        │   (K3s built-in)         │
                        └──────────────────────────┘
                                   |
                    ┌──────────────┴──────────────┐
                    |                             |
              vikingthe.dev              grafana.vikingthe.dev
                    |                             |
                    v                             v
         ┌──────────────────┐         ┌──────────────────┐
         │  Frontend (Nginx) │         │  OAuth2 Proxy    │
         │  Svelte SPA       │         │  (GitHub Auth)   │
         │  2-3 replicas     │         └─────────┬────────┘
         └─────────┬─────────┘                   |
                   │                             v
                   │ /api                 ┌──────────────┐
                   └──────┐               │   Grafana    │
                          │               └──────┬───────┘
                          v                      |
              ┌───────────────────┐              |
              │  Backend (Axum)    │              |
              │  Rust API          │              |
              │  2-3 replicas      │              |
              └─────────┬──────────┘              |
                        |                         |
                        | mTLS (prod)             v
                        |                  ┌──────────────┐
         ┌──────────────┼──────────────────┤ Prometheus   │
         |              |                  │ Monitoring   │
         v              v                  └──────────────┘
┌────────────────┐  ┌────────────────┐
│  PostgreSQL    │  │  ValKey Cache  │
│  StatefulSet   │  │  (Redis)       │
│  1 replica     │  │  1 replica     │
│  + exporter    │  │  + exporter    │
└────────┬───────┘  └────────────────┘
         |
         | backup every 6h
         |
         v
  ┌──────────────┐
  │    MinIO     │
  │  S3-compat   │
  │  storage     │
  └──────────────┘

┌─────────────────────────────────────────────┐
│  HashiCorp Vault (Secrets Management)       │
│  ┌──────────────┐      ┌─────────────────┐ │
│  │   Bootstrap  │ ───> │  Primary Vault  │ │
│  │   (dev mode) │      │  (auto-unseal)  │ │
│  └──────────────┘      └─────────────────┘ │
│                        • KV Secrets         │
│                        • PKI (mTLS certs)   │
│                        • AppRole Auth       │
└─────────────────────────────────────────────┘
```

## Network Isolation

```
┌─────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                  │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │          Public Network                     │    │
│  │  - Traefik Ingress                         │    │
│  │  - Frontend Pods                           │    │
│  │  - OAuth2 Proxy                            │    │
│  └────────────────────────────────────────────┘    │
│                        |                             │
│                        | ClusterIP Services          │
│                        |                             │
│  ┌────────────────────────────────────────────┐    │
│  │        Application Network                  │    │
│  │  - Backend Pods                            │    │
│  │  - Grafana                                 │    │
│  │  - Prometheus                              │    │
│  └────────────────────────────────────────────┘    │
│                        |                             │
│                        | mTLS (prod)                 │
│                        |                             │
│  ┌────────────────────────────────────────────┐    │
│  │          Data Network                       │    │
│  │  - PostgreSQL                              │    │
│  │  - ValKey                                  │    │
│  │  - MinIO                                   │    │
│  │  - Vault                                   │    │
│  └────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

## CI/CD Pipeline

```
┌─────────────────────────────────────────────────────┐
│                 GitHub Repository                    │
│                                                      │
│  ┌──────────┐         ┌──────────┐                 │
│  │   main   │         │   dev    │    prod         │
│  └────┬─────┘         └────┬─────┘      │          │
└───────┼──────────────────┼──────────────┼──────────┘
        │                  │              │
        │                  v              v
        │         ┌────────────────────────────────┐
        │         │    GitHub Actions Workflow     │
        │         │                                 │
        │         │  1. Run Tests (Rust + Svelte)  │
        │         │  2. Build Docker Images         │
        │         │  3. Security Scan (Trivy)       │
        │         │  4. Push to GHCR                │
        │         │  5. Update Kustomize Manifests  │
        │         └────────────────────────────────┘
        │                  │              │
        │                  v              v
        │         ┌─────────────────────────────────┐
        │         │  GitHub Container Registry      │
        │         │                                  │
        │         │  - backend:dev  - backend:prod  │
        │         │  - frontend:dev - frontend:prod │
        │         └─────────────────────────────────┘
        │                  │              │
        │                  v              v
        │         ┌─────────────────────────────────┐
        │         │          ArgoCD                  │
        │         │                                  │
        │         │  - Auto-sync enabled            │
        │         │  - Self-heal on drift           │
        │         │  - Prune unused resources       │
        │         └────────────┬────────────────────┘
        │                      │
        │                      v
        │         ┌─────────────────────────────────┐
        │         │      K3s Cluster (VPS)          │
        │         │                                  │
        │         │  dev.vikingthe.dev (dev env)    │
        │         │  vikingthe.dev     (prod env)   │
        │         └─────────────────────────────────┘
        │
        └────> Manual deployment for testing
```

## Data Flow

### User Request Flow

```
1. User Browser
      |
      | HTTPS
      v
2. Let's Encrypt TLS Termination
      |
      v
3. Traefik Ingress
      |
      ├─> /         ──> Frontend (Nginx serving Svelte SPA)
      |                    |
      |                    | Client-side routing
      |                    v
      └─> /api/*    ──> Backend (Axum API)
                          |
              ┌───────────┼───────────┐
              |           |           |
              v           v           v
          ValKey      PostgreSQL   Vault
         (cache)     (database)  (secrets)
```

### Secret Management Flow

```
1. Application Pod Starts
      |
      v
2. Vault Agent Injector (Init Container)
      |
      | AppRole Auth
      v
3. HashiCorp Vault
      |
      ├─> KV Secrets (DB credentials, API keys)
      |
      └─> PKI Engine (TLS certificates for mTLS)
      |
      v
4. Secrets Rendered to /vault/secrets/
      |
      v
5. Application Reads Secrets
      |
      ├─> Connects to PostgreSQL with credentials
      |
      └─> Establishes mTLS connections with certs
```

### Backup Flow

```
Every 6 hours:

1. CronJob Triggers
      |
      v
2. pg_dump PostgreSQL Database
      |
      | gzip compression
      v
3. Upload to MinIO (S3-compatible)
      |
      v
4. MinIO stores backup
      |
      v
5. Cleanup old backups (>7 days)
```

## Monitoring Flow

```
Application Metrics:
  Backend (/metrics)     ──┐
  PostgreSQL (exporter)  ──┤
  ValKey (exporter)      ──┼──> Prometheus
  Kubernetes (API)       ──┘       |
                                   | Query
                                   v
                               Grafana
                                   |
                                   | GitHub OAuth
                                   v
                            Authorized Users
```

## High Availability Strategy

### Stateless Services (Can Scale Horizontally)
- **Frontend**: 2-3 replicas, round-robin load balancing
- **Backend**: 2-3 replicas, load balanced via ClusterIP Service
- **OAuth2 Proxy**: 2 replicas for Grafana auth

### Stateful Services (Single Instance + Backups)
- **PostgreSQL**: 1 replica, automated backups every 6h
- **Vault**: 1 replica, auto-unseal with Transit
- **ValKey**: 1 replica, ephemeral (sessions lost on restart acceptable)
- **MinIO**: 1 replica, local storage

### Future Scaling Options
- PostgreSQL: Add read replicas or use Patroni for HA
- ValKey: Redis Sentinel for automatic failover
- MinIO: Distributed mode across multiple nodes
- Vault: 3-5 node Raft cluster for true HA

## Security Layers

```
Layer 1: External
  └─> Let's Encrypt TLS (HTTPS)

Layer 2: Authentication
  └─> GitHub OAuth (Grafana)
  └─> AppRole (Vault)

Layer 3: Network
  └─> Kubernetes NetworkPolicies
  └─> Service mesh (optional future)

Layer 4: Transport (Production)
  └─> mTLS between services
  └─> Vault PKI for certificate management

Layer 5: Application
  └─> Secrets from Vault (never in code/config)
  └─> Read-only filesystems
  └─> Non-root containers

Layer 6: Container
  └─> Chainguard minimal images
  └─> No shell in production containers
  └─> Regular vulnerability scanning
```

## Resource Allocation

```
Service              CPU Request  CPU Limit  RAM Request  RAM Limit
─────────────────────────────────────────────────────────────────────
Vault Bootstrap      250m        500m       512Mi        1Gi
Vault Primary        500m        1000m      2Gi          4Gi
PostgreSQL           1000m       2000m      4Gi          8Gi
ValKey               500m        1000m      1Gi          2Gi
Backend (per pod)    500m        1000m      1Gi          2Gi
  x3 replicas        1500m       3000m      3Gi          6Gi
Frontend (per pod)   250m        500m       256Mi        512Mi
  x3 replicas        750m        1500m      768Mi        1.5Gi
MinIO                500m        1000m      1Gi          2Gi
Prometheus           500m        1000m      2Gi          4Gi
Grafana              250m        500m       512Mi        1Gi
OAuth2 Proxy (x2)    200m        400m       256Mi        512Mi
─────────────────────────────────────────────────────────────────────
TOTAL                ~10.5 cores ~20 cores  ~26GB        ~52GB

Available on VPS:    12 cores               64GB
Reserved for future: 1.5+ cores             38GB+ (for scaling/new services)
```

## Certificate Management

```
┌────────────────────────────────────────────┐
│           cert-manager                      │
│                                             │
│  ClusterIssuer: letsencrypt-prod           │
│  ClusterIssuer: letsencrypt-staging        │
└─────────────┬──────────────────────────────┘
              |
              | HTTP-01 Challenge
              v
      Let's Encrypt ACME Server
              |
              | Issues certificates
              v
      ┌───────────────────────┐
      │  Kubernetes Secrets   │
      │  - homepage-tls       │
      │  - grafana-tls        │
      └───────────────────────┘
              |
              | Mount as volumes
              v
      ┌───────────────────────┐
      │   Ingress Resources   │
      │   (Traefik uses TLS)  │
      └───────────────────────┘

Internal mTLS (Vault PKI):
      ┌───────────────────────┐
      │   Vault PKI Engine    │
      │                       │
      │   Root CA (10y)       │
      │   ├─> Intermediate CA │
      │       └─> Backend     │
      │       └─> PostgreSQL  │
      └───────────────────────┘
              |
              | Vault Agent Template
              v
      /vault/secrets/tls.crt
      /vault/secrets/tls.key
              |
              | Certificate watcher
              v
      Graceful reload (no downtime)
```

## Development vs Production

```
┌─────────────────────────────────────────────────────────┐
│                    Development                           │
├─────────────────────────────────────────────────────────┤
│  Environment:    docker-compose                         │
│  Hot Reload:     ✅ Enabled (cargo-watch + Vite HMR)    │
│  Vault:          Dev mode (in-memory, root token)       │
│  TLS:            ❌ Disabled (HTTP only)                │
│  Domain:         localhost                              │
│  Secrets:        .env file                              │
│  Monitoring:     Optional (can run locally)             │
│  Replicas:       1 of each service                      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                    Production                            │
├─────────────────────────────────────────────────────────┤
│  Environment:    Kubernetes (K3s)                       │
│  Hot Reload:     ❌ Disabled (optimized builds)         │
│  Vault:          Production mode (Raft, auto-unseal)   │
│  TLS:            ✅ Let's Encrypt + mTLS                │
│  Domain:         vikingthe.dev                          │
│  Secrets:        Vault                                  │
│  Monitoring:     ✅ Prometheus + Grafana                │
│  Replicas:       2-3 of stateless services              │
└─────────────────────────────────────────────────────────┘
```

## Deployment Environments

```
╔═══════════════════════════════════════════════════════╗
║  Main Branch (Development Work)                       ║
╚═══════════════════════════════════════════════════════╝
         │
         │ Feature development
         │
         ▼
╔═══════════════════════════════════════════════════════╗
║  Dev Branch                                           ║
║  ├─> GitHub Actions (build, test, scan)              ║
║  ├─> Push: ghcr.io/vikingthedev/homepage-*:dev       ║
║  └─> ArgoCD deploys to: dev.vikingthe.dev            ║
╚═══════════════════════════════════════════════════════╝
         │
         │ Testing & QA
         │
         ▼
╔═══════════════════════════════════════════════════════╗
║  Prod Branch                                          ║
║  ├─> GitHub Actions (build, test, scan, strict)      ║
║  ├─> Push: ghcr.io/vikingthedev/homepage-*:prod      ║
║  └─> ArgoCD deploys to: vikingthe.dev                ║
╚═══════════════════════════════════════════════════════╝
```

This architecture provides:
✅ High availability for stateless services
✅ Data persistence with automated backups
✅ Secure secrets management
✅ End-to-end encryption (TLS + mTLS)
✅ Comprehensive monitoring and alerting
✅ GitOps deployment workflow
✅ Easy local development experience
✅ Production-ready security posture
