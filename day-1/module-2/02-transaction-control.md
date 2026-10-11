# Transaction control

This page covers transactions from the point of view of someone writing SQL: when a change becomes permanent, how to undo all or part of it, why a DDL statement in the middle of a script commits your earlier work, and what other sessions see while your transaction is still open. The internals (redo, undo and LGWR) are on the Module 1 page [COMMIT, redo and undo](../module-1/10-commit-redo-and-undo.md).

Slides: 24 of the Day 1 deck.

## What a transaction is

A **transaction** is a unit of work made of one or more DML statements (INSERT, UPDATE, DELETE, MERGE) that succeed or fail together. In Oracle you never type BEGIN TRANSACTION. The first DML statement after the previous transaction ended starts a new one, and the transaction ends when one of these happens:

- you issue COMMIT or ROLLBACK;
- you run a DDL statement (CREATE, ALTER, DROP, TRUNCATE, RENAME and so on), which commits implicitly;
- you disconnect. A normal exit from most Oracle tools commits, but this behaviour depends on the tool and can be configured (in SQL*Plus, `SET EXITCOMMIT OFF` makes EXIT roll back instead). If the client process ends abnormally, Oracle rolls the transaction back.

Until the transaction commits, nothing it changed is permanent and no other session can see the changes. Your own session sees them straight away.

Each single statement is also atomic. If one UPDATE fails halfway (for example on a constraint violation in the 900th row), Oracle rolls back the whole statement, but the earlier statements in your transaction stay as they were. This is called statement-level rollback.

## COMMIT and ROLLBACK

`COMMIT` makes every change of the current transaction permanent and visible to other sessions, and releases the transaction's locks. `ROLLBACK` throws away every change since the transaction started and also releases the locks.

Get into the habit of checking the result of DML before you commit, and of rolling back when you were only testing. In SQL Developer, the Commit and Rollback buttons on the worksheet toolbar do the same as the statements.

## SAVEPOINT and ROLLBACK TO SAVEPOINT

A **savepoint** is a named marker inside a transaction. `ROLLBACK TO SAVEPOINT name` undoes only the work done after the marker. The transaction stays open, the changes before the marker stay pending, and you still need a COMMIT or ROLLBACK at the end.

If you have played a video game with save points, you already know the idea. ROLLBACK TO SAVEPOINT reloads your last save and you carry on from there. A plain ROLLBACK sends you back to the start of the level. COMMIT is finishing the level: after that there is nothing to reload, because the game has moved on and wiped the save points.

In this example you scrap all wafers of lot L26-011, set a savepoint, then also mark the lot itself as scrapped. Then you change your mind about the lot, and for the moment keep the wafer change.

```sql
UPDATE wafers SET grade = 'SCRAP' WHERE lot_id = 'L26-011';      -- 5 rows updated
SAVEPOINT wafers_scrapped;
UPDATE lots SET status = 'SCRAPPED' WHERE lot_id = 'L26-011';    -- 1 row updated

SELECT l.lot_id, l.status, w.grade, COUNT(*) AS wafers
FROM   lots l JOIN wafers w ON w.lot_id = l.lot_id
WHERE  l.lot_id = 'L26-011'
GROUP  BY l.lot_id, l.status, w.grade;
```

```text
LOT_ID   STATUS    GRADE      WAFERS
-------- --------- ------ ----------
L26-011  SCRAPPED  SCRAP           5
```

```sql
ROLLBACK TO SAVEPOINT wafers_scrapped;
-- run the same SELECT again
```

```text
LOT_ID   STATUS    GRADE      WAFERS
-------- --------- ------ ----------
L26-011  ACTIVE    SCRAP           5
```

The lot status is back to ACTIVE; the wafer update from before the savepoint is still pending. A full ROLLBACK then undoes the rest:

```sql
ROLLBACK;
-- run the same SELECT again
```

```text
LOT_ID   STATUS    GRADE      WAFERS
-------- --------- ------ ----------
L26-011  ACTIVE    PRIME           4
L26-011  ACTIVE    TEST            1
```

After a ROLLBACK or COMMIT the transaction has ended, and its savepoints are gone with it:

```sql
ROLLBACK TO SAVEPOINT wafers_scrapped;
```

```text
ORA-01086: savepoint 'WAFERS_SCRAPPED' never established in this session or is invalid
```

A few more rules from the SQL Language Reference:

- Rolling back to a savepoint erases the savepoints created after it. The named savepoint itself is kept, so you can roll back to it more than once.
- Creating a second savepoint with the same name erases the earlier one.
- Rolling back to a savepoint releases the table and row locks acquired after that savepoint.

## DDL commits implicitly

Oracle issues an implicit COMMIT before every DDL statement, and another one after the DDL statement if it succeeds. The commit before the DDL happens even when the DDL statement then fails. Any DML you had pending at that moment is committed and can no longer be rolled back.

You can see this with a scratch table (create it in your own FAB_LAB schema and drop it afterwards):

```sql
CREATE TABLE txn_demo (note VARCHAR2(30));
INSERT INTO txn_demo VALUES ('pending row');

-- A DDL statement that fails: the table already exists
CREATE TABLE txn_demo (note VARCHAR2(30));
```

```text
ORA-00955: name is already used by an existing object
```

```sql
ROLLBACK;
SELECT * FROM txn_demo;
```

```text
NOTE
------------------------------
pending row
```

The CREATE TABLE failed, but the implicit commit before it had already made the INSERT permanent, so the ROLLBACK had nothing left to undo. Clean up with `DROP TABLE txn_demo PURGE;`.

This catches people in data-fix scripts. A CREATE TABLE, a TRUNCATE or an index rebuild halfway through the script commits everything before it, and the "ROLLBACK if anything goes wrong" at the end only undoes the work after the DDL. Keep DDL out of scripts that must be all-or-nothing, or put it at the very start. (Day 2 shows autonomous transactions, which let PL/SQL commit a log row without committing the caller's work.)

## What other sessions see: read consistency and locks

Oracle guarantees **statement-level read consistency**: a query returns data that is committed and consistent as of a single point in time, the moment the query started. Uncommitted changes from other sessions are never visible, and changes that other sessions commit while your query runs do not appear halfway through your result. Oracle builds that consistent view from undo data, so a query does not have to lock anything to get it.

The consequence, in the words of the Concepts guide: a reader never blocks a writer, and a writer never blocks a reader. Writers can block other writers, though. When you change a row, you hold a row lock on it until your transaction ends, and any other session that tries to change or lock the same row waits.

Think of a lot sitting at a tool. Anyone can walk past and read the lot's run card, and they see what it said at the last sign-off, not the step the operator is halfway through. A second operator who wants to load the same lot has to wait until the first one is done with it.

The following run used two sessions connected as FAB_LAB. Lot L26-011 has priority 3.

Session 1 changes the priority and does not commit:

```sql
UPDATE lots SET priority = 1 WHERE lot_id = 'L26-011';
SELECT priority FROM lots WHERE lot_id = 'L26-011';
```

```text
  PRIORITY
----------
         1
```

Session 1 sees its own change. Session 2 reads the same row while session 1's transaction is still open:

```sql
SELECT lot_id, priority FROM lots WHERE lot_id = 'L26-011';
```

```text
LOT_ID         PRIORITY
------------ ----------
L26-011               3
```

Session 2 gets the last committed value, 3, without waiting. Now session 2 tries to lock the row, asking not to wait:

```sql
SELECT lot_id, priority FROM lots WHERE lot_id = 'L26-011' FOR UPDATE NOWAIT;
```

```text
ORA-00054: resource busy and acquire with NOWAIT specified or timeout expired
```

A plain `UPDATE lots SET priority = 2 WHERE lot_id = 'L26-011';` in session 2 does not fail; it simply hangs until session 1 ends its transaction. In this run session 1 issued ROLLBACK, the value in session 1 went back to 3, and session 2's UPDATE then completed with "1 row updated" (it was rolled back afterwards too).

Two practical points follow:

- A forgotten open transaction in one tool (an UPDATE in SQL Developer that was never committed) can make a batch job or another user hang on the same rows. If something "hangs" on a simple UPDATE, look for an uncommitted session first.
- Read consistency only covers a single statement by default. Two queries in the same session can see different data if another session committed in between.

## Common mistakes

- Assuming that a ROLLBACK at the end of a script undoes everything, when a DDL statement in the middle has already committed the earlier DML.
- Leaving a transaction open in SQL Developer and then wondering why another session waits.
- Expecting a savepoint to survive a COMMIT or ROLLBACK (ORA-01086).
- Testing a DELETE "just to see the count" and closing the tool. A normal exit from SQL*Plus commits by default, so roll back explicitly before you leave.

## Check your understanding

1. You run UPDATE, then SAVEPOINT a, then DELETE, then ROLLBACK TO SAVEPOINT a, then COMMIT. Which changes are permanent?
2. A script runs an INSERT, then `CREATE INDEX` on a column that does not exist (the CREATE fails), then ROLLBACK. Is the inserted row still there? Why?
3. Session A has updated a lot's status and not committed. What does session B see if it queries that lot? What happens if session B tries to update the same lot?
4. What does `ROLLBACK TO SAVEPOINT` do to the locks taken after the savepoint?

## Further reading

- [Oracle Database Concepts 19c: Transactions](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/transactions.html)
- [Oracle Database Concepts 19c: Data Concurrency and Consistency](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-concurrency-and-consistency.html)
- [Oracle Database SQL Language Reference 19c: COMMIT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/COMMIT.html)
- [Oracle Database SQL Language Reference 19c: ROLLBACK](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ROLLBACK.html)
- [Oracle Database SQL Language Reference 19c: SAVEPOINT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SAVEPOINT.html)
- [SQL*Plus User's Guide and Reference 19c: SET System Variable Summary](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SET-system-variable-summary.html) (SET EXITCOMMIT)

To practise, do question A7 in [Lab 3: SQL review](../labs/lab-3-sql-review.md).

### Answers

1. Only the UPDATE. The DELETE was undone by the rollback to the savepoint, and the COMMIT made the remaining pending change, the UPDATE, permanent.
2. Yes. Oracle commits before every syntactically valid DDL statement, even one that then fails, so the INSERT was committed before CREATE INDEX ran. The ROLLBACK had nothing to undo.
3. Session B sees the last committed status, without waiting (statement-level read consistency; a writer does not block a reader). If session B tries to update the same row, it waits until session A commits or rolls back (or gets ORA-00054 if it asked for NOWAIT).
4. It releases the table and row locks acquired after the savepoint. Locks taken before the savepoint are kept until the transaction ends.
