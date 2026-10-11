-- =====================================================================
-- Lab 2  Inside your instance: memory, processes and files
-- Run as SYSTEM. Sections 1 to 5 in the ROOT container (CDB$ROOT),
-- section 6 in the pluggable database:
--   SQL Developer: connection SYSTEM to service ORCL (root), then ORCLPDB
--   SQL*Plus:      sqlplus system/<password>@//localhost:1521/ORCL @lab2_explore_instance.sql
-- Your service names may differ: read them from lsnrctl status (Lab 1, step 1).
-- Read each result and answer the worksheet question next to it.
-- =====================================================================

SET LINESIZE 200 PAGESIZE 100
COLUMN name           FORMAT A30
COLUMN value          FORMAT A40
COLUMN member         FORMAT A60
COLUMN file_name      FORMAT A60
COLUMN description    FORMAT A40
COLUMN host_name      FORMAT A20
COLUMN instance_name  FORMAT A16
COLUMN pdb_name       FORMAT A12

PROMPT === 1. Which container am I in? ==========================
SHOW CON_NAME

PROMPT === 2. Instance and database ==============================
SELECT instance_name, host_name, version_full, status, startup_time
FROM   v$instance;

SELECT name, cdb, log_mode, open_mode, database_role
FROM   v$database;

PROMPT === 3. Containers (root, seed, pluggable databases) =======
SELECT con_id, name, open_mode
FROM   v$containers
ORDER  BY con_id;

PROMPT === 4. Memory: SGA components and PGA =====================
SELECT name, ROUND(bytes/1024/1024) AS mb
FROM   v$sgainfo
WHERE  name IN ('Fixed SGA Size','Redo Buffers','Buffer Cache Size',
                'Shared Pool Size','Large Pool Size','Java Pool Size',
                'Maximum SGA Size')
ORDER  BY bytes DESC;

SELECT name, value
FROM   v$parameter
WHERE  name IN ('sga_target','pga_aggregate_target','memory_target',
                'db_block_size','processes','undo_tablespace')
ORDER  BY name;

PROMPT === 5. Background processes and files =====================
-- Running background processes (DBWn, LGWR, CKPT, SMON, PMON, ...)
SELECT COUNT(*) AS running_background_processes
FROM   v$bgprocess
WHERE  paddr <> '00';

-- The core ones every instance has (ARC0 only runs in ARCHIVELOG mode)
SELECT name, description
FROM   v$bgprocess
WHERE  paddr <> '00'
AND    name IN ('PMON','SMON','DBW0','LGWR','CKPT','MMON','MMAN','RECO','LREG','ARC0','CJQ0')
ORDER  BY name;

-- Control files
COLUMN name FORMAT A60
SELECT name FROM v$controlfile;
COLUMN name FORMAT A30

-- Online redo log groups and their members
SELECT l.group#, l.sequence#, ROUND(l.bytes/1024/1024) AS mb, l.status, f.member
FROM   v$log l JOIN v$logfile f ON f.group# = l.group#
ORDER  BY l.group#;

-- Data files of every container, by tablespace
SELECT c.name AS pdb_name, t.name AS tablespace, ROUND(d.bytes/1024/1024) AS mb
FROM   v$datafile d
JOIN   v$tablespace t ON t.ts# = d.ts# AND t.con_id = d.con_id
JOIN   v$containers c ON c.con_id = d.con_id
ORDER  BY c.con_id, t.name;

PROMPT === 6. Now connect to the PDB and run this part ===========
PROMPT   (SQL Developer: switch connection; SQL*Plus: CONNECT system@//localhost:1521/ORCLPDB)
-- Who is connected, and with which tool?
-- SELECT username, program, status FROM v$session WHERE username IS NOT NULL;
-- The lab schema after fab_lab_data.sql:
-- SELECT table_name, num_rows FROM dba_tables WHERE owner = 'FAB_LAB' ORDER BY table_name;
-- SELECT segment_name, segment_type, bytes/1024 AS kb FROM dba_segments WHERE owner = 'FAB_LAB' ORDER BY bytes DESC;
