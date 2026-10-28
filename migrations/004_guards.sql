-- Migration 004_guards.sql
-- Triggers, procedures, and retention guards

-- BR3: State transition and lifecycle guard
CREATE OR REPLACE FUNCTION fn_internships_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- New internships may only be created in APPLIED or ACTIVE status
        IF NEW.status NOT IN ('APPLIED', 'ACTIVE') THEN
            RAISE EXCEPTION 'New internships may only be created in APPLIED or ACTIVE status (attempted: %)', NEW.status
                USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Terminal state TERMINATED cannot change
        IF OLD.status = 'TERMINATED' AND NEW.status <> OLD.status THEN
            RAISE EXCEPTION 'Terminal state TERMINATED for internship % cannot be modified', OLD.internship_id
                USING ERRCODE = 'check_violation';
        END IF;

        -- Terminal state COMPLETED cannot change:
        -- If an evaluation exists, let composite FK ON UPDATE RESTRICT fire and report 23503;
        -- if no evaluation exists, raise check_violation (23514).
        IF OLD.status = 'COMPLETED' AND NEW.status <> OLD.status THEN
            IF NOT EXISTS (SELECT 1 FROM evaluations WHERE internship_id = OLD.internship_id) THEN
                RAISE EXCEPTION 'Terminal state COMPLETED for internship % cannot be modified', OLD.internship_id
                    USING ERRCODE = 'check_violation';
            END IF;
            -- If evaluation exists, let foreign key ON UPDATE RESTRICT enforce 23503
        END IF;

        -- ACTIVE cannot regress to APPLIED
        IF OLD.status = 'ACTIVE' AND NEW.status = 'APPLIED' THEN
            RAISE EXCEPTION 'Illegal status transition: ACTIVE internship cannot revert to APPLIED'
                USING ERRCODE = 'check_violation';
        END IF;

        -- APPLIED cannot transition directly to COMPLETED or TERMINATED
        IF OLD.status = 'APPLIED' AND NEW.status NOT IN ('APPLIED', 'ACTIVE') THEN
            RAISE EXCEPTION 'Illegal status transition: APPLIED internship cannot transition directly to %', NEW.status
                USING ERRCODE = 'check_violation';
        END IF;

        -- Guard against completing an internship when open tasks remain
        IF NEW.status = 'COMPLETED' AND OLD.status <> 'COMPLETED' THEN
            IF EXISTS (
                SELECT 1 FROM tasks
                WHERE internship_id = NEW.internship_id
                  AND status IN ('ASSIGNED', 'SUBMITTED')
            ) THEN
                RAISE EXCEPTION 'Cannot complete internship %: open tasks remain', NEW.internship_id
                    USING ERRCODE = 'check_violation';
            END IF;
        END IF;

        RETURN NEW;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_internships_guard ON internships;
CREATE TRIGGER trg_internships_guard
    BEFORE INSERT OR UPDATE ON internships
    FOR EACH ROW
    EXECUTE FUNCTION fn_internships_guard();

-- BR4: Task invariants guard
CREATE OR REPLACE FUNCTION fn_tasks_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_parent_status VARCHAR(20);
BEGIN
    -- A task never moves to another internship
    IF TG_OP = 'UPDATE' THEN
        IF NEW.internship_id <> OLD.internship_id THEN
            RAISE EXCEPTION 'Task % cannot be reassigned to another internship', OLD.task_id
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    -- Tasks only for ACTIVE internships.
    -- Orphan tasks (non-existent parent) fall through so FK reports 23503.
    SELECT status INTO v_parent_status
    FROM internships
    WHERE internship_id = NEW.internship_id;

    IF v_parent_status IS NOT NULL AND v_parent_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Tasks can only be assigned to ACTIVE internships (current status: %)', v_parent_status
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tasks_guard ON tasks;
CREATE TRIGGER trg_tasks_guard
    BEFORE INSERT OR UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION fn_tasks_guard();

-- BR4: Atomic internship completion procedure
CREATE OR REPLACE FUNCTION complete_internship(p_internship_id INTEGER, p_end_date DATE)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_start_date DATE;
    v_open_tasks INTEGER;
BEGIN
    SELECT status, start_date INTO v_status, v_start_date
    FROM internships
    WHERE internship_id = p_internship_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Internship % does not exist', p_internship_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Internship % is not ACTIVE (current status: %)', p_internship_id, v_status
            USING ERRCODE = 'check_violation';
    END IF;

    IF p_end_date IS NULL OR p_end_date < v_start_date THEN
        RAISE EXCEPTION 'Completion end_date % must be on or after start_date %', p_end_date, v_start_date
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT COUNT(*) INTO v_open_tasks
    FROM tasks
    WHERE internship_id = p_internship_id
      AND status IN ('ASSIGNED', 'SUBMITTED');

    IF v_open_tasks > 0 THEN
        RAISE EXCEPTION 'Cannot complete internship %: % open tasks remain', p_internship_id, v_open_tasks
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE internships
    SET status = 'COMPLETED',
        end_date = p_end_date
    WHERE internship_id = p_internship_id;
END;
$$;

-- BR6: Retention guards raising restrict_violation (SQLSTATE 23001)
CREATE OR REPLACE FUNCTION fn_prevent_hard_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Hard deletion is not allowed: % records must be retained', TG_TABLE_NAME
        USING ERRCODE = 'restrict_violation';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_delete_interns ON interns;
CREATE TRIGGER trg_prevent_delete_interns
    BEFORE DELETE ON interns
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_prevent_delete_internships ON internships;
CREATE TRIGGER trg_prevent_delete_internships
    BEFORE DELETE ON internships
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_prevent_delete_tasks ON tasks;
CREATE TRIGGER trg_prevent_delete_tasks
    BEFORE DELETE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_prevent_delete_evaluations ON evaluations;
CREATE TRIGGER trg_prevent_delete_evaluations
    BEFORE DELETE ON evaluations
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_prevent_delete_departments ON departments;
CREATE TRIGGER trg_prevent_delete_departments
    BEFORE DELETE ON departments
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_prevent_delete_mentors ON mentors;
CREATE TRIGGER trg_prevent_delete_mentors
    BEFORE DELETE ON mentors
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_hard_delete();
