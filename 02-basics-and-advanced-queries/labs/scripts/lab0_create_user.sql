-- =====================================================================
-- FALLBACK ONLY: create FAB_LAB when you are connected to the ROOT (orcl)
-- and not to a PDB. Use lab0_create_user.sql instead whenever you can
-- connect to your PDB (orclpdb).
-- Run as SYSTEM, connected to orcl. Safe to run more than once.
-- The hidden parameter below lets a plain user name (no C## prefix)
-- be created in the root. It is meant for a throwaway training laptop.
-- =====================================================================

ALTER SESSION SET "_ORACLE_SCRIPT" = TRUE;

BEGIN
  EXECUTE IMMEDIATE 'DROP USER fab_lab CASCADE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1918 THEN RAISE; END IF;   -- -1918 = user does not exist yet
END;
/

CREATE USER fab_lab IDENTIFIED BY "Lab_2026"
  DEFAULT TABLESPACE users
  QUOTA UNLIMITED ON users;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE SYNONYM, CREATE TYPE
TO fab_lab;

GRANT SELECT_CATALOG_ROLE TO fab_lab;
