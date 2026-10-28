-- Migration 002_internships.sql
-- Internships table and relationship constraints

CREATE TABLE IF NOT EXISTS internships (
    internship_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    intern_id INTEGER NOT NULL CONSTRAINT fk_internships_intern REFERENCES interns(intern_id) ON DELETE RESTRICT,
    department_id INTEGER NOT NULL CONSTRAINT fk_internships_department REFERENCES departments(department_id) ON DELETE RESTRICT,
    mentor_id INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL CONSTRAINT chk_internships_status CHECK (status IN ('APPLIED', 'ACTIVE', 'COMPLETED', 'TERMINATED')),
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- BR2: Composite FK enforcing mentor belongs to the internship's department
    CONSTRAINT fk_internships_mentor_dept FOREIGN KEY (mentor_id, department_id)
        REFERENCES mentors(mentor_id, department_id) ON DELETE RESTRICT,

    -- BR5: Composite unique key allowing composite FK from evaluations (status-bound)
    CONSTRAINT uq_internships_id_status UNIQUE (internship_id, status),

    -- BR3: Dates must match the state:
    -- APPLIED: no dates
    -- ACTIVE: start date only
    -- COMPLETED/TERMINATED: start and end dates, end >= start
    CONSTRAINT chk_internships_status_dates CHECK (
        (status = 'APPLIED' AND start_date IS NULL AND end_date IS NULL) OR
        (status = 'ACTIVE' AND start_date IS NOT NULL AND end_date IS NULL) OR
        (status IN ('COMPLETED', 'TERMINATED') AND start_date IS NOT NULL AND end_date IS NOT NULL AND end_date >= start_date)
    )
);

-- BR1: One ACTIVE internship per intern (partial unique index)
CREATE UNIQUE INDEX IF NOT EXISTS uq_internships_active_per_intern
    ON internships (intern_id)
    WHERE (status = 'ACTIVE');
