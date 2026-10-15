# Lab 18: Tuning a little

**Time:** 45 minutes. **Reading first:** [Tuning a little: how Oracle runs your query](../topics/06-tuning-a-little.md).

> **This lab creates things and must clean up.** You will create three indexes on `MEASUREMENTS_BIG`, a function `IS_DIRTY` and a helper table `MY_VERDICT`. Exercise 7 removes them all. The table data itself is never changed. If you stop early, run the statements of Exercise 7 anyway, otherwise later runs of this lab will fail with "name is already used by an existing object".

## The story

Maya's night-shift report runs slowly. "The measurement table is big now," she says. "Is there anything a person who writes queries can do about it, or must I call the DBA?" Her report asks for the readings of one wafer, one tool and one day, and it flags every reading as dirty or clean.

You will look at how Oracle runs these requests, speed up the ones that can be sped up, and find out why one obvious fix does nothing.

## What you will do

- read an execution plan and the real numbers behind it
- create an index and compare the work done
- find a case where an index does not help
- rewrite a predicate that a function was blocking
- see bind variables in `V$SQL`
- time a function called per row, and compare a loop with bulk processing and one statement
- clean up

## Before you start

- Everything here is run as `FAB_LAB`. You need `SELECT_CATALOG_ROLE`, which the setup script granted. Check with `SELECT * FROM session_roles;`.
- `MEASUREMENTS_BIG` comes from the Day 3 and 4 add-on, the four files `day34_addon_0_reset.sql`, `day34_addon_1_tables.sql`, `day34_addon_2_lot_history_data.sql` and `day34_addon_3_big_table_and_check.sql` in [`labs/scripts`](scripts), explained in [day34_new_data.md](scripts/day34_new_data.md). It must have 200,000 rows: `SELECT COUNT(*) FROM measurements_big;`. If it does not, run the four files again in that order.
- Your seconds will not match the solutions. Buffer counts and the shape of the plans should match closely.
- Open the Output panel (**Ctrl + Shift + O**, or **SQL Editor > Show Server Output**) before you run anything. Exercises 5 and 6 print with `DBMS_OUTPUT`.
- Run a single statement with the cursor inside it and **Ctrl + Enter**. Run a PL/SQL block or a `CREATE FUNCTION` by selecting the whole of it, from its first line down to its `END;` line, and pressing **Ctrl + Enter**. One at a time. Do not leave blank lines inside a block: DBeaver can cut it in two there. Use a line holding only `--` if you want space.

## Scripts

| File | What it does |
| --- | --- |
| [`lab18_tuning_a_little.sql`](scripts/lab18_tuning_a_little.sql) | Every exercise as a comment, plus a ready-made helper statement for reading real plans. Run as `FAB_LAB`. |

Solutions: [lab-18-solutions.md](../solutions/lab-18-solutions.md).

## How to see what really happened

The plan from `EXPLAIN PLAN` is a prediction. For the real work, put a marker comment right after `SELECT`, run the statement, and then ask for its plan by the marker. The script has the helper at the top. Use a new marker for each statement, and switch on the counting first:

```sql
ALTER SESSION SET STATISTICS_LEVEL = ALL;
```

The helper finds your statement in `V$SQL` by its marker and passes its `sql_id` to `DBMS_XPLAN.DISPLAY_CURSOR`. Change `mine1` to your marker:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /* mine1 */%'
          ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY), NULL, 'ALLSTATS LAST'));
```

You may see the shortcut `DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST')` elsewhere. It shows the last statement your session ran, and in DBeaver that is often one of DBeaver's own background queries. The marker works in every tool.

Look at the columns `A-Rows` (real rows) and `Buffers` (blocks read).

## Exercise 1: Statistics and a first plan

Maya: "Why is looking up one reading by its number instant, but looking up a wafer's readings slow?"

- **1a.** How many rows and blocks does `USER_TABLES` say `MEASUREMENTS_BIG` has? How many distinct values do `MEAS_ID`, `WAFER_ID` and `TOOL_ID` have in `USER_TAB_COL_STATISTICS`?
- **1b.** Use `EXPLAIN PLAN FOR` and `DBMS_XPLAN.DISPLAY` for `WHERE meas_id = 100000` and for `WHERE wafer_id = 'L26-005-02'`. Compare the operation and the cost.

<details>
<summary>Hint 1: where are the numbers?</summary>

`USER_TABLES` has `NUM_ROWS` and `BLOCKS`. `USER_TAB_COL_STATISTICS` has `COLUMN_NAME` and `NUM_DISTINCT`. Filter on `TABLE_NAME = 'MEASUREMENTS_BIG'`.
</details>

<details>
<summary>Hint 2: the plan</summary>

Two statements per plan:

```sql
EXPLAIN PLAN FOR SELECT * FROM measurements_big WHERE meas_id = 100000;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
</details>

<details>
<summary>Hint 3: what to look at</summary>

The `Operation` column (a line with `TABLE ACCESS FULL` or `INDEX ... SCAN`), the `Rows` estimate and the `Cost`.
</details>

**Checkpoint:** 200,000 rows in 1,385 blocks. The first plan uses `INDEX UNIQUE SCAN` on `MEAS_BIG_PK` with cost 3 (2 on some databases, depending on the depth of the index). The second uses `TABLE ACCESS FULL` with an estimate of 3,030 rows and cost 378.

**Trap:** do not call a cost of 378 "378 milliseconds". It is a score for comparing plans of the same statement.

## Exercise 2: Create an index and watch the buffers

Maya: "Can you make the wafer lookup quick?"

Run `SELECT /* l18a */ AVG(thickness_nm) FROM measurements_big WHERE wafer_id = 'L26-005-02';` and read its real plan. Then create an index on `wafer_id`, run the same query with the marker `l18b`, and compare `Buffers`.

<details>
<summary>Hint 1: the statements</summary>

`CREATE INDEX name ON table (column);` Pick the name `meas_big_wafer_ix`.
</details>

<details>
<summary>Hint 2: reading the real plan</summary>

Run the helper from the top of the script with `l18a` in `LIKE 'SELECT /* l18a */%'`. The first line of the result is the SQL text, which tells you that you have the right statement.
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

After `CREATE INDEX`, the plan changes without any change to your query. Look for `INDEX RANGE SCAN` and a much smaller number under `Buffers`.
</details>

**Checkpoint:** before the index, `TABLE ACCESS FULL` with about 1,360 buffers. After the index, `INDEX RANGE SCAN` with about 33 buffers. `A-Rows` is 3,030 in both.

**Trap:** if the plan after the index still shows `TABLE ACCESS FULL`, check that the marker in your `LIKE` matches the statement you just ran, and that you created the index in your own schema. The helper picks the newest statement with that marker, so reusing a marker for a different statement shows the wrong plan.

## Exercise 3: When an index does not help

Maya: "Same trick for the tool, please."

Create an index on `tool_id`. Get the real plan of `SELECT AVG(thickness_nm) FROM measurements_big WHERE tool_id = 'MET02'` (with a marker). Then force the index with `/*+ INDEX(m meas_big_tool_ix) */` (give the table the alias `m`) and compare `Buffers`. Also compare `E-Rows` with `A-Rows`.

<details>
<summary>Hint 1: how selective is MET02?</summary>

Count the readings per tool with `GROUP BY tool_id`. The share of the rarest tool is the answer to "how much of the table do I want?".
</details>

<details>
<summary>Hint 2: the hint syntax</summary>

`SELECT /*+ INDEX(m meas_big_tool_ix) */ /* l18d */ AVG(thickness_nm) FROM measurements_big m WHERE tool_id = 'MET02';` The hint comment comes right after `SELECT`. The alias in the hint must match the alias in the query.
</details>

<details>
<summary>Hint 3: the marker</summary>

To find the hinted statement, the `LIKE` pattern must include the hint text: `LIKE 'SELECT /*+ INDEX(m meas_big_tool_ix) */ /* l18d */%'`.
</details>

**Checkpoint:** each tool has at least 4.8% of the rows. Oracle chooses `TABLE ACCESS FULL` (1,359 buffers) even with the new index. The forced index plan reads about 1,381 buffers, slightly more. `E-Rows` is 28,571 (200,000 divided by 7) and `A-Rows` is 9,524.

**Trap:** do not keep the hint "because it is better". Here it is not. And a typo in the alias makes Oracle ignore the hint without any message.

## Exercise 4: The function-on-the-column trap

Maya: "How many readings were taken on 15 September 2026?"

Create an index on `meas_time`. Count the readings with `TRUNC(meas_time) = DATE '2026-09-15'`. Then count them with a range predicate. Compare plans and buffers.

<details>
<summary>Hint 1: the range idea</summary>

A day is "from midnight, up to but not including the next midnight". Two conditions joined with `AND`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT /* l18f */ COUNT(*) FROM measurements_big
WHERE  meas_time >= DATE '___' AND meas_time < DATE '___';
```
</details>

<details>
<summary>Hint 3: what to compare</summary>

The operation (`INDEX FAST FULL SCAN` or `INDEX RANGE SCAN`) and the `Buffers` column. Both queries should return the same count.
</details>

**Checkpoint:** both return 2,985. The `TRUNC` form uses `INDEX FAST FULL SCAN` with 541 buffers. The range form uses `INDEX RANGE SCAN` with 11 buffers.

**Trap:** end the range with `<` the next day's date. If you write `<= DATE '2026-09-15'` you only get the readings taken at exactly midnight. If you write `<= DATE '2026-09-16'` you also count any reading taken at exactly midnight of the 16th.

## Exercise 5: Bind variables

Maya: "Does it matter if we paste the wafer id into the query?"

- **5a.** Count the readings of wafers `L26-001-01`, `-02` and `-03` with the id typed in as a literal, marker `l18g`. Look in `V$SQL` for the marker.
- **5b.** Do the same with a bind variable `:w` and marker `l18h`, for the same three wafers. Write one block that runs the query text three times with `EXECUTE IMMEDIATE ... USING` (hint 2), then look in `V$SQL`.
- **5c.** In a PL/SQL block, loop over the wafers of lot `L26-001` and count each wafer's readings with a static `SELECT ... INTO` that uses the loop variable. Find the statement in `V$SQL`.

<details>
<summary>Hint 1: V$SQL</summary>

```sql
SELECT sql_text, executions FROM v$sql WHERE sql_text LIKE 'SELECT /* l18g */%' ORDER BY sql_text;
```
</details>

<details>
<summary>Hint 2: binds in a block</summary>

`EXECUTE IMMEDIATE` sends the text exactly as you wrote it, and `USING` fills in `:w`. Repeat the pair of lines for `-02` and `-03`:

```sql
DECLARE
  v_n NUMBER;
BEGIN
  EXECUTE IMMEDIATE 'SELECT /* l18h */ COUNT(*) FROM measurements_big WHERE wafer_id = :w'
    INTO v_n USING 'L26-001-01';
  DBMS_OUTPUT.PUT_LINE('L26-001-01 ' || v_n);
  ...
END;
/
```

You can also try it by hand in DBeaver: run `SELECT /* l18h */ COUNT(*) FROM measurements_big WHERE wafer_id = :w;` on its own, type `'L26-001-01'` in the dialog that opens, and repeat with the other two values. DBeaver may send the bind under another name (for example `:1`), so the text in `V$SQL` can differ a little from the block version. The block is the reliable way.
</details>

<details>
<summary>Hint 3: 5c</summary>

Use `FOR w IN (SELECT wafer_id FROM wafers WHERE lot_id = 'L26-001' ORDER BY wafer_id) LOOP ... WHERE wafer_id = w.wafer_id ... END LOOP;`. To find the statement afterwards, search with `UPPER(sql_text) LIKE '%WAFER_ID = :B1%'` and exclude your own query.
</details>

**Checkpoint:** 5a shows three rows with one execution each. 5b shows one row with three executions. 5c shows a statement with `:B1`.

**Trap:** Oracle shares a statement only when the text is identical, character for character. A different letter case or an extra space in the bind version makes a new statement again.

## Exercise 6: The cost of calling PL/SQL, and loops against sets

Maya: "I need every reading flagged `DIRTY` (30 or more defects) or `CLEAN`."

- **6a.** Create `FUNCTION is_dirty (p_defects NUMBER) RETURN NUMBER` (1 for 30 or more, otherwise 0). In one block, time `SUM(CASE WHEN defect_count >= 30 THEN 1 ELSE 0 END)` and `SUM(is_dirty(defect_count))` over `MEASUREMENTS_BIG`, five runs each, with `DBMS_UTILITY.GET_TIME` (hundredths of a second).
- **6b.** Create `MY_VERDICT (meas_id NUMBER(8) NOT NULL, verdict VARCHAR2(5) NOT NULL)`. For `meas_id <= 50000`, fill it three ways and time each way: a loop with one `INSERT` per row, `BULK COLLECT ... LIMIT 1000` with `FORALL`, and one `INSERT ... SELECT`. Truncate the table before each way.

<details>
<summary>Hint 1: timing in a block</summary>

```sql
v_start := DBMS_UTILITY.GET_TIME;
... the work ...
DBMS_OUTPUT.PUT_LINE('label: ' || (DBMS_UTILITY.GET_TIME - v_start) / 100 || ' s');
```

For 6a put the query inside `FOR i IN 1 .. 5 LOOP ... SELECT ... INTO v_n ... END LOOP;`.
</details>

<details>
<summary>Hint 2: clearing the table</summary>

Inside PL/SQL write `EXECUTE IMMEDIATE 'TRUNCATE TABLE my_verdict';`. Commit after each way.
</details>

<details>
<summary>Hint 3: the bulk way</summary>

```sql
OPEN c;
LOOP
  FETCH c BULK COLLECT INTO v_ids, v_defs LIMIT 1000;
  EXIT WHEN v_ids.COUNT = 0;
  FORALL i IN 1 .. v_ids.COUNT
    INSERT INTO my_verdict (meas_id, verdict)
    VALUES (v_ids(i), CASE WHEN v_defs(i) >= 30 THEN 'DIRTY' ELSE 'CLEAN' END);
END LOOP;
CLOSE c;
```

`FORALL` takes one `INSERT` that indexes the collections with `i`. The solution computes the verdicts into a third collection first, but the `CASE` inside the `VALUES` list works too.
</details>

**Checkpoint:** 6a gives 61,333 dirty readings both ways and the function version is clearly slower (the solution run shows more than 20 times). In 6b, `MY_VERDICT` ends with 34,667 `CLEAN` and 15,333 `DIRTY`, and the row-by-row loop is much slower than the other two.

**Trap:** `FORALL` is not a loop. It is one statement that sends all collected rows at once, so you cannot put other statements inside it. Also, `GET_TIME` has a resolution of 0.01 s, so a very fast way may show 0.

## Exercise 7: Clean up

Drop `MY_VERDICT`, the three indexes and `IS_DIRTY`, and set the session back to normal.

<details>
<summary>Hint 1: statements</summary>

`DROP TABLE ... PURGE;`, `DROP INDEX ...;`, `DROP FUNCTION ...;` and `ALTER SESSION SET STATISTICS_LEVEL = TYPICAL;`
</details>

<details>
<summary>Hint 2: names</summary>

`meas_big_wafer_ix`, `meas_big_tool_ix`, `meas_big_time_ix`.
</details>

<details>
<summary>Hint 3: check</summary>

`SELECT index_name FROM user_indexes WHERE table_name = 'MEASUREMENTS_BIG';`
</details>

**Checkpoint:** only `MEAS_BIG_PK` is left, and `MY_VERDICT` is gone.

**Trap:** leaving one index behind. It slows every later write to `MEASUREMENTS_BIG` and makes the next run of this lab fail with ORA-00955. Run the check query, not just the drops.
