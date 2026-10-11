# Lab 2: Inside your instance

In this lab you look at the architecture of your own database from three sides. First, as SYSTEM, you read the memory, the background processes and the files of the instance from V$ views. Then, as FAB_LAB in two separate sessions, you see read consistency and row locking happen. Last, still as FAB_LAB, you use the data dictionary to describe the lab schema: its tables, foreign keys, indexes and segments.

Slides: 19 of the Day 1 deck.

| | |
| --- | --- |
| Time | 35 minutes: part 1 about 15, part 2 about 10, part 3 about 10 |
| Database | Your PDB with the lab data, as set up in [Lab 1](lab-1-connect-and-configure.md) |
| Connections | `system-root` for part 1; two unshared FAB_LAB worksheets for part 2; `fab_lab` for part 3 |
| You finish with | Your instance described on one page, proof that readers do not see uncommitted changes, and FAB_LAB unchanged |

## What this lab practises

| Part | Topic page |
| --- | --- |
| 1 | [Instance and database](../module-1/06-instance-and-database.md), [Memory: the SGA and the PGA](../module-1/07-memory-sga-and-pga.md), [Background processes](../module-1/08-background-processes.md), [Storage structures](../module-1/09-storage-structures.md) |
| 2 | [COMMIT, redo and undo](../module-1/10-commit-redo-and-undo.md), [Tools](../module-1/11-tools.md) (unshared worksheets) |
| 3 | [The data dictionary](../module-1/12-data-dictionary.md), [Storage structures](../module-1/09-storage-structures.md) |

## Scripts

| Script | Run as | Used in |
| --- | --- | --- |
| [`lab2_explore_instance.sql`](scripts/lab2_explore_instance.sql) | SYSTEM, in the root (section 6 optionally in the PDB) | Part 1 |
| (no script) | FAB_LAB, two unshared worksheets | Part 2 |
| [`lab2_dictionary.sql`](scripts/lab2_dictionary.sql) | FAB_LAB, in the PDB | Part 3 |

The numbers you read in part 1 depend on your edition, your options and your memory settings. Do not expect your neighbour's sizes or process counts to match yours.

## Part 1: Memory, processes and files

1. Open `lab2_explore_instance.sql` in a worksheet for the `system-root` connection. Sections 1 to 5 must run in the root, because they look at the whole instance and every container.
2. Press F5 and read the Script Output. Each block starts with a `=== n. ...` heading. Section 1 must say `CDB$ROOT`.
3. Answer questions 1 to 8 of the [worksheet](#worksheet).

| Section | Views | Topic page |
| --- | --- | --- |
| 1, 2 | `SHOW CON_NAME`, `v$instance`, `v$database` | [Instance and database](../module-1/06-instance-and-database.md) |
| 3 | `v$containers` | [Multitenant architecture](../module-1/02-multitenant-architecture.md) |
| 4 | `v$sgainfo`, `v$parameter` | [Memory: the SGA and the PGA](../module-1/07-memory-sga-and-pga.md) |
| 5 | `v$bgprocess`, `v$controlfile`, `v$log`, `v$logfile`, `v$datafile`, `v$tablespace` | [Background processes](../module-1/08-background-processes.md), [Storage structures](../module-1/09-storage-structures.md) |

Section 3 lists all three containers, including `CDB$ROOT`, which `v$pdbs` in Lab 1 did not show.

### Optional: section 6 in the PDB

Section 6 is commented out, because it must run in the PDB. Copy these queries into a worksheet for the `system-pdb` connection and run them:

```sql
-- Who is connected, and with which tool?
SELECT username, program, status FROM v$session WHERE username IS NOT NULL;

-- The lab schema after fab_lab_data.sql
SELECT table_name, num_rows FROM dba_tables WHERE owner = 'FAB_LAB' ORDER BY table_name;
SELECT segment_name, segment_type, bytes/1024 AS kb
FROM   dba_segments WHERE owner = 'FAB_LAB' ORDER BY bytes DESC;
```

Your own SQL Developer sessions appear in `v$session`. `num_rows` in `dba_tables` may be empty: it is filled in when optimizer statistics are gathered, not by counting rows. Statistics come back on Day 4.

## Part 2: Read consistency with two sessions

You need two database sessions as FAB_LAB. In SQL Developer, every worksheet of one connection normally shares a single session, so a second normal worksheet would see your uncommitted change. Open the second worksheet as an unshared worksheet instead: select the `fab_lab` connection and press Ctrl+Shift+N. Its tab has its own session.

Run each statement on its own with Ctrl+Enter, in this order. Do not COMMIT anything in this part.

| # | Worksheet | Statement | What happens |
| --- | --- | --- | --- |
| 1 | 1 | `UPDATE lots SET status = 'HOLD', hold_reason = 'Read test' WHERE lot_id = 'L26-010';` | 1 row updated. Not committed |
| 2 | 1 | `SELECT lot_id, status FROM lots WHERE lot_id = 'L26-010';` | Note the status (question 9) |
| 3 | 2 | `SELECT lot_id, status FROM lots WHERE lot_id = 'L26-010';` | Note the status (question 9) |
| 4 | 2 | `UPDATE lots SET priority = priority WHERE lot_id = 'L26-010';` | Watch what happens (question 10). Leave it and go on |
| 5 | 1 | `ROLLBACK;` | Rollback complete |
| 6 | 2 | (look at the result of step 4) | Question 10 |
| 7 | 2 | `ROLLBACK;` | Rollback complete |

Step 4 changes nothing in the data (it sets the priority to its own value), but it is still an UPDATE of the row, so it needs that row.

A picture that helps with question 9: a query works from something like a photograph of the lot board taken when it started, while the shift keeps moving lots on the real board. Uncommitted moves are not in anyone else's photograph.

Optional, while worksheet 2 is in step 4: in the `system-root` or `system-pdb` connection, run

```sql
SELECT sid, blocking_session FROM v$session WHERE blocking_session IS NOT NULL;
```

and see which session waits for which. This is the query a DBA runs first when users say "the application hangs".

Finish with both worksheets rolled back. Labs 3 to 5 rely on the data as it was loaded. To check, run `SELECT lot_id, status, hold_reason FROM lots WHERE lot_id = 'L26-010';` in either worksheet: the lot must be ACTIVE with no hold reason.

## Part 3: The data dictionary

1. Open `lab2_dictionary.sql` in a worksheet for the `fab_lab` connection and press F5.
2. Answer questions 11 to 14 of the worksheet.

| Section | Views | Shows |
| --- | --- | --- |
| 1 | `user_tables` | Your tables and the tablespace each one is stored in |
| 2 | `user_tab_columns` | The columns of LOTS, their types and whether they allow NULL |
| 3 | `user_constraints` | The foreign keys, joined to the constraint they refer to |
| 4 | `user_indexes`, `user_ind_columns` | Each index and the column or columns it covers |
| 5 | `user_segments` | The space each table and index takes |
| 6 | `dictionary` | Dictionary views whose name starts with `USER_CONS` |

The script runs as FAB_LAB, so it uses the `USER_` views, which show only FAB_LAB's own objects. SQL Developer's Connections tree reads the same views when you expand Tables or Indexes. See [The data dictionary](../module-1/12-data-dictionary.md).

## Worksheet

| # | Question | Where to look | Your answer |
| --- | --- | --- | --- |
| 1 | Instance name, host name and when the instance was started | Part 1, section 2, `v$instance` | |
| 2 | Is it a container database? Which log mode? | Part 1, section 2, `v$database` | |
| 3 | Size of the buffer cache and of the shared pool, in MB, and the maximum SGA size | Part 1, section 4, `v$sgainfo` | |
| 4 | What is `memory_target`? What does that value tell you about how SGA and PGA are sized? | Part 1, section 4, `v$parameter` | |
| 5 | How many background processes are running? Name the one that writes redo and the one that writes data blocks | Part 1, section 5 | |
| 6 | How many control files? How many online redo log groups? Which group is CURRENT? | Part 1, section 5 | |
| 7 | Which tablespaces does your PDB have? | Part 1, section 5, last query | |
| 8 | Is ARC0 running? Why, or why not? | Part 1, section 5 (and question 2) | |
| 9 | What status did worksheet 1 see for L26-010 after its UPDATE, and what did worksheet 2 see? Why the difference? | Part 2, steps 2 and 3 | |
| 10 | What happened to worksheet 2's UPDATE, and what made it finish? | Part 2, steps 4 to 6 | |
| 11 | Which tables have a foreign key that points to LOTS? | Part 3, section 3, column `R_TABLE` | |
| 12 | How many indexes does FAB_LAB have? Is that the same as the number of rows in section 4? | Part 3, section 4 | |
| 13 | How many segments does FAB_LAB have, and how big is each one? | Part 3, section 5 | |
| 14 | Which dictionary view would you query to see the columns of a constraint? | Part 3, section 6 | |

Hints:

- `v$sgainfo` already gives MB in the script. `v$parameter` shows bytes: divide by 1024 twice.
- In `v$bgprocess`, a process is running when its `paddr` is not `'00'`; the script filters on that.
- In the redo log query, a group can have more than one member (file). Count the groups, not the rows.
- Question 9: which session made the change, and has it been committed?
- Question 10: a reader never blocks a writer, and a writer never blocks a reader. What about two writers of the same row?
- Question 12: look at the index names, not only at the row count.

## Discussion

A COMMIT returns as soon as which process has written what? Why is that enough to survive a power cut? Think about it with your partner, then read [COMMIT, redo and undo](../module-1/10-commit-redo-and-undo.md).

## Checkpoints

| Part | You should see |
| --- | --- |
| 1 | Section 1 shows `CDB$ROOT`; section 3 shows three containers (`CDB$ROOT`, `PDB$SEED`, your PDB); LGWR and DBW0 in the list of core processes; at least two control files |
| 2 | Step 3 does not wait; step 4 waits until step 5; after step 7, L26-010 is ACTIVE with no hold reason |
| 3 | Section 1 lists five tables, all in tablespace USERS; section 3 lists five foreign keys; section 4 returns 12 rows; section 5 lists 16 segments |

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Section 3 of part 1 shows only one container, or section 1 shows your PDB name | The worksheet is on `system-pdb`. Switch it to `system-root` and run again |
| Memory values in the PDB differ from the root (for example `sga_target` 0) | Memory belongs to the whole instance. Read it from the root, as the script does |
| ARC0 is missing from the process list | Expected in NOARCHIVELOG mode. That is question 8 |
| In part 2, worksheet 2 sees HOLD | Worksheet 2 shares worksheet 1's session. Close it and open an unshared worksheet with Ctrl+Shift+N. Also check that autocommit is off in SQL Developer (Tools, Preferences, Database, Advanced) |
| In part 2, the UPDATE in step 4 does not wait | Worksheet 1 has already rolled back or committed, or the two worksheets share one session. Start part 2 again from step 1 |
| SQL Developer asks whether to commit or roll back when you disconnect | Choose Rollback |
| L26-010 is still HOLD at the end of part 2 | Something was committed. Run `fab_lab_data.sql` again as FAB_LAB to reload the data |
| ORA-00942: table or view does not exist in part 2 or 3 | The worksheet is connected as SYSTEM. Use the `fab_lab` connection |
| Part 3 lists tables and indexes you do not recognise | You ran it as SYSTEM. The `USER_` views show only the connected user's own objects; run the script on the `fab_lab` connection |

## Further reading

- [Oracle Database Concepts, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/index.html) (memory, process and storage architecture; data concurrency and consistency)
- [Oracle Database Reference, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/index.html) (every V$ and data dictionary view used in this lab)
