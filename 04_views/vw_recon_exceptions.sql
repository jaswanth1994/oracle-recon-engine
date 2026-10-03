-- =============================================================================
-- vw_recon_exceptions.sql
-- Purpose : Everything that did NOT match, with account and date details, and
--           a rank so the largest problems in each status come first.
--           Filter on run_id when querying.
-- =============================================================================

CREATE OR REPLACE VIEW vw_recon_exceptions AS
SELECT rr.run_id,
       rr.match_status,
       rr.txn_ref,
       COALESCE(s.account_no, t.account_no) AS account_no,
       COALESCE(s.txn_date,   t.txn_date)   AS txn_date,
       rr.src_amount,
       rr.tgt_amount,
       rr.diff_amount,
       ROW_NUMBER() OVER (
           PARTITION BY rr.run_id, rr.match_status
           ORDER BY ABS(COALESCE(rr.diff_amount, rr.src_amount, rr.tgt_amount)) DESC
       ) AS rank_in_status
  FROM recon_results rr
  LEFT JOIN src_transactions s ON s.txn_id = rr.src_txn_id
  LEFT JOIN tgt_transactions t ON t.txn_id = rr.tgt_txn_id
 WHERE rr.match_status <> 'MATCHED';
