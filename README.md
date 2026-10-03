# Oracle Reconciliation Engine (SQL + PL/SQL)

A small Oracle project that compares two sets of financial transactions, for example a **bank statement (source)** and an **internal ledger (target)**, and reports what matched and what did not.

Reconciliation is a routine task in banking and finance systems. This project shows how to do it in pure SQL and PL/SQL with clean structure, error handling and automated checks.

## What it does

For every transaction reference found in either table, the engine assigns one status:

| Status | Meaning |
|---|---|
| `MATCHED` | Present on both sides with the same amount |
| `AMOUNT_MISMATCH` | Present on both sides but the amounts differ |
| `MISSING_IN_TARGET` | In the source only |
| `MISSING_IN_SOURCE` | In the target only |

Each run is stored with its results, a per-status summary, and a log of any errors.

## Techniques demonstrated

- `FULL OUTER JOIN` to find matches and gaps on both sides in a single pass
- Explicit cursor with `BULK COLLECT ... LIMIT` and `FORALL` for fast batch inserts
- `MERGE` to rebuild the summary table (safe to re-run)
- Analytic functions: `RATIO_TO_REPORT` and `ROW_NUMBER`
- Packages with a separate specification and body, constants and a user-defined exception
- Error logging with `PRAGMA AUTONOMOUS_TRANSACTION`, so log entries survive a rollback
- Audit triggers that fill created/updated columns automatically
- Identity columns, constraints, check constraints and indexes
- A self-checking test script with PASS/FAIL output

## Project structure

```
oracle-recon-engine/
├── README.md
├── run_all.sql                    builds everything and runs the tests
├── demo.sql                       runs a reconciliation and prints a report
├── 01_tables/
│   ├── 00_drop_objects.sql        clean-up so scripts can be re-run
│   ├── 01_transaction_tables.sql  SRC_TRANSACTIONS, TGT_TRANSACTIONS
│   ├── 02_recon_tables.sql        RECON_RUNS, RECON_RESULTS, RECON_SUMMARY, RECON_ERROR_LOG
│   └── 03_audit_triggers.sql      audit column triggers
├── 02_sample_data/
│   └── 01_sample_data.sql         fictitious data covering every status
├── 03_packages/
│   ├── pkg_recon.pks              package specification
│   └── pkg_recon.pkb              package body
├── 04_views/
│   ├── vw_recon_summary.sql       status counts with percentage of run
│   └── vw_recon_exceptions.sql    unmatched items ranked by size
└── 05_tests/
    └── test_pkg_recon.sql         automated checks
```

## Requirements

- Oracle Database **12c or later** (the tables use identity columns). Oracle XE is free.
- SQL*Plus, SQLcl or SQL Developer
- A practice schema with privileges to create tables, triggers, views and packages

## How to run

1. Clone the repository and open a terminal in the project folder.
2. Connect to your Oracle schema, for example `sqlplus user/password@localhost/XEPDB1`.
3. Build everything and run the tests:
   ```sql
   @run_all.sql
   ```
4. See a report:
   ```sql
   @demo.sql
   ```

`run_all.sql` begins by dropping this project's tables, so use a practice schema.

## Using the package

```sql
SET SERVEROUTPUT ON

DECLARE
    l_run_id NUMBER;
BEGIN
    -- Reconcile everything
    pkg_recon.run_recon(l_run_id);
    pkg_recon.print_summary(l_run_id);

    -- Or reconcile a date range only
    pkg_recon.run_recon(l_run_id, DATE '2026-09-01', DATE '2026-09-02');
END;
/
```

Query the results:

```sql
-- Everything that did not match, largest differences first
SELECT * FROM vw_recon_exceptions
 WHERE run_id = :run_id
 ORDER BY match_status, rank_in_status;

-- Share of each status in a run
SELECT * FROM vw_recon_summary WHERE run_id = :run_id;
```

## Expected output with the sample data

The sample data holds 14 distinct transaction references. A full run should give:

```
Reconciliation run 1
STATUS                   COUNT      ABS DIFF
--------------------------------------------
AMOUNT_MISMATCH              3      1,400.27
MATCHED                      7          0.00
MISSING_IN_SOURCE            2          0.00
MISSING_IN_TARGET            2          0.00
Match rate: 50%
```

The run number depends on how many runs already exist in your schema.

## Public interface of `PKG_RECON`

| Subprogram | Purpose |
|---|---|
| `run_recon(p_run_id OUT, p_date_from, p_date_to)` | Runs a reconciliation; dates are optional and inclusive |
| `refresh_summary(p_run_id)` | Rebuilds the summary rows for a run using `MERGE` |
| `get_match_rate(p_run_id)` | Returns the percentage of references that matched |
| `print_summary(p_run_id)` | Prints a summary with `DBMS_OUTPUT` |
| `log_error(...)` | Writes to `RECON_ERROR_LOG` in an autonomous transaction |

## Design notes

- **Match key:** transactions are matched on `txn_ref`, which is unique on each side.
- **Run tracking:** the run row is committed before processing starts, so a failed run can be marked `FAILED` and its error logged against a real run id.
- **Batch size:** the cursor fetches 500 rows at a time. This is a constant in the package body and easy to tune.
- **Sign of differences:** `diff_amount = target amount - source amount`.
- **All data is fictitious.** No real account or client data is used.

## Testing

`05_tests/test_pkg_recon.sql` checks, among other things:

- The audit trigger fills its columns
- Counts for each status on a full run
- The run row ends as `COMPLETED` with the right record count
- Summary totals and that refreshing the summary twice does not duplicate rows
- The date filter
- An invalid date range raises `e_invalid_date_range` and is logged

Each check prints `PASS` or `FAIL`, followed by a total.

## Possible enhancements

- Match on account number and currency as well as reference
- Add an amount tolerance (for example, treat differences under 0.01 as matched)
- Handle duplicate references with a one-to-many matching rule
- Use `FORALL ... SAVE EXCEPTIONS` for row-level error handling
- Schedule runs with `DBMS_SCHEDULER`
- Load source and target data from external tables or CSV files

## Author

Jaswanth Antony Jais, Oracle PL/SQL Developer
