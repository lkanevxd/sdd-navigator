#!/usr/bin/env bash
# @req SCI-TRACE-001
# Traceability check: ensures every infra file has @req annotations
# and all referenced requirement IDs exist in requirements.yaml.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQUIREMENTS_FILE="${REPO_ROOT}/requirements.yaml"
EXIT_CODE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# --- Extract valid requirement IDs from requirements.yaml ---
if [[ ! -f "${REQUIREMENTS_FILE}" ]]; then
  echo -e "${RED}ERROR: requirements.yaml not found at ${REQUIREMENTS_FILE}${NC}"
  exit 1
fi

VALID_IDS=$(grep -E '^\s*-?\s*id:\s*' "${REQUIREMENTS_FILE}" | sed 's/.*id:[[:space:]]*//' | awk '{print $1}' | sort -u)
if [[ -z "${VALID_IDS}" ]]; then
  echo -e "${RED}ERROR: No requirement IDs found in requirements.yaml${NC}"
  exit 1
fi

echo "=== SDD Traceability Check ==="
echo ""
echo "Valid requirement IDs:"
echo "${VALID_IDS}" | sed 's/^/  /'
echo ""

# --- Collect infra files to scan ---
INFRA_FILES=()
while IFS= read -r -d '' file; do
  # Skip Chart.lock and dependency tarballs
  [[ "${file}" == *.tgz ]] && continue
  INFRA_FILES+=("${file}")
done < <(find "${REPO_ROOT}/charts" "${REPO_ROOT}/ansible" "${REPO_ROOT}/.github" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.tpl' \) -print0 2>/dev/null)

if [[ ${#INFRA_FILES[@]} -eq 0 ]]; then
  echo -e "${RED}ERROR: No infra files found to scan${NC}"
  exit 1
fi

echo "Files to scan: ${#INFRA_FILES[@]}"
echo ""

# --- Check each file for @req annotations ---
UNANNOTATED=()
ALL_REFS=()
ORPHANS=()

for file in "${INFRA_FILES[@]}"; do
  rel_path="${file#"${REPO_ROOT}/"}"

  # Extract all @req references from file (handles comma-separated IDs)
  has_req=$(grep -l '@req' "${file}" 2>/dev/null || true)
  refs=$(grep '@req' "${file}" 2>/dev/null | grep -oE 'SCI-[A-Z]+-[0-9]+' || true)

  if [[ -z "${has_req}" ]]; then
    UNANNOTATED+=("${rel_path}")
  else
    while IFS= read -r ref_id; do
      ALL_REFS+=("${ref_id}")
      if ! echo "${VALID_IDS}" | grep -qx "${ref_id}"; then
        ORPHANS+=("${rel_path}: @req ${ref_id}")
      fi
    done <<< "${refs}"
  fi
done

# --- Report results ---
echo "=== Results ==="
echo ""

if [[ ${#UNANNOTATED[@]} -gt 0 ]]; then
  echo -e "${RED}FAIL: Unannotated files (missing @req):${NC}"
  for f in "${UNANNOTATED[@]}"; do
    echo -e "  ${RED}✗${NC} ${f}"
  done
  echo ""
  EXIT_CODE=1
else
  echo -e "${GREEN}PASS: All files have @req annotations${NC}"
  echo ""
fi

if [[ ${#ORPHANS[@]} -gt 0 ]]; then
  echo -e "${RED}FAIL: Orphan annotations (reference non-existent requirements):${NC}"
  for o in "${ORPHANS[@]}"; do
    echo -e "  ${RED}✗${NC} ${o}"
  done
  echo ""
  EXIT_CODE=1
else
  echo -e "${GREEN}PASS: No orphan annotations${NC}"
  echo ""
fi

# --- SCI-HELM-001: API deployment MUST have livenessProbe ---
API_DEPLOY="${REPO_ROOT}/charts/sdd-navigator/charts/api/templates/deployment.yaml"
if [[ -f "${API_DEPLOY}" ]] && grep -v '^\s*#' "${API_DEPLOY}" | grep -q 'livenessProbe:'; then
  echo -e "${GREEN}PASS [SCI-HELM-001]${NC}: API deployment has livenessProbe"
else
  echo -e "${RED}FAIL [SCI-HELM-001]${NC}: API deployment is missing livenessProbe on /healthcheck"
  EXIT_CODE=1
fi
echo ""

# --- SCI-HELM-005: values.yaml MUST NOT contain plaintext credentials ---
VALUES="${REPO_ROOT}/charts/sdd-navigator/values.yaml"
BAD_PASSWORDS=$(grep -E '^\s+password:' "${VALUES}" | grep -v '^\s*#' | grep -v 'CHANGE_ME' || true)
if [[ -z "${BAD_PASSWORDS}" ]]; then
  echo -e "${GREEN}PASS [SCI-HELM-005]${NC}: All password defaults use CHANGE_ME placeholders"
else
  echo -e "${RED}FAIL [SCI-HELM-005]${NC}: Plaintext credentials in values.yaml defaults:"
  echo "${BAD_PASSWORDS}" | sed 's/^/    /'
  EXIT_CODE=1
fi
echo ""

# --- SCI-HELM-006: Template files MUST NOT hardcode port numbers ---
HARDCODED_FOUND=0
while IFS= read -r -d '' file; do
  rel="${file#"${REPO_ROOT}/"}"
  matches=$(grep -nEi '[^a-z]port: [0-9]+' "${file}" 2>/dev/null | grep -v '{{' || true)
  if [[ -n "${matches}" ]]; then
    echo -e "${RED}FAIL [SCI-HELM-006]${NC}: Hardcoded port in ${rel}:"
    echo "${matches}" | sed 's/^/    /'
    HARDCODED_FOUND=1
    EXIT_CODE=1
  fi
done < <(find "${REPO_ROOT}/charts/sdd-navigator/charts" "${REPO_ROOT}/charts/sdd-navigator/templates" \
  -path "*/templates/*.yaml" \
  -not -path "*/charts/postgresql*" \
  -print0 2>/dev/null)
if [[ ${HARDCODED_FOUND} -eq 0 ]]; then
  echo -e "${GREEN}PASS [SCI-HELM-006]${NC}: No hardcoded port numbers in template files"
fi
echo ""

# --- Summary ---
UNIQUE_REFS=$(printf '%s\n' "${ALL_REFS[@]}" | sort -u | wc -l | tr -d ' ')
TOTAL_VALID=$(echo "${VALID_IDS}" | wc -l | tr -d ' ')

echo "=== Summary ==="
echo "  Files scanned:        ${#INFRA_FILES[@]}"
echo "  Unannotated files:    ${#UNANNOTATED[@]}"
echo "  Orphan annotations:   ${#ORPHANS[@]}"
echo "  Unique IDs referenced: ${UNIQUE_REFS} / ${TOTAL_VALID}"
echo ""

if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo -e "${GREEN}All traceability checks passed.${NC}"
else
  echo -e "${RED}Traceability violations found. See above.${NC}"
fi

exit ${EXIT_CODE}
