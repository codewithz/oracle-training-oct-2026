# Lab 18 solutions: Tuning a little

Try each exercise yourself first. The runnable file is [`lab18_solutions.sql`](scripts/lab18_solutions.sql).

Each exercise has the same parts: the problem in plain words, the code, how the code runs (step by step, in the order Oracle runs it, and what each plan line means), the output, and what to notice.

All outputs and the in-between values in the step-by-step parts were produced by running the code, and pieces of it, on the lab data (Oracle 21c XE in a small container; 19c gives the same plans and row counts). **Timings and buffer counts vary by machine.** Your seconds, `Reads`, `SQL_ID` values and sometimes your costs will differ. The operations, the row counts and the buffer counts should be close to these. Where a time is given, compare the ratio, not the digits. A re-run for this version gave the same operations, rows and buffer counts as shown, except the cost of the first plan in exercise 1 (see there).

The real-plan listings are shortened to the table of steps. The `SQL_ID`, the statement text, the `Plan hash value` and most predicate lines are left out.

How to run the code in DBeaver: open the Output panel first (**Ctrl + Shift + O**). Run each plain statement with the cursor inside it and **Ctrl + Enter**. Select each `DECLARE ... END;` block and the `CREATE OR REPLACE FUNCTION` whole, from the first line down to `END;`, and press **Ctrl + Enter**, one at a time.

Before the exercises, the script switches on the counting that real plans need:

```sql
ALTER SESSION SET STATISTICS_LEVEL = ALL;
```

Two ideas carry this lab:

- **A plan is the list of steps Oracle chose.** Read it from the most indented line outwards: the innermost step runs first and hands its rows to the line above it. `EXPLAIN PLAN` shows the plan Oracle expects to use, with estimates. `DISPLAY_CURSOR` with `'ALLSTATS LAST'` shows the plan it really used, with real numbers.
- **Buffers are the yardstick.** `Buffers` is the number of blocks read from memory. It changes very little from run to run, while the time does.

**How the plans are found.** Each statement you want to inspect carries a marker comment right after `SELECT`, such as `/* l18a */`. The helper query looks in `V$SQL` (the list of statements Oracle has run recently) for the newest statement whose text starts with that marker, takes its `sql_id`, and passes it to `DBMS_XPLAN.DISPLAY_CURSOR`. The shortcut `DISPLAY_CURSOR(NULL, NULL, ...)` shows the session's last statement, and in DBeaver that is often one of DBeaver's own background queries. The marker works in both DBeaver and SQL*Plus. The helper itself starts with `SELECT * FROM TABLE`, so it never finds itself.

## Exercise 1: Statistics and a first plan

**Maya asks:** "Why is looking up one reading by its number instant, but looking up a wafer's readings slow?"

### The problem in plain words

`MEASUREMENTS_BIG` has one row per reading: 200,000 rows, with `meas_id` (the primary key, indexed), `wafer_id`, `tool_id` and more. `USER_TABLES` and `USER_TAB_COL_STATISTICS` hold the statistics the optimizer uses: one row for the table and one row per column. Then two predicted plans: one for a single `meas_id`, one for all the readings of one wafer.

### The code

```sql
SELECT table_name, num_rows, blocks FROM user_tables WHERE table_name = 'MEASUREMENTS_BIG';
SELECT column_name, num_distinct FROM user_tab_col_statistics
WHERE  table_name = 'MEASUREMENTS_BIG' AND column_name IN ('MEAS_ID','WAFER_ID','TOOL_ID') ORDER BY column_name;
EXPLAIN PLAN FOR SELECT * FROM measurements_big WHERE meas_id = 100000;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
EXPLAIN PLAN FOR SELECT * FROM measurements_big WHERE wafer_id = 'L26-005-02';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

### How the code runs

**Step 1. The statistics.** `NUM_ROWS` = 200,000 and `BLOCKS` = 1,385: the table fills 1,385 blocks. `MEAS_ID` has 200,000 distinct values (one per row), `WAFER_ID` 66 and `TOOL_ID` 7.

**Step 2. `EXPLAIN PLAN FOR ... meas_id = 100000`.** Oracle works out a plan without running the query and writes it to `PLAN_TABLE`. `DBMS_XPLAN.DISPLAY` prints it:

- Line 2, `INDEX UNIQUE SCAN` on `MEAS_BIG_PK`: walk down the primary key index to the one entry for 100000. Rows 1.
- Line 1, `TABLE ACCESS BY INDEX ROWID`: the index entry holds the row's address (rowid), so Oracle reads exactly that one table block. Rows 1, 43 bytes.
- Line 0, `SELECT STATEMENT`: the result. Cost 3 on this run.

**Step 3. `EXPLAIN PLAN FOR ... wafer_id = 'L26-005-02'`.** There is no index on `wafer_id`.

- Line 1, `TABLE ACCESS FULL`: read every block of the table and test each row (`filter("WAFER_ID"='L26-005-02')`). Estimated rows 3,030, which is 200,000 / 66. Cost 378.
- Line 0: the same numbers for the whole statement.

### Output

```text
TABLE_NAME           NUM_ROWS     BLOCKS
------------------ ---------- ----------
MEASUREMENTS_BIG       200000       1385

COLUMN_NAME    NUM_DISTINCT
-------------- ------------
MEAS_ID              200000
TOOL_ID                   7
WAFER_ID                 66

------------------------------------------------------------------------------------------------
| Id  | Operation                   | Name             | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |                  |     1 |    43 |     3   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| MEASUREMENTS_BIG |     1 |    43 |     3   (0)| 00:00:01 |
|*  2 |   INDEX UNIQUE SCAN         | MEAS_BIG_PK      |     1 |       |     2   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
| Id  | Operation         | Name             | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |                  |  3030 |   127K|   378   (1)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| MEASUREMENTS_BIG |  3030 |   127K|   378   (1)| 00:00:01 |
--------------------------------------------------------------------------------------
```

### What to notice

The primary key is indexed and unique, so Oracle goes straight to one row (cost 3). On some databases this plan shows cost 2 and 1: the cost counts the levels of the index Oracle walks through, and that depth depends on how the index was built. `wafer_id` has no index, and 200,000 rows divided by 66 wafers is about 3,030 rows per wafer. Oracle estimates 3,030 and reads the whole table to find them (cost 378). A cost is a score for comparing plans of the same statement, not a time.

## Exercise 2: Create an index and watch the buffers

**Maya asks:** "Can you make the wafer lookup quick?"

### The problem in plain words

The query returns one row: the average thickness of the 3,030 readings of wafer `L26-005-02`. It runs once without an index and once after an index on `wafer_id` is created. Each time, the helper shows the real plan, and the two `Buffers` numbers are compared.

### The code

```sql
SELECT /* l18a */ AVG(thickness_nm) FROM measurements_big WHERE wafer_id = 'L26-005-02';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /* l18a */%'
          ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY), NULL, 'ALLSTATS LAST'));
CREATE INDEX meas_big_wafer_ix ON measurements_big (wafer_id);
SELECT /* l18b */ AVG(thickness_nm) FROM measurements_big WHERE wafer_id = 'L26-005-02';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /* l18b */%'
          ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY), NULL, 'ALLSTATS LAST'));
```

### How the code runs

**Step 1. The `l18a` query** runs with a full scan, as predicted in exercise 1. Because `STATISTICS_LEVEL = ALL`, Oracle counts rows, time and buffers for every plan line while it runs.

**Step 2. The helper for `l18a`.** The inner `SELECT sql_id FROM v$sql ...` finds the newest statement starting with `SELECT /* l18a */`, and `DISPLAY_CURSOR` prints its plan with `'ALLSTATS LAST'`, the real numbers of the last run:

- Line 2, `TABLE ACCESS FULL`: `E-Rows` 3,030 (estimate), `A-Rows` 3,030 (real), `Buffers` 1,360.
- Line 1, `SORT AGGREGATE`: takes the 3,030 rows and computes one `AVG`, so `A-Rows` 1. The buffer column adds up the lines below it, so it shows 1,360 again.
- Line 0: the statement, 1 row, 1,360 buffers in total.

**Step 3. CREATE INDEX.** Oracle reads the table once, sorts the 200,000 `wafer_id` values with their rowids, and stores them as `MEAS_BIG_WAFER_IX`. Creating an index also gathers its statistics.

**Step 4. The `l18b` query.** The text is new (a different marker), so Oracle builds a new plan, and now it sees the index:

- Line 3, `INDEX RANGE SCAN` on `MEAS_BIG_WAFER_IX`: find the first index entry for `L26-005-02` and read along the entries until the wafer id changes. 3,030 entries, 12 buffers.
- Line 2, `TABLE ACCESS BY INDEX ROWID BATCHED`: fetch the table rows for those 3,030 rowids, collected in batches. 33 buffers including the 12 of the index, so about 21 table blocks.
- Lines 1 and 0: `SORT AGGREGATE` makes one row; 33 buffers in total.

### Output

```text
Before (l18a):
-------------------------------------------------------------------------------------------------
| Id  | Operation          | Name             | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |                  |      1 |        |      1 |00:00:00.01 |    1360 |
|   1 |  SORT AGGREGATE    |                  |      1 |      1 |      1 |00:00:00.01 |    1360 |
|*  2 |   TABLE ACCESS FULL| MEASUREMENTS_BIG |      1 |   3030 |   3030 |00:00:00.01 |    1360 |
-------------------------------------------------------------------------------------------------

After (l18b):
-----------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                            | Name              | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |
-----------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                     |                   |      1 |        |      1 |00:00:00.01 |      33 |     32 |
|   1 |  SORT AGGREGATE                      |                   |      1 |      1 |      1 |00:00:00.01 |      33 |     32 |
|   2 |   TABLE ACCESS BY INDEX ROWID BATCHED| MEASUREMENTS_BIG  |      1 |   3030 |   3030 |00:00:00.01 |      33 |     32 |
|*  3 |    INDEX RANGE SCAN                  | MEAS_BIG_WAFER_IX |      1 |   3030 |   3030 |00:00:00.01 |      12 |     32 |
-----------------------------------------------------------------------------------------------------------------------------
```

### What to notice

The query text did not change, but the plan did. Buffers dropped from 1,360 to 33, about 40 times less work, for the same 3,030 rows. The time is 0.01 s both times because everything is cached, which is why buffers are the better yardstick. A `Reads` column appears only when some blocks had to come from disk, so you may or may not see it. This gain is unusually large. The rows of one wafer sit together in the table, so the 3,030 matching rows are in few blocks.

## Exercise 3: When an index does not help

**Maya asks:** "Same trick for the tool, please."

### The problem in plain words

The readings come from 7 tools. The first query counts the readings per tool (7 rows) and shows each tool's share. Then the average thickness of tool `MET02` is computed twice, once with the plan Oracle picks and once with a hint that forces the new index on `tool_id`, and the buffers are compared.

### The code

```sql
CREATE INDEX meas_big_tool_ix ON measurements_big (tool_id);
SELECT tool_id, COUNT(*) AS readings, ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 1) AS pct
FROM   measurements_big GROUP BY tool_id ORDER BY readings DESC;
SELECT /* l18c */ AVG(thickness_nm) FROM measurements_big WHERE tool_id = 'MET02';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /* l18c */%'
          ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY), NULL, 'ALLSTATS LAST'));
SELECT /*+ INDEX(m meas_big_tool_ix) */ /* l18d */ AVG(thickness_nm) FROM measurements_big m WHERE tool_id = 'MET02';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /*+ INDEX(m meas_big_tool_ix) */ /* l18d */%'
          ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY), NULL, 'ALLSTATS LAST'));
```

### How the code runs

**Step 1. CREATE INDEX** on `tool_id`: `MEAS_BIG_TOOL_IX`.

**Step 2. The count per tool.** `GROUP BY tool_id` gives 7 groups. `RATIO_TO_REPORT(COUNT(*)) OVER ()` divides each group's count by the total of all groups. `MET02` has 9,524 readings, 4.8 percent; the largest, `MET01`, has 47,619.

**Step 3. The `l18c` query and its plan.** The optimizer knows 7 distinct values but not how they are spread, so it assumes each tool has 200,000 / 7 = 28,571 rows. Reaching 28,571 rows through an index, one table block at a time, looks more expensive than reading the table once.

- Line 2, `TABLE ACCESS FULL`: `E-Rows` 28,571, `A-Rows` 9,524, `Buffers` 1,359.
- Lines 1 and 0: one `AVG` row, 1,359 buffers.

**Step 4. The `l18d` query with the hint.** `/*+ INDEX(m meas_big_tool_ix) */` tells the optimizer to use that index for the table with alias `m`. The marker comes after the hint, so the helper's `LIKE` pattern includes the hint text.

- Line 3, `INDEX RANGE SCAN` on `MEAS_BIG_TOOL_IX`: 9,524 entries, 26 buffers.
- Line 2, `TABLE ACCESS BY INDEX ROWID BATCHED`: 9,524 rows fetched by rowid. The readings of one tool are spread across the whole table, so this visits nearly every table block: 1,381 buffers in total.

### Output

```text
TOOL_I   READINGS        PCT
------ ---------- ----------
MET01       47619       23.8
ANL02       33334       16.7
SPL01       33333       16.7
SPL02       33333       16.7
ANL01       33333       16.7
MET03        9524        4.8
MET02        9524        4.8

l18c, no hint:
|   0 | SELECT STATEMENT   |                  |      1 |        |      1 |00:00:00.01 |    1359 |
|   1 |  SORT AGGREGATE    |                  |      1 |      1 |      1 |00:00:00.01 |    1359 |
|*  2 |   TABLE ACCESS FULL| MEASUREMENTS_BIG |      1 |  28571 |   9524 |00:00:00.01 |    1359 |

l18d, INDEX hint:
|   0 | SELECT STATEMENT                     |                  |      1 |        |      1 |00:00:00.01 |    1381 |
|   1 |  SORT AGGREGATE                      |                  |      1 |      1 |      1 |00:00:00.01 |    1381 |
|   2 |   TABLE ACCESS BY INDEX ROWID BATCHED| MEASUREMENTS_BIG |      1 |  28571 |   9524 |00:00:00.01 |    1381 |
|*  3 |    INDEX RANGE SCAN                  | MEAS_BIG_TOOL_IX |      1 |  28571 |   9524 |00:00:00.01 |      26 |
```

### What to notice

Oracle ignored the new index and read the table: 1,359 buffers. When forced to use the index, it read 1,381 buffers, slightly more. 4.8 percent of 200,000 rows is still 9,524 rows spread through the table, and visiting them one by one through the index costs more than reading everything once. Look at `E-Rows`: the optimizer guessed 28,571 for every tool, because with no histogram it assumes the 7 tools are equally common. The real count was 9,524. A wrong estimate like this is the usual cause of an odd plan.

## Exercise 4: The function-on-the-column trap

**Maya asks:** "How many readings were taken on 15 September 2026?"

### The problem in plain words

One number: the readings whose `meas_time` falls on 15 September 2026. It is counted twice, once with `TRUNC(meas_time) = DATE '2026-09-15'` and once with a range from midnight to the next midnight. Both must return the same count; the plans and buffers are compared.

### The code

```sql
CREATE INDEX meas_big_time_ix ON measurements_big (meas_time);
SELECT /* l18e */ COUNT(*) FROM measurements_big WHERE TRUNC(meas_time) = DATE '2026-09-15';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /* l18e */%'
          ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY), NULL, 'ALLSTATS LAST'));
SELECT /* l18f */ COUNT(*) FROM measurements_big
WHERE  meas_time >= DATE '2026-09-15' AND meas_time < DATE '2026-09-16';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /* l18f */%'
          ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY), NULL, 'ALLSTATS LAST'));
```

### How the code runs

**Step 1. CREATE INDEX** on `meas_time`: `MEAS_BIG_TIME_IX`, the 200,000 times in sorted order.

**Step 2. The `l18e` query with `TRUNC`.** The index holds the times as they are, for example 15 September 10:30, not the truncated day. Oracle cannot walk to "all entries whose `TRUNC` is the 15th", so it must look at every entry.

- Line 2, `INDEX FAST FULL SCAN` on `MEAS_BIG_TIME_IX`: read all the index blocks, in any order, and apply `filter(TRUNC(...) = 2026-09-15)` to each entry. The index is smaller than the table, and the query needs no other column, so this beats a full table scan. `E-Rows` 2,000 is the optimizer's standard guess of 1 percent for a function on a column; `A-Rows` 2,985. `Buffers` 541.
- Lines 1 and 0: `SORT AGGREGATE` counts the rows into one number. 541 buffers.

**Step 3. The `l18f` query with the range.** Now the condition is on the column itself.

- Line 2, `INDEX RANGE SCAN`: `access("MEAS_TIME" >= 2026-09-15 00:00 AND "MEAS_TIME" < 2026-09-16 00:00)`. Oracle walks down the index to the first entry of the 15th and reads along until the 16th starts. `E-Rows` 2,987, `A-Rows` 2,985, `Buffers` 11.
- Lines 1 and 0: count, one row, 11 buffers.

### Output

```text
  COUNT(*)
----------
      2985

l18e, TRUNC on the column:
|   0 | SELECT STATEMENT      |                  |      1 |        |      1 |00:00:00.05 |     541 |
|   1 |  SORT AGGREGATE       |                  |      1 |      1 |      1 |00:00:00.05 |     541 |
|*  2 |   INDEX FAST FULL SCAN| MEAS_BIG_TIME_IX |      1 |   2000 |   2985 |00:00:00.05 |     541 |
   2 - filter(TRUNC(INTERNAL_FUNCTION("MEAS_TIME"))=TO_DATE(' 2026-09-15 00:00:00', ...

l18f, range:
|   0 | SELECT STATEMENT  |                  |      1 |        |      1 |00:00:00.01 |      11 |
|   1 |  SORT AGGREGATE   |                  |      1 |      1 |      1 |00:00:00.01 |      11 |
|*  2 |   INDEX RANGE SCAN| MEAS_BIG_TIME_IX |      1 |   2987 |   2985 |00:00:00.01 |      11 |
   2 - access("MEAS_TIME">=TO_DATE(' 2026-09-15 00:00:00', ...
```

### What to notice

Same answer, 541 buffers against 11. With `TRUNC` on the column, Oracle must read every entry of the index and apply `TRUNC` to it (`filter`). With the range, it walks directly to the entries of that day (`access`). Because we count only, the table itself is never touched. If you ask for `AVG(thickness_nm)` instead, Oracle may choose a full scan of the table for both forms, because one day's readings are scattered all over the table. The `TRUNC` still blocks a good plan. The range allows one.

## Exercise 5: Bind variables

**Maya asks:** "Does it matter if we paste the wafer id into the query?"

### The problem in plain words

The query counts the readings of one wafer. It runs for three wafers of lot `L26-001`: first with the wafer id typed into the text (a literal), then with a placeholder `:w` (a bind variable) that gets a different value each time, then from a PL/SQL loop. After each part, `V$SQL` shows which statement texts Oracle has stored and how often each one ran: one row per distinct text.

### The code

```sql
SELECT /* l18g */ COUNT(*) FROM measurements_big WHERE wafer_id = 'L26-001-01';
SELECT /* l18g */ COUNT(*) FROM measurements_big WHERE wafer_id = 'L26-001-02';
SELECT /* l18g */ COUNT(*) FROM measurements_big WHERE wafer_id = 'L26-001-03';
SELECT sql_text, executions FROM v$sql WHERE sql_text LIKE 'SELECT /* l18g */%' ORDER BY sql_text;
```

```sql
DECLARE
  v_n NUMBER;
BEGIN
  EXECUTE IMMEDIATE 'SELECT /* l18h */ COUNT(*) FROM measurements_big WHERE wafer_id = :w'
    INTO v_n USING 'L26-001-01';
  DBMS_OUTPUT.PUT_LINE('L26-001-01 ' || v_n);
  EXECUTE IMMEDIATE 'SELECT /* l18h */ COUNT(*) FROM measurements_big WHERE wafer_id = :w'
    INTO v_n USING 'L26-001-02';
  DBMS_OUTPUT.PUT_LINE('L26-001-02 ' || v_n);
  EXECUTE IMMEDIATE 'SELECT /* l18h */ COUNT(*) FROM measurements_big WHERE wafer_id = :w'
    INTO v_n USING 'L26-001-03';
  DBMS_OUTPUT.PUT_LINE('L26-001-03 ' || v_n);
END;
/
SELECT sql_text, executions FROM v$sql WHERE sql_text LIKE 'SELECT /* l18h */%' ORDER BY sql_text;
```

The counts were 3,032, 3,033 and 3,033. Now the PL/SQL block:

```sql
DECLARE
  v_n NUMBER;
BEGIN
  FOR w IN (SELECT wafer_id FROM wafers WHERE lot_id = 'L26-001' ORDER BY wafer_id) LOOP
    SELECT COUNT(*) INTO v_n FROM measurements_big WHERE wafer_id = w.wafer_id AND defect_count >= 1 AND step <> 'NONE';
    DBMS_OUTPUT.PUT_LINE(w.wafer_id || ' ' || v_n);
  END LOOP;
END;
/
SELECT sql_text, executions FROM v$sql
WHERE  UPPER(sql_text) LIKE '%MEASUREMENTS_BIG WHERE WAFER_ID = :B1 AND DEFECT_COUNT >= 1%'
AND    sql_text NOT LIKE '%v$sql%';
```

### How the code runs

**Step 1. The three literal queries (5a).** The texts differ in the last characters (`-01`, `-02`, `-03`), so for Oracle they are three different statements. Each one is parsed and gets its own plan, and each runs once.

**Step 2. The `V$SQL` query for `l18g`** shows those three texts with `EXECUTIONS` = 1 each.

**Step 3. The block with `EXECUTE IMMEDIATE` (5b).** `EXECUTE IMMEDIATE` sends the text in quotes to Oracle exactly as written, with `:w` still in it. `USING 'L26-001-01'` supplies the value for `:w`, and `INTO v_n` receives the count: 3,032. The second call sends the identical text, so Oracle finds the statement it already parsed and runs it again with `:w` = `'L26-001-02'`: `v_n` = 3,033. The third call does the same with `'L26-001-03'`: 3,033.

**Step 4. The `V$SQL` query for `l18h`** shows one text, with `:w` in it, and `EXECUTIONS` = 3.

**Step 5. The PL/SQL loop (5c).** The `FOR` loop reads the 5 wafers of lot `L26-001` in order. On each pass, `w.wafer_id` holds one wafer id, for example `L26-001-01` on pass 1 and `L26-001-02` on pass 2. The static `SELECT ... INTO` uses `w.wafer_id`. When the block was compiled, PL/SQL rewrote that statement: it replaced `w.wafer_id` by the bind `:B1`, wrote the keywords and names in capitals, and removed extra spaces. So every pass sends the same text, with a different value for `:B1`. The five counts are 3,032 and then 3,033 four times. The extra conditions `defect_count >= 1 AND step <> 'NONE'` keep every row of these wafers; they are only there to make the text easy to find.

**Step 6. The last `V$SQL` query** searches in capitals, because that is how PL/SQL stored the text, and skips its own text, which also contains the search words. It finds one statement with `EXECUTIONS` = 5.

### Output

```text
SQL_TEXT                                                                         EXECUTIONS
-------------------------------------------------------------------------------- ----------
SELECT /* l18g */ COUNT(*) FROM measurements_big WHERE wafer_id = 'L26-001-01'            1
SELECT /* l18g */ COUNT(*) FROM measurements_big WHERE wafer_id = 'L26-001-02'            1
SELECT /* l18g */ COUNT(*) FROM measurements_big WHERE wafer_id = 'L26-001-03'            1
```

```text
L26-001-01 3032
L26-001-02 3033
L26-001-03 3033

SQL_TEXT                                                                         EXECUTIONS
-------------------------------------------------------------------------------- ----------
SELECT /* l18h */ COUNT(*) FROM measurements_big WHERE wafer_id = :w                      3
```

```text
L26-001-01 3032
L26-001-02 3033
L26-001-03 3033
L26-001-04 3033
L26-001-05 3033

SQL_TEXT                                                                         EXECUTIONS
-------------------------------------------------------------------------------- ----------
SELECT COUNT(*) FROM MEASUREMENTS_BIG WHERE WAFER_ID = :B1 AND DEFECT_COUNT >= 1          5
 AND STEP <> 'NONE'
```

### What to notice

Three literals made three statements, each parsed on its own. The bind version made one statement that ran three times. In the PL/SQL block, you wrote `w.wafer_id` and PL/SQL turned it into `:B1`, so five wafers used one statement. You get bind variables for free in static SQL, and you lose them only when you build SQL text yourself with `||`. If you run the exercise a second time, the `EXECUTIONS` numbers grow, because Oracle still holds the statements from the first run.

## Exercise 6: The cost of calling PL/SQL, and loops against sets

**Maya asks:** "I need every reading flagged `DIRTY` (30 or more defects) or `CLEAN`."

### The problem in plain words

6a counts the dirty readings among all 200,000, once with a `CASE` inside the SQL and once with a PL/SQL function called for every row, five runs each, and prints the time of each way and the answer. Both must give the same answer. 6b fills `MY_VERDICT` with one row per reading for the first 50,000 readings (`meas_id`, and `DIRTY` or `CLEAN`), three times in three ways, and prints the time and row count of each way. At the end the table holds 50,000 rows.

### The code

```sql
CREATE OR REPLACE FUNCTION is_dirty (p_defects NUMBER) RETURN NUMBER IS
BEGIN
  IF p_defects >= 30 THEN
    RETURN 1;
  ELSE
    RETURN 0;
  END IF;
END is_dirty;
/
DECLARE
  v_start NUMBER;
  v_n     NUMBER;
BEGIN
  v_start := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. 5 LOOP
    SELECT SUM(CASE WHEN defect_count >= 30 THEN 1 ELSE 0 END) INTO v_n FROM measurements_big;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('CASE in SQL    : ' || (DBMS_UTILITY.GET_TIME - v_start) / 100 || ' s for 5 runs, answer ' || v_n);
  v_start := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. 5 LOOP
    SELECT SUM(is_dirty(defect_count)) INTO v_n FROM measurements_big;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('is_dirty() call : ' || (DBMS_UTILITY.GET_TIME - v_start) / 100 || ' s for 5 runs, answer ' || v_n);
END;
/
```

Now the three ways to fill `MY_VERDICT` for the first 50,000 readings:

```sql
CREATE TABLE my_verdict (meas_id NUMBER(8) NOT NULL, verdict VARCHAR2(5) NOT NULL);
DECLARE
  v_start NUMBER;
  v_rows  NUMBER := 0;
  TYPE t_ids  IS TABLE OF measurements_big.meas_id%TYPE;
  TYPE t_defs IS TABLE OF measurements_big.defect_count%TYPE;
  TYPE t_verd IS TABLE OF my_verdict.verdict%TYPE;
  v_ids  t_ids;
  v_defs t_defs;
  v_verd t_verd;
  CURSOR c IS SELECT meas_id, defect_count FROM measurements_big WHERE meas_id <= 50000 ORDER BY meas_id;
BEGIN
  -- way 1: row by row
  EXECUTE IMMEDIATE 'TRUNCATE TABLE my_verdict';
  v_start := DBMS_UTILITY.GET_TIME;
  FOR r IN c LOOP
    INSERT INTO my_verdict (meas_id, verdict)
    VALUES (r.meas_id, CASE WHEN r.defect_count >= 30 THEN 'DIRTY' ELSE 'CLEAN' END);
    v_rows := v_rows + 1;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('row by row          : ' || (DBMS_UTILITY.GET_TIME - v_start) / 100 || ' s for ' || v_rows || ' rows');
  --
  -- way 2: BULK COLLECT + FORALL
  EXECUTE IMMEDIATE 'TRUNCATE TABLE my_verdict';
  v_rows := 0;
  v_start := DBMS_UTILITY.GET_TIME;
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_ids, v_defs LIMIT 1000;
    EXIT WHEN v_ids.COUNT = 0;
    v_verd := t_verd();
    v_verd.EXTEND(v_ids.COUNT);
    FOR i IN 1 .. v_ids.COUNT LOOP
      v_verd(i) := CASE WHEN v_defs(i) >= 30 THEN 'DIRTY' ELSE 'CLEAN' END;
    END LOOP;
    FORALL i IN 1 .. v_ids.COUNT
      INSERT INTO my_verdict (meas_id, verdict) VALUES (v_ids(i), v_verd(i));
    v_rows := v_rows + SQL%ROWCOUNT;
  END LOOP;
  CLOSE c;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('BULK COLLECT+FORALL : ' || (DBMS_UTILITY.GET_TIME - v_start) / 100 || ' s for ' || v_rows || ' rows');
  --
  -- way 3: one statement
  EXECUTE IMMEDIATE 'TRUNCATE TABLE my_verdict';
  v_start := DBMS_UTILITY.GET_TIME;
  INSERT INTO my_verdict (meas_id, verdict)
  SELECT meas_id, CASE WHEN defect_count >= 30 THEN 'DIRTY' ELSE 'CLEAN' END
  FROM   measurements_big WHERE meas_id <= 50000;
  v_rows := SQL%ROWCOUNT;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('one INSERT..SELECT  : ' || (DBMS_UTILITY.GET_TIME - v_start) / 100 || ' s for ' || v_rows || ' rows');
END;
/
SELECT verdict, COUNT(*) AS readings FROM my_verdict GROUP BY verdict ORDER BY verdict;
```

### How the code runs

**Step 1. CREATE FUNCTION is_dirty.** Compiled and stored. It returns 1 for 30 or more defects, otherwise 0.

**Step 2. The 6a block, first loop.** `v_start` takes `DBMS_UTILITY.GET_TIME`, a clock in hundredths of a second. The loop runs the `CASE` query 5 times; each run reads all 200,000 rows and gives `v_n` = 61,333. The elapsed hundredths divided by 100 give seconds: .05 s for the five runs.

**Step 3. The 6a block, second loop.** The same five runs with `SUM(is_dirty(defect_count))`. The SQL engine now hands each row's `defect_count` to the PL/SQL engine and takes the 1 or 0 back: 200,000 calls per run, 1,000,000 in all. `v_n` is again 61,333, and the time is 1.12 s.

**Step 4. CREATE TABLE my_verdict.** An empty table with two columns.

**Step 5. The 6b block, declarations.** Three collection types (lists) for ids, defect counts and verdicts, three empty list variables, and the cursor `c` over the 50,000 readings with `meas_id <= 50000`.

**Step 6. Way 1, row by row.** `TRUNCATE` empties the table; inside PL/SQL a DDL statement has to go through `EXECUTE IMMEDIATE`. The cursor loop fetches one reading per pass: pass 1 is `meas_id` 1 with 25 defects, so `CLEAN`; pass 2 is `meas_id` 2 with 2 defects, `CLEAN`; pass 3 is `meas_id` 3 with 63 defects, `DIRTY`. Each pass runs one `INSERT`, so 50,000 single-row inserts, and `v_rows` counts up to 50,000. Then `COMMIT` and the time: 2 s.

**Step 7. Way 2, BULK COLLECT and FORALL.** The table is emptied again and `v_rows` reset to 0. `OPEN c`, then the loop:

- Fetch 1: `BULK COLLECT ... LIMIT 1000` fills `v_ids` and `v_defs` with readings 1 to 1000 in one go. `v_ids.COUNT` = 1000, so no exit. The inner `FOR` loop fills `v_verd` with 1000 verdicts. `FORALL` sends one `INSERT` with all 1000 rows to the SQL engine. `SQL%ROWCOUNT` = 1000, so `v_rows` = 1000.
- Fetch 2: readings 1001 to 2000. `v_rows` = 2000.
- Fetches 3 to 50 do the same. After fetch 50, `v_rows` = 50,000.
- Fetch 51 finds no more rows: `v_ids.COUNT` = 0, and `EXIT WHEN` leaves the loop.

`CLOSE c`, `COMMIT`, and the time: .09 s.

**Step 8. Way 3, one statement.** The table is emptied again. One `INSERT ... SELECT` reads the 50,000 readings and writes the 50,000 rows inside the SQL engine. `SQL%ROWCOUNT` = 50,000. `COMMIT`, and the time: .05 s.

**Step 9. The last query** groups the 50,000 rows left by way 3 by verdict: 34,667 `CLEAN` and 15,333 `DIRTY`.

### Output

```text
CASE in SQL    : .05 s for 5 runs, answer 61333
is_dirty() call : 1.12 s for 5 runs, answer 61333
```

```text
row by row          : 2 s for 50000 rows
BULK COLLECT+FORALL : .09 s for 50000 rows
one INSERT..SELECT  : .05 s for 50000 rows

VERDICT  READINGS
-------- ----------
CLEAN         34667
DIRTY         15333
```

### What to notice

The function version is about 20 times slower for exactly the same answer, because Oracle switches between the SQL and PL/SQL engines for every one of 200,000 rows. In the loop test the row-by-row version is by far the slowest, for the same reason: one switch per `INSERT`. Bulk processing sends 1,000 rows per switch, and the single statement has no switches. The exact seconds change with every run on a laptop. When the test was repeated, the row-by-row loop took between 0.6 and 2 s while the other two stayed under 0.1 s. The order never changed.

## Exercise 7: Clean up

**Maya asks:** "Leave the table the way you found it."

### The problem in plain words

Everything this lab created goes away: the table `MY_VERDICT`, the three indexes and the function `IS_DIRTY`. The session's counting goes back to normal. The checks show the indexes left on `MEASUREMENTS_BIG` (only the primary key) and that `MY_VERDICT` no longer exists.

### The code

```sql
ALTER SESSION SET STATISTICS_LEVEL = TYPICAL;
DROP TABLE my_verdict PURGE;
DROP INDEX meas_big_wafer_ix;
DROP INDEX meas_big_tool_ix;
DROP INDEX meas_big_time_ix;
DROP FUNCTION is_dirty;
SELECT index_name FROM user_indexes WHERE table_name = 'MEASUREMENTS_BIG';
SELECT COUNT(*) AS my_tables FROM user_tables WHERE table_name = 'MY_VERDICT';
```

### How the code runs

**Step 1. ALTER SESSION ... TYPICAL** stops the extra counting, which slows every statement a little.

**Step 2. The DROP statements.** `DROP TABLE ... PURGE` removes the table without keeping it in the recycle bin. Each `DROP INDEX` removes one index; the table rows are not touched. `DROP FUNCTION` removes `IS_DIRTY`.

**Step 3. The checks.** `USER_INDEXES` lists one index for the table, `MEAS_BIG_PK`. `USER_TABLES` has no row for `MY_VERDICT`, so the count is 0.

### Output

```text
Session altered.
Table dropped.
Index dropped.
Index dropped.
Index dropped.
Function dropped.

INDEX_NAME
--------------------------------------------------------------------------------
MEAS_BIG_PK

 MY_TABLES
----------
         0
```

### What to notice

`MEASUREMENTS_BIG` is back to having only its primary key index, as the add-on script made it.
