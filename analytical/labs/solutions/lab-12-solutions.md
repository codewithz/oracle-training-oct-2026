# Lab 12 solutions: What your SELECT sees

Try each exercise yourself first. Compare the output, not the spelling. The outputs below were produced by running each step, with the two-tab steps run as two separate sessions against the same database. The script [`lab12_solutions.sql`](scripts/lab12_solutions.sql) holds all the statements. The statements for the two tabs are comments in it, marked TAB A and TAB B, so that the file can also run in one session.

The times in the flashback outputs come from the test run. Yours will be different.

## Exercise 1: Sandbox and two sessions

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

**What to notice.** The session number in the second tab is a different number. If both tabs show the same one, they share a connection and the following exercises will not behave as described.

## Exercise 2: Your pencil is invisible to others

**Maya asks:** "If the night shift changes a lot while I am looking, do I wait, and what do I see?"

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

**What to notice.** The first answer came back without waiting and showed the old value 3. B's change was still in pencil. After the commit, a new query sees 9. Readers do not wait for writers.

## Exercise 3: One photograph for the whole report

**Maya asks:** "Can I stop two queries in one report from disagreeing?"

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

**What to notice.** Eight active lots each gained 1, so the total went from 38 to 46. Inside the read-only transaction tab A kept seeing 38, because every query in it reads from the moment the transaction began. After the commit tab A is back to a new photograph for each statement. Without `SET TRANSACTION READ ONLY`, each statement in tab A takes its own photograph, and the second select would have shown 46 already.

## Exercise 4: What was it a minute ago?

**Maya asks:** "Show me what lot L26-002 was in between, and the whole history of the row."

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

**What to notice.** The noted time falls between the two commits, so flashback shows the middle value 7. The first version (2) has no start time because it existed before anything in the window, and the last (8) has no end time because it is the current one. The solutions script uses `SYSTIMESTAMP - INTERVAL '8' SECOND` and the two pauses so that it runs without typing anything. In class you type the time you noted.

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

**What to notice.** Flashback only reads. The old rows came back because an ordinary `INSERT` wrote them again, and they were permanent only after `COMMIT`. Count before you insert, so you know what you are about to put back. If you had used `TRUNCATE`, the earlier state would be unreadable (`ORA-01466`).

## Exercise 6: FOR UPDATE and its options

**Maya asks:** "How do I stop two planners taking the same lot?"

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

**What to notice.** (a) is not blocked: only `FOR UPDATE` and DML take row locks. (b) fails at once, (c) fails after the 5 seconds. (d) is the quiet one: the answer has two rows, and nothing says that L26-001 exists and was skipped. Tab A now holds the lock on L26-001, so click **Rollback** in tab A as well.

## Exercise 7: Leave no trace

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

**What to notice.** `LOTS` was never touched. Both tabs must be rolled back before you drop the table: a lock held by an open tab would make the `DROP` fail with `ORA-00054`. Finally, switch both tabs back to Auto-Commit.
