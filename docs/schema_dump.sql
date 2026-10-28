--
-- PostgreSQL database dump
--

-- Dumped from database version 16.8
-- Dumped by pg_dump version 16.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: complete_internship(integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_internship(p_internship_id integer, p_end_date date) RETURNS void
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


--
-- Name: fn_internships_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_internships_guard() RETURNS trigger
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


--
-- Name: fn_prevent_hard_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_prevent_hard_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'Hard deletion is not allowed: % records must be retained', TG_TABLE_NAME
        USING ERRCODE = 'restrict_violation';
END;
$$;


--
-- Name: fn_tasks_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_tasks_guard() RETURNS trigger
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    department_id integer NOT NULL,
    department_name character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: departments_department_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.departments ALTER COLUMN department_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.departments_department_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evaluations (
    evaluation_id integer NOT NULL,
    internship_id integer NOT NULL,
    internship_status character varying(20) DEFAULT 'COMPLETED'::character varying NOT NULL,
    score integer NOT NULL,
    feedback text NOT NULL,
    evaluated_on date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_evaluations_score CHECK (((score >= 1) AND (score <= 5))),
    CONSTRAINT chk_evaluations_status_completed CHECK (((internship_status)::text = 'COMPLETED'::text))
);


--
-- Name: evaluations_evaluation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.evaluations ALTER COLUMN evaluation_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.evaluations_evaluation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: interns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interns (
    intern_id integer NOT NULL,
    intern_name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    registered_on date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_interns_email CHECK (((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))
);


--
-- Name: interns_intern_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.interns ALTER COLUMN intern_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.interns_intern_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: internships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.internships (
    internship_id integer NOT NULL,
    intern_id integer NOT NULL,
    department_id integer NOT NULL,
    mentor_id integer NOT NULL,
    status character varying(20) NOT NULL,
    start_date date,
    end_date date,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_internships_status CHECK (((status)::text = ANY ((ARRAY['APPLIED'::character varying, 'ACTIVE'::character varying, 'COMPLETED'::character varying, 'TERMINATED'::character varying])::text[]))),
    CONSTRAINT chk_internships_status_dates CHECK (((((status)::text = 'APPLIED'::text) AND (start_date IS NULL) AND (end_date IS NULL)) OR (((status)::text = 'ACTIVE'::text) AND (start_date IS NOT NULL) AND (end_date IS NULL)) OR (((status)::text = ANY ((ARRAY['COMPLETED'::character varying, 'TERMINATED'::character varying])::text[])) AND (start_date IS NOT NULL) AND (end_date IS NOT NULL) AND (end_date >= start_date))))
);


--
-- Name: internships_internship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.internships ALTER COLUMN internship_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.internships_internship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mentors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mentors (
    mentor_id integer NOT NULL,
    department_id integer NOT NULL,
    mentor_name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_mentors_email CHECK (((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))
);


--
-- Name: mentors_mentor_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.mentors ALTER COLUMN mentor_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.mentors_mentor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    filename character varying(255) NOT NULL,
    checksum character varying(64) NOT NULL,
    applied_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    task_id integer NOT NULL,
    internship_id integer NOT NULL,
    title character varying(200) NOT NULL,
    status character varying(20) NOT NULL,
    assigned_on date NOT NULL,
    due_on date NOT NULL,
    submitted_on date,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_tasks_dates CHECK ((due_on >= assigned_on)),
    CONSTRAINT chk_tasks_status CHECK (((status)::text = ANY ((ARRAY['ASSIGNED'::character varying, 'SUBMITTED'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[]))),
    CONSTRAINT chk_tasks_status_dates CHECK (((((status)::text = 'ASSIGNED'::text) AND (submitted_on IS NULL)) OR (((status)::text = ANY ((ARRAY['SUBMITTED'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[])) AND (submitted_on IS NOT NULL) AND (submitted_on >= assigned_on))))
);


--
-- Name: tasks_task_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tasks ALTER COLUMN task_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tasks_task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (department_id);


--
-- Name: evaluations evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT evaluations_pkey PRIMARY KEY (evaluation_id);


--
-- Name: interns interns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interns
    ADD CONSTRAINT interns_pkey PRIMARY KEY (intern_id);


--
-- Name: internships internships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT internships_pkey PRIMARY KEY (internship_id);


--
-- Name: mentors mentors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mentors
    ADD CONSTRAINT mentors_pkey PRIMARY KEY (mentor_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (filename);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (task_id);


--
-- Name: departments uq_departments_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT uq_departments_name UNIQUE (department_name);


--
-- Name: evaluations uq_evaluations_internship_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT uq_evaluations_internship_id UNIQUE (internship_id);


--
-- Name: interns uq_interns_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interns
    ADD CONSTRAINT uq_interns_email UNIQUE (email);


--
-- Name: internships uq_internships_id_status; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT uq_internships_id_status UNIQUE (internship_id, status);


--
-- Name: mentors uq_mentors_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mentors
    ADD CONSTRAINT uq_mentors_email UNIQUE (email);


--
-- Name: mentors uq_mentors_mentor_department; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mentors
    ADD CONSTRAINT uq_mentors_mentor_department UNIQUE (mentor_id, department_id);


--
-- Name: uq_internships_active_per_intern; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_internships_active_per_intern ON public.internships USING btree (intern_id) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: internships trg_internships_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_internships_guard BEFORE INSERT OR UPDATE ON public.internships FOR EACH ROW EXECUTE FUNCTION public.fn_internships_guard();


--
-- Name: departments trg_prevent_delete_departments; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_delete_departments BEFORE DELETE ON public.departments FOR EACH ROW EXECUTE FUNCTION public.fn_prevent_hard_delete();


--
-- Name: evaluations trg_prevent_delete_evaluations; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_delete_evaluations BEFORE DELETE ON public.evaluations FOR EACH ROW EXECUTE FUNCTION public.fn_prevent_hard_delete();


--
-- Name: interns trg_prevent_delete_interns; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_delete_interns BEFORE DELETE ON public.interns FOR EACH ROW EXECUTE FUNCTION public.fn_prevent_hard_delete();


--
-- Name: internships trg_prevent_delete_internships; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_delete_internships BEFORE DELETE ON public.internships FOR EACH ROW EXECUTE FUNCTION public.fn_prevent_hard_delete();


--
-- Name: mentors trg_prevent_delete_mentors; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_delete_mentors BEFORE DELETE ON public.mentors FOR EACH ROW EXECUTE FUNCTION public.fn_prevent_hard_delete();


--
-- Name: tasks trg_prevent_delete_tasks; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_delete_tasks BEFORE DELETE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.fn_prevent_hard_delete();


--
-- Name: tasks trg_tasks_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tasks_guard BEFORE INSERT OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.fn_tasks_guard();


--
-- Name: evaluations fk_evaluations_completed_internship; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluations
    ADD CONSTRAINT fk_evaluations_completed_internship FOREIGN KEY (internship_id, internship_status) REFERENCES public.internships(internship_id, status) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: internships fk_internships_department; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT fk_internships_department FOREIGN KEY (department_id) REFERENCES public.departments(department_id) ON DELETE RESTRICT;


--
-- Name: internships fk_internships_intern; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT fk_internships_intern FOREIGN KEY (intern_id) REFERENCES public.interns(intern_id) ON DELETE RESTRICT;


--
-- Name: internships fk_internships_mentor_dept; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT fk_internships_mentor_dept FOREIGN KEY (mentor_id, department_id) REFERENCES public.mentors(mentor_id, department_id) ON DELETE RESTRICT;


--
-- Name: mentors fk_mentors_department; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mentors
    ADD CONSTRAINT fk_mentors_department FOREIGN KEY (department_id) REFERENCES public.departments(department_id) ON DELETE RESTRICT;


--
-- Name: tasks fk_tasks_internship; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_internship FOREIGN KEY (internship_id) REFERENCES public.internships(internship_id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

