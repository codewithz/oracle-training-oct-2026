# Install Oracle Database 19c on Windows

Every participant works on their own Oracle Database 19c, installed on their own Windows 10 or Windows 11 machine. This page takes you from an empty machine to a running container database with one pluggable database (PDB), SQL Developer installed, and two working connections. Do it before Day 1. Most of the time goes on downloading the software and waiting while the installer creates the database.

Slides: 4 of the Day 1 deck (the lab environment). The installation itself is explained on [Installing Oracle 19c](../day-1/module-1/03-installing-oracle-19c.md).

The steps follow Oracle's [Database Installation Guide, 19c for Microsoft Windows](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/index.html). If a screen on your machine looks different from what is described here, the installation guide is the reference.

## What you end up with

| Item | Value after this guide |
| --- | --- |
| Database software | Oracle Database 19c (release 19.3), Enterprise Edition, in an Oracle home folder on your C: drive |
| Database | A container database (CDB) with one pluggable database (PDB), character set AL32UTF8 |
| Windows services | One for the database instance and one for the listener, both starting automatically |
| Listener | `localhost`, port 1521 |
| Tool | SQL Developer, with a SYSTEM connection to the root and one to the PDB |
| PDB state | Open in READ WRITE mode, and saved so it opens again after a reboot |

The lab user FAB_LAB is not created here. You create it in [Lab 1](../day-1/labs/lab-1-connect-and-configure.md) on Day 1.

## 1. Check your machine

Oracle lists these minimums for Windows x64 in [Hardware Component Requirements for Windows x64](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/hardware-component-requirements-windowsx64.html) and [Hard Disk Space Requirements](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/hard-disk-space-requirements.html):

| Requirement | Minimum |
| --- | --- |
| Processor | x64 (AMD64 or Intel EM64T) |
| Physical memory | 2 GB |
| Virtual memory (page file) | Same size as the RAM when you have 2 GB to 16 GB of RAM; 16 GB when you have more |
| Disk space for Enterprise Edition | About 10.9 GB (temporary space, inventory, Oracle home and data files) |
| Screen resolution | 1024 x 768 |

Add about 3 GB for the downloaded zip file. You can delete the zip once the installation has finished.

Supported Windows versions are listed in [Oracle Database Software Requirements](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/oracle-database-software-requirements.html). For desktops these are Windows 10 x64 and Windows 11 x64 in the Pro, Enterprise and Education editions. Home editions are not in the list. The same page says Windows 11 is supported starting with Release Update 19.13, which is later than the 19.3 base release you download. If the installer reports a problem with the operating system, see [Troubleshooting](#troubleshooting).

You also need:

- a Windows account that is a member of the local Administrators group (the installer must run as an administrator);
- an internet connection for the downloads;
- an Oracle account to download the software (creating one is free).

## 2. Download Oracle Database 19c for Windows x64

1. Open the page [Oracle Database 19c Download for Microsoft Windows x64 (64-bit)](https://www.oracle.com/database/technologies/oracle19c-windows-downloads.html).
2. Under the database home, download `WINDOWS.X64_193000_db_home.zip`. It is about 2.9 GB (3,105,763,999 bytes). The page has other zip files (grid home, client, examples, gateways); you do not need them.
3. The download asks you to accept the license agreement and to sign in with your Oracle account. Create the account on the sign-in page if you do not have one.

## 3. Extract the zip into the Oracle home

The 19c software is image based: the folder you extract the zip into becomes the Oracle home. There is no separate copy step later, so choose the folder before you extract.

1. Create the folder for the Oracle home. The course slides use `C:\app\oracle\product\19c\dbhome_1`; Oracle's guide uses `C:\app\oracle\product\19.0.0\dbhome_1`. Either works. A short path such as `C:\Oracle` also works. Pick one and use it throughout.
2. Extract the contents of `WINDOWS.X64_193000_db_home.zip` into that folder (in File Explorer: right-click the zip, "Extract All", and give the Oracle home folder as the destination).
3. Check the result: `setup.exe` must be directly inside the Oracle home folder, for example `C:\app\oracle\product\19c\dbhome_1\setup.exe`, next to folders such as `bin` and `network`. If you find it one level deeper, the zip was extracted into a subfolder. Move the contents up, or extract again.

The rest of this page writes `ORACLE_HOME` for the folder you chose.

## 4. Run the installer

Oracle's procedure is in [Installing the Oracle Database Software](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/install-oracle-database.html). Two rules from that page matter here: log in as an administrator, and run `setup.exe` from the Oracle home only (not the `setup.exe` under `ORACLE_HOME\oui\bin`).

1. In File Explorer, go to `ORACLE_HOME`, right-click `setup.exe` and choose "Run as administrator".
2. A console window opens first and stays open behind the installer, printing INFO lines (for example about `extproc.exe.config`). This is normal. Do not close it.

The installer then shows a list of steps on the left. With the choices below, the list is: Configuration Option, System Class, Oracle Home User, Typical Installation, Prerequisite Checks, Summary, Install Product, Finish.

### Configuration Option

Choose "Create and configure a single instance database". With this option the installer installs the software and then runs the Database Configuration Assistant (DBCA) for you, so you get a database at the end. The other main choice, "Set Up Software Only", installs the software without a database; do not use it for this course.

### System Class

Choose "Desktop class". Oracle describes it as the class for laptops and desktop computers: it creates a starter database and needs minimal configuration. Server class leads to more screens with advanced options that the course does not need.

### Oracle Home User

This is the Windows account the Oracle services run as. Choose "Virtual Account". Oracle recommends a Virtual Account or a standard (non-administrator) Windows user rather than a built-in Windows account; see [Creating Oracle Home User](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/creating-oracle-home-user.html). A Virtual Account needs no password, so there is nothing to remember.

### Typical Installation

One screen collects all the settings. Fill it in as follows (the exact field labels on your screen may differ slightly):

| Setting | What to enter |
| --- | --- |
| Oracle base | Leave the proposed value, or set the parent folder of your Oracle home (for example `C:\app\oracle`) |
| Software location | Already your `ORACLE_HOME`; leave it |
| Database file location | Leave the proposed value |
| Database edition | Enterprise Edition |
| Character set | Unicode (AL32UTF8). It is normally preselected; check it. Changing the character set of an existing database later is a project, so get it right now |
| Global database name | `orcl` (this becomes the service name of the root container) |
| Password and confirm password | A password for the administrative accounts, including SYS and SYSTEM. Write it down: you connect as SYSTEM on Day 1 |
| Create as Container database | Checked |
| Pluggable database name | `orclpdb` (this becomes the service name of your PDB) |

You may choose other names than `orcl` and `orclpdb`. Whatever you choose, you read the real service names from the listener later, in step 6, and use those.

If the installer warns that the password does not meet Oracle's recommended standard, you can go back and choose a stronger one. Oracle's password recommendations are referenced from [Requirements for Database Password](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/requirements-for-database-password.html).

### Prerequisite Checks, Summary, Install Product

1. "Prerequisite Checks" runs automatically. If a check fails, read its message. The installation goes ahead only when every check shows Succeeded or Warning.
2. "Summary" lists your choices. Check the global database name, the PDB name and the character set, then click "Install".
3. "Install Product" shows the progress: first the software, then the database creation by DBCA. This part takes the longest. Leave the machine on and awake.

### Finish

The Finish page (step 8 of 8) should say "The configuration of Oracle Database was successful". It also shows the URL of Oracle Enterprise Manager Database Express (EM Express), the browser tool built into the database:

```text
https://localhost:5500/em
```

Note the URL, then click "Close".

## 5. Check the Windows services

The installer registers the database and the listener as Windows services that start automatically; see [Understanding Oracle Database Services on Windows](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/understanding-oracle-database-services-on-windows.html). Open the Services tool (press Windows+R, type `services.msc`, press Enter) and find:

| Service | Name pattern | Example with the defaults above |
| --- | --- | --- |
| Database instance | `OracleService<SID>` | `OracleServiceORCL` |
| Listener | `Oracle<HOMENAME>TNSListener` | `OracleOraDB19Home1TNSListener` |

Both should have the status Running and the startup type Automatic. You may see further Oracle services; leave them as they are.

You start and stop these services like any other Windows service: right-click, then Start or Stop ([Starting and Stopping the Database from the Microsoft Windows Services Utility](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/starting-and-stopping-db-from-microsoft-utility.html)).

## 6. Read your service names from the listener

Open a new Command Prompt and run:

```text
lsnrctl status
```

Scroll to the section that starts with `Services Summary...`. It lists every service name the listener knows, one `Service "..."` line each. Look for two of them:

- the root container's service, named after the global database name you entered (for example `orcl`);
- the PDB's service, named after the pluggable database name you entered (for example `orclpdb`).

You may see other entries too, such as a service whose name is a long hexadecimal string. Ignore them. Write down the two names: you need them in SQL Developer, and Lab 1 starts from them. The listener and service names are explained on [Oracle Net and the listener](../day-1/module-1/04-oracle-net-and-the-listener.md).

If the command is not recognised, close the Command Prompt and open a new one, or run it with its full path, `ORACLE_HOME\bin\lsnrctl status`.

## 7. Install SQL Developer

SQL Developer is the tool for all the labs. Oracle's database home includes a copy of SQL Developer (on the Start menu under the Oracle home entry), but install the current release from Oracle's site, as the course does.

1. Open [Oracle SQL Developer Downloads](https://www.oracle.com/database/sqldeveloper/technologies/download/).
2. Download the Windows 64-bit zip that includes the JDK (the page says the archive includes JDK 17). With this file you do not need to install Java separately.
3. Unzip it into a folder of your choice, for example `C:\`. This creates a folder `C:\sqldeveloper`. Do not unzip into an existing `sqldeveloper` folder from an older version: delete the old folder first, or use another location.
4. Start SQL Developer by double-clicking `sqldeveloper.exe` in the `sqldeveloper` folder. You can pin it to the taskbar.

The steps are in the [Oracle SQL Developer Installation Guide](https://docs.oracle.com/en/database/oracle/sql-developer/26.2/rptig/installing-and-starting-sql-developer.html), section "Windows Systems".

## 8. Connect as SYSTEM to the root and to the PDB

In SQL Developer, right-click "Connections" in the Connections panel and choose "New Connection". Create two connections:

| Field | Connection 1 | Connection 2 |
| --- | --- | --- |
| Name | `system-root` | `system-pdb` |
| Username | `SYSTEM` | `SYSTEM` |
| Password | The password from the installer | The same |
| Hostname | `localhost` | `localhost` |
| Port | `1521` | `1521` |
| Service name (not SID) | Your root service, for example `orcl` | Your PDB service, for example `orclpdb` |

Make sure you select "Service name" and not "SID". They are two different fields, and a service name typed into the SID field fails. The listener works like a hotel receptionist: you ask for a guest by name, and if you give a name the receptionist has never heard of (ORA-12514), you do not get upstairs. Click "Test": the status should change to Success. Then click "Save" and "Connect".

In each connection's worksheet, run these lines (put the cursor in the worksheet and press F5, Run Script):

```sql
SHOW CON_NAME
SELECT banner_full FROM v$version;
```

In `system-root` the container name is `CDB$ROOT`. In `system-pdb` it is your PDB name, for example `ORCLPDB`. The banner shows Oracle Database 19c and the release, for example 19.3.0.0.0.

Then check the database character set:

```sql
SELECT value
FROM   nls_database_parameters
WHERE  parameter = 'NLS_CHARACTERSET';
```

The result must be `AL32UTF8`.

## 9. Open the PDB and save its state

A PDB has its own open mode. After the container database restarts, for example after a Windows reboot, a PDB comes back only MOUNTED unless its open state has been saved. Applications that connect to it then get ORA-01109 "database not open". Saving the state is like leaving the night shift a note of which tools to switch back on after a power cut; without the note, the PDB sits there mounted, like a tool left idling. You fix that once, now.

In the `system-root` connection (you must be in `CDB$ROOT`), run:

```sql
SELECT name, open_mode FROM v$pdbs;

ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;

SELECT con_name, state FROM dba_pdb_saved_states;
```

The first query lists `PDB$SEED` (READ ONLY) and your PDB. The two ALTER statements each return "Pluggable database altered". Running `ALL OPEN` when the PDB is already open is harmless. The last query should show your PDB with the state OPEN. For comparison, on a small test install whose PDB is called XEPDB1 the last query returned:

```text
CON_NAME     STATE
------------ --------------
XEPDB1       OPEN
```

`SAVE STATE` tells the database to give the PDB the same open mode after a restart that it had just before ([ALTER PLUGGABLE DATABASE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ALTER-PLUGGABLE-DATABASE.html) in the SQL Language Reference). Configuration after the install is covered on [Configuration and parameters](../day-1/module-1/05-configuration-and-parameters.md).

To be sure, restart Windows, open SQL Developer, connect with `system-root` and run `SELECT name, open_mode FROM v$pdbs;` again. Your PDB must show READ WRITE.

## A note on patching

19.3 is the base release of Oracle Database 19c. Production systems run a later Release Update, which is applied with Oracle's OPatch tool. The installation guide describes where Release Updates come from in [Downloading Release Update Patches](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/downloading-and-installing-patch-updates.html). You do not need to patch for this course unless your trainer asks you to.

## Final checklist

Before Day 1, check each line:

- [ ] `setup.exe` was run from the Oracle home and the Finish page said the configuration was successful.
- [ ] Services shows `OracleService<SID>` and the TNS listener service as Running, startup type Automatic.
- [ ] `lsnrctl status` lists your root service and your PDB service, and you have written both names down.
- [ ] SQL Developer starts, and the `system-root` and `system-pdb` connections both test with Success.
- [ ] `SHOW CON_NAME` returns `CDB$ROOT` in one connection and your PDB name in the other.
- [ ] `SELECT banner_full FROM v$version;` shows Oracle Database 19c.
- [ ] The character set is AL32UTF8.
- [ ] `dba_pdb_saved_states` shows your PDB as OPEN, and the PDB is READ WRITE after a reboot.
- [ ] You know the SYSTEM password.

On Day 1, Lab 1 starts from this point: it creates the lab user FAB_LAB in your PDB and loads the lab data.

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| The installer stops at Prerequisite Checks with a failed check | Read the message and fix what it names, then run the check again. On Windows 11 the 19.3 base release is older than the first release Oracle supports there (19.13). If a check about the operating system fails and you cannot resolve it, note the exact message and contact your trainer before Day 1 |
| The installer does not start, or complains about its location | Run `setup.exe` from the Oracle home folder, as an administrator. Check that the zip was not extracted into an extra subfolder |
| A console window stays open behind the installer, printing INFO lines | Normal. Leave it open until the installer has finished |
| `lsnrctl` or `sqlplus` is "not recognized as an internal or external command" | Open a new Command Prompt, or use the full path `ORACLE_HOME\bin\lsnrctl` |
| ORA-12541: TNS:no listener | The listener service is stopped. Start the `Oracle...TNSListener` service in Services, or run `lsnrctl start` |
| ORA-12514: TNS:listener does not currently know of service requested in connect descriptor | The service name is wrong, or it was typed into the SID field. Copy the name from `lsnrctl status` and choose Service name in SQL Developer. Right after the database service starts, wait a minute and try again: the database registers its services with the listener shortly after it opens |
| ORA-01109: database not open | The PDB is only mounted. As SYSTEM in the root, run `ALTER PLUGGABLE DATABASE ALL OPEN;` and then `ALTER PLUGGABLE DATABASE ALL SAVE STATE;` |
| ORA-01017: invalid username/password; logon denied | Passwords are case-sensitive. Use the password you entered on the Typical Installation screen |
| The database service is stopped after a reboot | Start `OracleService<SID>` in Services and check that its startup type is Automatic |
| SQL Developer asks for the path to a JDK | You downloaded the zip without the JDK. Download the one that includes JDK 17, or point it to an installed JDK 17 |
| SQL Developer does not start | Oracle's download page notes that the Windows executable needs `MSVCR100.dll`, and that a 32-bit copy found first on the PATH stops it from starting. The page suggests copying a 64-bit `MSVCR100.dll` into SQL Developer's `bin` folder or fixing the PATH order |

## Further reading

- [Oracle Database Database Installation Guide, 19c for Microsoft Windows](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/index.html)
- [Database Installation Guide for Microsoft Windows: Installing the Oracle Database Software](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/install-oracle-database.html)
- [Database Installation Guide for Microsoft Windows: Oracle Database Software Requirements](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/oracle-database-software-requirements.html)
- [Database Installation Guide for Microsoft Windows: Understanding Oracle Database Services on Windows](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/understanding-oracle-database-services-on-windows.html)
- [Database Installation Guide for Microsoft Windows: Accessing Oracle Database with Oracle SQL Developer](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/accessing-oracle-database-with-oracle-sql-developer.html)
- [Oracle Database 2 Day DBA: Installing Oracle Database and Creating a Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/installing-oracle-database-creating-database.html)
- [Oracle SQL Developer Downloads](https://www.oracle.com/database/sqldeveloper/technologies/download/)
- [Oracle SQL Developer Installation Guide, Release 26.2](https://docs.oracle.com/en/database/oracle/sql-developer/26.2/rptig/index.html)
- [Oracle SQL Developer User's Guide, Release 26.2](https://docs.oracle.com/en/database/oracle/sql-developer/26.2/rptug/index.html)
