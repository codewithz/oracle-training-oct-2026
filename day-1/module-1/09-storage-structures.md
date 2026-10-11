# Storage structures

This page explains how Oracle stores data. On the logical side, tables and indexes are segments made of extents, which are made of blocks, and segments live in tablespaces. On the physical side, tablespaces are stored in data files, and the database also needs control files and online redo log files, plus archived redo logs in ARCHIVELOG mode. You see each of these through the data dictionary and V$ views such as `V$DATAFILE`, `V$LOG` and `V$CONTROLFILE`.

Slides: 15 of the Day 1 deck.

## Logical and physical structures

Oracle separates how data is organized from where it is stored.

The **logical structures** are what SQL and the data dictionary talk about: tablespaces, segments, extents and blocks. The **physical structures** are files the operating system can see: data files, temp files, control files and redo log files.

The two meet at the tablespace. A tablespace is a logical container, and its data files are its physical side.

A warehouse is a reasonable mental model. The block is a single box, the smallest thing a forklift ever moves. An extent is a pallet of boxes stacked together, a segment is all the pallets that belong to one customer's order, and a tablespace is a storage zone of the warehouse. The data files are the actual floor space under that zone, and you can extend the zone onto a new patch of floor without the customer noticing.

```text
Logical                                  Physical
-------                                  --------
Tablespace (USERS)          stored in    Data file(s)  users01.dbf
  Segment (table LOTS)
    Extent (contiguous blocks)           An extent lies in one data file
      Block (8 KB)                       A block maps to bytes on disk
```

## The logical hierarchy

### Data blocks

A **data block** is the smallest logical unit of storage and the minimum unit of database I/O. When Oracle reads a row, it reads the whole block that contains it into the buffer cache. The `DB_BLOCK_SIZE` initialization parameter sets the standard block size when the database is created, and it cannot be changed afterwards except by re-creating the database. The standard size is 4 KB or 8 KB; course installations use 8 KB.

### Extents

An **extent** is a set of logically contiguous data blocks allocated for one segment. When a table needs more room, Oracle allocates another extent to it, the way the warehouse brings in another pallet when an order grows. An extent is always contained in one data file.

### Segments

A **segment** is the set of extents allocated for one database object. Each table has a table segment and each index has an index segment. A segment belongs to exactly one tablespace, but inside that tablespace it can have extents in several data files.

By default Oracle uses **deferred segment creation**: when you create a table, only its definition is stored in the data dictionary. The segment is created when the first row is inserted. A table you have just created and never filled has no segment, so it does not appear in `DBA_SEGMENTS`.

### Tablespaces

A **tablespace** is a storage unit that contains segments. A PDB in this course has these tablespaces:

| Tablespace | Holds |
| --- | --- |
| SYSTEM | The data dictionary |
| SYSAUX | Auxiliary data for Oracle components, such as the Automatic Workload Repository, which keeps load off SYSTEM |
| UNDOTBS1 | Undo: old values for ROLLBACK and for read consistency |
| TEMP | Temporary data for sorts and hash joins that do not fit in the PGA |
| USERS | The default tablespace for user data; FAB_LAB's tables and indexes live here |

The undo tablespace is explained in [COMMIT, redo and undo](10-commit-redo-and-undo.md). The temporary tablespace is stored in **temp files** rather than data files, and Oracle never generates redo for temp files.

## Seeing the logical structures

Run these as SYSTEM in the PDB. `DBA_TABLESPACES` lists the tablespaces:

```sql
SELECT tablespace_name, block_size, contents, extent_management, segment_space_management
FROM   dba_tablespaces
ORDER  BY tablespace_name;
```

```text
TABLESPACE_N BLOCK_SIZE CONTENTS   EXTENT_MAN SEGMEN
------------ ---------- ---------- ---------- ------
SYSAUX             8192 PERMANENT  LOCAL      AUTO
SYSTEM             8192 PERMANENT  LOCAL      MANUAL
TEMP               8192 TEMPORARY  LOCAL      MANUAL
UNDOTBS1           8192 UNDO       LOCAL      MANUAL
USERS              8192 PERMANENT  LOCAL      AUTO

5 rows selected.
```

`DBA_SEGMENTS` shows how much space each table and index really uses. After the Lab 1 data load, FAB_LAB has 16 segments, all in USERS:

```sql
SELECT segment_name, segment_type, tablespace_name, extents, blocks, bytes/1024 AS kb
FROM   dba_segments
WHERE  owner = 'FAB_LAB'
ORDER  BY segment_type DESC, segment_name;
```

```text
SEGMENT_NAME       SEGMENT_TYPE       TABLESPACE_N    EXTENTS     BLOCKS         KB
------------------ ------------------ ------------ ---------- ---------- ----------
LOTS               TABLE              USERS                 1          8         64
MEASUREMENTS       TABLE              USERS                 1          8         64
PRODUCTS           TABLE              USERS                 1          8         64
TOOLS              TABLE              USERS                 1          8         64
WAFERS             TABLE              USERS                 1          8         64
LOTS_PARENT_IX     INDEX              USERS                 1          8         64
LOTS_PK            INDEX              USERS                 1          8         64
LOTS_PRODUCT_IX    INDEX              USERS                 1          8         64
MEASUREMENTS_PK    INDEX              USERS                 1          8         64
MEAS_TOOL_TIME_IX  INDEX              USERS                 1          8         64
MEAS_WAFER_IX      INDEX              USERS                 1          8         64
PRODUCTS_CODE_UK   INDEX              USERS                 1          8         64
PRODUCTS_PK        INDEX              USERS                 1          8         64
TOOLS_PK           INDEX              USERS                 1          8         64
WAFERS_LOT_IX      INDEX              USERS                 1          8         64
WAFERS_PK          INDEX              USERS                 1          8         64

16 rows selected.
```

The lab tables are tiny: each segment is one extent of 8 blocks of 8 KB, which is 64 KB. Even MEASUREMENTS, with 186 rows, fits in its first extent. `DBA_EXTENTS` shows where that extent is:

```sql
SELECT segment_name, extent_id, file_id, block_id, blocks
FROM   dba_extents
WHERE  owner = 'FAB_LAB' AND segment_name = 'MEASUREMENTS'
ORDER  BY extent_id;
```

```text
SEGMENT_NAME        EXTENT_ID    FILE_ID   BLOCK_ID     BLOCKS
------------------ ---------- ---------- ---------- ----------
MEASUREMENTS                0         12        224          8

1 row selected.
```

The extent starts at block 224 of data file 12, which is the USERS data file of the PDB on the test instance. File numbers and block numbers on your machine will differ.

## The physical files

An Oracle database consists of these files:

| File | What it is | View |
| --- | --- | --- |
| Data files | Hold the tablespaces' data. Every database has at least one | `V$DATAFILE`, `DBA_DATA_FILES` |
| Temp files | Hold temporary tablespaces | `V$TEMPFILE`, `DBA_TEMP_FILES` |
| Control files | A small binary file with the database name, the list of data files and redo log files, checkpoint information and RMAN backup records | `V$CONTROLFILE` |
| Online redo log files | Two or more files that record every change as it happens; the most important structure for recovery | `V$LOG`, `V$LOGFILE` |
| Archived redo log files | Copies of filled online redo logs, made only in ARCHIVELOG mode | `V$ARCHIVED_LOG` |

The spfile (server parameter file) and the password file sit alongside these files but are not part of the database itself (see [Instance and database](06-instance-and-database.md)).

### Control files

The **control file** records the physical structure of the database. The instance reads it when it mounts the database, to find the data files and redo logs. It is the warehouse's floor plan: without it, the stock is still there, but nobody knows which aisle to walk down. Oracle recommends keeping several identical copies (multiplexing), each on a different disk: if all control files are lost, the instance fails and media recovery is needed.

`V$CONTROLFILE` displays the names of the control files. Run as SYSTEM in the root:

```sql
SELECT name FROM v$controlfile;
```

```text
NAME
--------------------------------------------------
/opt/oracle/oradata/XE/control01.ctl
/opt/oracle/oradata/XE/control02.ctl

2 rows selected.
```

The test instance runs on Linux, so the paths are Linux paths. On your Windows install they are Windows paths in the data file location chosen at installation.

### Online redo log

The **online redo log** is a set of at least two groups of files. LGWR writes to one group at a time, the CURRENT group. When that group is full, a **log switch** happens and LGWR moves to the next group, which gets a new log sequence number. When it reaches the last group, it starts again from the first, so the groups are used in a circle.

A group can have several identical **members** (copies), ideally on different disks. LGWR writes to all members of the current group at the same time.

`V$LOG` displays log file information from the control file:

```sql
SELECT group#, thread#, sequence#, ROUND(bytes/1024/1024) AS mb, members, archived, status
FROM   v$log
ORDER  BY group#;
```

```text
    GROUP#    THREAD#  SEQUENCE#         MB    MEMBERS ARC STATUS
---------- ---------- ---------- ---------- ---------- --- ----------------
         1          1         22         10          1 NO  INACTIVE
         2          1         23         10          1 NO  CURRENT

2 rows selected.
```

`V$LOGFILE` lists the member files:

```sql
SELECT group#, member FROM v$logfile ORDER BY group#;
```

```text
    GROUP# MEMBER
---------- ---------------------------------------------
         1 /opt/oracle/oradata/XE/redo01.log
         2 /opt/oracle/oradata/XE/redo02.log

2 rows selected.
```

The `STATUS` values you meet most often are:

| Status | Meaning |
| --- | --- |
| CURRENT | The group LGWR is writing to now |
| ACTIVE | Not current, but still needed for instance recovery |
| INACTIVE | No longer needed for instance recovery (it may still be needed for media recovery) |
| UNUSED | Never written to, for example a newly added group |

A filled group can be reused only when it is no longer needed: after DBWn has written the changes it protects to the data files (a checkpoint), and, in ARCHIVELOG mode, after ARCn has archived it.

### Archived redo logs

An **archived redo log** is a copy of a filled online redo log group, written to an archive location. Archiving happens only in ARCHIVELOG mode. With all archived logs since a backup, you can restore that backup and roll it forward to the moment of a failure; without them, you can only restore the backup as it was. The course databases run in NOARCHIVELOG mode, which is fine for a laptop and not acceptable for a production system that must not lose data.

### Data files

`V$DATAFILE` displays data file information from the control file. In a CDB, it shows the data files of every container when you query it from the root. This query from [Lab 2](../labs/lab-2-inside-your-instance.md) groups them by container and tablespace:

```sql
SELECT c.name AS pdb_name, t.name AS tablespace, ROUND(d.bytes/1024/1024) AS mb
FROM   v$datafile d
JOIN   v$tablespace t ON t.ts# = d.ts# AND t.con_id = d.con_id
JOIN   v$containers c ON c.con_id = d.con_id
ORDER  BY c.con_id, t.name;
```

```text
PDB_NAME   TABLESPACE         MB
---------- ---------- ----------
CDB$ROOT   SYSAUX            560
CDB$ROOT   SYSTEM            875
CDB$ROOT   UNDOTBS1           11
CDB$ROOT   USERS               2
PDB$SEED   SYSAUX            330
PDB$SEED   SYSTEM            272
PDB$SEED   UNDOTBS1           11
XEPDB1     SYSAUX            330
XEPDB1     SYSTEM            272
XEPDB1     UNDOTBS1           11
XEPDB1     USERS              12

11 rows selected.
```

Each container has its own SYSTEM, SYSAUX and undo tablespaces (see [Multitenant architecture](02-multitenant-architecture.md)). The sizes come from the small test install; yours will differ. TEMP does not appear because temporary tablespaces use temp files, which are in `V$TEMPFILE`.

Inside the PDB, `DBA_DATA_FILES` gives the same information for that PDB only, with the file names:

```sql
SELECT tablespace_name, file_name, ROUND(bytes/1024/1024) AS mb, autoextensible
FROM   dba_data_files
ORDER  BY tablespace_name;
```

```text
TABLESPACE_N FILE_NAME                                                  MB AUT
------------ -------------------------------------------------- ---------- ---
SYSAUX       /opt/oracle/oradata/XE/XEPDB1/sysaux01.dbf                330 YES
SYSTEM       /opt/oracle/oradata/XE/XEPDB1/system01.dbf                272 YES
UNDOTBS1     /opt/oracle/oradata/XE/XEPDB1/undotbs01.dbf                11 YES
USERS        /opt/oracle/oradata/XE/XEPDB1/users01.dbf                  12 YES

4 rows selected.
```

`AUTOEXTENSIBLE = YES` means Oracle grows the file automatically when the tablespace needs more space, up to a maximum size.

## Common mistakes

- Expecting a newly created, empty table in `DBA_SEGMENTS`. With deferred segment creation, the segment appears with the first row.
- Confusing a tablespace with a schema. A schema (FAB_LAB) is a set of objects owned by a user; a tablespace is where segments are stored. One schema can use several tablespaces, and one tablespace can hold segments of many schemas.
- Querying `V$DATAFILE` in the PDB and wondering where the root's files are. From the PDB you see only that PDB's files; query from the root to see all containers.
- Looking for TEMP in `V$DATAFILE` or `DBA_DATA_FILES`. Temporary tablespaces use temp files: `V$TEMPFILE` and `DBA_TEMP_FILES`.
- Running a database that must not lose data in NOARCHIVELOG mode. Without archived logs, you cannot recover past your last backup.

## Check your understanding

1. Put these in order from smallest to largest: segment, block, tablespace, extent.
2. Can a segment have extents in two data files? Can it have extents in two tablespaces?
3. FAB_LAB creates a new table and inserts nothing. Does `DBA_SEGMENTS` list it? Why?
4. `V$LOG` shows group 1 INACTIVE and group 2 CURRENT. What happens to group 1 at the next log switch?
5. Which file does the instance read first, when it mounts the database, to find the data files and redo logs?

## Further reading

- [Oracle Database Concepts 19c: Logical Storage Structures](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/logical-storage-structures.html)
- [Oracle Database Concepts 19c: Physical Storage Structures](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/physical-storage-structures.html)
- [Oracle Database Reference 19c: V$DATAFILE](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-DATAFILE.html)
- [Oracle Database Reference 19c: V$LOG](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-LOG.html)
- [Oracle Database Reference 19c: V$CONTROLFILE](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-CONTROLFILE.html)
- [Oracle Database 2 Day DBA 19c: Managing Database Storage Structures](https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/managing-database-storage-structures.html)

### Answers

1. Block, extent, segment, tablespace.
2. Yes, within its tablespace a segment can have extents in several data files (each single extent stays in one file). No, a segment belongs to exactly one tablespace.
3. No. With deferred segment creation, which is the default, only the table's definition is stored; the segment is created when the first row is inserted.
4. LGWR switches to group 1, which becomes CURRENT with a new, higher sequence number, and its old contents are overwritten. Group 2 becomes ACTIVE until a checkpoint has written the changes it protects to the data files, then INACTIVE.
5. The control file.
