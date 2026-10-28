-- Migration 001_people.sql
-- Core organizational entities: departments, mentors, interns

-- Departments hosting internships
CREATE TABLE IF NOT EXISTS departments (
    department_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL CONSTRAINT uq_departments_name UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Mentors assigned to departments
CREATE TABLE IF NOT EXISTS mentors (
    mentor_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_id INTEGER NOT NULL CONSTRAINT fk_mentors_department REFERENCES departments(department_id) ON DELETE RESTRICT,
    mentor_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL CONSTRAINT uq_mentors_email UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_mentors_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    -- BR2: Composite unique key allowing composite foreign key reference from internships
    CONSTRAINT uq_mentors_mentor_department UNIQUE (mentor_id, department_id)
);

-- Registered interns
CREATE TABLE IF NOT EXISTS interns (
    intern_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    intern_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL CONSTRAINT uq_interns_email UNIQUE,
    registered_on DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_interns_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);
