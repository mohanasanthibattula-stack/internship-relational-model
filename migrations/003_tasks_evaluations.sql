-- Migration 003_tasks_evaluations.sql
-- Work tasks and final performance evaluations

-- Tasks assigned to an internship
CREATE TABLE IF NOT EXISTS tasks (
    task_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    internship_id INTEGER NOT NULL CONSTRAINT fk_tasks_internship REFERENCES internships(internship_id) ON DELETE RESTRICT,
    title VARCHAR(200) NOT NULL,
    status VARCHAR(20) NOT NULL CONSTRAINT chk_tasks_status CHECK (status IN ('ASSIGNED', 'SUBMITTED', 'APPROVED', 'REJECTED')),
    assigned_on DATE NOT NULL,
    due_on DATE NOT NULL,
    submitted_on DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- BR4: Due date must be on or after assignment date
    CONSTRAINT chk_tasks_dates CHECK (due_on >= assigned_on),

    -- BR4: submitted_on required unless ASSIGNED (and must be on or after assignment date)
    CONSTRAINT chk_tasks_status_dates CHECK (
        (status = 'ASSIGNED' AND submitted_on IS NULL) OR
        (status IN ('SUBMITTED', 'APPROVED', 'REJECTED') AND submitted_on IS NOT NULL AND submitted_on >= assigned_on)
    )
);

-- Final evaluations recorded once an internship completes
CREATE TABLE IF NOT EXISTS evaluations (
    evaluation_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    internship_id INTEGER NOT NULL CONSTRAINT uq_evaluations_internship_id UNIQUE,
    -- BR5: Fixed status column guaranteed to be 'COMPLETED'
    internship_status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED' CONSTRAINT chk_evaluations_status_completed CHECK (internship_status = 'COMPLETED'),
    -- BR5: Score bounded between 1 and 5
    score INTEGER NOT NULL CONSTRAINT chk_evaluations_score CHECK (score BETWEEN 1 AND 5),
    feedback TEXT NOT NULL,
    evaluated_on DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- BR5: Composite FK ensuring evaluation references an internship that is in 'COMPLETED' status
    -- ON UPDATE RESTRICT prevents reopening an evaluated internship
    CONSTRAINT fk_evaluations_completed_internship FOREIGN KEY (internship_id, internship_status)
        REFERENCES internships(internship_id, status)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);
