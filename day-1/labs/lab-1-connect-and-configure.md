# Lab 1: Connect and configure

In this lab you check that you can reach your own Oracle 19c database through the listener, connect as SYSTEM to the root and to the PDB, and read how the database is configured: its containers and open modes, the services it offers, its character set, its parameter file and a few parameters. Then you create the lab user FAB_LAB in the PDB and load the lab data that Labs 2 to 5 use.

Slides: 11 of the Day 1 deck.

| | |
| --- | --- |
| Time | 25 minutes |
| Database | Your own 19c install from [Install Oracle Database 19c on Windows](../../before-you-start/install-oracle-19c-windows.md): a container database with one PDB, listener on `localhost:1521` |
| Tools | SQL Developer, and a Command Prompt for `lsnrctl` |
| Users | SYSTEM (your installer password); FAB_LAB, password `Lab_2026`, which you create in step 5 |
| You finish with | Working connections as SYSTEM and FAB_LAB, a PDB that opens by itself after a restart, the lab data loaded, and the worksheet filled in |

Work in pairs if you like and compare results, but each of you runs every step on your own database.

## What this lab practises

| Step | Topic page |
| --- | --- |
| 1 | [Oracle Net and the listener](../module-1/04-oracle-net-and-the-listener.md) |
| 2 | [Multitenant architecture](../module-1/02-multitenant-architecture.md), [Tools](../module-1/11-tools.md) |
| 3, 4 | [Oracle Database 19c overview](../module-1/01-oracle-19c-overview.md), [Multitenant architecture](../module-1/02-multitenant-architecture.md), [Installing Oracle 19c](../module-1/03-installing-oracle-19c.md), [Configuration and parameters](../module-1/05-configuration-and-parameters.md) |
| 5, 6 | [Multitenant architecture](../module-1/02-multitenant-architecture.md) (common and local users) |

## Scripts

Save these three scripts into one folder on your machine, for example `C:\training\day1\labs`:

| Script | Run as | Used in |
| --- | --- | --- |
| [`lab1_connect_configure.sql`](scripts/lab1_connect_configure.sql) | SYSTEM, in the root (`CDB$ROOT`) | Step 3 |
| [`lab0_oracle_create_user.sql`](scripts/lab0_oracle_create_user.sql) | SYSTEM, in the PDB | Step 5 |
| [`fab_lab_data.sql`](scripts/fab_lab_data.sql) | FAB_LAB, in the PDB | Step 6 |

The script comments show the example service names `ORCL` and `ORCLPDB`. Use your own names wherever these appear.

Two habits help all day:

1. Know which container you are in. Run `SHOW CON_NAME` whenever in doubt. The course user and its tables belong in the PDB, never in `CDB$ROOT`. In January 2017 a GitLab engineer meant to wipe the data directory on the secondary database server and ran the command on the primary instead; about six hours of data was lost. Two clearly named connections, `system-root` and `system-pdb`, are the cheap version of that lesson.
2. Read the error number first. ORA-12514, ORA-01109 and ORA-65096 each have a short fix; see [Troubleshooting](#troubleshooting).

## Step 1: Read your service names from the listener

Open a Command Prompt and run:

```text
lsnrctl status
```

Look at two parts of the output:

- Listening Endpoints Summary: a line with `PORT=1521` is the listener for database connections. A line with `PORT=5500` and `Presentation=HTTP` is EM Express (optional step 7).
- Services Summary: the service names a client may use. Find the service of the root, named after the global database name you chose when installing (for example `orcl`), and the service of your PDB (for example `orclpdb`).

Other entries, such as a service with a long hexadecimal name or one ending in `XDB`, can be ignored for now. Write your two names down.

## Step 2: Connect as SYSTEM to the root and to the PDB

If you created the `system-root` and `system-pdb` connections while installing, use them. Otherwise create them now in SQL Developer: right-click "Connections", choose "New Connection", and fill in:

| Field | `system-root` | `system-pdb` |
| --- | --- | --- |
| Username | `SYSTEM` | `SYSTEM` |
| Password | Your installer password | The same |
| Hostname | `localhost` | `localhost` |
| Port | `1521` | `1521` |
| Service name (not SID) | Your root service, for example `orcl` | Your PDB service, for example `orclpdb` |

Click "Test" (the status must say Success), then "Save" and "Connect". In each connection's worksheet, run:

```sql
SHOW CON_NAME
```

`system-root` must show `CDB$ROOT`. `system-pdb` must show your PDB name. If the PDB connection fails with ORA-01109, the PDB is not open: step 4 fixes it.

## Step 3: Run the configuration script in the root

1. Open `lab1_connect_configure.sql` (File, Open) and set the worksheet's connection to `system-root` (the connection list at the top right of the worksheet).
2. Press F5 (Run Script). The Script Output panel shows seven blocks, each starting with a `=== n. ...` heading.
3. Fill in the [worksheet](#worksheet) from the output.

| Section | What it queries |
| --- | --- |
| 1 | `v$version` and `SHOW CON_NAME`: the release, and the container you are in |
| 2 | `v$pdbs`: the PDBs and their open mode |
| 3 | `dba_pdb_saved_states`: whether a PDB's open state is saved |
| 4 | `v$services`: the services the database registers with the listener, per container |
| 5 | `database_properties`: the database character set |
| 6 | `SHOW PARAMETER spfile`: which server parameter file the instance started from |
| 7 | `v$parameter`: eight parameters, with `ISDEFAULT`, `ISSYS_MODIFIABLE` and `ISPDB_MODIFIABLE` |

Section 1 must say `CDB$ROOT`. If it shows your PDB name, the worksheet is on the wrong connection.

## Step 4: Open the PDB and save its state, if needed

Look at sections 2 and 3 of the output.

- Section 2 should show your PDB with `OPEN_MODE` READ WRITE.
- Section 3 should show your PDB with `STATE` OPEN. If it returns no rows, the PDB's open state was never saved, and after the next restart of Windows the PDB comes back MOUNTED.

If either is not the case, run this in the `system-root` worksheet:

```sql
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;
```

Each statement returns `Pluggable database altered.` Running `ALL OPEN` on a PDB that is already open does no harm. Run sections 2 and 3 again (select the two queries and press F5) and check that they now show READ WRITE and OPEN. The background is on [Configuration and parameters](../module-1/05-configuration-and-parameters.md), section "Saving the PDB state".

## Step 5: Create the lab user

1. Switch to the `system-pdb` connection and check once more that `SHOW CON_NAME` returns your PDB name, not `CDB$ROOT`.
2. Open `lab0_oracle_create_user.sql` in a worksheet for `system-pdb`.
3. Press F5.

What to expect in the Script Output panel:

- On the first run, the first statement `DROP USER fab_lab CASCADE` fails with ORA-01918 "user 'FAB_LAB' does not exist". There is nothing to drop yet, so this is expected.
- `User created.` and then `Grant succeeded.` for the grants.
- If the last grant, `GRANT CTXAPP TO fab_lab`, fails with ORA-01919 "role 'CTXAPP' does not exist", Oracle Text is not installed in your database. Day 1 does not need it; the full-text search topic on Day 4 does. Tell your trainer.

FAB_LAB is a local user: it exists only in your PDB. If you run the script in the root by mistake, `CREATE USER` fails with ORA-65096, because a user created in the root must be a common user whose name starts with `C##`.

The script can be re-run at any time. It drops FAB_LAB with everything in it and creates it again, so you would have to run step 6 again too.

## Step 6: Load the lab data

1. Create a third connection: name `fab_lab`, username `FAB_LAB`, password `Lab_2026` (passwords are case-sensitive), hostname `localhost`, port `1521`, Service name = your PDB service.
2. Connect, open `fab_lab_data.sql` in a worksheet for the `fab_lab` connection, and press F5.

The script drops and creates its five tables, inserts the rows and commits. The last query counts the rows, and you must get:

```text
TABLE_NAME    ROW_COUNT
------------ ----------
PRODUCTS              5
TOOLS                 9
LOTS                 16
WAFERS               66
MEASUREMENTS        186
```

If a number differs, run the script again as FAB_LAB; it is safe to re-run. The tables are described in [Lab 3](lab-3-sql-review.md#the-lab-schema).

## Step 7 (optional): open EM Express

EM Express is the small web console built into the database ([Tools](../module-1/11-tools.md)). If step 1 showed a listening endpoint on port 5500, open this address in your browser:

```text
https://localhost:5500/em
```

Log in as SYSTEM with your installer password. The console uses a self-signed certificate, so your browser may show a security warning first. If you do not know the port, ask the database as SYSTEM in the root:

```sql
SELECT dbms_xdb_config.gethttpsport() AS https_port FROM dual;
```

A result of 0 means no HTTPS port is configured, and EM Express is not reachable.

## Worksheet

| # | Question | Where to look | Your answer |
| --- | --- | --- | --- |
| 1 | Which release are you running? Write down the full version | Section 1 | |
| 2 | Which PDBs exist, and what is the open mode of each? Why does `CDB$ROOT` not appear in this list? | Section 2 | |
| 3 | Is your PDB's open state saved? What would happen after a restart if it were not? | Section 3 (and step 4) | |
| 4 | Which service names does the listener know for the root, and which for your PDB? | Section 4, column `CON_ID`; compare with step 1 | |
| 5 | What is the database character set? | Section 5 | |
| 6 | Where is the spfile? | Section 6 | |
| 7 | Of the eight parameters, which can you change while the instance runs, without a restart? | Section 7, column `ISSYS_MODIFIABLE` | |
| 8 | Which of the eight can be given a different value inside a PDB? | Section 7, column `ISPDB_MODIFIABLE` | |

Hints for reading the output:

- In section 4, `CON_ID` 1 is the root and `CON_ID` 3 is usually your PDB. `SYS$BACKGROUND` and `SYS$USERS` are internal services; no client connects to them by name.
- In section 7, `ISSYS_MODIFIABLE` is `IMMEDIATE` (ALTER SYSTEM changes it at once), `DEFERRED` (the change applies to new sessions) or `FALSE` (a static parameter: it only changes when the instance restarts).
- `ISDEFAULT` is `TRUE` when the parameter was not set in the parameter file.
- Sizes in `v$parameter` are in bytes. Divide by 1024 twice to get MB.

## Checkpoints

| After step | You should see |
| --- | --- |
| 1 | Two service names written down, one for the root and one for the PDB |
| 2 | `CDB$ROOT` in `system-root`, your PDB name in `system-pdb` |
| 3 | Section 1 shows Oracle Database 19c and `CDB$ROOT`; section 2 shows two rows (`PDB$SEED` READ ONLY and your PDB); section 7 shows eight rows |
| 4 | Your PDB READ WRITE in section 2, and OPEN in section 3 |
| 5 | ORA-01918 once (first run only), then `User created.` and `Grant succeeded.` |
| 6 | PRODUCTS 5, TOOLS 9, LOTS 16, WAFERS 66, MEASUREMENTS 186 |

For the debrief, be ready to say which of the eight parameters could be changed without a restart, and how you could tell.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `lsnrctl` is not recognised as a command | The Oracle home's `bin` folder is not on the PATH of this Command Prompt. Open a new Command Prompt after the install, or run `lsnrctl` from `ORACLE_HOME\bin` |
| ORA-12541: TNS:no listener | The listener is stopped. Start the `Oracle...TNSListener` service in Windows Services (for example `OracleOraDB19Home1TNSListener`), or run `lsnrctl start` |
| ORA-12514: listener does not currently know of service | Wrong service name. Copy it from `lsnrctl status`. In SQL Developer choose Service name, not SID |
| ORA-12505: listener does not currently know of SID | The connection uses SID. Switch it to Service name |
| ORA-01109: database not open | The PDB is mounted, not open. Do step 4 in `system-root` |
| Section 2 shows only one row, or section 1 shows your PDB name | The script ran on `system-pdb`. Switch the worksheet to `system-root` and run it again |
| ORA-65096: invalid common user or role name | You ran lab0 in `CDB$ROOT`. Switch the worksheet to `system-pdb` and run lab0 again |
| ORA-01918: user 'FAB_LAB' does not exist | Expected on the first run of lab0. Nothing to fix |
| ORA-01919: role 'CTXAPP' does not exist | Oracle Text is not installed. Fine for today; tell your trainer before Day 4 |
| ORA-01017: invalid username/password | Passwords are case-sensitive. The lab user's password is `Lab_2026` |
| ORA-00942: table or view does not exist in step 6 | You are connected as SYSTEM instead of FAB_LAB. Check the connection at the top right of the worksheet |
| The browser cannot open `https://localhost:5500/em` | Check the port with the `gethttpsport` query in step 7, and that the address starts with `https`. EM Express only works while the database is open |

## Further reading

- [Oracle Database Net Services Administrator's Guide, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/netag/index.html)
- [Oracle Multitenant Administrator's Guide, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/index.html)
- [GitLab blog: Postmortem of database outage of January 31](https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/)
- [Oracle Database Reference, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/index.html) (descriptions of every parameter and V$ view used in the script)
