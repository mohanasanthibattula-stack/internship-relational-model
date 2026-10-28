#!/usr/bin/env bash
set -euo pipefail

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
cd "${ROOT_DIR}"
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-internship_db}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

echo "============================================================"
echo " MUTATION TEST: Dropping BR1 partial unique index"
echo "============================================================"
psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -c "DROP INDEX uq_internships_active_per_intern;"

echo "============================================================"
echo " Expecting tests/10_negative.sql to FAIL..."
echo "============================================================"
set +e
psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/tests/10_negative.sql"
TEST_STATUS=$?
set -e

if [ $TEST_STATUS -eq 0 ]; then
  echo "FATAL: Negative test suite succeeded when BR1 index was absent!"
  exit 1
else
  echo "==> CONFIRMED: Negative test failed as expected with status code ${TEST_STATUS}."
fi

echo "============================================================"
echo " Restoring BR1 partial unique index..."
echo "============================================================"
psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -c "CREATE UNIQUE INDEX uq_internships_active_per_intern ON internships (intern_id) WHERE (status = 'ACTIVE');"

echo "============================================================"
echo " Verifying negative tests pass after index restoration..."
echo "============================================================"
psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/tests/10_negative.sql" > /dev/null
echo "==> MUTATION CHECK PASSED: BR1 index uniquely guards against multiple active internships."
