# Tools for database management

This page describes the tools you use to work with Oracle Database 19c and when to pick each one: SQL*Plus and SQLcl on the command line, SQL Developer as the graphical tool for daily work, Enterprise Manager Database Express and Cloud Control in the browser, and the utilities that create databases and control the listener.

Slides: 17 of the Day 1 deck.

## Overview

| Tool | Use it for |
| --- | --- |
| SQL*Plus | Scripts, scheduled jobs, emergencies. Always installed |
| SQL Developer | Daily development and DBA work, reports, explain plan, PL/SQL debugger (Day 3). Free |
| SQLcl | Modern command line: SQL*Plus-compatible, with history and completion |
| EM Express | Browser view of performance and storage, for one database |
| Enterprise Manager Cloud Control | Monitoring, alerts and patching for many databases. A separate product |
| DBCA, NETCA, `lsnrctl` | Create databases, configure the network, control the listener |
| Data Pump, RMAN, SQL*Loader | Export and import, backup and recovery, bulk loads (outside this course) |

All of these tools work through the same SQL and the same data dictionary (see [The data dictionary](12-data-dictionary.md)). A query that works in SQL Developer also works in SQL*Plus, SQLcl or a script, which is why this course writes everything as SQL first.

If SQL Developer is the multimeter on your bench, with a display, probes and a dozen modes, SQL*Plus is the pocket screwdriver. It does less, but it is always with you and still works over a bad remote session on a server with nothing else installed.

## SQL*Plus

**SQL*Plus** is the command-line tool included in every Oracle Database installation. It sends SQL and PL/SQL statements to the database, interactively or from script files, and is installed in the `bin` directory of the Oracle home.

Use it when:

- A script must run unattended, for example from Windows Task Scheduler or a nightly job.
- Nothing else is available: a server with no graphical tools, or an emergency where you need to connect with `sqlplus / as sysdba` on the database server itself.
- You need the startup and shutdown commands (`STARTUP`, `SHUTDOWN`), which you run as SYSDBA.

You connect with an Easy Connect string: user, then host, port and service name.

```text
sqlplus system@//localhost:1521/ORCLPDB
```

Your service names may differ; `lsnrctl status` lists them (see [Oracle Net and the listener](04-oracle-net-and-the-listener.md)).

A SQL*Plus script is a text file of SQL statements and SQL*Plus commands. This one lists the lots on hold in the FAB_LAB schema:

```sql
SET PAGESIZE 50 LINESIZE 120 FEEDBACK ON
COLUMN hold_reason FORMAT A40
SELECT lot_id, status, hold_reason
FROM   lots
WHERE  status = 'HOLD'
ORDER  BY lot_id;
EXIT
```

Saved as `lots_on_hold.sql`, it runs silently (`-s`) from a command prompt:

```text
sqlplus -s fab_lab/Lab_2026@//localhost:1521/XEPDB1 @lots_on_hold.sql
```

```text
LOT_ID       STATUS   HOLD_REASON
------------ -------- ----------------------------------------
L26-003B     HOLD     Thickness out of spec at FINAL
L26-005      HOLD

2 rows selected.
```

The service name `XEPDB1` is the PDB of the test database used to prepare this course; use your own PDB's service name. Putting the password on the command line is fine for a lab, but on a shared or production machine anyone who can list processes or read the job definition can see it, so use a secure method there.

## SQL Developer

**SQL Developer** is Oracle's free graphical tool for SQL and PL/SQL development. You use it for both labs today and for the PL/SQL debugger on Day 3. With it you can browse database objects, run SQL statements and scripts, edit and debug PL/SQL, and run the many built-in reports or create your own.

Features worth knowing early:

- In a worksheet, Ctrl+Enter runs the statement under the cursor and shows the result in a grid. F5 (Run Script) runs the whole worksheet as a script, which is how you run the lab scripts.
- Normally every worksheet of a connection shares one database session. Ctrl+Shift+N opens an unshared worksheet with its own session. You need this to see two sessions interact, as in the read-consistency demo in [COMMIT, redo and undo](10-commit-redo-and-undo.md).
- The Explain Plan button on the worksheet toolbar shows the optimizer's plan for a statement. Day 4 uses it.
- The Reports panel has many ready-made reports, built on data dictionary queries, and you can create and save your own.
- The DBA panel, opened from View > DBA, gives administration features, such as storage information, for connections with DBA privileges. Many developers who use SQL Developer every day never open it.

The connection dialog asks for host, port and either a service name or a SID. For a PDB, always choose *Service name*.

## SQLcl

**SQLcl** (SQL Developer Command Line) is a Java-based command-line interface for Oracle Database. It runs SQL and PL/SQL interactively or as a batch file, supports existing SQL*Plus scripts, and adds inline editing, statement completion and command recall. It also has commands of its own, such as `INFO` (for example `info lots`), which describes a table.

Use SQLcl when you like working on the command line and want a more comfortable editor than SQL*Plus. For unattended scripts, either works; SQL*Plus has the advantage of being installed with every database. SQLcl needs a supported Java release; check the SQLcl documentation for the version you download.

## Enterprise Manager Database Express

**EM Express** is a web-based management tool built into the database. It has no middle tier to install. It covers performance monitoring and basic administration, such as user security, memory and storage. Because it runs inside the database, it is only available when the database is open, much like a tool's front-panel display, which cannot help you power the tool on: you cannot use it to start the database, or for other operations that change the database's state, such as switching ARCHIVELOG mode on or off.

You open it in a browser at `https://<host>:<port>/em/`. The HTTPS port is usually set by DBCA when it creates the database (the course's test database uses 5500, so on a laptop that gives `https://localhost:5500/em`). Oracle's guide recommends using the machine's host name rather than `localhost` in the URL. If you do not know the port, ask the database (as SYSTEM in the root):

```sql
SELECT dbms_xdb_config.gethttpsport() AS https_port FROM dual;
```

```text
HTTPS_PORT
----------
      5500
```

A value of 0 means no HTTPS port is configured. In 19c, EM Express is based on Oracle JET and no longer needs Flash.

## Enterprise Manager Cloud Control

**Enterprise Manager Cloud Control** is a separate product that you install on its own server. It is a web-based interface for monitoring across the Oracle technology stack and other components: many databases, their hosts, middleware, alerts, patching and performance history. Large sites run one Cloud Control installation for all their databases. For a single database on a laptop, EM Express is enough.

## Installation and network utilities

| Utility | Purpose |
| --- | --- |
| DBCA (Database Configuration Assistant) | Creates and configures databases, from Oracle-supplied templates or your own |
| NETCA (Oracle Net Configuration Assistant) | Configures listeners, naming methods and net service names in `tnsnames.ora`. Runs during installation |
| `lsnrctl` (Listener Control Utility) | Starts, stops and checks the listener |

`lsnrctl` commands you will use:

| Command | What it does |
| --- | --- |
| `lsnrctl status` | Basic status: configuration, listening addresses and a summary of the services registered with the listener |
| `lsnrctl services` | Detailed information about services, instances and the handlers the listener forwards connections to |
| `lsnrctl start` / `lsnrctl stop` | Starts or stops the listener |
| `lsnrctl reload` | Rereads `listener.ora` without stopping the listener |

On Windows the listener also runs as a Windows service, so you can start it from the Services console. [Oracle Net and the listener](04-oracle-net-and-the-listener.md) explains how to read the `lsnrctl status` output.

## Data movement and backup utilities

These are part of every Oracle installation but are outside this course:

- Data Pump (`expdp` and `impdp`) moves data and metadata between databases at high speed: logical export and import.
- RMAN (Recovery Manager) performs backup and recovery, and records its backups in the control file.
- SQL*Loader (`sqlldr`) loads data from external files into tables.

## Which tool when

| Task | Good choice |
| --- | --- |
| Write and test queries, browse a schema | SQL Developer |
| Debug a PL/SQL procedure (Day 3) | SQL Developer |
| Run a script every night | SQL*Plus (or SQLcl) from a scheduled job |
| Check which services the listener knows | `lsnrctl status` |
| Start or stop the database | SQL*Plus as SYSDBA (or the Windows service) |
| Look at load and top SQL on one database in a browser | EM Express |
| Watch alerts and performance across many databases | Cloud Control |
| Answer any question about the database's structure or current activity | A data dictionary query, in any of the above |

## Common mistakes

- Choosing *SID* instead of *Service name* in the SQL Developer connection dialog when connecting to a PDB. A PDB is reached through its service, so the connection fails.
- Testing two-session behaviour in two worksheets of the same SQL Developer connection. They share one session; use Ctrl+Shift+N.
- Trying to start a closed database from EM Express. EM Express needs an open database; use SQL*Plus.
- Pressing Ctrl+Enter on a script of many statements in SQL Developer and wondering why only one ran. Use F5 (Run Script).

## Check your understanding

1. You need a report to run unattended every night at 02:00. Which tool runs it, and why that one?
2. Why can EM Express not start a database that is shut down?
3. What is the difference between a normal SQL Developer worksheet and one opened with Ctrl+Shift+N?
4. A colleague cannot connect to the PDB and you suspect a wrong service name. Which command shows the service names the listener knows?
5. Your site has 40 production databases. Is EM Express or Cloud Control the better fit for monitoring them, and why?

## Further reading

- [Oracle Database Concepts 19c: Concepts for Database Administrators](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/concepts-for-database-administrators.html)
- [Oracle Database 2 Day DBA 19c: Getting Started with Database Administration](https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/getting-started-with-database-administration.html) (EM Express, SQL*Plus and SQL Developer)
- [Oracle Database 2 Day DBA 19c: Introduction](https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/introduction.html) (Tools for Administering the Database)
- [SQL*Plus User's Guide and Reference 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/index.html)
- [Oracle Database Net Services Reference 19c: Listener Control Utility](https://docs.oracle.com/en/database/oracle/oracle-database/19/netrf/listener-control-utility.html)
- [Oracle SQL Developer User's Guide 24.3: SQL Developer Concepts and Usage](https://docs.oracle.com/en/database/oracle/sql-developer/24.3/rptug/sql-developer-concepts-usage.html)
- [Oracle SQLcl User's Guide 24.3: Using Oracle SQLcl](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/24.3/sqcug/working-sqlcl.html)
- [Enterprise Manager Cloud Control Introduction 13.5: Overview of Oracle Enterprise Manager Cloud Control 13c](https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emcon/overview-oracle-enterprise-manager.html)
- [ORACLE-BASE: SQLcl : Going cold turkey from SQL*Plus](https://oracle-base.com/blog/2018/01/25/sqlcl-going-cold-turkey-from-sqlplus/)

### Answers

1. SQL*Plus (or SQLcl), started by a scheduler such as Windows Task Scheduler. It runs a script without a user interface, and SQL*Plus is installed with every database.
2. EM Express is built into the database and runs inside it, so it is only available while the database is open.
3. A normal worksheet shares the connection's database session with the other worksheets of that connection. An unshared worksheet has its own session, so it behaves like a different user: it does not see uncommitted changes made in the other worksheets.
4. `lsnrctl status`, in the "Services Summary" section.
5. Cloud Control. It is built for monitoring many databases and hosts from one place, with alerts and patching. EM Express manages one database at a time.
