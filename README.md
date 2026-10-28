# RabTech Internship Management Relational Model

[![CI](https://github.com/mohanasanthibattula-stack/internship-relational-model/actions/workflows/ci.yml/badge.svg)](https://github.com/mohanasanthibattula-stack/internship-relational-model/actions/workflows/ci.yml)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791.svg)](https://www.postgresql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-grade, declarative PostgreSQL 16 schema translating narrative business rules into verifiable, tamper-proof relational invariants before writing application-layer code.

---

## Architecture Overview

```
                                      +--------------------+
                                      |    departments     |
                                      +--------------------+
                                       /|                |\
                     (department_id)  / |                | \  (department_id)
                                     /  |                |  \
                                    /   |                |   \
                     +-------------+    |                |    +------------------+
                     |   mentors   |<---+                |    |   internships    |
                     +-------------+    |                |    +------------------+
                                        | (mentor_id,    |     /|   ||   ||   |\
                                        |  department_id)|    / |   ||   ||   | \
                                        +----------------+   /  |   ||   ||   |  \
                                                            /   |   ||   ||   |   \
                  +----------------------------------------+    |   ||   ||   |    +---------------+
                  |                                             |   ||   ||   |    |  evaluations  |
          +---------------+                                     |   ||   ||   |    +---------------+
          |    interns    |-------------------------------------+   ||   ||   |    (status='COMPLETED')
          +---------------+ (UQ on intern_id WHERE status='ACTIVE') ||   ||   |
                                                                    ||   ||   |
                                                                    ||   ||   +--------------------+
                                                                    ||   ||   |       tasks        |
                                                                    ||   ||   +--------------------+
                                                                    ||   ||   (ACTIVE internships only)
```

---

## Business Rules & Database Invariants

| Rule | Business Constraint | Relational Implementation | Error Code (SQLSTATE) |
|---|---|---|---|
| **BR1** | **One ACTIVE internship per intern** | Partial Unique Index on `internships(intern_id) WHERE status = 'ACTIVE'` | `23505` (`unique_violation`) |
| **BR2** | **Mentor in same department** | Composite FK `(mentor_id, department_id)` referencing Composite Unique on `mentors` | `23503` (`foreign_key_violation`) |
| **BR3** | **State-bound dates & lifecycle** | Table `CHECK` on status/dates; BEFORE trigger enforcing forward-only transitions (`APPLIED`/`ACTIVE` creation only) | `23514` (`check_violation`) |
| **BR4** | **Task invariants & atomic completion** | Trigger restricting tasks to `ACTIVE` internships; immutable task parent; atomic stored procedure `complete_internship()` blocking on open tasks | `23514` (`check_violation`)<br>`23503` (orphan task) |
| **BR5** | **Evaluations for COMPLETED only** | Composite FK `(internship_id, internship_status)` referencing `(internship_id, status)` with `ON UPDATE RESTRICT`; fixed column `CHECK`; score 1-5 | `23503` (`foreign_key_violation`)<br>`23505` (`unique_violation`)<br>`23514` (`check_violation`) |
| **BR6** | **Retention (no hard deletes)** | BEFORE DELETE triggers on all core entities raising `restrict_violation`; FKs configured with `ON DELETE RESTRICT` | `23001` (`restrict_violation`) |

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── ci.yml               # GitHub Actions CI workflow (PostgreSQL 16)
├── docs/
│   ├── business_brief.md        # Complete business requirements and lifecycle analysis
│   ├── er_diagram.md            # Mermaid ER diagram with PK/FK/UK annotations
│   ├── rule_constraint_matrix.md# Detailed mapping from business rules to database objects
│   └── schema_dump.sql          # Clean schema-only SQL dump
├── migrations/
│   ├── 001_people.sql           # Departments, mentors, and interns
│   ├── 002_internships.sql      # Internships, composite keys, and BR1 partial unique index
│   ├── 003_tasks_evaluations.sql# Tasks, evaluations, and declarative status binding
│   └── 004_guards.sql           # Triggers, state transitions, complete_internship, retention
├── reference/
│   └── commerce-seed-data.sql   # RabTech SQL internship starter database
├── reports/
│   └── proof/
│       ├── environment.txt      # Execution environment details
│       ├── PROOF.md             # Verification artifact log and reproduction commands
│       ├── seed_counts.txt      # Verified fixture row counts
│       └── test_output.txt      # Verbatim negative & positive test execution log
├── scripts/
│   ├── migrate.sh               # Migration runner with sha256 checksum tracking & idempotence
│   ├── reset.sh                 # Database teardown and recreation script
│   ├── seed.sh                  # Representative seed fixture runner
│   └── test.sh                  # End-to-end automation test suite
├── seeds/
│   └── 001_seed.sql             # Representative fixture dataset (3 depts, 4 mentors, 5 interns, 6 internships, 7 tasks, 1 eval)
├── tests/
│   ├── 00_helpers.sql           # Assertions harness (expect_error, expect_success)
│   └── 10_negative.sql          # Negative test suite and positive controls
├── CITATION.cff                 # Citation metadata
├── docker-compose.yml           # PostgreSQL 16 container service definition
├── LICENSE                      # MIT License
├── Makefile                     # Make orchestration targets
└── README.md                    # Project documentation
```

---

## Quickstart & Local Reproduction

### Prerequisites
- PostgreSQL 16 (`psql`, `pg_dump`, `createdb`) OR Docker & Docker Compose.
- Bash shell (Git Bash on Windows, or standard Linux/macOS shell).

### Using Docker Compose
```bash
# Start PostgreSQL 16 service
make up

# Run full test suite (reset -> migrate -> seed -> re-migrate -> negative tests)
make test

# Tear down container
make down
```

### Using Local PostgreSQL Installation
```bash
export PGHOST=127.0.0.1
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=postgres
export PGDATABASE=internship_db

# Execute automated test suite
bash scripts/test.sh
```

---

## Verification & Proof

### Migration Idempotency
`scripts/migrate.sh` tracks SHA-256 checksums inside the `schema_migrations` table. Re-running migrations is guaranteed to be a no-op, and modifying any applied migration file triggers an error.

### Seed Fixtures
Seeding strictly follows entity dependency lifecycles:
- 3 Departments (`Engineering`, `Data Science`, `Product Management`)
- 4 Mentors (partitioned across departments)
- 5 Interns
- 6 Internships (`COMPLETED`, `TERMINATED`, `ACTIVE`, `APPLIED`, including demonstrating historical re-enrollment)
- 7 Tasks (`ASSIGNED`, `SUBMITTED`, `APPROVED`, `REJECTED`)
- 1 Evaluation (attached to the completed internship)

### Negative & Positive Test Assertions
All 40+ test scenarios are executed within a sandboxed transaction that rolls back, confirming:
- Invalid states and orphan relationships fail with exact standard SQLSTATEs (`23505`, `23503`, `23514`, `23001`).
- `complete_internship()` fails cleanly when open tasks exist and leaves database records untouched.
- Positive controls verify that legitimate state transitions and multi-internship histories function as designed.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
