# Installing Oracle 19c

This page explains the ideas behind a 19c installation on Windows: what the Oracle base and Oracle home are, what an image-based install is, what the setup wizard and DBCA each do, which Windows services you end up with, and why the character set choice matters. It does not repeat the click-by-click steps; those are in [Install Oracle Database 19c on Windows](../../before-you-start/install-oracle-19c-windows.md).

Slides: 8 of the Day 1 deck.

## The install at a glance

The slide summarises the course install in five steps:

| Step | What you do | What you get |
| --- | --- | --- |
| 1 | Unzip the 19.3 zip into the Oracle home, for example `C:\app\oracle\product\19c\dbhome_1` | Software in place |
| 2 | Run `setup.exe` and choose "Create and configure a single instance database" | DBCA runs for you |
| 3 | Oracle Home user: virtual account. Character set: AL32UTF8 | Correct Unicode from day one |
| 4 | Container database ORCL with one PDB, ORCLPDB | A CDB and a PDB |
| 5 | Apply the latest Release Update with OPatch | 19.3 is only the base release |

The result is a running database: the Windows services for the instance and the listener, the listener on port 1521, and EM Express on port 5500. The sections below explain each idea.

## Oracle base and Oracle home

Two directories organise everything Oracle puts on disk.

The **Oracle base** is the top-level directory of an Oracle installation, for example `C:\app\oracle`. The installer creates it if no other Oracle software is on the machine; its default form on Windows is `C:\app\<user name>`. The Oracle Home user (see below) has full control over it. Diagnostic files such as the alert log and trace files live under it, in the `diag` folder.

The **Oracle home** is the directory that holds one installed copy of the database software, for example `C:\app\oracle\product\19c\dbhome_1`. It sits under the Oracle base. You can have several Oracle homes on one machine, for instance a 19c home and a 21c home, and each Windows service and each tool belongs to one home. Inside the Oracle home you will find, among others:

| Folder under the Oracle home | Contents |
| --- | --- |
| `bin` | Executables: `sqlplus`, `lsnrctl`, `dbca`, `netca` |
| `network\admin` | Oracle Net files: `listener.ora`, `tnsnames.ora`, `sqlnet.ora` |
| `database` | On Windows, the default location of the parameter files |
| `OPatch` | The tool that applies patches to this home |

Scripts and documentation refer to these two directories as `%ORACLE_BASE%` and `%ORACLE_HOME%` on Windows (`$ORACLE_BASE` and `$ORACLE_HOME` on Linux).

## Image-based installation

Oracle Database 19c software is shipped as a zip file that is already an Oracle home (an **image-based installation**). You do not run an installer that copies files to a destination. Instead you:

1. create the directory you want as the Oracle home,
2. extract the zip into it,
3. run the setup wizard (`setup.exe` on Windows) from that directory.

The setup wizard registers the software and, if you ask it to, creates a database. Oracle's documentation states that you must extract the zip into the directory where you want the Oracle home to be. Extracting it into `Downloads` or a temporary folder and running setup from there makes that temporary folder your Oracle home. Think of a process tool that arrives already assembled on its frame: wherever the riggers set it down is where it gets hooked up, so you pick the bay before the crate is opened.

## The Oracle Home user

On Windows, the database services run under a Windows account called the **Oracle Home user**. The installer offers:

- a **virtual account** (the course choice, and one of the two options Oracle recommends): no password to manage, and it can create and manage database services,
- an existing standard Windows user (not an administrator),
- a new Windows local user created by the installer,
- the Windows built-in account (LocalSystem), which Oracle does not recommend for security reasons.

For a training laptop, the virtual account is the simplest choice.

## The setup wizard and DBCA

Installing the software and creating a database are two separate jobs, much as installing a new tool in the fab is a separate job from running the first lot through it.

The **setup wizard** installs (registers) the software in the Oracle home. If you choose "Create and configure a single instance database", it then runs the **Database Configuration Assistant (DBCA)** for you. DBCA is the tool that actually creates a database: it creates the instance's parameter file, the control files, the online redo logs and the data files, and for a container database the root, the seed and the PDBs you asked for. Oracle recommends DBCA over writing a `CREATE DATABASE` statement by hand, because the database is ready to use when DBCA finishes.

You can run DBCA again later from `%ORACLE_HOME%\bin\dbca` to create another database, add a PDB, or delete a database. The companion tool **NETCA** (Net Configuration Assistant) creates or changes listeners and `tnsnames.ora` entries.

For this course DBCA creates a container database called ORCL (this is also the SID, the name of the instance) with one PDB called ORCLPDB. See [Multitenant architecture](02-multitenant-architecture.md).

## Character set

The **database character set** decides how text in VARCHAR2, CHAR and CLOB columns is encoded. The course install uses **AL32UTF8**, Oracle's name for UTF-8. Since 12.2 it is the default for databases created from DBCA's general-purpose template, and Oracle recommends it.

Changing it later is hard, a bit like deciding a production line should run a different wafer diameter after the tools are installed. Oracle's installation guide warns that changing the character set of an existing database is usually very expensive in time and resources and may mean exporting and re-importing all the data. Choose AL32UTF8 at install time and you can store any language, including the accented names and units such as "µm" that appear in real fab data.

You can check the character set of any database with a data dictionary query. On the test database used for these pages:

```sql
SELECT parameter, value
FROM   nls_database_parameters
WHERE  parameter IN ('NLS_CHARACTERSET', 'NLS_NCHAR_CHARACTERSET');
```

```text
PARAMETER                VALUE
------------------------ ------------
NLS_NCHAR_CHARACTERSET   AL16UTF16
NLS_CHARACTERSET         AL32UTF8
```

`NLS_NCHAR_CHARACTERSET` is the separate national character set used by NCHAR, NVARCHAR2 and NCLOB columns.

## What you have after the install

On Windows, the database runs as Windows services. With the course names you get:

| Windows service | What it is |
| --- | --- |
| `OracleServiceORCL` | The database instance ORCL |
| `OracleOraDB19Home1TNSListener` | The listener for the Oracle home `OraDB19Home1` |

Other Oracle services appear too (for example a VSS writer service), but these two are the ones you check when something does not work. You can see them in the Windows Services console (`services.msc`).

In addition:

- the listener listens on TCP port 1521 (see [Oracle Net and the listener](04-oracle-net-and-the-listener.md)),
- EM Express, a small web console built into the database, is available at `https://localhost:5500/em` (see [Tools](11-tools.md)),
- the Oracle Net configuration files are in `%ORACLE_HOME%\network\admin`,
- the alert log, the instance's own diary of startups, shutdowns, parameter changes and errors, is under `%ORACLE_BASE%\diag\rdbms\...`. The query below gives the exact folder on any platform:

```sql
SELECT value FROM v$diag_info WHERE name = 'Diag Trace';
```

On the Linux test database this returned `/opt/oracle/diag/rdbms/xe/XE/trace`; on your Windows install it is a folder under `%ORACLE_BASE%\diag\rdbms`. The alert log is the file `alert_<SID>.log` in that folder, for example `alert_ORCL.log`.

## Base release and Release Updates

The 19c zip contains release 19.3, the base release. Oracle publishes Release Updates (RUs) for 19c, which contain security and bug fixes, and Oracle's installation guide tells you to download and install them after the installation. Each RU raises the second number of the version (19.4, 19.5 and so on). You apply an RU with **OPatch**, the patching tool in `%ORACLE_HOME%\OPatch`, following the README that comes with the patch.

For the course a 19.3 database is enough. In production, expect to see a recent 19.x Release Update.

## Common mistakes

- Extracting the zip to a temporary folder. The folder you extract into is the Oracle home. Create the final directory first.
- Picking a legacy character set. WE8MSWIN1252 and similar character sets limit which characters you can store. Moving to AL32UTF8 later is a project.
- Using an administrator account as the Oracle Home user. Oracle recommends a virtual account or a standard user.
- Assuming 19.3 is up to date. It is the base release. Production systems need a Release Update.
- Not knowing your names. Write down the SID (ORCL), the PDB name (ORCLPDB), the passwords you set and the Oracle home path. You need them to connect.

## Check your understanding

1. What is the difference between the Oracle base and the Oracle home?
2. What is "image-based" about a 19c installation, and what does that mean for where you unzip the software?
3. Which tool creates the database, and when does it run during the course install?
4. Why should you choose AL32UTF8 at install time instead of planning to change it later?
5. Which two Windows services do you check first when you cannot connect?

## Further reading

- [Oracle Database Installation Guide for Microsoft Windows 19c, chapter 7: Installing Oracle Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/installing-oracle-database.html)
- [Oracle Database Installation Guide for Microsoft Windows 19c: About Image-Based Oracle Database Installation](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/about-image-based-database-installation.html)
- [Oracle Database Installation Guide for Microsoft Windows 19c: Creating Oracle Home User](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/creating-oracle-home-user.html)
- [Oracle Database Installation Guide for Microsoft Windows 19c: Oracle Home Directory](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/oracle-home-directory.html)
- [Oracle Database Installation Guide for Microsoft Windows 19c: About Character Set Selection During Installation](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/about-character-set-selection-during-installation.html)
- [Oracle Database Installation Guide for Microsoft Windows 19c, chapter 8: Oracle Database Postinstallation Tasks](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/oracle-database-postinstallation-tasks.html)
- [Oracle Database Administrator's Reference for Microsoft Windows 19c: About Windows Services for Oracle Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntqrf/about-windows-services-for-oracle-database.html)
- [Oracle Database Administrator's Guide 19c, chapter 2: Creating and Configuring an Oracle Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/creating-and-configuring-an-oracle-database.html) (DBCA and character set selection)

### Answers

1. The Oracle base is the top-level directory for one installation owner's Oracle software and files, including diagnostic files. The Oracle home is one installed copy of the database software, and it sits under the Oracle base. A machine can have several Oracle homes.
2. The zip file is already an Oracle home. You create the final Oracle home directory, extract the zip into it, and run `setup.exe` from there. Wherever you extract it becomes the Oracle home.
3. DBCA, the Database Configuration Assistant. The setup wizard runs it when you choose "Create and configure a single instance database". You can also run it on its own later.
4. AL32UTF8 can store any language and is Oracle's recommended character set. Changing the character set of a database that already holds data is slow and expensive and may require a full export and import.
5. `OracleServiceORCL` (the instance) and `OracleOraDB19Home1TNSListener` (the listener), or the equivalents for your SID and Oracle home name.
