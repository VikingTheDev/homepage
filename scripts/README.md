# Scripts Documentation

This directory contains helper scripts for deploying and managing the homepage application.

## 📋 Available Scripts

### `make-executable.sh`
Makes all scripts executable on Linux/Unix systems.

**Usage:**
```bash
bash scripts/make-executable.sh
```

**When to use:** Run this immediately after cloning the repository on a Linux system.

---

### `setup-dev.sh`
Sets up the local development environment using Docker Compose.

**Usage:**
```bash
./scripts/setup-dev.sh
```

**What it does:**
- Checks for Docker and Docker Compose
- Installs pnpm if not present
- Creates `.env` file from template if needed
- Installs frontend dependencies
- Starts all services with Docker Compose
- Displays access information for all services

**Services started:**
- Frontend (http://localhost:5173)
- Backend API (http://localhost:8000)
- Vault (http://localhost:8200)
- PostgreSQL (localhost:5432)
- ValKey/Redis (localhost:6379)
- MinIO (http://localhost:9001)

---

### `deploy-k8s.sh`
Deploys the application to a Kubernetes cluster (K3s).

**Usage:**
```bash
# Deploy to production
./scripts/deploy-k8s.sh prod

# Deploy to development
./scripts/deploy-k8s.sh dev
```

**Prerequisites:**
- K3s installed and running
- kubectl configured
- cert-manager installed
- (Optional) ArgoCD installed

**What it does:**
1. Creates the appropriate namespace (`homepage` or `homepage-dev`)
2. Deploys resources using Kustomize from `k8s/overlays/{env}`
3. Applies cert-manager ClusterIssuers (if file exists)
4. Sets up ArgoCD applications (if ArgoCD is installed)
5. Displays next steps and access information

**After running:**
- Initialize Vault: `./scripts/vault-init.sh <namespace>`
- Check pod status: `kubectl get pods -n <namespace>`
- Monitor deployment: `kubectl get events -n <namespace>`

---

### `setup-vault-bootstrap.sh`
Configures the vault-bootstrap pod to enable transit auto-unseal for the main Vault instance.

**Usage:**
```bash
# For production
./scripts/setup-vault-bootstrap.sh homepage

# For development
./scripts/setup-vault-bootstrap.sh homepage-dev
```

**Prerequisites:**
- kubectl installed
- vault-bootstrap deployment running in the namespace

**What it does:**
1. Checks that vault-bootstrap pod exists and is ready
2. Enables the transit secrets engine
3. Creates the `autounseal` key in the transit engine
4. Verifies the configuration

**When to run:**
- **After** deploying Kubernetes manifests (`kubectl apply -k k8s/overlays/prod`)
- **Before** initializing the main Vault
- Only needs to be run once per environment

**After running:**
- Restart main Vault pod: `kubectl delete pod vault-0 -n <namespace>`
- Then initialize Vault: `./scripts/vault-init.sh <namespace>`

**How it works:**
- The main Vault uses transit auto-unseal, which means it encrypts its master key using the vault-bootstrap's transit engine
- This allows the main Vault to automatically unseal on restart without manual intervention
- The vault-bootstrap runs in dev mode and provides the transit service

---

### `vault-init.sh`
Initializes HashiCorp Vault and sets up secrets management.

**Usage:**
```bash
# For production (namespace: homepage, port: 8200)
./scripts/vault-init.sh

# For production (explicit)
./scripts/vault-init.sh homepage 8200

# For development (namespace: homepage-dev, port: 8201)
./scripts/vault-init.sh homepage-dev 8201
```

**Prerequisites:**
- Vault CLI installed
- kubectl installed
- jq installed
- netcat/nc installed
- Port-forward to Vault service running
- **vault-bootstrap configured** (run `setup-vault-bootstrap.sh` first)

**Port-forward setup:**
```bash
# For production
kubectl port-forward -n homepage svc/vault 8200:8200

# For development
kubectl port-forward -n homepage-dev svc/vault 8201:8200
```

**What it does:**
1. Checks prerequisites (vault CLI, kubectl, jq, nc)
2. Verifies port-forward is active
3. Waits for Vault to be ready
4. Initializes Vault (or prompts for root token if already initialized)
5. Unseals Vault with 3 of 5 keys
6. Enables KV secrets engine
7. Sets up PKI for mTLS certificates
   - Root CA
   - Intermediate CA
   - Roles for backend and postgres
8. Enables AppRole authentication
9. Creates backend policy and AppRole
10. Generates AppRole credentials
11. Optionally creates Kubernetes secret with credentials

**Output files:**
- `vault-keys.txt` - Contains unseal keys and root token (KEEP SECURE!)
- `pki_intermediate.csr` - Intermediate CA CSR (can be deleted after)
- `intermediate.cert.pem` - Signed intermediate cert (can be deleted after)

**Important:**
- **BACKUP `vault-keys.txt`** - You need these keys to unseal Vault if it restarts
- Store the file in a secure location (password manager, encrypted backup, etc.)
- If you lose these keys and Vault is sealed, you'll lose all secrets

**Interactive prompts:**
- Root token (if Vault already initialized)
- Whether to create Kubernetes secret automatically

---

## 🔒 Security Best Practices

1. **Never commit `vault-keys.txt`** to git
2. **Store unseal keys securely** - use a password manager or encrypted storage
3. **Rotate AppRole credentials** periodically
4. **Use separate Vault instances** for dev and prod
5. **Backup vault-keys.txt** to multiple secure locations

---

## 🚀 Quick Start Workflows

### Local Development
```bash
# 1. Make scripts executable
bash scripts/make-executable.sh

# 2. Set up development environment
./scripts/setup-dev.sh

# 3. Access services at localhost ports
# Frontend: http://localhost:5173
# Backend: http://localhost:8000
```

### Production Deployment
```bash
# 1. Make scripts executable
bash scripts/make-executable.sh

# 2. Deploy to K8s
./scripts/deploy-k8s.sh prod

# 3. In one terminal: Port-forward to Vault
kubectl port-forward -n homepage svc/vault 8200:8200

# 4. In another terminal: Initialize Vault
./scripts/vault-init.sh homepage

# 5. Wait for all pods to be ready
kubectl get pods -n homepage -w

# 6. Access your site
# https://vikingthe.dev
```

### Development on K8s
```bash
# 1. Deploy dev environment
./scripts/deploy-k8s.sh dev

# 2. Initialize Vault for dev
kubectl port-forward -n homepage-dev svc/vault 8201:8200
./scripts/vault-init.sh homepage-dev 8201

# 3. Access dev site
# https://dev.vikingthe.dev
```

---

## 🐛 Common Issues

### "Permission denied" when running scripts
```bash
chmod +x scripts/*.sh
```

### vault-init.sh stuck on "Waiting for Vault"
- Ensure port-forward is running
- Check Vault pod is healthy: `kubectl get pods -n homepage`
- Try restarting port-forward

### "nc: command not found"
```bash
sudo apt install -y netcat-openbsd
```

### "jq: command not found"
```bash
sudo apt install -y jq
```

### Lost vault-keys.txt
- If Vault is still unsealed, you can access it with the root token
- If Vault is sealed and keys are lost, you'll need to reinitialize (loses all secrets)
- **Prevention:** Always backup vault-keys.txt immediately after creation

---

## 📚 Additional Resources

- [Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [K3s Documentation](https://docs.k3s.io/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
