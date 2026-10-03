-- =============================================================================
-- 02_recon_tables.sql
-- Purpose : Tables that store the output of a reconciliation run.
--             RECON_RUNS       one row per execution of PKG_RECON.RUN_RECON
--             RECON_RESULTS    one row per transaction reference compared
--             RECON_SUMMARY    counts and differences per status, per run
--             RECON_ERROR_LOG  errors written by PKG_RECON.LOG_ERROR
-- =============================================================================

CREATE TABLE recon_runs (
    run_id         NUMBER GENERATED ALWAYS AS IDENTITY
                   CONSTRAINT pk_recon_runs PRIMARY KEY,
    run_date       DATE          DEFAULT SYSDATE      NOT NULL,
    date_from      DATE,
    date_to        DATE,
    status         VARCHAR2(15)  DEFAULT 'RUNNING'    NOT NULL,
    started_at     TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    ended_at       TIMESTAMP,
    total_records  NUMBER        DEFAULT 0            NOT NULL,
    CONSTRAINT ck_recon_runs_status
        CHECK (status IN ('RUNNING', 'COMPLETED', 'FAILED'))
);

COMMENT ON TABLE recon_runs IS 'One row per reconciliation run';


CREATE TABLE recon_results (
    result_id     NUMBER GENERATED ALWAYS AS IDENTITY
                  CONSTRAINT pk_recon_results PRIMARY KEY,
    run_id        NUMBER        NOT NULL
                  CONSTRAINT fk_results_run REFERENCES recon_runs (run_id),
    txn_ref       VARCHAR2(30)  NOT NULL,
    src_txn_id    NUMBER,
    tgt_txn_id    NUMBER,
    src_amount    NUMBER(15,2),
    tgt_amount    NUMBER(15,2),
    diff_amount   NUMBER(15,2),
    match_status  VARCHAR2(25)  NOT NULL,
    created_date  DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT ck_results_status CHECK (match_status IN
        ('MATCHED', 'AMOUNT_MISMATCH', 'MISSING_IN_TARGET', 'MISSING_IN_SOURCE'))
);

COMMENT ON TABLE  recon_results             IS 'Outcome for every transaction reference compared in a run';
COMMENT ON COLUMN recon_results.diff_amount IS 'Target amount minus source amount; NULL when one side is missing';

CREATE INDEX idx_results_run_status ON recon_results (run_id, match_status);


CREATE TABLE recon_summary (
    run_id          NUMBER        NOT NULL
                    CONSTRAINT fk_summary_run REFERENCES recon_runs (run_id),
    match_status    VARCHAR2(25)  NOT NULL,
    record_count    NUMBER        NOT NULL,
    total_abs_diff  NUMBER(17,2)  DEFAULT 0 NOT NULL,
    refreshed_at    DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_recon_summary PRIMARY KEY (run_id, match_status)
);

COMMENT ON TABLE recon_summary IS 'Roll-up of RECON_RESULTS by status for each run';


CREATE TABLE recon_error_log (
    error_id         NUMBER GENERATED ALWAYS AS IDENTITY
                     CONSTRAINT pk_recon_error_log PRIMARY KEY,
    logged_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    run_id           NUMBER,
    module_name      VARCHAR2(100),
    error_code       NUMBER,
    error_message    VARCHAR2(4000),
    error_backtrace  VARCHAR2(4000),
    logged_by        VARCHAR2(50)  DEFAULT USER
);

COMMENT ON TABLE recon_error_log IS 'Errors captured by PKG_RECON; written in an autonomous transaction';
