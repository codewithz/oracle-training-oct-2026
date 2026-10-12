-- =====================================================================
-- Basics course: create the lab user FAB_LAB
-- Run as SYSTEM, connected to your PLUGGABLE database (the PDB).
-- Safe to run more than once: it drops FAB_LAB first if it exists.
-- =====================================================================

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
