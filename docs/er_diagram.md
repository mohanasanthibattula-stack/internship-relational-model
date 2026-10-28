# Entity Relationship Diagram

The following Mermaid diagram visualizes the RabTech Internship Relational Model schema, including Primary Keys (`PK`), Foreign Keys (`FK`), Unique Keys (`UK`), and composite constraints.

```mermaid
erDiagram
    departments ||--o{ mentors : "employs (1:N)"
    departments ||--o{ internships : "hosts (1:N)"
    mentors ||--o{ internships : "supervises within department (1:N)"
    interns ||--o{ internships : "registers for (1:N, max 1 ACTIVE)"
    internships ||--o{ tasks : "contains (1:N, ACTIVE only)"
    internships ||--o| evaluations : "evaluated by (1:0..1, COMPLETED only)"

    departments {
        int department_id PK "Generated Always as Identity"
        varchar(100) department_name UK "Unique department title"
        timestamptz created_at "Audit creation timestamp"
    }

    mentors {
        int mentor_id PK "Generated Always as Identity"
        int department_id FK "References departments(department_id)"
        varchar(100) mentor_name "Mentor full name"
        varchar(255) email UK "Unique mentor email"
        timestamptz created_at "Audit creation timestamp"
    }

    interns {
        int intern_id PK "Generated Always as Identity"
        varchar(100) intern_name "Intern full name"
        varchar(255) email UK "Unique intern email"
        date registered_on "Registration date"
        timestamptz created_at "Audit creation timestamp"
    }

    internships {
        int internship_id PK "Generated Always as Identity"
        int intern_id FK "References interns(intern_id)"
        int department_id FK "References departments(department_id)"
        int mentor_id FK "References mentors(mentor_id, department_id)"
        varchar(20) status "APPLIED, ACTIVE, COMPLETED, TERMINATED"
        date start_date "Start date (required for ACTIVE/COMPLETED/TERMINATED)"
        date end_date "End date (required for COMPLETED/TERMINATED)"
        timestamptz created_at "Audit creation timestamp"
    }

    tasks {
        int task_id PK "Generated Always as Identity"
        int internship_id FK "References internships(internship_id)"
        varchar(200) title "Task title"
        varchar(20) status "ASSIGNED, SUBMITTED, APPROVED, REJECTED"
        date assigned_on "Date task assigned"
        date due_on "Due date (due_on >= assigned_on)"
        date submitted_on "Submission date (required if not ASSIGNED)"
        timestamptz created_at "Audit creation timestamp"
    }

    evaluations {
        int evaluation_id PK "Generated Always as Identity"
        int internship_id FK, UK "References internships(internship_id, status)"
        varchar(20) internship_status FK "Fixed to 'COMPLETED'"
        int score "Score between 1 and 5"
        text feedback "Detailed evaluation narrative"
        date evaluated_on "Evaluation recording date"
        timestamptz created_at "Audit creation timestamp"
    }
```

## Key Constraint Details

1. **Composite Key on `mentors`**:
   - `UNIQUE (mentor_id, department_id)` provides the target for BR2 composite foreign key.
2. **Composite Key on `internships`**:
   - `UNIQUE (internship_id, status)` provides the target for BR5 composite foreign key.
3. **Partial Unique Index on `internships`**:
   - `CREATE UNIQUE INDEX uq_internships_active_per_intern ON internships (intern_id) WHERE (status = 'ACTIVE');` (BR1).
4. **Declarative State Filter on `evaluations`**:
   - `internship_status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED' CHECK (internship_status = 'COMPLETED')` paired with composite foreign key `(internship_id, internship_status) REFERENCES internships(internship_id, status)` guarantees evaluations can only ever be attached to `COMPLETED` internships.
