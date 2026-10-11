# Instance and database

This page explains the difference between an Oracle instance and an Oracle database, which people mix up all the time, and walks through the stages an instance goes through at startup: NOMOUNT, MOUNT and OPEN. It ends with the rule that one instance opens one database, and the one exception, Oracle RAC.

Slides: 12 of the Day 1 deck.

## Two words, two things

In everyday speech "the database" means the whole Oracle system. Oracle's own terminology is more precise, and the rest of this course uses it.

The **instance** is the running part: memory and processes.

- The System Global Area (SGA), a block of shared memory that all sessions use. See [Memory: SGA and PGA](07-memory-sga-and-pga.md).
- The background processes, such as DBWn, LGWR, CKPT, SMON and PMON, which do the work of writing, logging and recovering. See [Background processes](08-background-processes.md).

The instance is created when you start it (STARTUP, or on Windows when the `OracleService<SID>` service starts it) and disappears completely when you shut it down.

The **database** is the set of files on disk:

- data files, which hold the tables, indexes and other data,
- control files, small files that record the database's structure: its name, and where every data file and redo log is,
- online redo log files, which record every change made to the data.

Several other files live alongside these and belong to the system without being part of the database proper: archived redo logs (copies of filled online redo logs, in ARCHIVELOG mode), the spfile (see [Configuration and parameters](05-configuration-and-parameters.md)) and the password file. All of these files survive a restart. [Storage structures](09-storage-structures.md) describes them in more detail.

| | Instance | Database |
| --- | --- | --- |
| Made of | SGA and background processes | Data files, control files, online redo logs |
| Lives in | Memory | Disk |
| Exists | From STARTUP to SHUTDOWN | Until someone deletes the files |
| Identified by | The SID, for example ORCL | The database name, for example ORCL |

Because an instance lives in memory and a database is files, either can exist without the other: an instance can run without having opened a database yet (that is what NOMOUNT means, below), and a database's files sit on disk while no instance is running.

A library makes the split easy to remember. The database is the books on the shelves. The instance is the staff and the open reading room: they arrive in the morning, go home at night, and if the whole staff left tomorrow the books would still be on the shelves.

When someone says "the database is down", they almost always mean the instance is down. The files are still there, and starting the instance again brings the database back.

## Looking at both from SQL

`V$INSTANCE` describes the instance and `V$DATABASE` describes the database it has opened. On the test database used for these pages (a small 21c XE install, so names differ from yours):

```sql
SELECT instance_name, status, database_status FROM v$instance;
SELECT name, cdb, log_mode, open_mode FROM v$database;
```

```text
INSTANCE_NAME STATUS   DATABASE_STATUS
------------- -------- -----------------
XE            OPEN     ACTIVE

NAME   CDB LOG_MODE     OPEN_MODE
------ --- ------------ ----------
XE     YES NOARCHIVELOG READ WRITE
```

The instance is called XE and is OPEN. The database is also called XE, is a container database (`CDB = YES`), and is open read/write. On your machine both names will be ORCL, or whatever you chose.

The files that make up the database are listed in V$ views too. As SYSTEM in the root:

```sql
SELECT type, COUNT(*) AS files FROM (
  SELECT 'Data file' AS type FROM v$datafile
  UNION ALL SELECT 'Temp file' FROM v$tempfile
  UNION ALL SELECT 'Control file' FROM v$controlfile
  UNION ALL SELECT 'Online redo log member' FROM v$logfile)
GROUP BY type ORDER BY type;
```

```text
TYPE                        FILES
---------------------- ----------
Control file                    2
Data file                      11
Online redo log member          2
Temp file                       3
```

The data file count covers every container: the root, the seed and the PDB each have their own data files. Your counts will differ. Lab 2 looks at each kind of file in turn.

## Startup: NOMOUNT, MOUNT, OPEN

A plain `STARTUP` command takes the instance through three stages. You can also stop at each one, which DBAs do for maintenance and recovery. In library terms: the staff arrive and switch on the lights (NOMOUNT), someone opens the catalogue that says where every book is shelved (MOUNT), and then the doors open to readers (OPEN).

```sql
STARTUP NOMOUNT;        -- stage 1: start the instance only
ALTER DATABASE MOUNT;   -- stage 2: open the control files
ALTER DATABASE OPEN;    -- stage 3: open the data files and redo logs
```

These statements need the SYSDBA privilege, for example `sqlplus / as sysdba` on the database server. Do not try them on your course database during the labs.

### Stage 1: NOMOUNT (instance started)

Oracle:

1. finds and reads the parameter file (the spfile, or a pfile),
2. allocates the SGA using the sizes in the parameters,
3. starts the background processes,
4. opens the alert log and trace files.

The instance now exists but is not associated with any database. `V$INSTANCE.STATUS` shows `STARTED`. You need this stage to create a database or to re-create lost control files.

### Stage 2: MOUNT (database mounted)

Oracle reads the `control_files` parameter, opens the control files, and reads from them the names of the data files and online redo logs. The instance is now associated with one database, but the database is closed: only administrators can connect, and no user data can be read. `V$INSTANCE.STATUS` shows `MOUNTED`. Some maintenance, such as switching the database to ARCHIVELOG mode or full database recovery, is done in this stage.

### Stage 3: OPEN (database open)

Oracle opens the data files and the online redo log files, and the database becomes available to every user with the CREATE SESSION privilege. If a file is missing or damaged, the open fails with an error and the database stays mounted until the file is restored or recovered. `V$INSTANCE.STATUS` shows `OPEN`.

When the whole sequence runs in SQL*Plus, Oracle's Concepts guide shows this output:

```text
SQL> STARTUP
ORACLE instance started.
Database mounted.
Database opened.
```

### What MOUNTED means for a PDB

The same word appears in the multitenant world. When a CDB opens, the root is opened, but the PDBs are only mounted until you open them (or until a saved state opens them for you). A mounted PDB is closed, as in stage 2 above: its files are known, but ordinary users cannot connect, and they get ORA-01109. See [Multitenant architecture](02-multitenant-architecture.md) and [Configuration and parameters](05-configuration-and-parameters.md).

### Shutting down

`SHUTDOWN` reverses the stages: it closes the database, dismounts it and stops the instance, which frees the SGA and ends the background processes. `SHUTDOWN IMMEDIATE` is the usual choice: it rolls back open transactions and disconnects users, then closes cleanly. `SHUTDOWN ABORT` stops the instance at once without closing the files; the next startup then performs instance recovery, using the online redo logs (see [COMMIT, redo and undo](10-commit-redo-and-undo.md)).

## One instance, one database (and RAC)

In a normal single-instance installation, like yours, there is a one-to-one relationship: an instance mounts exactly one database, and cannot mount two at the same time. A container database does not break this rule. A CDB is one database with one instance, however many PDBs it holds.

The exception is **Oracle Real Application Clusters (RAC)**. In RAC, several instances, each on its own server, open the same database files on shared storage at the same time. If one server fails, the instances on the other servers keep the database available. RAC is a separately licensed option and is not part of this course, but you may meet it in production, where `V$INSTANCE` on each node shows a different instance name for the same database.

## Common mistakes

- Saying "database" when you mean "instance". "The database crashed" usually means the instance stopped. The files are fine, and a restart with instance recovery brings everything back.
- Confusing the SID with the PDB name. The SID (for example ORCL) names the instance. The PDB (ORCLPDB) is a container inside the database, and you reach it through its service.
- Thinking a mounted database is open. MOUNTED means the control files are open and the data files are not. Users cannot connect.

## Check your understanding

1. Which of these belong to the instance and which to the database: the buffer cache, a data file, LGWR, a control file, the online redo logs?
2. What does the instance do in the NOMOUNT stage, and which file does it read?
3. What does Oracle read when it mounts the database, and what does it learn from it?
4. Your PDB shows MOUNTED. Can FAB_LAB connect to it?
5. In a RAC database with three nodes, how many instances and how many databases are there?

## Further reading

- [Oracle Database Concepts 19c, chapter 14: Oracle Database Instance](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/oracle-database-instance.html) (instance and database, startup stages, parameter files)
- [Oracle Database Concepts 19c, chapter 1: Introduction to Oracle Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/introduction-to-oracle-database.html) (section "Database and Instance")
- [Oracle Database Administrator's Guide 19c, chapter 3: Starting Up and Shutting Down](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/starting-up-and-shutting-down.html)
- [Oracle Database Reference 19c: V$INSTANCE](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-INSTANCE.html)
- [Oracle Multitenant Administrator's Guide 19c, chapter 13: Administering a CDB](https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/administering-a-cdb-with-sql-plus.html) (starting a CDB and the open mode of its PDBs)
- [ORACLE-BASE: Multitenant: Startup and Shutdown Container Databases (CDB) and Pluggable Databases (PDB)](https://oracle-base.com/articles/12c/multitenant-startup-and-shutdown-cdb-and-pdb-12cr1)

### Answers

1. Instance: the buffer cache (part of the SGA) and LGWR (a background process). Database: the data file, the control file and the online redo logs.
2. It reads the parameter file (the spfile, or a pfile), allocates the SGA, starts the background processes and opens the alert log. No database is associated with it yet.
3. It reads the control files, whose locations come from the `control_files` parameter. From them it learns the names and locations of the data files and online redo logs.
4. No. A mounted PDB is closed, and ordinary users get ORA-01109. Only administrators with a privilege such as SYSDBA can connect to it. Someone must open it first.
5. Three instances, one on each node, and one database, whose files all three instances open at the same time.
