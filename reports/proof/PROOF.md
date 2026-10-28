# Proof of Verification

This document catalogs all deliverables and verifiable proof artifacts demonstrating that the narrative business brief has been translated into enforceable, declarative database invariants in PostgreSQL 16.

---

## Deliverables & Invariant Verification Matrix

| Proof Item | File Path | Status | Verification Command |
|---|---|---|---|
| **ER Diagram** | `docs/er_diagram.md` | **VERIFIED** | Inspect Mermaid rendering on GitHub |
| **Rule-to-Constraint Matrix** | `docs/rule_constraint_matrix.md` | **VERIFIED** | Cross-reference constraints against SQLSTATE codes |
| **Business Brief** | `docs/business_brief.md` | **VERIFIED** | Review domain analysis and lifecycle requirements |
| **Repeatable Migrations** | `migrations/*.sql`, `scripts/migrate.sh` | **VERIFIED** | `bash scripts/migrate.sh` (second run reports `[SKIPPED]`) |
| **Deterministic Seed Fixtures** | `seeds/001_seed.sql`, `scripts/seed.sh` | **VERIFIED** | `bash scripts/seed.sh` (verified in `reports/proof/seed_counts.txt`) |
| **Negative Test Suite** | `tests/10_negative.sql`, `tests/00_helpers.sql` | **VERIFIED** | `bash scripts/test.sh` (verified in `reports/proof/test_output.txt`) |
| **Mutation Test (BR1 Failure)** | `scripts/mutation_check.sh` | **VERIFIED** | `bash scripts/mutation_check.sh` (fails on dropped index, passes on restore) |
| **Schema Dump** | `docs/schema_dump.sql` | **VERIFIED** | `pg_dump -U postgres --schema-only internship_db > docs/schema_dump.sql` |
| **Environment Telemetry** | `reports/proof/environment.txt` | **VERIFIED** | Inspect versions (PostgreSQL 16.8, Git, Bash) |
| **CI Automation** | `.github/workflows/ci.yml` | **PASSED** (Run ID [40726832161](https://github.com/mohanasanthibattula-stack/internship-relational-model/actions/runs/40726832161)) | GitHub Actions CI workflow passed on `main` push (`gh run view 40726832161`) |

---

## Detailed Test Verification Summary

- **Total Test Cases**: 41 assertions executed (38 negative tests + 3 positive controls).
- **Test Results**: 41 PASS, 0 FAIL.
- **Rollback Guarantee**: All tests execute inside a transaction block (`BEGIN; ... ROLLBACK;`), preserving pristine fixture data.
- **Enforced SQLSTATE Codes**:
  - `23505` (`unique_violation`): BR1 partial active index, unique emails, unique department name, unique evaluation.
  - `23503` (`foreign_key_violation`): BR2 composite mentor-department FK, orphan records, BR5 composite status FK (`ON UPDATE RESTRICT`).
  - `23514` (`check_violation`): BR3 date/status matrix, BR3 lifecycle state transitions, BR4 task invariants, BR4 atomic completion open tasks guard, BR5 score bounds.
  - `23001` (`restrict_violation`): BR6 deletion prevention on all entities.

---

## Seed Fixture Verification

The representative fixtures strictly fulfill required counts:
- `departments`: 3
- `mentors`: 4
- `interns`: 5
- `internships`: 6 (Includes demonstrating re-enrollment after completion/termination)
- `tasks`: 7
- `evaluations`: 1
