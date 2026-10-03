-- =============================================================================
-- 03_audit_triggers.sql
-- Purpose : Fill the audit columns (created_by, created_date, updated_by,
--           updated_date) automatically so application code never has to.
-- =============================================================================

CREATE OR REPLACE TRIGGER trg_src_transactions_audit
    BEFORE INSERT OR UPDATE ON src_transactions
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_by   := USER;
        :NEW.created_date := SYSDATE;
    END IF;

    :NEW.updated_by   := USER;
    :NEW.updated_date := SYSDATE;
END trg_src_transactions_audit;
/

CREATE OR REPLACE TRIGGER trg_tgt_transactions_audit
    BEFORE INSERT OR UPDATE ON tgt_transactions
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_by   := USER;
        :NEW.created_date := SYSDATE;
    END IF;

    :NEW.updated_by   := USER;
    :NEW.updated_date := SYSDATE;
END trg_tgt_transactions_audit;
/
