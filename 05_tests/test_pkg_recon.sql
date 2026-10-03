-- =============================================================================
-- test_pkg_recon.sql
-- Purpose : Self-checking tests for PKG_RECON against the sample data.
-- Output  : One PASS/FAIL line per check and a total at the end.
-- Note    : Each run of RUN_RECON adds rows to RECON_RUNS/RESULTS, so the tests
--           can be repeated safely; use 00_drop_objects.sql to start clean.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    l_run_id    NUMBER;
    l_status    VARCHAR2(15);
    l_records   NUMBER;
    l_count     PLS_INTEGER;
    l_before    PLS_INTEGER;
    l_after     PLS_INTEGER;
    l_checks    PLS_INTEGER := 0;
    l_failures  PLS_INTEGER := 0;

    PROCEDURE check_true (p_name IN VARCHAR2, p_condition IN BOOLEAN) IS
    BEGIN
        l_checks := l_checks + 1;
        IF p_condition THEN
            DBMS_OUTPUT.PUT_LINE('PASS  ' || p_name);
        ELSE
            l_failures := l_failures + 1;
            DBMS_OUTPUT.PUT_LINE('FAIL  ' || p_name);
        END IF;
    END check_true;

    FUNCTION count_status (p_run_id IN NUMBER, p_status IN VARCHAR2) RETURN PLS_INTEGER IS
        l_cnt PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO l_cnt
          FROM recon_results
         WHERE run_id = p_run_id
           AND match_status = p_status;
        RETURN l_cnt;
    END count_status;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- PKG_RECON tests ---');

    -- 1. Audit trigger -------------------------------------------------------
    SELECT COUNT(*)
      INTO l_count
      FROM src_transactions
     WHERE created_by IS NULL OR created_date IS NULL;
    check_true('Audit trigger fills created_by/created_date', l_count = 0);

    -- 2. Full run ------------------------------------------------------------
    pkg_recon.run_recon(l_run_id);

    check_true('Full run: 7 MATCHED',
               count_status(l_run_id, pkg_recon.c_matched) = 7);
    check_true('Full run: 3 AMOUNT_MISMATCH',
               count_status(l_run_id, pkg_recon.c_amount_mismatch) = 3);
    check_true('Full run: 2 MISSING_IN_TARGET',
               count_status(l_run_id, pkg_recon.c_missing_in_target) = 2);
    check_true('Full run: 2 MISSING_IN_SOURCE',
               count_status(l_run_id, pkg_recon.c_missing_in_source) = 2);

    SELECT status, total_records
      INTO l_status, l_records
      FROM recon_runs
     WHERE run_id = l_run_id;
    check_true('Run row is COMPLETED with 14 records',
               l_status = 'COMPLETED' AND l_records = 14);

    check_true('Match rate is 50.00', pkg_recon.get_match_rate(l_run_id) = 50);

    -- 3. Summary table (MERGE) -----------------------------------------------
    SELECT SUM(record_count)
      INTO l_count
      FROM recon_summary
     WHERE run_id = l_run_id;
    check_true('Summary counts add up to 14', l_count = 14);

    pkg_recon.refresh_summary(l_run_id);   -- second call must update, not duplicate
    pkg_recon.refresh_summary(l_run_id);
    SELECT COUNT(*)
      INTO l_count
      FROM recon_summary
     WHERE run_id = l_run_id;
    check_true('Refreshing the summary twice keeps 4 rows', l_count = 4);
    ROLLBACK;

    -- 4. Date filter ---------------------------------------------------------
    pkg_recon.run_recon(l_run_id, DATE '2026-09-01', DATE '2026-09-02');

    check_true('Date range: 3 MATCHED',
               count_status(l_run_id, pkg_recon.c_matched) = 3);
    check_true('Date range: 1 AMOUNT_MISMATCH',
               count_status(l_run_id, pkg_recon.c_amount_mismatch) = 1);
    check_true('Date range: nothing missing on either side',
               count_status(l_run_id, pkg_recon.c_missing_in_target)
             + count_status(l_run_id, pkg_recon.c_missing_in_source) = 0);

    -- 5. Error handling and logging ------------------------------------------
    SELECT COUNT(*) INTO l_before FROM recon_error_log WHERE error_code = -20001;

    BEGIN
        pkg_recon.run_recon(l_run_id, DATE '2026-09-30', DATE '2026-09-01');
        check_true('Reversed date range raises an error', FALSE);
    EXCEPTION
        WHEN pkg_recon.e_invalid_date_range THEN
            check_true('Reversed date range raises e_invalid_date_range', TRUE);
    END;

    SELECT COUNT(*) INTO l_after FROM recon_error_log WHERE error_code = -20001;
    check_true('Error is written to RECON_ERROR_LOG', l_after = l_before + 1);

    -- Result -----------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- ' || l_checks || ' checks, ' || l_failures || ' failed ---');
END;
/
