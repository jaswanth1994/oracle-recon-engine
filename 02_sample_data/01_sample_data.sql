-- =============================================================================
-- 01_sample_data.sql
-- Purpose : Small, completely fictitious data set that exercises every
--           reconciliation outcome.
--
-- Expected result of a full run on this data (14 references in total):
--   MATCHED            7   TXN1001, 1002, 1003, 1005, 1006, 1008, 1009
--   AMOUNT_MISMATCH    3   TXN1004 (+500.00), TXN1007 (-900.00), TXN1010 (+0.27)
--   MISSING_IN_TARGET  2   TXN1011, TXN1012  (in source only)
--   MISSING_IN_SOURCE  2   TXN2001, TXN2002  (in target only)
-- =============================================================================

-- ---------- Source (bank statement) ------------------------------------------
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1001', 'ACC1001', DATE '2026-09-01', 15000.00, 'INR', 'Salary credit');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1002', 'ACC1001', DATE '2026-09-01',  2500.50, 'INR', 'Electricity bill');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1003', 'ACC1002', DATE '2026-09-02',   780.00, 'INR', 'Online purchase');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1004', 'ACC1002', DATE '2026-09-02', 12000.00, 'INR', 'Rent payment');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1005', 'ACC1003', DATE '2026-09-03', 45000.00, 'INR', 'Vendor payment');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1006', 'ACC1003', DATE '2026-09-03',   320.75, 'INR', 'Fuel');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1007', 'ACC1004', DATE '2026-09-04',  9999.99, 'INR', 'Insurance premium');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1008', 'ACC1004', DATE '2026-09-04',   150.00, 'INR', 'Subscription');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1009', 'ACC1005', DATE '2026-09-05', 62000.00, 'INR', 'Cash deposit');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1010', 'ACC1005', DATE '2026-09-05',   410.25, 'INR', 'Grocery');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1011', 'ACC1001', DATE '2026-09-06',  5000.00, 'INR', 'Loan EMI');
INSERT INTO src_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1012', 'ACC1002', DATE '2026-09-06',   275.00, 'INR', 'Mobile recharge');

-- ---------- Target (internal ledger) -----------------------------------------
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1001', 'ACC1001', DATE '2026-09-01', 15000.00, 'INR', 'Salary credit');
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1002', 'ACC1001', DATE '2026-09-01',  2500.50, 'INR', 'Electricity bill');
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1003', 'ACC1002', DATE '2026-09-02',   780.00, 'INR', 'Online purchase');
-- Amount differs from source (12000.00)
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1004', 'ACC1002', DATE '2026-09-02', 12500.00, 'INR', 'Rent payment');
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1005', 'ACC1003', DATE '2026-09-03', 45000.00, 'INR', 'Vendor payment');
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1006', 'ACC1003', DATE '2026-09-03',   320.75, 'INR', 'Fuel');
-- Amount differs from source (9999.99)
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1007', 'ACC1004', DATE '2026-09-04',  9099.99, 'INR', 'Insurance premium');
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1008', 'ACC1004', DATE '2026-09-04',   150.00, 'INR', 'Subscription');
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1009', 'ACC1005', DATE '2026-09-05', 62000.00, 'INR', 'Cash deposit');
-- Digits transposed vs source (410.25)
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN1010', 'ACC1005', DATE '2026-09-05',   410.52, 'INR', 'Grocery');
-- TXN1011 and TXN1012 are deliberately absent from the target.
-- The two rows below are deliberately absent from the source.
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN2001', 'ACC1003', DATE '2026-09-07',  1800.00, 'INR', 'Bank charges');
INSERT INTO tgt_transactions (txn_ref, account_no, txn_date, amount, currency, description)
VALUES ('TXN2002', 'ACC1004', DATE '2026-09-07',   640.00, 'INR', 'Interest adjustment');

COMMIT;
