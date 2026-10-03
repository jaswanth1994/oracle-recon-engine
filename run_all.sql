-- =============================================================================
-- run_all.sql
-- Purpose : Build the whole project in one go.
-- Usage   : cd into this folder, connect with SQL*Plus / SQLcl and run
--               @run_all.sql
--           (SQL Developer: open this file and press "Run Script", F5.)
-- WARNING : Starts by dropping this project's tables, so use a practice schema.
-- =============================================================================

SET ECHO OFF
SET FEEDBACK ON
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT === 1/6 Dropping old objects (objects that do not exist yet are skipped) ===
@@01_tables/00_drop_objects.sql

PROMPT === 2/6 Creating tables and triggers ===
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
@@01_tables/01_transaction_tables.sql
@@01_tables/02_recon_tables.sql
@@01_tables/03_audit_triggers.sql

PROMPT === 3/6 Loading sample data ===
@@02_sample_data/01_sample_data.sql

PROMPT === 4/6 Compiling package ===
@@03_packages/pkg_recon.pks
@@03_packages/pkg_recon.pkb
SHOW ERRORS

PROMPT === 5/6 Creating views ===
@@04_views/vw_recon_summary.sql
@@04_views/vw_recon_exceptions.sql

PROMPT === 6/6 Running tests ===
@@05_tests/test_pkg_recon.sql

PROMPT
PROMPT Done. Run  @demo.sql  to see a reconciliation report.
