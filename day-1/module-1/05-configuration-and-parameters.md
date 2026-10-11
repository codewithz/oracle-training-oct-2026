# Configuration and parameters

This page covers the two settings to get right after every install. The first is how initialization parameters work: where they are stored (spfile or pfile), how to read them from `V$PARAMETER`, and how `ALTER SYSTEM ... SCOPE` decides whether a change is temporary or permanent. The second is saving the open state of your PDB so that it opens by itself after a restart.

Slides: 10 of the Day 1 deck.

## Initialization parameters

An Oracle instance is configured by **initialization parameters**: a few hundred named settings that the instance reads when it starts. They decide, among other things, how much memory the instance uses (`sga_target`, `pga_aggregate_target`), where the control files are (`control_files`), how many processes may connect (`processes`), the database block size (`db_block_size`) and default formats for sessions (`nls_date_format`).

Most parameters have sensible defaults, and DBCA sets the ones that must be set. As a developer you will mostly read parameters. As a DBA you will change a few.

### Showing a parameter

In SQL*Plus or a SQL Developer worksheet, `SHOW PARAMETER` lists every parameter whose name contains the text you give:

```sql
SHOW PARAMETER open_cursors
```

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
open_cursors                         integer     300
```

The same information, with more detail, is in the view `V$PARAMETER`. Its most useful columns tell you whether and how a parameter can be changed:

| Column | Values and meaning |
| --- | --- |
| `VALUE` | The value in effect for your session |
| `ISDEFAULT` | `TRUE` if the parameter was not set in the parameter file |
| `ISSES_MODIFIABLE` | `TRUE` if you can change it for your own session with `ALTER SESSION` |
| `ISSYS_MODIFIABLE` | `IMMEDIATE`: `ALTER SYSTEM` changes it at once. `DEFERRED`: the change applies to new sessions. `FALSE`: a **static** parameter, which only changes at the next instance start |
| `ISPDB_MODIFIABLE` | `TRUE` if it can be set to a different value inside a PDB |

As SYSTEM on the test database (a small 21c XE install, so your values may differ):

```sql
SELECT name, value, isses_modifiable, issys_modifiable, ispdb_modifiable
FROM   v$parameter
WHERE  name IN ('open_cursors', 'nls_date_format', 'db_block_size', 'sga_max_size')
ORDER  BY name;
```

```text
NAME             VALUE        ISSES ISSYS_MOD ISPDB
---------------- ------------ ----- --------- -----
db_block_size    8192         FALSE FALSE     FALSE
nls_date_format  DD-MON-RR    TRUE  FALSE     TRUE
open_cursors     300          FALSE IMMEDIATE TRUE
sga_max_size     1610612736   FALSE FALSE     FALSE
```

Read the four rows as four kinds of parameter:

- `db_block_size` cannot be changed at all after the database is created.
- `nls_date_format` is a session parameter: each session can choose its own.
- `open_cursors` can be changed for the whole instance while it runs, and also per PDB.
- `sga_max_size` is static: you can only change it in the spfile and restart.

Three related views are worth knowing. `V$PARAMETER` shows the values for your session. `V$SYSTEM_PARAMETER` shows the instance-wide values that new sessions inherit. `V$SPPARAMETER` shows what is written in the spfile, which is not always what is in memory.

## The spfile and the pfile

The instance reads its parameters from a **parameter file** at startup. There are two kinds.

| | spfile (server parameter file) | pfile (text initialization parameter file) |
| --- | --- | --- |
| Format | Binary. Do not edit it with a text editor | Plain text, one `name = value` per line |
| Typical name | `spfile<SID>.ora`, for example `SPFILEORCL.ORA` | `init<SID>.ora`, for example `initORCL.ora` |
| Who writes it | The database, when you run `ALTER SYSTEM ... SCOPE = SPFILE` or `BOTH` | You, with an editor. The database can read it but never writes to it |
| Status | The recommended format, and what DBCA creates | A legacy format, still useful for recovery and for copying settings |

At startup the instance looks, in its default location, for `spfile<SID>.ora`, then `spfile.ora`, then `init<SID>.ora`, and uses the first one it finds. On Windows the default location is `%ORACLE_HOME%\database`. To see which spfile your instance used:

```sql
SHOW PARAMETER spfile
```

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
spfile                               string      /opt/oracle/dbs/spfileXE.ora
```

That is the Linux path of the test database. On your Windows install the value is a path under `%ORACLE_HOME%\database`. An empty value means the instance was started from a pfile, and then `ALTER SYSTEM` changes cannot be made permanent.

You can convert between the two formats in either direction. A text copy of the spfile is a useful backup before you change anything important:

```sql
CREATE PFILE = 'C:\temp\initORCL_backup.ora' FROM SPFILE;
CREATE SPFILE FROM PFILE = 'C:\temp\initORCL_backup.ora';
```

Run these as a user with the SYSDBA privilege (for example SYS). The second statement only works while the instance is not using the spfile it would overwrite.

## Changing parameters: ALTER SYSTEM and SCOPE

`ALTER SYSTEM SET` changes a parameter for the whole instance. The `SCOPE` clause says where the change goes:

| SCOPE | Changes | Takes effect | After a restart |
| --- | --- | --- | --- |
| `MEMORY` | The running instance only | Now | Lost |
| `SPFILE` | The spfile only | At the next restart | Kept |
| `BOTH` | The running instance and the spfile | Now | Kept |

`MEMORY` is a sticky note on the tool's screen: it works for this shift and is gone after a restart. `SPFILE` edits the written recipe, so the next start uses it, but nothing changes on the running tool. `BOTH` does the two at once.

If the instance was started with an spfile and you leave out `SCOPE`, the default is `BOTH`. If it was started with a pfile, `MEMORY` is the default and the only scope allowed. Some examples:

```sql
-- Try a value now, without making it permanent
ALTER SYSTEM SET open_cursors = 500 SCOPE = MEMORY;

-- Change it now and keep it after a restart
ALTER SYSTEM SET open_cursors = 500 SCOPE = BOTH;

-- A static parameter: write it to the spfile, then restart the instance
ALTER SYSTEM SET sga_max_size = 2G SCOPE = SPFILE;
```

If you try to change a static parameter in memory, Oracle refuses. On the test database:

```sql
ALTER SYSTEM SET sga_max_size = 2G SCOPE = MEMORY;
```

```text
ALTER SYSTEM SET sga_max_size = 2G SCOPE = MEMORY
                 *
ERROR at line 1:
ORA-02095: specified initialization parameter cannot be modified
```

The fix is `SCOPE = SPFILE` followed by a restart.

### ALTER SYSTEM and ALTER SESSION

`ALTER SYSTEM` affects the whole instance and needs the ALTER SYSTEM privilege. `ALTER SESSION` changes a parameter for your own session only, and the change is forgotten when you disconnect. FAB_LAB has no special privileges, and the statement below still works. Developers use it all the time, for example to get ISO dates. Connected as FAB_LAB:

```sql
ALTER SESSION SET nls_date_format = 'YYYY-MM-DD';

SELECT lot_id, start_date, status
FROM   lots
WHERE  lot_id IN ('L26-001', 'L26-010')
ORDER  BY lot_id;
```

```text
Session altered.

LOT_ID       START_DATE STATUS
------------ ---------- --------
L26-001      2026-08-03 SHIPPED
L26-010      2026-09-17 ACTIVE
```

After this, `V$PARAMETER` in the same session shows `nls_date_format` as `YYYY-MM-DD`. Other sessions still see the default.

### Parameters in a PDB

When you run `ALTER SYSTEM SET` as a common user in the root, the change applies to the CDB and is inherited by every PDB that has not set its own value. A parameter whose `ISPDB_MODIFIABLE` is `TRUE` can also be set inside a PDB, and then the value applies to that PDB only. On the test database, 262 parameters were PDB-modifiable:

```sql
SELECT COUNT(*) AS pdb_modifiable
FROM   v$system_parameter
WHERE  ispdb_modifiable = 'TRUE';
```

```text
PDB_MODIFIABLE
--------------
           262
```

Parameters that shape the instance itself, such as `sga_max_size`, `processes` and `db_block_size`, can only be set in the root.

## Saving the PDB state

The second setting to get right after an install has nothing to do with parameter files. Forgetting it is a common reason why applications cannot connect after a server restart.

When a CDB starts, it opens the root, but the PDBs stay MOUNTED (closed) unless you have told Oracle otherwise. Applications that connect to the PDB service then get:

```text
ORA-01109: database not open
```

The `SAVE STATE` clause of `ALTER PLUGGABLE DATABASE` records the current open mode of a PDB, so that after the next CDB restart the PDB comes back in the same mode. It is like leaving the night shift a list of which machines to switch back on after a power cut. Without the list, they restore power and the PDB sits there mounted, like a tool left in idle. Its opposite, `DISCARD STATE`, removes the record, and the PDB comes back MOUNTED, which is the default. Run this once after the install, as SYSTEM connected to the root:

```sql
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;
```

`ALL` means every PDB; you can also name one, as in `ALTER PLUGGABLE DATABASE orclpdb SAVE STATE;`. Check the result in `DBA_PDB_SAVED_STATES`:

```sql
SELECT con_name, state FROM dba_pdb_saved_states;
```

On the test database, where the state had been saved, this returned:

```text
CON_NAME   STATE
---------- ----------
XEPDB1     OPEN
```

On your machine you should see your PDB (for example ORCLPDB) with state OPEN. If the query returns no rows, nothing is saved and the PDB will be MOUNTED after the next restart.

As an invented example of why this matters: a planned Windows patch reboots a fab's database server overnight. In the morning the MES cannot connect. The CDB is open, but the MES PDB is only mounted, because nobody saved its state after the install. One `SAVE STATE` would have prevented the outage.

## Common mistakes

- Using SCOPE = MEMORY and expecting the change to survive. It is gone after the next restart. Use `BOTH` for a permanent change.
- Using SCOPE = SPFILE and expecting an immediate effect. Nothing changes until the instance restarts.
- Editing the spfile in Notepad. It is binary, and editing it can corrupt it. Create a pfile, edit that, and create a new spfile from it if you must.
- Changing a static parameter in memory. ORA-02095. Use `SCOPE = SPFILE` and restart.
- Forgetting SAVE STATE. The PDB is mounted after every restart and applications get ORA-01109.

## Check your understanding

1. What is the difference between `SCOPE = MEMORY`, `SCOPE = SPFILE` and `SCOPE = BOTH`?
2. You run `ALTER SYSTEM SET sga_max_size = 2G;` and get ORA-02095. Why, and what do you do?
3. Which column of `V$PARAMETER` tells you whether you can change a parameter for your own session only?
4. Why should you not open the spfile in a text editor?
5. After a reboot the PDB is MOUNTED. Which two statements fix it now and for future restarts, and where do you run them?

## Further reading

- [Oracle Database Administrator's Guide 19c, chapter 2: Creating and Configuring an Oracle Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/creating-and-configuring-an-oracle-database.html) (section "Managing Initialization Parameters Using a Server Parameter File")
- [Oracle Database Administrator's Guide 19c, chapter 3: Starting Up and Shutting Down](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/starting-up-and-shutting-down.html) (parameter file search order)
- [Oracle Database SQL Language Reference 19c: ALTER SYSTEM](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ALTER-SYSTEM.html)
- [Oracle Database SQL Language Reference 19c: ALTER PLUGGABLE DATABASE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ALTER-PLUGGABLE-DATABASE.html) (the `pdb_save_or_discard_state` clause)
- [Oracle Database Reference 19c: V$PARAMETER](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-PARAMETER.html)
- [Oracle Database Reference 19c: DBA_PDB_SAVED_STATES](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/DBA_PDB_SAVED_STATES.html)
- [Oracle Multitenant Administrator's Guide 19c, chapter 15: Administering PDBs](https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/administering-pdbs-with-sql-plus.html) (setting parameters in a PDB)
- [Oracle Database Administrator's Reference for Microsoft Windows 19c: About the Location of the Initialization Parameter File](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntqrf/about-the-location-of-the-initialization-parameter-file.html)
- [ORACLE-BASE: Persistent Initialization Parameters](https://oracle-base.com/articles/9i/persistent-initialization-parameters)
- [ORACLE-BASE: Multitenant: Configure Instance Parameters and Modify Container Databases (CDB) and Pluggable Databases (PDB)](https://oracle-base.com/articles/12c/multitenant-configure-instance-parameters-of-cdb-and-pdb-12cr1)
- [ORACLE-BASE: Multitenant: Startup and Shutdown Container Databases (CDB) and Pluggable Databases (PDB)](https://oracle-base.com/articles/12c/multitenant-startup-and-shutdown-cdb-and-pdb-12cr1) (includes "Preserve PDB Startup State")

### Answers

1. `MEMORY` changes the running instance only; the change is lost at restart. `SPFILE` writes the change to the spfile only; it takes effect at the next restart. `BOTH` does both: it takes effect now and is kept after a restart.
2. `sga_max_size` is a static parameter (its `ISSYS_MODIFIABLE` is `FALSE`), and without a SCOPE the statement tries to change it in memory as well as in the spfile. Run `ALTER SYSTEM SET sga_max_size = 2G SCOPE = SPFILE;` and restart the instance.
3. `ISSES_MODIFIABLE`. If it is `TRUE`, `ALTER SESSION SET` works for that parameter.
4. The spfile is a binary file maintained by the database. Editing it by hand can corrupt it. Use `ALTER SYSTEM ... SCOPE = SPFILE`, or create a pfile, edit that, and create a new spfile from it.
5. `ALTER PLUGGABLE DATABASE ALL OPEN;` and `ALTER PLUGGABLE DATABASE ALL SAVE STATE;`, as SYSTEM connected to the root (CDB$ROOT).
