# SDD Navigator — Kubernetes Deployment

Infrastructure for deploying the SDD Navigator stack: Rust API, Next.js frontend (nginx), and PostgreSQL on Kubernetes via Helm charts orchestrated by Ansible.

## Components

| Component  | Chart/Role                                    | Description                                                                                |
| ---------- | --------------------------------------------- | ------------------------------------------------------------------------------------------ |
| API        | `charts/sdd-navigator/charts/api/`            | Rust REST API (`sdd-coverage-api`) serving `/healthcheck`, `/stats`, `/requirements`, etc. |
| Frontend   | `charts/sdd-navigator/charts/frontend/`       | nginx serving pre-built Next.js static export                                              |
| PostgreSQL | Bitnami subchart dependency                   | Persistent database with PVC                                                               |
| Ingress    | `charts/sdd-navigator/templates/ingress.yaml` | Routes `/api/*` → API, `/` → Frontend                                                      |

## Project Structure

```tree
requirements.yaml                  # SDD specification
charts/sdd-navigator/              # Umbrella Helm chart
  Chart.yaml                       # Dependencies: api, frontend, postgresql
  values.yaml                      # All configurable values (DRY)
  templates/
    _helpers.tpl                   # Shared labels, selectors, names
    ingress.yaml                   # Ingress routing
  charts/
    api/                           # API subchart
      templates/deployment.yaml    # Deployment with probes
      templates/service.yaml       # ClusterIP service
      templates/configmap.yaml     # API_PORT, DATABASE_URL, LOG_LEVEL
      templates/secret.yaml        # Database credentials
    frontend/                      # Frontend subchart
      templates/deployment.yaml    # nginx deployment
      templates/service.yaml       # ClusterIP service
ansible/
  playbook.yml                     # Orchestration entry point
  roles/deploy/tasks/main.yml      # Ordered deployment
  roles/validate/tasks/main.yml    # Post-deploy health checks
  group_vars/all.yml               # Centralized variables
scripts/
  check-traceability.sh            # @req annotation scanner
.github/workflows/
  infra-ci.yml                     # CI pipeline (6 parallel jobs)
```

## Quick Start

### Render Helm templates locally

```bash
# Build dependencies (downloads Bitnami PostgreSQL chart)
helm dependency build charts/sdd-navigator/

# Render templates to stdout
helm template sdd-navigator charts/sdd-navigator/

# Lint with strict mode
helm lint charts/sdd-navigator/ --strict
```

### Run Ansible playbook

Requires a running Kubernetes cluster with kubeconfig configured.

```bash
cd ansible/

# Deploy (pass DB password via extra-vars or vault)
ansible-playbook playbook.yml \
  -i inventory/local.yml \
  --extra-vars "db_password=YOUR_SECRET postgres_password=YOUR_SECRET"

# Second run should produce zero changes (idempotency)
ansible-playbook playbook.yml \
  -i inventory/local.yml \
  --extra-vars "db_password=YOUR_SECRET postgres_password=YOUR_SECRET"
```

### Run traceability check

```bash
bash scripts/check-traceability.sh
```

### Run all CI checks locally

```bash
brew install helm kubeconform
pip install ansible-lint yamllint

helm lint charts/sdd-navigator/ --strict
helm template sdd-navigator charts/sdd-navigator/ | kubeconform --strict --summary
ansible-lint ansible/
yamllint -c .yamllint.yml .
bash scripts/check-traceability.sh
```

## Architecture Decisions

**PostgreSQL: Bitnami subchart** — chosen over a custom StatefulSet. Bitnami provides battle-tested defaults, built-in PVC management, security context, and readiness probes. Less code to maintain, satisfies SCI-HELM-002 with minimal infrastructure.

**Kubeconform over kubeval** — kubeval is deprecated. Kubeconform is actively maintained, supports `--strict` mode for unknown field detection, and validates against up-to-date Kubernetes schemas.

**Database credentials** — `values.yaml` defaults use `CHANGE_ME_*` placeholder values that fail visibly if not overridden at deploy time. Actual credentials are passed via `--extra-vars` or Ansible Vault. No plaintext secrets in committed files.

**Security** — API and frontend containers run as non-root users. All images specify explicit version tags (no `latest`). PostgreSQL uses restricted filesystem permissions.

## CI Runs

- `main` branch (passing): <https://github.com/lkanevxd/sdd-navigator/actions/runs/22812800687>
- `demo/violation` branch (failing): <https://github.com/lkanevxd/sdd-navigator/actions/runs/22812871476>

## Traceability

Every Helm template, Ansible task file, and CI workflow contains `# @req SCI-XXX-NNN` annotations linking artifacts to requirements in `requirements.yaml`. The `scripts/check-traceability.sh` script enforces this on every CI run.

## Requirements Coverage

| ID            | Title                      | Implementing Files                                   |
| ------------- | -------------------------- | ---------------------------------------------------- |
| SCI-HELM-001  | Helm chart for API service | `charts/sdd-navigator/charts/api/templates/*`        |
| SCI-HELM-002  | PostgreSQL deployment      | `charts/sdd-navigator/Chart.yaml` (Bitnami dep)      |
| SCI-HELM-003  | Frontend deployment        | `charts/sdd-navigator/charts/frontend/templates/*`   |
| SCI-HELM-004  | Ingress routing            | `charts/sdd-navigator/templates/ingress.yaml`        |
| SCI-HELM-005  | Secrets and ConfigMaps     | `charts/*/templates/configmap.yaml`, `secret.yaml`   |
| SCI-HELM-006  | DRY configuration          | `charts/*/values.yaml`, `_helpers.tpl`               |
| SCI-ANS-001   | Ansible orchestration      | `ansible/roles/deploy/tasks/main.yml`                |
| SCI-ANS-002   | Post-deploy validation     | `ansible/roles/validate/tasks/main.yml`              |
| SCI-ANS-003   | Idempotency                | `ansible/roles/deploy/tasks/main.yml`                |
| SCI-CI-001    | CI pipeline                | `.github/workflows/infra-ci.yml`                     |
| SCI-CI-002    | Manifest validation        | `.github/workflows/infra-ci.yml` (helm-validate job) |
| SCI-TRACE-001 | Traceability annotations   | `scripts/check-traceability.sh`                      |
| SCI-SEC-001   | Security baseline          | `charts/*/templates/deployment.yaml`                 |
