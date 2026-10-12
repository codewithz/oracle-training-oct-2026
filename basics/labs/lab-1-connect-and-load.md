# Lab 1: Connect and load the lab data

**Time:** 40 minutes. **Reading first:** [How Oracle works, in plain words](../topics/01-how-oracle-works.md).

## The story

It is your first morning at the fab. Maya, the shift manager, hands you a laptop and says: "Everything we track is in the database. Get connected, and load the practice copy so you can ask it questions without breaking anything."

This lab gets you to the point where you can ask those questions. Nothing here is clever. Follow the steps in order, tick each box, and ask for help the moment a step does not match what you see. A connection problem on step 4 is much easier to fix now than on Wednesday.

## What you will do

- find out your database's service name
- connect to your PDB with DBeaver as `SYSTEM`
- create the lab user `FAB_LAB`
- load the five tables
- check the row counts

## Scripts

| File | What it does |
| --- | --- |
| [`lab0_create_user.sql`](scripts/lab0_create_user.sql) | Creates the user `FAB_LAB`. Run as `SYSTEM`. |
| [`lab1_fab_lab_data.sql`](scripts/lab1_fab_lab_data.sql) | Creates and fills the five tables. Run as `FAB_LAB`. |

## Step 1: Check Oracle is running

Press `Win + R`, type `services.msc` and press Enter. Look for two services:

- one starting with `OracleService` (this is the instance)
- one ending in `TNSListener` (this is the host at the door)

Both must say **Running**. If one is stopped, right-click it and choose Start, then wait a minute for the database to open.

## Step 2: Read your service name

Open a Command Prompt and run:

```text
lsnrctl status
```

Scroll to the **Services Summary**. You will see lines like `Service "orcl" has 1 instance(s)` and `Service "orclpdb" has 1 instance(s)`. Two of these matter:

- the name of the **root** (usually the global database name you chose at install, for example `orcl`)
- the name of your **PDB** (for example `orclpdb`)

Ignore the entries with long hexadecimal names and the ones ending in `XDB`.

Write the PDB service name here, because you need it in a minute: **______________**

## Step 3: Install DBeaver and make the connection

If DBeaver Community is not installed yet, install it from the DBeaver website with the default options. Then:

1. Start DBeaver. Choose **Database > New Database Connection**.
2. Pick **Oracle** and click **Next**.
3. Fill in the form:

| Field | What to type |
| --- | --- |
| Connect by | Host |
| Host | `localhost` |
| Port | `1521` |
| Database | your PDB service name from step 2. Choose **Service Name**, not SID. |
| Username | `SYSTEM` |
| Password | `NobleProg@123` (the password chosen when Oracle was installed) |

4. Click **Test Connection**. The first time, DBeaver offers to download the Oracle driver files. Click **Download** and wait. This needs internet once.
5. When the test says **Connected**, click **Finish**.
6. Right-click the new connection, choose **Rename** and call it `system-pdb`.

> **Why a separate connection per user?** Later you will connect as `FAB_LAB` too. Two clearly named connections stop you running a script as the wrong user.

## Step 4: Prove you are in the right place

Click the connection `system-pdb`, then press `Ctrl + ]` to open a new SQL editor. Type this and press `Ctrl + Enter`:

```sql
SELECT sys_context('USERENV', 'CON_NAME') AS container FROM dual;
```

The result must be your PDB name. If it says `CDB$ROOT`, you connected to the root. Edit the connection (select it and press `F4`) and fix the Database field.

Run one more:

```sql
SELECT banner FROM v$version;
```

It should mention **Oracle Database 19c**.

## Step 5: Create the lab user

1. Choose **File > Open File** and open `lab0_create_user.sql`.
2. Check the active connection shown at the top of the editor is `system-pdb`. If not, press `Ctrl + 9` and choose it.
3. Run the whole file with **Execute Script**: `Alt + X`. Do **not** use `Ctrl + Enter`, which runs only one statement.

You should see the statements succeed, with no red errors. If the file runs a second time later, it simply drops and re-creates the user. That is on purpose.

## Step 6: Connect as FAB_LAB

Create a second connection exactly like the first, with two changes:

- **Username:** `FAB_LAB`
- **Password:** `Lab_2026`

Test it, finish, and rename it `fab-lab`. This is the connection you use for the rest of the course.

## Step 7: Load the data

1. Open `lab1_fab_lab_data.sql`.
2. Make sure the active connection is **`fab-lab`**, not `system-pdb`.
3. Press `Alt + X`.

The script finishes with a small table of row counts. It must read:

| TABLE_NAME | ROW_COUNT |
| --- | --- |
| PRODUCTS | 5 |
| TOOLS | 9 |
| LOTS | 16 |
| WAFERS | 66 |
| MEASUREMENTS | 186 |

If a count is wrong, run the script again. It starts by dropping its own tables, so a second run is safe.

## Step 8: Look around

Expand `fab-lab` in the navigator on the left, then **Schemas > FAB_LAB > Tables**. Double-click `LOTS`. Click the **Data** tab to see rows, and the **Properties** tab to see the columns. Then run:

```sql
SELECT * FROM lots;
```

You just asked the database your first question. The next lab teaches you to ask it properly.

## Checkpoints

Tick each box before you move on.

- [ ] `lsnrctl status` showed my PDB service name
- [ ] `system-pdb` connects and `CON_NAME` is my PDB, not `CDB$ROOT`
- [ ] `fab-lab` connects as `FAB_LAB`
- [ ] The row counts are 5, 9, 16, 66 and 186
- [ ] I can open the `LOTS` table in the navigator and see 16 rows

## Troubleshooting

| You see | What it usually means | What to do |
| --- | --- | --- |
| ORA-12541: no listener | The listener service is stopped | Start the `TNSListener` service (step 1) |
| ORA-12514: listener does not know of service | The Database field has the wrong service name | Re-read the Services Summary and retype it |
| ORA-01017: invalid username/password | A typo, or a different install password | Retype with care. Passwords are case sensitive |
| ORA-28000: account is locked | Too many wrong passwords | Ask your trainer, or as `SYSTEM` run `ALTER USER fab_lab ACCOUNT UNLOCK;` |
| ORA-01109: database not open | The PDB is closed | Connect to the root as `SYSTEM`, then run `ALTER PLUGGABLE DATABASE your_pdb_name OPEN;` followed by `ALTER PLUGGABLE DATABASE your_pdb_name SAVE STATE;` |
| ORA-65096: invalid common user | You are connected to the root | Switch the connection to the PDB service name |
| ORA-01918 on the first run of lab 0 | Not an error. The user did not exist yet | The script handles it. Carry on |
| DBeaver asks to download drivers and fails | No internet | Connect to the internet, then try again |

If you use SQL\*Plus instead of DBeaver and the password contains `@`, wrap it in double quotes: `sqlplus system/"NobleProg@123"@//localhost:1521/yourpdb`.

## Further reading

- [Oracle Database 19c Net Services Administrator's Guide: Identifying and accessing the database](https://docs.oracle.com/en/database/oracle/oracle-database/19/netag/identifying-and-accessing-database.html)
- [Oracle Database 19c Net Services Administrator's Guide: Troubleshooting Oracle Net Services](https://docs.oracle.com/en/database/oracle/oracle-database/19/netag/troubleshooting-oracle-net-services.html)
