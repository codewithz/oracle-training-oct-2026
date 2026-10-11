-- =====================================================================
-- Lab 2  Inside your instance, part 3: the data dictionary
-- Run as FAB_LAB (password Lab_2026) in your pluggable database:
--   SQL*Plus: sqlplus fab_lab/Lab_2026@//localhost:1521/ORCLPDB @lab2_dictionary.sql
-- Every tool you use (SQL Developer included) reads these same views.
-- =====================================================================

SET LINESIZE 200 PAGESIZE 100
COLUMN table_name      FORMAT A14
COLUMN column_name     FORMAT A16
COLUMN data_type       FORMAT A10
COLUMN constraint_name FORMAT A24
COLUMN r_table         FORMAT A14
COLUMN index_name      FORMAT A24
COLUMN segment_name    FORMAT A24
COLUMN tablespace_name FORMAT A10

PROMPT === 1. My tables and the tablespace they live in ===========
SELECT table_name, tablespace_name
FROM   user_tables
ORDER  BY table_name;

PROMPT === 2. Columns of LOTS =====================================
SELECT column_name, data_type, data_length, nullable
FROM   user_tab_columns
WHERE  table_name = 'LOTS'
ORDER  BY column_id;

PROMPT === 3. Foreign keys: which table points to which ===========
SELECT c.table_name, c.constraint_name, p.table_name AS r_table
FROM   user_constraints c
JOIN   user_constraints p ON p.constraint_name = c.r_constraint_name
WHERE  c.constraint_type = 'R'
ORDER  BY c.table_name, c.constraint_name;

PROMPT === 4. Indexes, and the column each one covers =============
SELECT i.table_name, i.index_name, ic.column_name, i.uniqueness
FROM   user_indexes i
JOIN   user_ind_columns ic ON ic.index_name = i.index_name
ORDER  BY i.table_name, i.index_name, ic.column_position;

PROMPT === 5. Space used by each segment ==========================
SELECT segment_name, segment_type, tablespace_name, extents, bytes / 1024 AS kb
FROM   user_segments
ORDER  BY bytes DESC, segment_name;

PROMPT === 6. Find a dictionary view by name: views about constraints
COLUMN view_name FORMAT A30
SELECT table_name AS view_name
FROM   dictionary
WHERE  table_name LIKE 'USER_CONS%'
ORDER  BY table_name;
