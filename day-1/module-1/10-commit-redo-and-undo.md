# COMMIT, redo and undo

This page follows a transaction through the instance: what an UPDATE changes in memory, what a COMMIT waits for, and how Oracle recovers committed work after a crash. It then explains undo, which gives you ROLLBACK and read consistency, and the ORA-01555 "snapshot too old" error that appears when undo runs out for a long query.

Slides: 16 of the Day 1 deck.

## A transaction in three steps

Take an invented example from the FAB_LAB wafer fab: a user puts lot L26-010 on hold.

```sql
UPDATE lots SET status = 'HOLD' WHERE lot_id = 'L26-010';
COMMIT;
```

### 1. Change

The server process reads the block that holds the row into the buffer cache (if it is not already there) and changes it in memory. Two more things happen at the same time:

- The old value (`ACTIVE`) is recorded as **undo**, in an undo segment of the undo tablespace. Undo is what Oracle needs to reverse the change.
- A description of the change is written as **redo** into the redo log buffer. Redo is what Oracle needs to repeat the change. The change to the undo block is also protected by redo.

The changed block in the buffer cache is now dirty. Nothing has been written to the data files.

### 2. COMMIT

At COMMIT, Oracle assigns the transaction a system change number (SCN) and puts a commit record in the redo log buffer. LGWR writes the remaining redo, including the commit record, to the online redo log on disk. Oracle's Concepts guide calls the write of the commit record "the single event that determines that the transaction has committed". Then the locks are released and COMMIT returns to your session.

COMMIT does not wait for the changed data blocks to reach the data files. This is called **fast commit**. A restaurant works the same way: the waiter writes your order on the ticket and confirms it straight away, and the kitchen cooks the dish afterwards. The ticket is the redo, and once it is written the order will not be forgotten. A commit is usually quick whatever the size of the transaction, because LGWR has already been writing the redo in the background while the transaction ran, and because redo is written sequentially, which is faster than writing blocks scattered across data files.

### 3. Later

DBWn writes the dirty block to the data file whenever it suits: when buffers are needed, or at a checkpoint. That can be seconds or minutes later, and it can even happen before the commit. Before writing a block, DBWn makes sure the redo for it is already on disk (the write-ahead rule).

## Why the redo is enough

Suppose the server loses power after the COMMIT returned but before DBWn wrote the block. The data file still holds `ACTIVE`. The online redo log holds the change and the commit record.

When the database is opened again, SMON performs **instance recovery** automatically, in two phases:

1. **Rolling forward** (cache recovery): Oracle applies all the changes recorded in the online redo log, starting at the last checkpoint. This repeats the committed UPDATE, and it also rebuilds the undo for any transactions that were still open.
2. **Rolling back** (transaction recovery): Oracle uses undo to remove changes of transactions that had not committed.

The redo log works like the lot traveller (run card) that goes with every lot and records each step it went through. If the wafer data were lost, you could take the traveller and replay the steps. Recovery does exactly that with the redo. The result is a database that contains every committed change and no uncommitted ones. This answers the discussion question in Lab 2: a COMMIT returns as soon as LGWR has written the transaction's redo, and that is enough to survive a power cut because recovery replays the redo.

The checkpoint limits how much redo recovery has to read: every change older than the checkpoint is already in the data files. This is also why an online redo log group cannot be overwritten until the changes it protects have been checkpointed (see [Storage structures](09-storage-structures.md)).

Instance recovery covers a crash of the instance. If the files themselves are deleted or damaged, you need a backup plus the archived redo logs, and the backup has to restore when you need it. GitLab found that out in January 2017, after an engineer deleted the data directory on the wrong database server: none of its backup methods worked as expected (a pg_dump job had been failing silently, and disk snapshots were not enabled for the database servers). It restored from an LVM snapshot about 6 hours old and lost about 6 hours of data. [Multitenant architecture](02-multitenant-architecture.md) tells the rest of the story.

## When commits are the bottleneck

Each COMMIT waits for one disk write by LGWR. A program that commits after every single row pays that wait for every row. Think of an invented equipment logger that inserts one tool event and commits, thousands of times a minute: its throughput is limited by how fast LGWR can write to the redo log, and its sessions spend their time waiting on the "log file sync" wait event. Committing in batches, or putting the redo logs on faster storage, fixes it. Day 3 (bulk processing) and Day 4 (tuning) come back to this.

Commit when the business transaction is complete. Committing more often does not make a program safer or faster, and committing in the middle of a business transaction can leave half-done work if the program fails.

## Undo

**Undo** records the old values of data changed by uncommitted or recently committed transactions. Oracle uses it for:

- ROLLBACK: undo is applied to restore the old values. See [Transaction control](../module-2/02-transaction-control.md) for ROLLBACK and SAVEPOINT.
- Instance recovery: rolling back the transactions that were open at the time of a crash.
- Read consistency: giving queries the data as it was when they started.
- Flashback features, such as Flashback Query, which read older versions of data.

Undo is kept in the undo tablespace (UNDOTBS1 on the course installations) and managed automatically. Three parameters control it:

```sql
SELECT name, value FROM v$parameter WHERE name LIKE 'undo%' ORDER BY name;
```

```text
NAME                 VALUE
-------------------- ----------
undo_management      AUTO
undo_retention       900
undo_tablespace      UNDOTBS1

3 rows selected.
```

`UNDO_RETENTION` is a minimum time, in seconds, that Oracle tries to keep committed undo before reusing its space. It is a best-effort target, and Oracle does not guarantee it. With an autoextending undo tablespace, Oracle tunes the real retention to be somewhat longer than the longest-running active query. With a fixed-size undo tablespace, Oracle keeps as much undo as the space allows.

## Read consistency

Oracle always enforces **statement-level read consistency**: the data a query returns is committed data, consistent as of a single point in time, the moment the query started. If another session changes a block after your query started, your query uses undo to rebuild the version of the block it needs.

This gives the locking rules Oracle's documentation summarizes:

- A reader never blocks a writer.
- A writer never blocks a reader.
- A writer of a row blocks another writer of the same row, until it commits or rolls back.

### Seeing it with two sessions

You can see read consistency with two sessions connected as FAB_LAB. In SQL Developer, open a second, unshared worksheet with Ctrl+Shift+N so that it uses its own session. A normal worksheet shares the session of its connection, so it would see your uncommitted change.

In session 1, change the lot but do not commit:

```sql
UPDATE lots SET status = 'HOLD' WHERE lot_id = 'L26-010';
SELECT status FROM lots WHERE lot_id = 'L26-010';
```

```text
1 row updated.

STATUS
--------
HOLD

1 row selected.
```

Session 1 sees its own change. Session 1's open transaction now uses undo, which `V$TRANSACTION` shows (FAB_LAB can read it because the lab grants it SELECT_CATALOG_ROLE):

```sql
SELECT used_ublk, used_urec
FROM   v$transaction t JOIN v$session s ON s.taddr = t.addr
WHERE  s.sid = SYS_CONTEXT('USERENV','SID');
```

```text
 USED_UBLK  USED_UREC
---------- ----------
         1          1

1 row selected.
```

One undo block and one undo record: the old value of the one row changed.

In session 2, while session 1 has not committed:

```sql
SELECT status FROM lots WHERE lot_id = 'L26-010';
```

```text
STATUS
--------
ACTIVE

1 row selected.
```

Session 2 does not wait for session 1's lock. It reads the committed value, rebuilt from undo. Only after session 1 commits does session 2 see `HOLD` on its next query. In the classroom demo you commit and then set the status back to `ACTIVE`. In the test run shown here, session 1 rolled back instead, and the row was `ACTIVE` again:

```sql
ROLLBACK;
SELECT status FROM lots WHERE lot_id = 'L26-010';
```

```text
Rollback complete.

STATUS
--------
ACTIVE

1 row selected.
```

### What this means for a long report

Picture a yield report in the invented fab that starts at 08:00 and runs for 20 minutes, summing yesterday's measurements. Meanwhile the manufacturing system keeps inserting measurements and updating lot status. The report returns a consistent answer as of 08:00, and the manufacturing system is never blocked by it. It is as if the report took a photograph of the lot board at 08:00 and worked from the photo while the shift kept moving lots on the real board.

## ORA-01555: snapshot too old

Read consistency only works while the undo the query needs still exists. A long query may need undo for changes committed long after it started. If that undo has already been overwritten by newer transactions, the query fails. In photo terms, someone threw away the negatives before you finished printing:

```text
ORA-01555: snapshot too old: rollback segment number string with name "string" too small
```

Oracle's error reference gives the cause as "rollback records needed by a reader for consistent read are overwritten by other writers", and the action, in automatic undo management mode, as "increase undo_retention setting". In practice the fixes are:

- Make sure the undo tablespace is large enough to keep undo for as long as your longest query runs (and set `UNDO_RETENTION` to match).
- Make the long query faster, so it needs undo for a shorter time.

`V$UNDOSTAT` shows undo usage in 10-minute intervals over the last four days, including the tuned retention, and is where a DBA starts when sizing undo.

## Common mistakes

- Believing COMMIT writes the table data to the data files. COMMIT waits only for LGWR to write the redo; DBWn writes the blocks later.
- Committing after every row in a loading program. Each commit waits for a redo write ("log file sync"); commit in batches.
- Testing read consistency in two SQL Developer worksheets of the same connection. They share one session, so the second worksheet sees the uncommitted change. Use an unshared worksheet (Ctrl+Shift+N).
- Leaving a transaction open in a worksheet and going to lunch. Other sessions can still read the row, but any session that tries to update it waits for your lock.
- Treating ORA-01555 as a bug in the query. It is an undo sizing problem, or a query that runs too long.

## Check your understanding

1. What exactly does a COMMIT wait for before it returns?
2. The server crashes one second after your COMMIT returned, and DBWn had not yet written your changed block. Is your change lost? Explain.
3. Session 1 updates a row and does not commit. Session 2 selects the same row. Does session 2 wait? Which value does it see, and where does that value come from?
4. A 3-hour report fails with ORA-01555. Name two things that could fix it.
5. Why can committing after each row make a load program slow?

## Further reading

- [Oracle Database Concepts 19c: Transactions](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/transactions.html)
- [Oracle Database Concepts 19c: Data Concurrency and Consistency](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-concurrency-and-consistency.html)
- [Oracle Database Concepts 19c: Oracle Database Instance](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/oracle-database-instance.html) (see "Overview of Instance Recovery")
- [Oracle Database Administrator's Guide 19c: Managing Undo](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-undo.html)
- [Oracle Database Error Messages 19c: ORA-01500 to ORA-02098](https://docs.oracle.com/en/database/oracle/oracle-database/19/errmg/ORA-01500.html) (ORA-01555)
- [ORACLE-BASE: Automatic Undo Management](https://oracle-base.com/articles/9i/automatic-undo-management)
- [GitLab blog: Postmortem of database outage of January 31](https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/)

### Answers

1. For LGWR to write the transaction's redo, including the commit record, to the online redo log on disk.
2. No. The redo of the change and the commit record are in the online redo log. When the database opens again, SMON's instance recovery rolls forward by applying the redo, so the committed change is written to the data file.
3. Session 2 does not wait: a writer never blocks a reader. It sees the last committed value, which Oracle rebuilds from undo.
4. A larger undo tablespace, with `UNDO_RETENTION` set to cover the report's run time, so the undo it needs is still there; or a faster report, so it needs undo for a shorter time.
5. Every COMMIT waits for LGWR to write redo to disk. With one commit per row, the program spends most of its time waiting for those writes ("log file sync") instead of doing work.
