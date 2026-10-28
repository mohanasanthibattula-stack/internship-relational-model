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

get_checksum() {
  local file="$1"
  if command -v sha256sum &> /dev/null; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum &> /dev/null; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  fi
}

echo "==> Running migrations on ${PGDATABASE} (${PGHOST}:${PGPORT})..."

# Ensure migration tracking table exists
psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 <<EOSQL
CREATE TABLE IF NOT EXISTS schema_migrations (
    filename VARCHAR(255) PRIMARY KEY,
    checksum VARCHAR(64) NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
EOSQL

MIGRATIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../migrations" && pwd)"

for file in $(find "${MIGRATIONS_DIR}" -maxdepth 1 -name "*.sql" | sort); do
  filename="$(basename "$file")"
  current_checksum="$(get_checksum "$file")"

  # Query recorded checksum if already applied
  recorded_checksum="$(psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -t -A \
    -c "SELECT checksum FROM schema_migrations WHERE filename = '${filename}';")"

  if [ -n "${recorded_checksum}" ]; then
    if [ "${recorded_checksum}" = "${current_checksum}" ]; then
      echo "    [SKIPPED] ${filename} (already applied, checksum matches)"
    else
      echo "==> ERROR: Checksum mismatch for migration ${filename}!"
      echo "    Recorded: ${recorded_checksum}"
      echo "    Current:  ${current_checksum}"
      echo "    Applied migration files must not be altered."
      exit 1
    fi
  else
    echo "==> [APPLYING] ${filename}..."
    psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 \
      -c "BEGIN;" \
      -f "${file}" \
      -c "INSERT INTO schema_migrations (filename, checksum) VALUES ('${filename}', '${current_checksum}');" \
      -c "COMMIT;"
    echo "    [SUCCESS]  ${filename} applied successfully."
  fi
done

echo "==> All migrations up to date."
