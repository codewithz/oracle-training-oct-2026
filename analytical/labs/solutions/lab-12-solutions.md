# Lab 12 solutions: What your SELECT sees

Try each exercise yourself first. Compare the output, not the spelling. The outputs below were produced by running each step, with the two-tab steps run as two separate sessions against the same database (Oracle 21c XE; 19c behaves the same). The script [`lab12_solutions.sql`](scripts/lab12_solutions.sql) holds all the statements. The statements for the two tabs are comments in it, marked TAB A and TAB B, so that the file can also run in one session.

The times in the flashback outputs come from the test run. Yours will be different.

Each exercise has the same parts: the problem in plain words, the steps with their output, and a breakdown of what each tab sees and why.

This lab is different from the others: the answer depends on when you run a query and from which tab, not only on how you write it. Four ideas explain every result:

- **Uncommitted changes are in pencil.** Only the session that made a change can see it until it commits.
- **Every query takes a photograph.** A `SELECT` sees the data as it was committed at the moment the query started, even if other sessions commit changes while it runs.
- **Oracle keeps old versions for a while** (in undo). That is how it can show another session the old value, and how flashback can show the past.
- **Reading never waits.** A plain `SELECT` takes no locks. Only `UPDATE`, `DELETE`, `INSERT` and `SELECT ... FOR UPDATE` lock rows.

## Exercise 1: Sandbox and two sessions

**Maya asks:** "Make a copy of the lot list for yourself, and prove that your two tabs are really two sessions."

### The problem in plain words

Every later exercise changes data, so we work on a private copy of `LOTS`, called `MY_LOTS_COPY`, and never touch the real table. We also need proof that tab A and tab B are two separate database sessions, because the whole lab is about what one session sees of another's work. Each session has its own number, the SID.

### The steps

```sql
CREATE TABLE my_lots_copy AS SELECT * FROM lots;
SELECT COUNT(*) AS rows_in_copy FROM my_lots_copy;
SELECT SYS_CONTEXT('USERENV', 'SID') AS my_session FROM dual;
```

```text
ROWS_IN_COPY
------------
          16

MY_SESSION
-------------------
45
```

### What each statement does

**Step 1. CREATE TABLE ... AS SELECT.** Creates a new table with the same columns as `LOTS` and copies all 16 rows into it. `CREATE TABLE` commits on its own, so the copy is visible to both tabs straight away.

**Step 2. COUNT(*).** 16 rows, the same as `LOTS`.

**Step 3. SYS_CONTEXT('USERENV', 'SID').** Asks Oracle "which session am I?". Run it in both tabs.

### What to notice

The session number in the second tab must be a different number. If both tabs show the same one, they share a connection and the following exercises will not behave as described.

## Exercise 2: Your pencil is invisible to others

**Maya asks:** "If the night shift changes a lot while I am looking, do I wait, and what do I see?"

### The problem in plain words

Tab B plays the night shift: it changes the priority of lot L26-001 from 3 to 9 but does not commit yet. Tab A plays Maya: she reads that lot. Two questions: does Maya's query wait for the night shift to finish, and does she see 3 or 9? Then the night shift commits and Maya reads again.

### The steps

Tab B:

```sql
UPDATE my_lots_copy SET priority = 9 WHERE lot_id = 'L26-001';
```

```text
1 row updated.
```

Tab A, while tab B has not committed:

```sql
SELECT lot_id, priority FROM my_lots_copy WHERE lot_id = 'L26-001';
```

```text
LOT_ID         PRIORITY
------------ ----------
L26-001               3
```

Tab B: `COMMIT;`. Tab A, the same select:

```text
LOT_ID         PRIORITY
------------ ----------
L26-001               9
```

### What each tab sees and why

**Tab B updates.** The row now holds 9, but only in pencil. Tab B has also locked the row, so no other session can change it until B commits or rolls back. Oracle keeps the old value 3 in undo.

**Tab A's first SELECT.** A query never shows another session's uncommitted change. Oracle notices the row was changed by an open transaction and rebuilds the last committed version from undo: 3. A plain `SELECT` does not need the lock, so tab A does not wait.

**Tab B commits.** The 9 is now permanent and visible to everyone.

**Tab A's second SELECT.** A new query takes a new photograph, after the commit, so it sees 9.

### What to notice

Maya's two answers: she does not wait, and she sees the last committed value. Readers do not wait for writers, and writers do not wait for readers.

## Exercise 3: One photograph for the whole report

**Maya asks:** "My report runs several queries. If a change is committed between two of them, the totals do not match. Can I stop that?"

### The problem in plain words

Normally each query takes its own photograph. If Maya's report runs two queries and someone commits a change between them, the first query and the second query describe two different moments, and their numbers will not agree. Maya wants every query in her report to see the same moment. Tab A runs the report, tab B commits a change in the middle, and tab A runs the same query again.

### The steps

Tab A:

```sql
SET TRANSACTION READ ONLY;
SELECT COUNT(*) AS lots, SUM(priority) AS total_priority FROM my_lots_copy;
```

```text
Transaction set.

      LOTS TOTAL_PRIORITY
---------- --------------
        16             38
```

Tab B:

```sql
UPDATE my_lots_copy SET priority = priority + 1 WHERE status = 'ACTIVE';
COMMIT;
```

```text
8 rows updated.

Commit complete.
```

Tab A, the same select, still inside the read-only transaction:

```text
      LOTS TOTAL_PRIORITY
---------- --------------
        16             38
```

Tab A: `COMMIT;` and the select once more:

```text
Commit complete.

      LOTS TOTAL_PRIORITY
---------- --------------
        16             46
```

### What each tab sees and why

**Where 38 comes from.** The 16 lots start with priorities that add up to 32. Exercise 2 raised L26-001 from 3 to 9, which adds 6, so the copy now totals 38.

**Tab A: SET TRANSACTION READ ONLY.** This must be the first statement of a transaction. It tells Oracle: take one photograph now and use it for every query until this transaction ends. It also means tab A cannot change any data in this transaction.

**Tab B: UPDATE and COMMIT.** The 8 ACTIVE lots each gain 1. After the commit the real total is 46.

**Tab A: the same SELECT again.** Still 38. Tab A is still in its read-only transaction, so Oracle rebuilds every row as it was when the transaction started, using undo.

**Tab A: COMMIT and SELECT.** The commit ends the read-only transaction. The next query is back to normal and takes a fresh photograph: 46.

### What to notice

Without `SET TRANSACTION READ ONLY`, the second select would have shown 46 straight away, and a report with one query before B's commit and one after would not add up. In DBeaver, tab A must be in manual commit mode; in auto-commit mode the transaction ends after each statement and the read-only setting is lost.

## Exercise 4: What was it a minute ago?

**Maya asks:** "Lot L26-002 is at priority 2. Somebody changes it twice. Show me what it was in between, and show me the whole history of the row."

### The problem in plain words

L26-002 starts at priority 2. We change it to 7 and commit, wait, note the time, wait, change it to 8 and commit. The noted time falls while the value was 7. Maya wants two things: the value at the noted time (which should be 7, even though the row now says 8), and a list of every version of the row with when it started and ended.

### The steps

```sql
UPDATE my_lots_copy SET priority = 7 WHERE lot_id = 'L26-002';
COMMIT;
-- wait about ten seconds
SELECT TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS time_i_noted FROM dual;
-- wait about ten seconds
UPDATE my_lots_copy SET priority = 8 WHERE lot_id = 'L26-002';
COMMIT;
```

```text
TIME_I_NOTED
-------------------
2026-10-13 04:49:57
```

Now and then (type the time you noted):

```sql
SELECT priority AS now_priority FROM my_lots_copy WHERE lot_id = 'L26-002';

SELECT priority AS then_priority
FROM   my_lots_copy
       AS OF TIMESTAMP TO_TIMESTAMP('2026-10-13 04:49:57', 'YYYY-MM-DD HH24:MI:SS')
WHERE  lot_id = 'L26-002';
```

```text
NOW_PRIORITY
------------
           8

THEN_PRIORITY
-------------
            7
```

The versions:

```sql
SELECT versions_starttime, versions_endtime, versions_operation AS op, priority
FROM   my_lots_copy
       VERSIONS BETWEEN TIMESTAMP MINVALUE AND MAXVALUE
WHERE  lot_id = 'L26-002'
ORDER  BY versions_starttime NULLS FIRST;
```

```text
VERSIONS_STARTTIME       VERSIONS_ENDTIME         OP   PRIORITY
------------------------ ------------------------ -- ----------
                         13-OCT-26 04.49.49 AM                2
13-OCT-26 04.49.49 AM    13-OCT-26 04.50.04 AM    U           7
13-OCT-26 04.50.04 AM                             U           8
```

### How the queries build the answer

**The timeline.** Priority 2 until the first commit at 04:49:49, then 7 until the second commit at 04:50:04, then 8. The noted time 04:49:57 sits in the middle.

**The plain SELECT.** No `AS OF`, so it reads the current committed value: 8.

**AS OF TIMESTAMP.** `AS OF` goes after the table name and asks for the table as it was at that moment. Oracle takes the current row and undoes, from undo, every change committed after that time. Undoing the change to 8 gives 7.

**VERSIONS BETWEEN TIMESTAMP MINVALUE AND MAXVALUE.** Instead of one moment, this asks for every committed version of the row over the whole period Oracle still has undo for. Each version gets extra columns: when it began (`versions_starttime`), when it was replaced (`versions_endtime`), and the operation that made it (`versions_operation`, U for update).

**ORDER BY versions_starttime NULLS FIRST.** The oldest version has no start time, so `NULLS FIRST` puts it on top and the list reads in time order.

### What to notice

The first version (2) has no start time because it existed before anything Oracle can see in undo, and the last (8) has no end time because it is the current one. The solutions script uses `SYSTIMESTAMP - INTERVAL '8' SECOND` and the two pauses so that it runs without typing anything. In class you type the time you noted. Flashback only works as far back as undo is kept, which on a busy database may be minutes, not days.

**The trap.** A time from before the table existed:

```sql
SELECT priority FROM my_lots_copy AS OF TIMESTAMP SYSTIMESTAMP - INTERVAL '1' HOUR;
```

```text
ORA-01466: unable to read data - table definition has changed
```

(This is the stretch question. Oracle cannot show a table at a time when it did not exist. The same error appears after a `TRUNCATE TABLE`.)

## Exercise 5: Put back what was deleted

**Maya asks:** "Somebody deleted the shipped lots by mistake. Put them back."

### The problem in plain words

We note the time, then delete the 5 SHIPPED lots from the copy and commit, so a `ROLLBACK` can no longer save us. The copy now has 11 rows. Maya wants the 5 lots back exactly as they were. The plan: look at the table as it was at the noted time, check that the 5 rows are there, copy them back with an ordinary `INSERT`, and commit.

### The steps

```sql
SELECT TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS time_before_delete FROM dual;
-- wait about ten seconds
DELETE FROM my_lots_copy WHERE status = 'SHIPPED';
COMMIT;
SELECT COUNT(*) AS rows_now FROM my_lots_copy;
```

```text
TIME_BEFORE_DELETE
-------------------
2026-10-13 04:50:13

5 rows deleted.

Commit complete.

  ROWS_NOW
----------
        11
```

Look first, then repair (with the time you noted in place of the relative one):

```sql
SELECT COUNT(*) AS shipped_then
FROM   my_lots_copy AS OF TIMESTAMP TO_TIMESTAMP('2026-10-13 04:50:13', 'YYYY-MM-DD HH24:MI:SS')
WHERE  status = 'SHIPPED';

INSERT INTO my_lots_copy
SELECT * FROM my_lots_copy AS OF TIMESTAMP TO_TIMESTAMP('2026-10-13 04:50:13', 'YYYY-MM-DD HH24:MI:SS')
WHERE  status = 'SHIPPED';
COMMIT;

SELECT COUNT(*) AS rows_after FROM my_lots_copy;
SELECT status, COUNT(*) AS lots FROM my_lots_copy GROUP BY status ORDER BY status;
```

```text
SHIPPED_THEN
------------
           5

5 rows created.

Commit complete.

ROWS_AFTER
----------
        16

STATUS         LOTS
-------- ----------
ACTIVE            8
HOLD              2
SCRAPPED          1
SHIPPED           5
```

### How the statements build the answer

**Step 1. The count AS OF the noted time.** `my_lots_copy AS OF TIMESTAMP ...` is the table as it was before the delete, rebuilt from undo. Filtering on SHIPPED there finds the 5 deleted lots. This is the "look first" step: it proves the rows are still readable before you write anything.

**Step 2. INSERT INTO ... SELECT ... AS OF.** The `SELECT` part reads the 5 old rows from the past. The `INSERT` part writes them into the table as it is now. To Oracle this is an ordinary insert of 5 new rows.

**Step 3. COMMIT.** Until here the restored rows were in pencil. The commit makes them permanent.

**Step 4. The checks.** 16 rows again, and the status counts match the original copy: 8 ACTIVE, 2 HOLD, 1 SCRAPPED, 5 SHIPPED.

### What to notice

Flashback only reads; it never changes the table by itself. Count before you insert, so you know what you are about to put back. Only rows that are missing should be restored: if some shipped lots had not been deleted, this `INSERT` would create duplicates (on the real `LOTS` table the primary key would stop that with an error; the copy has no primary key, because `CREATE TABLE ... AS SELECT` does not copy constraints other than `NOT NULL`). If you had used `TRUNCATE`, the earlier state would be unreadable (`ORA-01466`).

## Exercise 6: FOR UPDATE and its options

**Maya asks:** "Two planners both want to take lot L26-001 to the next stage. How do I stop them taking the same lot?"

### The problem in plain words

Each planner first reads a lot, then changes it. If both read at the same time, both think the lot is free. The fix is to lock the row while reading it, with `SELECT ... FOR UPDATE`, so the second planner cannot take it until the first one finishes. Tab B is the first planner and locks L26-001. Tab A is the second planner and tries four ways of reading the same lot. We look at what each way does when it meets B's lock.

### The steps

Tab B:

```sql
SELECT lot_id FROM my_lots_copy WHERE lot_id = 'L26-001' FOR UPDATE;
```

```text
LOT_ID
------------
L26-001
```

Tab A:

```sql
-- (a) plain select
SELECT lot_id, status FROM my_lots_copy WHERE lot_id = 'L26-001';
```

```text
LOT_ID       STATUS
------------ --------
L26-001      SHIPPED
```

```sql
-- (b)
SELECT lot_id FROM my_lots_copy WHERE lot_id = 'L26-001' FOR UPDATE NOWAIT;
```

```text
ORA-00054: resource busy and acquire with NOWAIT specified or timeout expired
```

```sql
-- (c)
SELECT lot_id FROM my_lots_copy WHERE lot_id = 'L26-001' FOR UPDATE WAIT 5;
```

```text
ORA-30006: resource busy; acquire with WAIT timeout expired or DTP service is
unavailable
```

```sql
-- (d)
SELECT lot_id FROM my_lots_copy
WHERE  lot_id IN ('L26-001', 'L26-002', 'L26-003')
ORDER  BY lot_id
FOR UPDATE SKIP LOCKED;
```

```text
LOT_ID
------------
L26-002
L26-003
```

After tab B rolls back, tab A runs (b) again:

```text
LOT_ID
------------
L26-001
```

### What each tab sees and why

**Tab B: FOR UPDATE.** Returns the row like a normal select, and also locks it. The lock lasts until tab B commits or rolls back, even though nothing has been changed.

**Tab A (a): plain SELECT.** Not blocked. A plain select takes no lock and does not care about B's lock. It shows the last committed version of the row.

**Tab A (b): FOR UPDATE NOWAIT.** Tries to lock the row, finds B's lock, and gives up at once with `ORA-00054`. Without `NOWAIT`, tab A would wait for as long as B keeps the lock, with no message.

**Tab A (c): FOR UPDATE WAIT 5.** Waits up to 5 seconds for B to let go. B does not, so it fails with `ORA-30006` after the 5 seconds.

**Tab A (d): FOR UPDATE SKIP LOCKED.** Looks at the three lots, locks the ones it can (L26-002 and L26-003) and silently leaves out the one that is locked (L26-001). This is how several planners can each grab "the next free lot" without blocking each other.

**After B rolls back.** B's lock is gone, so (b) now succeeds and tab A holds the lock on L26-001.

### What to notice

(d) is the quiet one: the answer has two rows, and nothing says that L26-001 exists and was skipped. Use it only when skipping is what you want. Tab A now holds the lock on L26-001 (and, from (d), on L26-002 and L26-003), so click **Rollback** in tab A as well.

## Exercise 7: Leave no trace

**Maya asks:** "Make sure nobody's lock is left hanging."

### The problem in plain words

We finish by removing the sandbox: both tabs must have ended their transactions, then the copy is dropped. We check that no `MY_` tables are left and that the real `LOTS` table still has all 16 lots.

### The steps

```sql
DROP TABLE my_lots_copy PURGE;
SELECT COUNT(*) AS my_tables_left FROM user_tables WHERE table_name LIKE 'MY\_%' ESCAPE '\';
SELECT COUNT(*) AS lots FROM lots;
```

```text
MY_TABLES_LEFT
--------------
             0

      LOTS
----------
        16
```

### What each statement does

**Step 1. DROP TABLE ... PURGE.** Removes the copy. `PURGE` skips the recycle bin, so it is gone for good. `DROP` needs the table free of row locks held by other sessions.

**Step 2. The MY_ check.** In `LIKE`, `_` normally means "any one character". `ESCAPE '\'` makes `\_` mean a real underscore, so the pattern finds only names that start with "MY_".

**Step 3. COUNT on LOTS.** 16, so the real table was never touched.

### What to notice

Both tabs must be rolled back before you drop the table: a lock held by an open tab would make the `DROP` fail with `ORA-00054`. Finally, switch both tabs back to Auto-Commit.
