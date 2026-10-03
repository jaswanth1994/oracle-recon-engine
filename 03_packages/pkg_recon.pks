-- =============================================================================
-- pkg_recon.pks  (package specification)
-- Purpose : Public interface of the reconciliation engine.
--
-- Typical use:
--     DECLARE
--         l_run_id NUMBER;
--     BEGIN
--         pkg_recon.run_recon(l_run_id);          -- all dates
--         pkg_recon.print_summary(l_run_id);
--     END;
-- =============================================================================

CREATE OR REPLACE PACKAGE pkg_recon AS

    -- Match status codes. Kept here so the package, tests and callers agree.
    c_matched            CONSTANT VARCHAR2(25) := 'MATCHED';
    c_amount_mismatch    CONSTANT VARCHAR2(25) := 'AMOUNT_MISMATCH';
    c_missing_in_target  CONSTANT VARCHAR2(25) := 'MISSING_IN_TARGET';
    c_missing_in_source  CONSTANT VARCHAR2(25) := 'MISSING_IN_SOURCE';

    -- Raised as ORA-20001 when p_date_from is later than p_date_to.
    e_invalid_date_range EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_invalid_date_range, -20001);

    /*
     * Writes one row to RECON_ERROR_LOG using an autonomous transaction, so the
     * log entry survives even if the caller rolls back.
     */
    PROCEDURE log_error (
        p_module     IN VARCHAR2,
        p_run_id     IN NUMBER,
        p_error_code IN NUMBER,
        p_error_msg  IN VARCHAR2
    );

    /*
     * Compares SRC_TRANSACTIONS with TGT_TRANSACTIONS on TXN_REF.
     * Both date parameters are optional and inclusive; NULL means "no limit".
     * Returns the id of the new run in p_run_id.
     */
    PROCEDURE run_recon (
        p_run_id    OUT NUMBER,
        p_date_from IN  DATE DEFAULT NULL,
        p_date_to   IN  DATE DEFAULT NULL
    );

    /*
     * Rebuilds the RECON_SUMMARY rows for one run using MERGE.
     * Safe to call repeatedly. Does not commit; the caller decides.
     */
    PROCEDURE refresh_summary (p_run_id IN NUMBER);

    /*
     * Percentage of compared references that matched exactly (0-100).
     * Returns NULL if the run has no results.
     */
    FUNCTION get_match_rate (p_run_id IN NUMBER) RETURN NUMBER;

    /* Prints a readable summary of one run using DBMS_OUTPUT. */
    PROCEDURE print_summary (p_run_id IN NUMBER);

END pkg_recon;
/
