-- =============================================================================
-- vw_recon_summary.sql
-- Purpose : Per-run summary with each status shown as a percentage of the run.
--           RATIO_TO_REPORT is an analytic function, so no self-join is needed.
-- =============================================================================

CREATE OR REPLACE VIEW vw_recon_summary AS
SELECT s.run_id,
       r.run_date,
       s.match_status,
       s.record_count,
       s.total_abs_diff,
       ROUND(RATIO_TO_REPORT(s.record_count) OVER (PARTITION BY s.run_id) * 100, 2) AS pct_of_run
  FROM recon_summary s
  JOIN recon_runs    r ON r.run_id = s.run_id;
