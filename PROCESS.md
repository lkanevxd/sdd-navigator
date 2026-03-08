# PROCESS.md — AI-Assisted Development Log

## 1. Tools Used

| Tool                    | Version / Model | Purpose                                                                          |
| ----------------------- | --------------- | -------------------------------------------------------------------------------- |
| **VS Code**             | Latest          | IDE, file editing, terminal                                                      |
| **GitHub Copilot Chat** | Claude Opus 4.6 | Primary AI assistant — architecture design, code generation, debugging, analysis |
| **Helm**                | v3.16.0 (CI)    | Chart linting and template rendering                                             |
| **kubeconform**         | v0.6.7          | Kubernetes manifest validation (replaces deprecated kubeval)                     |
| **ansible-lint**        | latest          | Ansible playbook linting (production profile)                                    |
| **yamllint**            | latest          | YAML syntax and style checking                                                   |
| **GitHub Actions**      | ubuntu-latest   | CI/CD pipeline execution                                                         |
| **Git**                 | CLI             | Version control, branching, commit structuring                                   |

The AI assistant was used via VS Code's Copilot Chat panel in agent mode. All code generation, debugging, and architectural decisions were discussed in this interface. The developer drove the conversation by providing the task specification, reviewing all outputs, and making corrections.

## 2. Conversation Log

### Session 1 — Initial Implementation (~2026-03-07 22:56 → 2026-03-08 05:15 MSK)

**Topic:** Full project scaffolding from task spec to working CI.

| Phase               | Developer Asked                                                    | AI Produced                                                     | Accepted / Rejected                             |
| ------------------- | ------------------------------------------------------------------ | --------------------------------------------------------------- | ----------------------------------------------- |
| Spec parsing        | Read & understand the task YAML                                    | Summarized deliverables: Helm charts, Ansible, CI, traceability | ✅ Accepted                                      |
| Requirements        | Generate `requirements.yaml` with SDD IDs                          | 13 requirement IDs (SCI-HELM-001 through SCI-SEC-001)           | ✅ Accepted                                      |
| Umbrella chart      | Helm umbrella with `_helpers.tpl`, ingress, Bitnami PostgreSQL dep | Chart.yaml, values.yaml, _helpers.tpl, ingress.yaml             | ✅ Accepted after review                         |
| API subchart        | Deployment, Service, ConfigMap, Secret for Rust API                | 4 template files with @req annotations                          | ✅ Accepted, needed fixes later                  |
| Frontend subchart   | nginx deployment and service                                       | 2 template files                                                | ✅ Accepted                                      |
| Ansible             | Playbook + deploy/validate roles                                   | playbook.yml, roles/deploy, roles/validate, group_vars          | ✅ Accepted                                      |
| CI pipeline         | GitHub Actions with 6 jobs                                         | infra-ci.yml                                                    | ✅ Accepted, iterated multiple times             |
| Traceability script | `check-traceability.sh` scanning @req annotations                  | Working scanner with annotation + orphan checks                 | ✅ Accepted, extended later                      |
| yamllint config     | `.yamllint.yml` with Helm template exclusions                      | Config with relaxed profile                                     | ✅ Accepted (was deleted by accident, recreated) |

### Session 2 — Audit, Fixes, and CI Stabilization (~2026-03-08 05:15 → 06:30 MSK)

**Topic:** Full re-audit against spec, fixing 7 issues, commit structuring, CI debugging.

| Phase                   | Developer Asked                                             | AI Produced                                                                   | Accepted / Rejected                                            |
| ----------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Re-audit                | Re-read spec, verify all files match                        | Found 7 issues                                                                | ✅ All reported issues confirmed                                |
| Commit plan             | Step-by-step plan + commit breakdown                        | 7 logical commits outlined                                                    | ✅ Accepted, developer executed commits                         |
| ingress.yaml            | Check ingress issues                                        | Found deprecated annotation + /api vs /api/                                   | ✅ Accepted                                                     |
| README completeness     | Does README match spec?                                     | Confirmed all sections present, CI links TODO                                 | ✅ Accepted                                                     |
| Install instructions    | Add brew/pip install to README                              | Added to "Run all CI checks locally" section                                  | ✅ Accepted                                                     |
| .yamllint.yml deleted   | Recreate deleted config                                     | Recreated from memory                                                         | ✅ Accepted                                                     |
| demo/violation branch   | Script created quite bad result, how to rollback            | Advised deleting remote + local branch                                        | ✅ Accepted                                                     |
| Only traceability fails | Isn't it wrong that only 1 check fails on violation branch? | Explained linters only catch syntax, not spec compliance                      | ✅ Led to extending script                                      |
| Extend traceability     | Add SCI-HELM-001/005/006 checks to existing script          | Generated 3 spec checks                                                       | ⚠️ Developer undid first attempt, asked to redo with edge cases |
| Edge-case analysis      | Analyze edge cases in the checks                            | Produced 19-case analysis table                                               | ✅ Accepted, applied "worth fixing" set                         |
| Final spec checks       | Apply fixes with edge-case hardening                        | Updated script with comment filtering, case-insensitive regex, umbrella scope | ✅ Accepted after review                                        |

## 3. Timeline

| Time (MSK)             | Commit    | Action                                                                | Duration                            |
| ---------------------- | --------- | --------------------------------------------------------------------- | ----------------------------------- |
| 2026-03-07 22:56       | `3548b23` | Initial commit (LICENSE via GitHub)                                   | —                                   |
| 2026-03-08 04:52       | `65980db` | `spec:` — requirements.yaml, .gitignore, .yamllint.yml                | ~6h (reading spec, planning)        |
| 2026-03-08 04:54       | `4437d2b` | `feat(helm):` — umbrella chart, _helpers.tpl, ingress                 | ~2 min                              |
| 2026-03-08 04:54       | `767a93f` | `feat(helm):` — API subchart (deployment, service, configmap, secret) | <1 min                              |
| 2026-03-08 04:57       | `35ddbad` | `feat(helm):` — frontend subchart                                     | ~3 min                              |
| 2026-03-08 04:58       | `530f6f8` | `feat(ansible):` — deploy + validate roles                            | ~1 min                              |
| 2026-03-08 05:01       | `980cd35` | `feat(ci):` — GitHub Actions pipeline + traceability script           | ~3 min                              |
| 2026-03-08 05:14       | `c8d06bd` | `fix(yamllint):` — recreate deleted .yamllint.yml                     | ~13 min (audit + fixes)             |
| 2026-03-08 05:15–06:10 | —         | Re-audit, 7 fixes, push, CI debugging, formatter fixes                | ~55 min                             |
| 2026-03-08 06:11       | `389ad47` | `feat(trace):` — spec compliance checks + edge-case hardening         | ~20 min (analysis + implementation) |
| 2026-03-08 06:14       | `e696c8f` | `demo:` — violation branch created with 5 violations                  | ~3 min                              |
| 2026-03-08 06:25       | `c85f055` | `docs:` — CI run links added to README                                | ~11 min                             |

**Total active development time:** ~2.5–3 hours (excluding initial spec reading time overnight gap).

## 4. Key Decisions

### Architecture

| Decision                 | Chosen Approach                                                                       | Alternatives Considered              | Rationale                                                                                                                                                           |
| ------------------------ | ------------------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PostgreSQL deployment    | Bitnami subchart (OCI)                                                                | Custom StatefulSet                   | Bitnami provides battle-tested PVC management, security contexts, readiness probes. Less code to maintain. Satisfies SCI-HELM-002 with minimal custom infra.        |
| Chart structure          | Umbrella chart with api/frontend subcharts                                            | Single chart with all templates      | Separation of concerns. Each component independently versioned. Subcharts can be reused.                                                                            |
| Manifest validation      | kubeconform                                                                           | kubeval                              | kubeval is deprecated. kubeconform is actively maintained, supports `--strict` for unknown fields, and supports current K8s schemas.                                |
| Credential handling      | `CHANGE_ME_*` placeholders in values.yaml                                             | Empty defaults / existingSecret only | Placeholder values fail visibly at deploy time. Production credentials passed via `--extra-vars` or Ansible Vault. Satisfies SCI-HELM-005: no real secrets in repo. |
| Traceability enforcement | Single script (`check-traceability.sh`) with both annotation scan and spec compliance | Separate scripts per check type      | Developer explicitly rejected creating additional files. Single script keeps the deliverable minimal (parsimony).                                                   |
| CI trigger scope         | All branches (`branches: ["*"]`)                                                      | Main only                            | Needed to run CI on `demo/violation` branch to demonstrate failure output.                                                                                          |
| Security baseline        | `runAsNonRoot`, explicit UIDs, no `latest` tags                                       | PodSecurityPolicy / OPA              | PSP is deprecated. Inline securityContext is the simplest approach that satisfies SCI-SEC-001 without extra tooling.                                                |

### Implementation

| Decision                                      | Choice                            | Reasoning                                                             |
| --------------------------------------------- | --------------------------------- | --------------------------------------------------------------------- |
| Ingress path `/api/` (trailing slash)         | Prefix match with slash           | Prevents `/api-docs` from matching the API backend route              |
| Ingress className vs annotation               | `spec.ingressClassName` field     | `kubernetes.io/ingress.class` annotation is deprecated since K8s 1.22 |
| SCI-HELM-006 regex: case-insensitive          | `grep -Ei '[^a-z]port: [0-9]+'`   | Catches `containerPort:`, `targetPort:`, not just `port:`             |
| Comment filtering in liveness/password checks | `grep -v '^\s*#'` before checking | Prevents false positives on commented-out lines                       |

## 5. What the Developer Controlled

### Files Directly Reviewed

The developer reviewed every generated file before committing. Specific interventions:

| File                                          | What Developer Did                                                                                                                                 |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `charts/sdd-navigator/templates/ingress.yaml` | Undid AI's removal of deprecated annotation initially, then re-applied `/api/` path fix.                                                           |
| `.yamllint.yml`                               | Accidentally deleted; verified recreated content matched original                                                                                  |
| `scripts/check-traceability.sh`               | Undid first version of spec compliance checks. Requested edge-case analysis before accepting v2. Reviewed all 19 edge cases in the analysis table. |
| `README.md`                                   | Verified structure against spec requirements. Requested install instructions be added.                                                             |
| `.github/workflows/infra-ci.yml`              | Verified CI triggers work on all branches, not just main.                                                                                          |

### Verification Steps

1. **Helm lint** — ran `helm lint --strict` locally before every commit
2. **Helm template** — rendered templates to verify no syntax errors
3. **Local script execution** — ran `check-traceability.sh` before committing each version
4. **CI observation** — watched GitHub Actions runs on both `main` (green) and `demo/violation` (red)
5. **Violation count** — verified all 5/5 violations produce explicit FAIL output with IDs

### Git Workflow

Developer structured commits into logical units (spec → umbrella → API → frontend → ansible → CI → fixes) rather than accepting a single monolithic commit. This was a deliberate organizational choice.

## 6. Course Corrections

### 1. Formatter Breaking Helm Templates
- **Issue:** VS Code's Prettier formatter auto-formatted `{{ .Values.port }}` to `{ { .Values.port } }` (added spaces) and reformatted YAML objects to multi-line in `service.yaml`
- **How caught:** `helm lint --strict` failed; developer spotted broken syntax
- **Resolution:** Manually restored correct Helm template format. Recognized this as recurring risk with IDE formatters on `.yaml` files containing Go templates.

### 2. Empty `DATABASE_HOST` in ConfigMap
- **Issue:** API ConfigMap rendered with empty DATABASE_HOST because database config was at wrong YAML nesting level in umbrella values.yaml
- **How caught:** `helm template` output review
- **Resolution:** Moved database config under `api:` key in umbrella values.yaml

### 3. PostgreSQL Using `auth.password` Instead of `existingSecret`
- **Issue:** Initial Bitnami config used plaintext password in values, violating SCI-HELM-005
- **How caught:** Developer's spec audit
- **Resolution:** Switched to `auth.existingSecret: sdd-navigator-db-credentials`

### 4. Traceability Script Not Scanning `.github/`
- **Issue:** `find` command only searched `charts/` and `ansible/`, missing CI workflow files
- **How caught:** Script showed 0 annotations for CI files during test run
- **Resolution:** Added `${REPO_ROOT}/.github` to find paths

### 5. Traceability Regex Missing Comma-Separated IDs
- **Issue:** `# @req SCI-CI-001, SCI-CI-002` only captured first ID
- **How caught:** Summary showed fewer unique IDs than expected
- **Resolution:** Changed extraction to `grep -oE 'SCI-[A-Z]+-[0-9]+'` which captures all matches per line

### 6. Demo/Violation Branch — Only Traceability Failed
- **Issue:** On `demo/violation`, only 2 out of 5 violations were detected (unannotated file + orphan ref). Hardcoded port, missing liveness probe, and plaintext password passed silently.
- **How caught:** Developer reviewed CI output and asked "isn't it wrong that only traceability check fails?"
- **Resolution:** Extended `check-traceability.sh` with 3 additional spec compliance checks (SCI-HELM-001, 005, 006). Developer initially rejected creation of a new script file, insisting checks be added to existing file (parsimony).

### 7. First Version of Spec Checks — Insufficient Edge-Case Coverage
- **Issue:** AI generated straightforward grep checks that could false-positive on commented lines and missed `containerPort:`/`targetPort:` patterns
- **How caught:** Developer asked "let's think through all edge cases" before committing
- **Resolution:** AI produced 19-case analysis. Developer reviewed and approved fixes: comment filtering, case-insensitive port regex, umbrella template scan scope.

## 7. Self-Assessment

### SDD Pillars Coverage

| Pillar                        | Coverage   | Assessment                                                                                                                                                                                                                                               |
| ----------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Traceability**              | ✅ Strong   | Every infra file has `@req` annotations. `check-traceability.sh` enforces on CI. 13/13 requirement IDs referenced. Orphan detection works.                                                                                                               |
| **DRY**                       | ✅ Strong   | All configurable values in `values.yaml`. Shared labels in `_helpers.tpl`. Named port references avoid repetition. No hardcoded values in templates.                                                                                                     |
| **Deterministic Enforcement** | ✅ Strong   | CI runs 6 parallel jobs on every push. Traceability + 3 spec compliance checks = 5 automated gates. `demo/violation` proves all 5 failure modes produce clear diagnostics.                                                                               |
| **Parsimony**                 | ⚠️ Adequate | Minimal file count. Bitnami subchart avoids reinventing PostgreSQL. Single traceability script covers all checks. However: `.tgz` archives for unpacked subcharts are redundant (Helm keeps both); some values.yaml entries could be further simplified. |

### What Needs Improvement

1. **Spec compliance checks are grep-based** — they verify presence/absence of patterns, not semantic correctness. A templated `livenessProbe:` with wrong path would pass. OPA/Kyverno policies would be more robust for production.
2. **No Ansible Vault integration demonstrated** — credentials section describes the pattern but no vault file exists. A `vault.yml.example` would strengthen the security story.
3. **No integration test** — CI validates syntax and structure, but doesn't deploy to a real cluster (e.g., kind/k3d). Ansible playbook is linted but never executed.
4. **PostgreSQL .tgz coexists with unpacked subcharts** — `helm dependency build` creates the archive, but we also have `charts/api/` and `charts/frontend/` unpacked. The `.tgz` files for api and frontend are redundant.
