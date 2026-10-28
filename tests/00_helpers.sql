-- Helper procedures for running database invariant assertions

-- Expects statement execution to raise a specific SQLSTATE.
-- If the statement succeeds or raises a different SQLSTATE, an exception is raised
-- causing the outer test transaction to fail.
CREATE OR REPLACE PROCEDURE pg_temp.expect_error(
    p_label TEXT,
    p_sql TEXT,
    p_expected_sqlstate TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_actual_sqlstate TEXT;
    v_errmsg TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
        -- Reached here means no error was thrown
        RAISE EXCEPTION 'TEST FAILED [%]: Expected SQLSTATE % but statement succeeded without error: %',
            p_label, p_expected_sqlstate, p_sql;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_actual_sqlstate = RETURNED_SQLSTATE,
                v_errmsg = MESSAGE_TEXT;

            -- Propagate self-generated failure messages directly
            IF v_errmsg LIKE 'TEST FAILED [%]%' THEN
                RAISE;
            END IF;

            IF v_actual_sqlstate <> p_expected_sqlstate THEN
                RAISE EXCEPTION 'TEST FAILED [%]: Expected SQLSTATE % but got % (Message: %): %',
                    p_label, p_expected_sqlstate, v_actual_sqlstate, v_errmsg, p_sql;
            ELSE
                RAISE NOTICE 'PASS: % (Received expected SQLSTATE %)', p_label, v_actual_sqlstate;
            END IF;
    END;
END;
$$;

-- Expects statement execution to succeed cleanly.
CREATE OR REPLACE PROCEDURE pg_temp.expect_success(
    p_label TEXT,
    p_sql TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_actual_sqlstate TEXT;
    v_errmsg TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
        RAISE NOTICE 'PASS (Positive Control): %', p_label;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_actual_sqlstate = RETURNED_SQLSTATE,
                v_errmsg = MESSAGE_TEXT;
            RAISE EXCEPTION 'TEST FAILED [%]: Expected success but failed with SQLSTATE % (Message: %): %',
                p_label, v_actual_sqlstate, v_errmsg, p_sql;
    END;
END;
$$;
