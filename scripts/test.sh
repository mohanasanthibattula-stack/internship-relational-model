#!/usr/bin/env bash
set -euo pipefail

# Ensure psql is accessible across environments
if ! command -v psql &> /dev/null; then
  if [ -d "/c/Users/mohan/.gemini/antigravity/scratch/pgsql/bin" ]; then
    export PATH="/c/Users/mohan/.gemini/antigravity/scratch/pgsql/bin:$PATH"
  elif [ -d "/c/Users/mohan/pgsql/bin" ]; then
    export PATH="/c/Users/mohan/pgsql/bin:$PATH"
  elif [ -d "/usr/lib/postgresql/16/bin" ]; then
    export PATH="/usr/lib/postgresql/16/bin:$PATH"
  fi
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-internship_db}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

echo "============================================================"
echo " STEP 1: Reset Database Schema"
echo "============================================================"
bash "${ROOT_DIR}/scripts/reset.sh"

echo "============================================================"
echo " STEP 2: Execute Database Migrations"
echo "============================================================"
bash "${ROOT_DIR}/scripts/migrate.sh"

echo "============================================================"
echo " STEP 3: Populate Seed Data"
echo "============================================================"
bash "${ROOT_DIR}/scripts/seed.sh"

echo "============================================================"
echo " STEP 4: Test Migration Repeatability (Idempotency Check)"
echo "============================================================"
bash "${ROOT_DIR}/scripts/migrate.sh"

echo "============================================================"
echo " STEP 5: Run Invariant & Negative Test Suite"
echo "============================================================"
cd "${ROOT_DIR}"
psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/tests/10_negative.sql"

echo "============================================================"
echo " ALL TESTS PASSED: Relational invariants strictly enforced!"
echo "============================================================"
