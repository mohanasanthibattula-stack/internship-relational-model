-- Negative and Positive Control Test Suite
-- Wrapped entirely in a transaction that rolls back to preserve seed data

BEGIN;

\i tests/00_helpers.sql

-- ============================================================================
-- BR1: ONE ACTIVE INTERNSHIP PER INTERN (Partial Unique Index -> 23505)
-- ============================================================================

-- Intern 3 (Kabir) already has ACTIVE internship 4; attempting a second ACTIVE internship
CALL pg_temp.expect_error(
    'BR1: Second ACTIVE internship for same intern rejected',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date)
          VALUES (3, 1, 1, 'ACTIVE', '2026-03-01')$sql$,
    '23505'
);

-- ============================================================================
-- BR2: MENTOR MUST BELONG TO INTERNSHIP DEPARTMENT (Composite FK -> 23503)
-- ============================================================================

-- Mentor 3 belongs to Department 2 (Data Science); attempting to assign to Department 1 (Engineering)
CALL pg_temp.expect_error(
    'BR2: Wrong-department mentor rejected by composite FK',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date)
          VALUES (5, 1, 3, 'ACTIVE', '2026-04-01')$sql$,
    '23503'
);

-- Orphan mentor (non-existent mentor_id 999)
CALL pg_temp.expect_error(
    'BR2: Orphan mentor rejected by foreign key',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date)
          VALUES (5, 1, 999, 'ACTIVE', '2026-04-01')$sql$,
    '23503'
);

-- ============================================================================
-- BR3: DATES MATCH STATE & LIFECYCLE GUARDS (CHECK & Trigger -> 23514)
-- ============================================================================

-- ACTIVE without start_date
CALL pg_temp.expect_error(
    'BR3: ACTIVE status without start_date rejected',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date)
          VALUES (5, 1, 1, 'ACTIVE', NULL)$sql$,
    '23514'
);

-- APPLIED with end_date
CALL pg_temp.expect_error(
    'BR3: APPLIED status with end_date rejected',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date, end_date)
          VALUES (5, 1, 1, 'APPLIED', NULL, '2026-04-01')$sql$,
    '23514'
);

-- End date before start date
CALL pg_temp.expect_error(
    'BR3: End date prior to start date rejected',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date, end_date)
          VALUES (5, 1, 1, 'TERMINATED', '2026-04-10', '2026-04-01')$sql$,
    '23514'
);

-- Unknown status value
CALL pg_temp.expect_error(
    'BR3: Unknown status rejected by domain CHECK constraint',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date)
          VALUES (5, 1, 1, 'INVALID_STATUS', '2026-04-01')$sql$,
    '23514'
);

-- Direct insert as COMPLETED rejected by lifecycle trigger
CALL pg_temp.expect_error(
    'BR3: Direct insert as COMPLETED rejected',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date, end_date)
          VALUES (5, 1, 1, 'COMPLETED', '2026-01-01', '2026-03-01')$sql$,
    '23514'
);

-- Direct insert as TERMINATED rejected by lifecycle trigger
CALL pg_temp.expect_error(
    'BR3: Direct insert as TERMINATED rejected',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date, end_date)
          VALUES (5, 1, 1, 'TERMINATED', '2026-01-01', '2026-03-01')$sql$,
    '23514'
);

-- Illegal state transition: TERMINATED -> ACTIVE
CALL pg_temp.expect_error(
    'BR3: Modifying terminal state TERMINATED to ACTIVE rejected',
    $sql$UPDATE internships SET status = 'ACTIVE', end_date = NULL WHERE internship_id = 2$sql$,
    '23514'
);

-- Illegal state transition: ACTIVE -> APPLIED
CALL pg_temp.expect_error(
    'BR3: Regression from ACTIVE to APPLIED rejected',
    $sql$UPDATE internships SET status = 'APPLIED', start_date = NULL WHERE internship_id = 3$sql$,
    '23514'
);

-- ============================================================================
-- BR4: TASK INVARIANTS & ATOMIC COMPLETION (CHECK, Trigger, Procedure)
-- ============================================================================

-- Orphan task (non-existent internship_id 999 -> 23503)
CALL pg_temp.expect_error(
    'BR4: Orphan task rejected by foreign key',
    $sql$INSERT INTO tasks (internship_id, title, status, assigned_on, due_on)
          VALUES (999, 'Orphan Task', 'ASSIGNED', '2026-04-01', '2026-04-10')$sql$,
    '23503'
);

-- Task assignment to COMPLETED internship 1 rejected
CALL pg_temp.expect_error(
    'BR4: Task on COMPLETED internship rejected',
    $sql$INSERT INTO tasks (internship_id, title, status, assigned_on, due_on)
          VALUES (1, 'New Task for Completed', 'ASSIGNED', '2026-04-01', '2026-04-10')$sql$,
    '23514'
);

-- Task assignment to TERMINATED internship 2 rejected
CALL pg_temp.expect_error(
    'BR4: Task on TERMINATED internship rejected',
    $sql$INSERT INTO tasks (internship_id, title, status, assigned_on, due_on)
          VALUES (2, 'New Task for Terminated', 'ASSIGNED', '2026-04-01', '2026-04-10')$sql$,
    '23514'
);

-- Task assignment to APPLIED internship 6 rejected
CALL pg_temp.expect_error(
    'BR4: Task on APPLIED internship rejected',
    $sql$INSERT INTO tasks (internship_id, title, status, assigned_on, due_on)
          VALUES (6, 'New Task for Applied', 'ASSIGNED', '2026-04-01', '2026-04-10')$sql$,
    '23514'
);

-- Reassigning task to another internship rejected
CALL pg_temp.expect_error(
    'BR4: Moving task to another internship rejected',
    $sql$UPDATE tasks SET internship_id = 4 WHERE task_id = 3$sql$,
    '23514'
);

-- Bad task dates: due_on < assigned_on
CALL pg_temp.expect_error(
    'BR4: Task due_on prior to assigned_on rejected',
    $sql$INSERT INTO tasks (internship_id, title, status, assigned_on, due_on)
          VALUES (3, 'Invalid Dates Task', 'ASSIGNED', '2026-04-10', '2026-04-01')$sql$,
    '23514'
);

-- Unknown task status
CALL pg_temp.expect_error(
    'BR4: Unknown task status rejected',
    $sql$INSERT INTO tasks (internship_id, title, status, assigned_on, due_on)
          VALUES (3, 'Invalid Status Task', 'IN_PROGRESS', '2026-04-01', '2026-04-10')$sql$,
    '23514'
);

-- SUBMITTED status without submitted_on date
CALL pg_temp.expect_error(
    'BR4: SUBMITTED task without submitted_on rejected',
    $sql$INSERT INTO tasks (internship_id, title, status, assigned_on, due_on, submitted_on)
          VALUES (3, 'Missing Submission Date', 'SUBMITTED', '2026-04-01', '2026-04-10', NULL)$sql$,
    '23514'
);

-- ASSIGNED status with submitted_on date
CALL pg_temp.expect_error(
    'BR4: ASSIGNED task with submitted_on rejected',
    $sql$INSERT INTO tasks (internship_id, title, status, assigned_on, due_on, submitted_on)
          VALUES (3, 'Premature Submission Date', 'ASSIGNED', '2026-04-01', '2026-04-10', '2026-04-05')$sql$,
    '23514'
);

-- Completion fails with open ASSIGNED task (Internship 3 has Task 3 in ASSIGNED)
CALL pg_temp.expect_error(
    'BR4: Completion blocked by open ASSIGNED task',
    $sql$SELECT complete_internship(3, '2026-04-15')$sql$,
    '23514'
);

-- Completion fails with open SUBMITTED task (Internship 4 has Task 4 in SUBMITTED)
CALL pg_temp.expect_error(
    'BR4: Completion blocked by open SUBMITTED task',
    $sql$SELECT complete_internship(4, '2026-04-15')$sql$,
    '23514'
);

-- Verify that the failed completion call left row state completely untouched
DO $$
DECLARE
    v_status VARCHAR(20);
    v_end_date DATE;
BEGIN
    SELECT status, end_date INTO v_status, v_end_date
    FROM internships
    WHERE internship_id = 4;

    IF v_status <> 'ACTIVE' OR v_end_date IS NOT NULL THEN
        RAISE EXCEPTION 'TEST FAILED: Failed complete_internship modified row state (status=%, end_date=%)',
            v_status, v_end_date;
    ELSE
        RAISE NOTICE 'PASS: Failed complete_internship left internship 4 unchanged (status=ACTIVE, end_date=NULL)';
    END IF;
END;
$$;

-- ============================================================================
-- BR5: EVALUATIONS FOR COMPLETED INTERNSHIPS ONLY (Composite FK & Unique)
-- ============================================================================

-- Evaluation on ACTIVE internship 3 rejected by composite FK (3, 'COMPLETED') -> 23503
CALL pg_temp.expect_error(
    'BR5: Evaluation on ACTIVE internship rejected',
    $sql$INSERT INTO evaluations (internship_id, score, feedback)
          VALUES (3, 4, 'Premature evaluation')$sql$,
    '23503'
);

-- Evaluation on TERMINATED internship 2 rejected by composite FK (2, 'COMPLETED') -> 23503
CALL pg_temp.expect_error(
    'BR5: Evaluation on TERMINATED internship rejected',
    $sql$INSERT INTO evaluations (internship_id, score, feedback)
          VALUES (2, 3, 'Terminated evaluation')$sql$,
    '23503'
);

-- Orphan evaluation (non-existent internship_id 999 -> 23503)
CALL pg_temp.expect_error(
    'BR5: Orphan evaluation rejected by foreign key',
    $sql$INSERT INTO evaluations (internship_id, score, feedback)
          VALUES (999, 4, 'Orphan evaluation')$sql$,
    '23503'
);

-- Duplicate evaluation on same internship 1 rejected by UNIQUE(internship_id) -> 23505
CALL pg_temp.expect_error(
    'BR5: Duplicate evaluation on same internship rejected',
    $sql$INSERT INTO evaluations (internship_id, score, feedback)
          VALUES (1, 4, 'Duplicate evaluation')$sql$,
    '23505'
);

-- Invalid score: 0
CALL pg_temp.expect_error(
    'BR5: Evaluation score 0 rejected by CHECK constraint',
    $sql$INSERT INTO evaluations (internship_id, score, feedback)
          VALUES (5, 0, 'Score too low')$sql$,
    '23514'
);

-- Invalid score: 6
CALL pg_temp.expect_error(
    'BR5: Evaluation score 6 rejected by CHECK constraint',
    $sql$INSERT INTO evaluations (internship_id, score, feedback)
          VALUES (5, 6, 'Score too high')$sql$,
    '23514'
);

-- Reopening an evaluated internship rejected by composite FK ON UPDATE RESTRICT -> 23503
CALL pg_temp.expect_error(
    'BR5: Reopening an evaluated completed internship rejected by ON UPDATE RESTRICT',
    $sql$UPDATE internships SET status = 'ACTIVE', end_date = NULL WHERE internship_id = 1$sql$,
    '23503'
);

-- ============================================================================
-- BR6: RETENTION: HARD DELETES PROHIBITED (Triggers -> 23001)
-- ============================================================================

CALL pg_temp.expect_error(
    'BR6: Hard delete of intern prohibited',
    $sql$DELETE FROM interns WHERE intern_id = 1$sql$,
    '23001'
);

CALL pg_temp.expect_error(
    'BR6: Hard delete of internship prohibited',
    $sql$DELETE FROM internships WHERE internship_id = 1$sql$,
    '23001'
);

CALL pg_temp.expect_error(
    'BR6: Hard delete of task prohibited',
    $sql$DELETE FROM tasks WHERE task_id = 1$sql$,
    '23001'
);

CALL pg_temp.expect_error(
    'BR6: Hard delete of evaluation prohibited',
    $sql$DELETE FROM evaluations WHERE evaluation_id = 1$sql$,
    '23001'
);

CALL pg_temp.expect_error(
    'BR6: Hard delete of department prohibited',
    $sql$DELETE FROM departments WHERE department_id = 1$sql$,
    '23001'
);

CALL pg_temp.expect_error(
    'BR6: Hard delete of mentor prohibited',
    $sql$DELETE FROM mentors WHERE mentor_id = 1$sql$,
    '23001'
);

-- ============================================================================
-- GENERAL INTEGRITY CONSTRAINTS (Unique Names, Emails, Regex Validation)
-- ============================================================================

CALL pg_temp.expect_error(
    'General: Duplicate department name rejected',
    $sql$INSERT INTO departments (department_name) VALUES ('Engineering')$sql$,
    '23505'
);

CALL pg_temp.expect_error(
    'General: Duplicate mentor email rejected',
    $sql$INSERT INTO mentors (department_id, mentor_name, email)
          VALUES (1, 'Clone Mentor', 'anita.sharma@company.com')$sql$,
    '23505'
);

CALL pg_temp.expect_error(
    'General: Duplicate intern email rejected',
    $sql$INSERT INTO interns (intern_name, email)
          VALUES ('Clone Intern', 'aarav.mehta@interns.company.com')$sql$,
    '23505'
);

CALL pg_temp.expect_error(
    'General: Malformed email rejected by regex CHECK',
    $sql$INSERT INTO interns (intern_name, email)
          VALUES ('Bad Email', 'not-an-email')$sql$,
    '23514'
);

CALL pg_temp.expect_error(
    'General: Orphan internship (non-existent intern_id) rejected by FK',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date)
          VALUES (999, 1, 1, 'ACTIVE', '2026-04-01')$sql$,
    '23503'
);

-- ============================================================================
-- POSITIVE CONTROLS
-- ============================================================================

-- Positive Control 1: Intern 1 (has COMPLETED internship 1) is allowed a new ACTIVE internship
CALL pg_temp.expect_success(
    'PC1: Intern with completed internship can start a new active internship',
    $sql$INSERT INTO internships (intern_id, department_id, mentor_id, status, start_date)
          VALUES (1, 1, 1, 'ACTIVE', '2026-04-10')$sql$
);

-- Positive Control 2: Closing all open tasks permits atomic completion
CALL pg_temp.expect_success(
    'PC2: Updating open tasks to closed states allows completion',
    $sql$
        UPDATE tasks SET status = 'APPROVED' WHERE task_id = 4;
        SELECT complete_internship(4, '2026-04-15');
    $sql$
);

-- Positive Control 3: Evaluating the newly completed internship succeeds
CALL pg_temp.expect_success(
    'PC3: Evaluation succeeds on legitimately completed internship',
    $sql$INSERT INTO evaluations (internship_id, score, feedback)
          VALUES (4, 4, 'Great project delivery across all milestones')$sql$
);

-- Roll back everything to guarantee seed data is left completely clean
ROLLBACK;
