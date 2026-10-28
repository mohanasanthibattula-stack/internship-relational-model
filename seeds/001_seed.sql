-- Seed fixtures for RabTech Internship Relational Model
-- Populates 3 departments, 4 mentors, 5 interns, 6 internships, 7 tasks, 1 evaluation
-- Follows strict lifecycle order to satisfy all guards and constraints

-- 1. Departments (3 records)
INSERT INTO departments (department_id, department_name) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Engineering'),
    (2, 'Data Science'),
    (3, 'Product Management');

-- 2. Mentors (4 records)
INSERT INTO mentors (mentor_id, department_id, mentor_name, email) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 'Anita Sharma', 'anita.sharma@company.com'),
    (2, 1, 'Rajesh Kumar', 'rajesh.kumar@company.com'),
    (3, 2, 'Priya Patel', 'priya.patel@company.com'),
    (4, 3, 'Vikram Malhotra', 'vikram.malhotra@company.com');

-- 3. Interns (5 records)
INSERT INTO interns (intern_id, intern_name, email, registered_on) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Aarav Mehta', 'aarav.mehta@interns.company.com', '2026-01-01'),
    (2, 'Diya Nair', 'diya.nair@interns.company.com', '2026-01-05'),
    (3, 'Kabir Shah', 'kabir.shah@interns.company.com', '2026-01-10'),
    (4, 'Meera Iyer', 'meera.iyer@interns.company.com', '2026-01-15'),
    (5, 'Rohan Verma', 'rohan.verma@interns.company.com', '2026-01-20');

-- 4. Initial Internships: insert ACTIVE (and APPLIED)
-- Internship 1: Intern 1 (will be completed)
-- Internship 2: Intern 2 (will be terminated)
-- Internship 4: Intern 3 (ACTIVE)
-- Internship 5: Intern 4 (ACTIVE)
-- Internship 6: Intern 5 (APPLIED)
INSERT INTO internships (internship_id, intern_id, department_id, mentor_id, status, start_date, end_date) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 1, 1, 'ACTIVE', '2026-01-10', NULL),
    (2, 2, 2, 3, 'ACTIVE', '2026-02-01', NULL),
    (4, 3, 2, 3, 'ACTIVE', '2026-02-15', NULL),
    (5, 4, 3, 4, 'ACTIVE', '2026-03-01', NULL),
    (6, 5, 1, 1, 'APPLIED', NULL, NULL);

-- 5. Tasks for Internship 1 (must be closed before completion)
INSERT INTO tasks (task_id, internship_id, title, status, assigned_on, due_on, submitted_on) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 'Database Schema Design', 'APPROVED', '2026-01-15', '2026-01-25', '2026-01-24'),
    (2, 1, 'SQL Optimization & Indexing', 'APPROVED', '2026-02-01', '2026-02-15', '2026-02-14');

-- 6. Atomically complete Internship 1 via complete_internship
SELECT complete_internship(1, '2026-03-31');

-- 7. Record evaluation for COMPLETED Internship 1
INSERT INTO evaluations (evaluation_id, internship_id, internship_status, score, feedback, evaluated_on) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 'COMPLETED', 5, 'Exceptional performance in relational database design and test execution.', '2026-04-01');

-- 8. Terminate Internship 2 (Intern 2)
UPDATE internships
SET status = 'TERMINATED',
    end_date = '2026-03-01'
WHERE internship_id = 2;

-- 9. Give Intern 2 a new ACTIVE internship (Internship 3) to demonstrate history continuity
INSERT INTO internships (internship_id, intern_id, department_id, mentor_id, status, start_date, end_date) OVERRIDING SYSTEM VALUE VALUES
    (3, 2, 1, 2, 'ACTIVE', '2026-03-15', NULL);

-- 10. Remaining tasks across active internships
INSERT INTO tasks (task_id, internship_id, title, status, assigned_on, due_on, submitted_on) OVERRIDING SYSTEM VALUE VALUES
    (3, 3, 'ETL Pipeline Ingestion', 'ASSIGNED', '2026-03-20', '2026-04-10', NULL),
    (4, 4, 'Feature Engineering Pipelines', 'SUBMITTED', '2026-02-20', '2026-03-10', '2026-03-08'),
    (5, 4, 'Model Evaluation Report', 'REJECTED', '2026-03-11', '2026-03-25', '2026-03-24'),
    (6, 5, 'User Feedback Taxonomy', 'APPROVED', '2026-03-05', '2026-03-18', '2026-03-17'),
    (7, 5, 'Product Metrics Dashboard', 'ASSIGNED', '2026-03-20', '2026-04-05', NULL);

-- 11. Reset identity sequences with setval to prevent collision with future inserts
SELECT setval(pg_get_serial_sequence('departments', 'department_id'), (SELECT COALESCE(MAX(department_id), 1) FROM departments));
SELECT setval(pg_get_serial_sequence('mentors', 'mentor_id'), (SELECT COALESCE(MAX(mentor_id), 1) FROM mentors));
SELECT setval(pg_get_serial_sequence('interns', 'intern_id'), (SELECT COALESCE(MAX(intern_id), 1) FROM interns));
SELECT setval(pg_get_serial_sequence('internships', 'internship_id'), (SELECT COALESCE(MAX(internship_id), 1) FROM internships));
SELECT setval(pg_get_serial_sequence('tasks', 'task_id'), (SELECT COALESCE(MAX(task_id), 1) FROM tasks));
SELECT setval(pg_get_serial_sequence('evaluations', 'evaluation_id'), (SELECT COALESCE(MAX(evaluation_id), 1) FROM evaluations));
