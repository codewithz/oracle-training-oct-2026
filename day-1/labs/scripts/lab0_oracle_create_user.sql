-- =====================================================================
-- Course setup: create the lab user FAB_LAB (Oracle 19c). Used all 4 days.
-- Run as SYSTEM, connected to the PLUGGABLE database (not the root CDB):
--   SQL Developer: connection SYSTEM, service name ORCLPDB (yours may differ)
--   SQL*Plus:      sqlplus system/<password>@//localhost:1521/ORCLPDB @lab0_oracle_create_user.sql
-- Check you are in the PDB first:  SHOW CON_NAME  must not say CDB$ROOT.
--
-- Re-running this script drops FAB_LAB and everything in it (the error
-- ORA-01918 "user does not exist" on the first run is expected).
-- =====================================================================

DROP USER fab_lab CASCADE;

CREATE USER fab_lab IDENTIFIED BY "Lab_2026"
  DEFAULT TABLESPACE users
  QUOTA UNLIMITED ON users;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE SYNONYM, CREATE TYPE
TO fab_lab;

-- Read the data dictionary and V$ views (Day 1 architecture lab, Day 4 plans)
GRANT SELECT_CATALOG_ROLE TO fab_lab;
-- Oracle Text, for the full-text search topic on Day 4. ORA-01919 here means
-- Oracle Text is not installed in this database. Day 1 does not need it;
-- tell your trainer so it can be fixed before Day 4.
GRANT CTXAPP TO fab_lab;

-- Next: connect as FAB_LAB (password Lab_2026) and run fab_lab_data.sql
