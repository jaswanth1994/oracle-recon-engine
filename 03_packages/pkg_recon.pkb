-- =============================================================================
-- pkg_recon.pkb  (package body)
-- Techniques used:
--   * FULL OUTER JOIN to find rows missing on either side in one pass
--   * Explicit cursor with BULK COLLECT ... LIMIT and FORALL for fast inserts
--   * MERGE to rebuild the summary table
--   * Autonomous-transaction error logging
--   * Structured exception handling with status tracking on the run row
-- =============================================================================

CREATE OR REPLACE PACKAGE BODY pkg_recon AS

    -- Rows fetched per round trip. Large enough to avoid excess SQL/PL-SQL
    -- context switches, small enough to keep session memory low.
    c_batch_limit CONSTANT PLS_INTEGER := 500;

    -- -------------------------------------------------------------------------
    PROCEDURE log_error (
        p_module     IN VARCHAR2,
        p_run_id     IN NUMBER,
        p_error_code IN NUMBER,
        p_error_msg  IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_backtrace VARCHAR2(4000);
    BEGIN
        l_backtrace := SUBSTR(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 1, 4000);

        INSERT INTO recon_error_log
               (run_id, module_name, error_code, error_message, error_backtrace)
        VALUES (p_run_id, p_module, p_error_code,
                SUBSTR(p_error_msg, 1, 4000), l_backtrace);

        COMMIT;
    END log_error;

    -- -------------------------------------------------------------------------
    PROCEDURE refresh_summary (p_run_id IN NUMBER) IS
    BEGIN
        MERGE INTO recon_summary d
        USING (SELECT run_id,
                      match_status,
                      COUNT(*)                        AS record_count,
                      NVL(SUM(ABS(diff_amount)), 0)   AS total_abs_diff
                 FROM recon_results
                WHERE run_id = p_run_id
                GROUP BY run_id, match_status) s
           ON (d.run_id = s.run_id AND d.match_status = s.match_status)
         WHEN MATCHED THEN
              UPDATE SET d.record_count   = s.record_count,
                         d.total_abs_diff = s.total_abs_diff,
                         d.refreshed_at   = SYSDATE
         WHEN NOT MATCHED THEN
              INSERT (run_id, match_status, record_count, total_abs_diff, refreshed_at)
              VALUES (s.run_id, s.match_status, s.record_count, s.total_abs_diff, SYSDATE);
    END refresh_summary;

    -- -------------------------------------------------------------------------
    PROCEDURE run_recon (
        p_run_id    OUT NUMBER,
        p_date_from IN  DATE DEFAULT NULL,
        p_date_to   IN  DATE DEFAULT NULL
    ) IS
        l_run_id    NUMBER;
        l_total     PLS_INTEGER := 0;
        l_date_from DATE := NVL(p_date_from, DATE '1900-01-01');
        l_date_to   DATE := NVL(p_date_to,   DATE '9999-12-31');

        -- One pass over both tables. A FULL OUTER JOIN returns matched rows,
        -- rows only in source and rows only in target together.
        CURSOR c_compare IS
            SELECT NVL(s.txn_ref, t.txn_ref) AS txn_ref,
                   s.txn_id                  AS src_txn_id,
                   t.txn_id                  AS tgt_txn_id,
                   s.amount                  AS src_amount,
                   t.amount                  AS tgt_amount,
                   t.amount - s.amount       AS diff_amount,
                   CASE
                       WHEN t.txn_id IS NULL THEN c_missing_in_target
                       WHEN s.txn_id IS NULL THEN c_missing_in_source
                       WHEN s.amount = t.amount THEN c_matched
                       ELSE c_amount_mismatch
                   END                       AS match_status
              FROM (SELECT txn_id, txn_ref, amount
                      FROM src_transactions
                     WHERE txn_date BETWEEN l_date_from AND l_date_to) s
              FULL OUTER JOIN
                   (SELECT txn_id, txn_ref, amount
                      FROM tgt_transactions
                     WHERE txn_date BETWEEN l_date_from AND l_date_to) t
                ON s.txn_ref = t.txn_ref
             ORDER BY 1;

        TYPE t_compare_tab IS TABLE OF c_compare%ROWTYPE;
        l_rows t_compare_tab;
    BEGIN
        IF p_date_from > p_date_to THEN
            RAISE_APPLICATION_ERROR(-20001,
                'p_date_from cannot be later than p_date_to');
        END IF;

        -- Create the run row first and commit it, so a failure later can still
        -- be recorded against a real run id.
        INSERT INTO recon_runs (date_from, date_to)
        VALUES (p_date_from, p_date_to)
        RETURNING run_id INTO l_run_id;
        COMMIT;

        p_run_id := l_run_id;

        OPEN c_compare;
        LOOP
            FETCH c_compare BULK COLLECT INTO l_rows LIMIT c_batch_limit;
            EXIT WHEN l_rows.COUNT = 0;

            FORALL i IN 1 .. l_rows.COUNT
                INSERT INTO recon_results
                       (run_id, txn_ref, src_txn_id, tgt_txn_id,
                        src_amount, tgt_amount, diff_amount, match_status)
                VALUES (l_run_id,
                        l_rows(i).txn_ref,
                        l_rows(i).src_txn_id,
                        l_rows(i).tgt_txn_id,
                        l_rows(i).src_amount,
                        l_rows(i).tgt_amount,
                        l_rows(i).diff_amount,
                        l_rows(i).match_status);

            l_total := l_total + l_rows.COUNT;
        END LOOP;
        CLOSE c_compare;

        refresh_summary(l_run_id);

        UPDATE recon_runs
           SET status        = 'COMPLETED',
               ended_at      = SYSTIMESTAMP,
               total_records = l_total
         WHERE run_id = l_run_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- Log first (autonomous), then undo this run's partial work.
            log_error('PKG_RECON.RUN_RECON', l_run_id, SQLCODE, SQLERRM);
            ROLLBACK;

            IF c_compare%ISOPEN THEN
                CLOSE c_compare;
            END IF;

            IF l_run_id IS NOT NULL THEN
                UPDATE recon_runs
                   SET status   = 'FAILED',
                       ended_at = SYSTIMESTAMP
                 WHERE run_id = l_run_id;
                COMMIT;
            END IF;

            RAISE;
    END run_recon;

    -- -------------------------------------------------------------------------
    FUNCTION get_match_rate (p_run_id IN NUMBER) RETURN NUMBER IS
        l_total   NUMBER;
        l_matched NUMBER;
    BEGIN
        SELECT COUNT(*),
               COUNT(CASE WHEN match_status = c_matched THEN 1 END)
          INTO l_total, l_matched
          FROM recon_results
         WHERE run_id = p_run_id;

        IF l_total = 0 THEN
            RETURN NULL;
        END IF;

        RETURN ROUND(l_matched / l_total * 100, 2);
    END get_match_rate;

    -- -------------------------------------------------------------------------
    PROCEDURE print_summary (p_run_id IN NUMBER) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Reconciliation run ' || p_run_id);
        DBMS_OUTPUT.PUT_LINE(RPAD('STATUS', 22) || LPAD('COUNT', 8) || LPAD('ABS DIFF', 14));
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 44, '-'));

        FOR r IN (SELECT match_status, record_count, total_abs_diff
                    FROM recon_summary
                   WHERE run_id = p_run_id
                   ORDER BY match_status)
        LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(r.match_status, 22) ||
                LPAD(TO_CHAR(r.record_count), 8) ||
                LPAD(TO_CHAR(r.total_abs_diff, 'FM999,999,990.00'), 14));
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('Match rate: ' || NVL(TO_CHAR(get_match_rate(p_run_id)), 'n/a') || '%');
    END print_summary;

END pkg_recon;
/
