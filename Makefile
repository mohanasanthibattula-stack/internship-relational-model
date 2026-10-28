.PHONY: up down reset migrate seed test dump help

help:
	@echo "Available commands:"
	@echo "  make up       - Start PostgreSQL 16 container via Docker Compose"
	@echo "  make down     - Stop PostgreSQL 16 container"
	@echo "  make reset    - Drop and recreate database schema"
	@echo "  make migrate  - Execute migrations idempotently"
	@echo "  make seed     - Populate representative seed fixtures"
	@echo "  make test     - Run full test suite (reset -> migrate -> seed -> migrate -> test)"
	@echo "  make dump     - Dump current schema to docs/schema_dump.sql"

up:
	docker compose up -d

down:
	docker compose down

reset:
	bash scripts/reset.sh

migrate:
	bash scripts/migrate.sh

seed:
	bash scripts/seed.sh

test:
	bash scripts/test.sh

dump:
	pg_dump --schema-only $${PGDATABASE:-internship_db} > docs/schema_dump.sql
