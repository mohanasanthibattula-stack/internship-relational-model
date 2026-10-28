# Business Brief: Internship Management Relational Model

## Executive Summary
This document defines the structural specifications, entity lifecycles, cardinality constraints, and business rules governing the RabTech Internship Relational Model. The objective is to translate operational policies into enforceable, declarative database invariants within PostgreSQL 16 prior to the implementation of application-layer business logic.

---

## 1. Domain Entities & Attributes

The system models six primary entities:

1. **Departments (`departments`)**
   - Organizational unit hosting internships.
   - Attributes: `department_id` (PK), `department_name` (UNIQUE), `created_at`.
2. **Mentors (`mentors`)**
   - Senior staff members assigned to departments to supervise interns.
   - Attributes: `mentor_id` (PK), `department_id` (FK to departments), `mentor_name`, `email` (UNIQUE), `created_at`.
   - Structural Key: Composite `(mentor_id, department_id)` UNIQUE constraint to support department-scoped foreign keys.
3. **Interns (`interns`)**
   - Candidates registered within the company.
   - Attributes: `intern_id` (PK), `intern_name`, `email` (UNIQUE), `registered_on`, `created_at`.
4. **Internships (`internships`)**
   - Engagement contract linking an intern, a department, and a mentor.
   - States: `APPLIED`, `ACTIVE`, `COMPLETED`, `TERMINATED`.
   - Attributes: `internship_id` (PK), `intern_id` (FK to interns), `department_id` (FK to departments), `mentor_id`, `status`, `start_date`, `end_date`, `created_at`.
   - Structural Key: Composite `(internship_id, status)` UNIQUE constraint to support status-verified evaluation foreign keys.
5. **Tasks (`tasks`)**
   - Work units assigned to an intern during an active internship.
   - States: `ASSIGNED`, `SUBMITTED`, `APPROVED`, `REJECTED`.
   - Attributes: `task_id` (PK), `internship_id` (FK to internships), `title`, `status`, `assigned_on`, `due_on`, `submitted_on`, `created_at`.
6. **Evaluations (`evaluations`)**
   - Performance evaluation recorded once an internship successfully completes.
   - Attributes: `evaluation_id` (PK), `internship_id` (FK, UNIQUE), `internship_status` (Fixed to `'COMPLETED'`), `score` (1-5), `feedback`, `evaluated_on`, `created_at`.

---

## 2. Cardinalities & Relationships

| Relationship | Cardinality | Enforcing Mechanism |
|---|---|---|
| Department to Mentor | 1 : N (Zero or more mentors per department) | Foreign Key `mentors(department_id)` |
| Intern to Internship | 1 : N (Historical internships allowed, max 1 ACTIVE) | Partial Unique Index on `internships(intern_id) WHERE status = 'ACTIVE'` |
| Department to Internship | 1 : N | Foreign Key `internships(department_id)` |
| Mentor to Internship | 1 : N (Must match department) | Composite Foreign Key `(mentor_id, department_id)` |
| Internship to Tasks | 1 : N (Only during ACTIVE status) | Foreign Key + BEFORE INSERT/UPDATE Trigger |
| Internship to Evaluation | 1 : 0..1 (Exactly one, only if COMPLETED) | Composite FK `(internship_id, internship_status)` + UNIQUE(`internship_id`) |

---

## 3. Entity States and Lifecycles

### Internship Lifecycle
```
[APPLIED] ──(Start)──> [ACTIVE] ──(complete_internship)──> [COMPLETED] (Terminal)
   │                      │
   │                      └──(Terminate)─────────────────> [TERMINATED] (Terminal)
   └──(Direct Active at creation allowed)
```
- **Creation Allowed States**: `APPLIED` or `ACTIVE`. Direct insertion as `COMPLETED` or `TERMINATED` is prohibited.
- **Terminal States**: `COMPLETED` and `TERMINATED` cannot transition to any other status.
- **Rollback Prohibition**: `ACTIVE` cannot regress to `APPLIED`.
- **Reopening Prohibition**: An internship with an evaluation can never change status.

### Task Lifecycle
```
[ASSIGNED] ──(Submit)──> [SUBMITTED] ──(Review)──> [APPROVED] (Closed)
                                     └──(Review)──> [REJECTED] (Closed)
```
- Tasks may only be created or modified while the parent internship is in `ACTIVE` state.
- Once created, a task can never be reassigned to a different internship.
- Closed tasks (`APPROVED` or `REJECTED`) permit the parent internship to be completed; open tasks (`ASSIGNED` or `SUBMITTED`) block completion.

---

## 4. Five Non-Negotiable Business Rules & Retention

### BR1: One Active Internship per Intern
- **Rule**: An intern can register once and complete multiple internships over time, but may hold at most one active internship concurrently.
- **Implementation**: Partial Unique Index `uq_internships_active_per_intern` on `internships (intern_id) WHERE status = 'ACTIVE'`.
- **Violation Code**: SQLSTATE `23505` (`unique_violation`).

### BR2: Mentor Belongs to Internship's Department
- **Rule**: Every internship must be supervised by a mentor belonging to the exact department offering the internship. Cross-department mentoring is strictly invalid.
- **Implementation**: Composite Unique key `UNIQUE (mentor_id, department_id)` on `mentors`, paired with Composite Foreign Key `FOREIGN KEY (mentor_id, department_id) REFERENCES mentors(mentor_id, department_id)` on `internships`.
- **Violation Code**: SQLSTATE `23503` (`foreign_key_violation`).

### BR3: Temporal Consistency & State Advancement
- **Rule**: Dates must align strictly with the internship lifecycle state:
  - `APPLIED`: `start_date IS NULL` and `end_date IS NULL`.
  - `ACTIVE`: `start_date IS NOT NULL` and `end_date IS NULL`.
  - `COMPLETED` or `TERMINATED`: `start_date IS NOT NULL`, `end_date IS NOT NULL`, and `end_date >= start_date`.
  - Creation is restricted to `APPLIED` or `ACTIVE`. Terminal states cannot be altered. Status cannot regress.
- **Implementation**: Table-level `CHECK` constraint on date-status pairs, combined with BEFORE INSERT/UPDATE trigger `trg_internships_guard`.
- **Violation Code**: SQLSTATE `23514` (`check_violation`).

### BR4: Task Invariants & Atomic Completion
- **Rule**: Tasks can only be assigned to `ACTIVE` internships. A task cannot be moved across internships. `due_on >= assigned_on`. `submitted_on` is required for `SUBMITTED`, `APPROVED`, and `REJECTED` states, and prohibited for `ASSIGNED`. An internship cannot be completed while any task remains open (`ASSIGNED` or `SUBMITTED`).
- **Implementation**:
  - `CHECK (due_on >= assigned_on)`
  - `CHECK ((status = 'ASSIGNED' AND submitted_on IS NULL) OR (status IN ('SUBMITTED', 'APPROVED', 'REJECTED') AND submitted_on IS NOT NULL))`
  - BEFORE INSERT/UPDATE Trigger on `tasks` rejecting non-active parent internships and foreign key reassignment.
  - Stored function `complete_internship(p_internship_id, p_end_date)` executing atomically, raising an exception if open tasks exist, leaving rows untouched on failure.
- **Violation Code**: SQLSTATE `23514` (`check_violation`), SQLSTATE `23503` for orphan tasks.

### BR5: Strict Evaluation for Completed Internships
- **Rule**: Exactly one evaluation is recorded per internship, permitted only if the internship is in `COMPLETED` status. Score must be an integer between 1 and 5.
- **Implementation**:
  - `UNIQUE (internship_id)` on `evaluations`.
  - Column `internship_status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED' CHECK (internship_status = 'COMPLETED')`.
  - Composite Foreign Key `FOREIGN KEY (internship_id, internship_status) REFERENCES internships(internship_id, status) ON UPDATE RESTRICT ON DELETE RESTRICT`.
  - `CHECK (score BETWEEN 1 AND 5)`.
- **Violation Code**: SQLSTATE `23503` (attempting evaluation on non-completed internship or updating completed status), SQLSTATE `23505` (duplicate evaluation), SQLSTATE `23514` (invalid score).

### BR6: Strict Data Retention (No Hard Deletes)
- **Rule**: No intern, internship, task, evaluation, mentor, or department records may be hard-deleted from the database.
- **Implementation**: BEFORE DELETE triggers on all core entities raising SQLSTATE `23001` (`restrict_violation`), backed by `ON DELETE RESTRICT` foreign keys.
- **Violation Code**: SQLSTATE `23001` (`restrict_violation`).
