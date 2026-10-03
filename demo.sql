-- =============================================================================
-- demo.sql
-- Purpose : Run one reconciliation and print the results.
-- Usage   : @demo.sql   (after run_all.sql has been executed)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 150
SET PAGESIZE 50
COLUMN match_status FORMAT A20
COLUMN txn_ref      FORMAT A10
COLUMN account_no   FORMAT A10

DECLARE
    l_run_id NUMBER;
BEGIN
    pkg_recon.run_recon(l_run_id);
    pkg_recon.print_summary(l_run_id);
END;
/

PROMPT
PROMPT Exceptions from the latest run (largest difference first within each status):

SELECT match_status, txn_ref, account_no, txn_date,
       src_amount, tgt_amount, diff_amount
  FROM vw_recon_exceptions
 WHERE run_id = (SELECT MAX(run_id) FROM recon_runs)
 ORDER BY match_status, rank_in_status;

PROMPT
PROMPT Percentage split of the latest run:

SELECT match_status, record_count, pct_of_run
  FROM vw_recon_summary
 WHERE run_id = (SELECT MAX(run_id) FROM recon_runs)
 ORDER BY match_status;
