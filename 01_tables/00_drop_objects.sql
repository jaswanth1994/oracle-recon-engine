-- =============================================================================
-- 00_drop_objects.sql
-- Purpose : Drop every object created by this project so the scripts can be
--           re-run from scratch. Objects that do not exist yet are skipped.
-- WARNING : Deletes all project data. Run only in your own practice schema.
-- =============================================================================

SET SERVEROUTPUT ON

DECLARE
    PROCEDURE drop_if_exists (p_stmt IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_stmt;
        DBMS_OUTPUT.PUT_LINE('DROPPED : ' || p_stmt);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('SKIPPED : ' || p_stmt);
    END drop_if_exists;
BEGIN
    drop_if_exists('DROP PACKAGE pkg_recon');
    drop_if_exists('DROP VIEW vw_recon_exceptions');
    drop_if_exists('DROP VIEW vw_recon_summary');
    drop_if_exists('DROP TABLE recon_error_log PURGE');
    drop_if_exists('DROP TABLE recon_summary PURGE');
    drop_if_exists('DROP TABLE recon_results PURGE');
    drop_if_exists('DROP TABLE recon_runs PURGE');
    drop_if_exists('DROP TABLE tgt_transactions PURGE');
    drop_if_exists('DROP TABLE src_transactions PURGE');
END;
/
