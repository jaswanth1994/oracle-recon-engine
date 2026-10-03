-- =============================================================================
-- 01_transaction_tables.sql
-- Purpose : The two data sets that get reconciled.
--             SRC_TRANSACTIONS = what the bank statement says (source)
--             TGT_TRANSACTIONS = what our ledger says (target)
-- Requires: Oracle 12c or later (identity columns)
-- =============================================================================

CREATE TABLE src_transactions (
    txn_id        NUMBER GENERATED ALWAYS AS IDENTITY
                  CONSTRAINT pk_src_transactions PRIMARY KEY,
    txn_ref       VARCHAR2(30)  NOT NULL,
    account_no    VARCHAR2(20)  NOT NULL,
    txn_date      DATE          NOT NULL,
    amount        NUMBER(15,2)  NOT NULL,
    currency      VARCHAR2(3)   DEFAULT 'INR' NOT NULL,
    description   VARCHAR2(200),
    created_by    VARCHAR2(50),
    created_date  DATE,
    updated_by    VARCHAR2(50),
    updated_date  DATE,
    CONSTRAINT uq_src_txn_ref UNIQUE (txn_ref)
);

COMMENT ON TABLE  src_transactions         IS 'Source-side transactions (e.g. bank statement feed)';
COMMENT ON COLUMN src_transactions.txn_ref IS 'Business key used to match a source row to a target row';

CREATE INDEX idx_src_txn_date ON src_transactions (txn_date);


CREATE TABLE tgt_transactions (
    txn_id        NUMBER GENERATED ALWAYS AS IDENTITY
                  CONSTRAINT pk_tgt_transactions PRIMARY KEY,
    txn_ref       VARCHAR2(30)  NOT NULL,
    account_no    VARCHAR2(20)  NOT NULL,
    txn_date      DATE          NOT NULL,
    amount        NUMBER(15,2)  NOT NULL,
    currency      VARCHAR2(3)   DEFAULT 'INR' NOT NULL,
    description   VARCHAR2(200),
    created_by    VARCHAR2(50),
    created_date  DATE,
    updated_by    VARCHAR2(50),
    updated_date  DATE,
    CONSTRAINT uq_tgt_txn_ref UNIQUE (txn_ref)
);

COMMENT ON TABLE  tgt_transactions         IS 'Target-side transactions (e.g. internal ledger)';
COMMENT ON COLUMN tgt_transactions.txn_ref IS 'Business key used to match a target row to a source row';

CREATE INDEX idx_tgt_txn_date ON tgt_transactions (txn_date);
