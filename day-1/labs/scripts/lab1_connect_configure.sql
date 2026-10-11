-- =====================================================================
-- Lab 1  Connect and configure: check your containers, services and parameters
-- Run as SYSTEM in the ROOT container (CDB$ROOT):
--   SQL Developer: connection SYSTEM, service name ORCL (yours may differ)
--   SQL*Plus:      sqlplus system/<password>@//localhost:1521/ORCL @lab1_connect_configure.sql
-- Read your service names from lsnrctl status (Lab 1, step 1).
-- Read each result and answer the worksheet question next to it.
-- =====================================================================

SET LINESIZE 200 PAGESIZE 100
COLUMN name           FORMAT A30
COLUMN value          FORMAT A40
COLUMN banner_full    FORMAT A80
COLUMN con_name       FORMAT A12
COLUMN instance_name  FORMAT A16
COLUMN state          FORMAT A10
COLUMN network_name   FORMAT A40
COLUMN property_value FORMAT A20
COLUMN issys_modifiable FORMAT A16

PROMPT === 1. Version and container ===============================
SELECT banner_full FROM v$version;
SHOW CON_NAME

PROMPT === 2. Pluggable databases and their open mode =============
SELECT con_id, name, open_mode, restricted
FROM   v$pdbs
ORDER  BY con_id;

PROMPT === 3. Saved PDB states (empty = PDB stays MOUNTED after a restart)
SELECT con_name, instance_name, state
FROM   dba_pdb_saved_states;

PROMPT === 4. Services the database registers with the listener ===
SELECT name, network_name, con_id
FROM   v$services
ORDER  BY con_id, name;

PROMPT === 5. Database character set ===============================
SELECT property_value
FROM   database_properties
WHERE  property_name = 'NLS_CHARACTERSET';

PROMPT === 6. Where the parameters come from ======================
SHOW PARAMETER spfile

PROMPT === 7. A few parameters: value, and can they change while running?
SELECT name, value, isdefault, issys_modifiable, ispdb_modifiable
FROM   v$parameter
WHERE  name IN ('db_name', 'db_block_size', 'sga_target', 'pga_aggregate_target',
                'sga_max_size', 'open_cursors', 'undo_retention', 'local_listener')
ORDER  BY name;

-- Next: connect as SYSTEM to your PDB service and run lab0_oracle_create_user.sql
