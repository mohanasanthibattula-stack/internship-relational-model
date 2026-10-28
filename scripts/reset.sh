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

echo "==> Resetting database: ${PGDATABASE} on ${PGHOST}:${PGPORT} as ${PGUSER}..."

# Connect to maintenance db 'postgres' to terminate connections and recreate target db
psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d postgres -v ON_ERROR_STOP=1 <<EOSQL
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${PGDATABASE}' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS ${PGDATABASE} WITH (FORCE);
CREATE DATABASE ${PGDATABASE};
EOSQL

echo "==> Database ${PGDATABASE} successfully recreated."
