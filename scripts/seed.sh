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

PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-internship_db}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

SEEDS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../seeds" && pwd)"

echo "==> Seeding database ${PGDATABASE} (${PGHOST}:${PGPORT})..."

psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "${SEEDS_DIR}/001_seed.sql"

echo "==> Verifying seed record counts:"
psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -c "
SELECT 'departments'  AS entity, COUNT(*) AS count FROM departments
UNION ALL
SELECT 'mentors'      AS entity, COUNT(*) AS count FROM mentors
UNION ALL
SELECT 'interns'      AS entity, COUNT(*) AS count FROM interns
UNION ALL
SELECT 'internships'  AS entity, COUNT(*) AS count FROM internships
UNION ALL
SELECT 'tasks'        AS entity, COUNT(*) AS count FROM tasks
UNION ALL
SELECT 'evaluations'  AS entity, COUNT(*) AS count FROM evaluations;
"

echo "==> Seeding completed successfully."
