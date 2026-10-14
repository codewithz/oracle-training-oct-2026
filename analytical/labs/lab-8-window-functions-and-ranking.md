# Lab 8: Window functions and ranking

**Time:** 40 minutes. **Reading first:** [Window functions](../topics/01-window-functions.md) and [Ranking](../topics/02-ranking.md).

> **Your original tables are safe.** The only thing this lab creates is the add-on set (`LOT_HISTORY`, `MEASUREMENTS_BIG`, `ERROR_LOG`). All exercises only read data.

## The story

Maya has stopped asking for single numbers. "A number without something to compare it with tells me nothing," she says. "I want each reading next to its product average, I want to know which tool sends me the worst wafers, and I want the top few without the rest." Today you answer with window functions: the rows stay, and every row gets a number worked out from its group.

Before the questions, you load the extra tables that Days 3 and 4 use.

## What you will do

- load the Day 3 and 4 add-on tables and check them
- put an average next to each row with `OVER ()` and `PARTITION BY`
- compute a share of the total
- filter on a window result with an inline view
- pick the best row per group with `ROW_NUMBER`, and see what ties do
- use `FETCH FIRST ... WITH TIES` and `NTILE`

## Scripts

| File | What it does |
| --- | --- |
| [`lab8_window_functions_and_ranking.sql`](scripts/lab8_window_functions_and_ranking.sql) | Your worksheet: each question is a comment with space below it for your query. Run as `FAB_LAB`. |
| [`day34_addon.sql`](scripts/day34_addon.sql) | Loads the add-on tables. Run once with `Alt + X`. |
| [`day34_reset.sql`](scripts/day34_reset.sql) | Removes the add-on tables, to start again. |

Solutions: [lab-8-solutions.md](../solutions/lab-8-solutions.md).

## Before you start

1. Connect to `FAB_LAB` in DBeaver (`fab-lab` connection) and open `lab8_window_functions_and_ranking.sql` with **File > Open File**.
2. Run one statement at a time with `Ctrl + Enter` (the cursor must be inside the statement, which must end with a semicolon).
3. Auto-commit is fine. Nothing is changed.
4. Every exercise has three hints. Open Hint 1 first and use the next one only when you are stuck. Each exercise ends with a checkpoint: compare your row count and key value before you open the solutions page.

## Part 0: load the add-on tables (5 minutes)

Days 3 and 4 use three more tables. Everybody loads them once, now. The script is [`day34_addon.sql`](scripts/day34_addon.sql), a copy of the course file. It does not touch your five basics tables.

1. In DBeaver, connect with the **`fab-lab`** connection (user `FAB_LAB`).
2. Open `day34_addon.sql` with **File > Open File**. Check that the connection shown above the editor is `fab-lab`.
3. Run the whole file with **Execute Script** (`Alt + X`), not `Ctrl + Enter`. It creates the tables, fills them and takes a few seconds. The script uses a `DECLARE ... END;` block and a loop, so the Alt + X run is what you need.
4. The last statement counts the rows. Check the result grid:

| TABLE_NAME | ROW_COUNT |
| --- | --- |
| LOT_HISTORY | 147 |
| MEASUREMENTS_BIG | 200000 |
| ERROR_LOG | 0 |

If you see an error saying that a name is already used by an existing object, you ran the script before. Run [`day34_reset.sql`](scripts/day34_reset.sql) with `Alt + X`, then run `day34_addon.sql` again. The reset removes only the three add-on tables and their sequences.

What the script created:

| Object | What it holds |
| --- | --- |
| `LOT_HISTORY` | One row per status change of a lot: `hist_id`, `lot_id`, `old_status`, `new_status`, `changed_at`, `changed_by`, `note`. 147 rows. The first row of each lot has no `old_status`. The `note` column is free text written by operators and is messy on purpose. Day 4 uses it. |
| `MEASUREMENTS_BIG` | 200,000 readings in the same shape as `MEASUREMENTS`. You will use it in Day 4, where volume matters. Today the small `MEASUREMENTS` table is better, because you can check results by eye. |
| `ERROR_LOG` | An empty table for a Day 4 demo. |

Look at the history of one lot to see what the rows mean:

```sql
SELECT lot_id, old_status, new_status,
       TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI') AS changed_at
FROM   lot_history
WHERE  lot_id = 'L26-003B'
ORDER  BY changed_at;
```
<!--gen-->
```text
LOT_ID       OLD_STAT NEW_STAT CHANGED_AT
------------ -------- -------- ----------------
L26-003B              ACTIVE   2026-08-14 10:05
L26-003B     ACTIVE   HOLD     2026-08-16 08:05
L26-003B     HOLD     ACTIVE   2026-08-17 05:05
L26-003B     ACTIVE   HOLD     2026-08-19 08:05
```

The lot started `ACTIVE`, went on `HOLD`, came back, and went on `HOLD` again. Lab 9 turns rows like these into hours. Then continue with the window function questions.

## Part A: the average next to every row

### Exercise 1: Lot average next to each reading

**Maya asks:** "Lot L26-005 is on hold. Show each of its FINAL readings with the average FINAL thickness of the lot next to it, and how far each wafer is from that average (two decimals)."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

The average of the lot's readings is an aggregate. To keep every row you need `OVER ()` after it. Filter the lot and the step in `WHERE`, so the window only sees L26-005 FINAL readings.

</details>

<details>
<summary>Hint 2</summary>

`SELECT m.wafer_id, m.thickness_nm, ROUND(AVG(m.thickness_nm) OVER (), 2) AS avg_lot, ROUND(m.thickness_nm - AVG(m.___) OVER (), 2) AS diff FROM measurements m JOIN wafers w ON w.___ = m.___ WHERE w.lot_id = '___' AND m.step = '___' ORDER BY m.wafer_id;`

</details>

<details>
<summary>Hint 3</summary>

The `WHERE` has two tests: `w.lot_id = 'L26-005'` and `m.step = 'FINAL'`. You can use the same `AVG(...) OVER ()` twice in one `SELECT`.

</details>

**Checkpoint:** 4 rows. `avg_lot` is 218.27 on every row, and `L26-005-01` is 2.8 above it.

### Exercise 2: Compare with the product average

**Maya asks:** "Show every FINAL reading with its product code, the average FINAL thickness of that product, and the difference. I only want the three readings that are furthest from their product average, in either direction."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

You need the average per product, so the window needs `PARTITION BY` the product code. For "furthest in either direction" sort by the absolute value of the difference, biggest first, and keep three rows with `FETCH FIRST`.

</details>

<details>
<summary>Hint 2</summary>

`ROUND(m.thickness_nm - AVG(m.thickness_nm) OVER (PARTITION BY p.___), 2) AS diff` for the column. Put `ABS(...)` of the same expression in the `ORDER BY`, with `DESC`. The joins are `measurements`, `wafers`, `lots`, `products`.

</details>

<details>
<summary>Hint 3</summary>

`ORDER BY ABS(m.thickness_nm - AVG(m.thickness_nm) OVER (PARTITION BY p.product_code)) DESC FETCH FIRST 3 ROWS ONLY;` Window functions are allowed in `ORDER BY`. Only `WHERE` and `HAVING` refuse them.

</details>

**Checkpoint:** 3 rows. The biggest difference is 54.56, wafer `L26-008-04` (product `PWR-200`).

### Exercise 3: Share of defects per product family

**Maya asks:** "What percentage of all defects (all steps) comes from each product family? One line per family, biggest share first, one decimal. The shares should add up to 100."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

This is the share-of-total pattern: a window around a `GROUP BY` aggregate. The inner `SUM` is the family total, the outer `SUM ... OVER ()` adds up all the family totals.

</details>

<details>
<summary>Hint 2</summary>

`SELECT p.family, SUM(m.defect_count) AS defects, ROUND(100 * SUM(m.defect_count) / SUM(SUM(m.defect_count)) OVER (), 1) AS pct_of_all FROM ... GROUP BY p.family ORDER BY defects DESC;` Join `measurements`, `wafers`, `lots`, `products`. No `WHERE`, since Maya said all steps.

</details>

<details>
<summary>Hint 3</summary>

Only `p.family` goes in `GROUP BY`. The window needs no `PARTITION BY`, because you want one total over all four lines.

</details>

**Checkpoint:** 4 rows. `FD-SOI` has 1753 defects, 48.2 percent. The four percentages add to 99.9 because of rounding.

## Part B: filtering and ranking

### Exercise 4: Above-average readings, counted per product

**Maya asks:** "How many FINAL readings are thicker than the average FINAL thickness of their own product? Give me the count for each product."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

A window function cannot go in `WHERE` (try it and read the error: `ORA-30483`). Calculate the product average in an inner query, keep it as a column, and compare in the outer query. Then `GROUP BY` the product.

</details>

<details>
<summary>Hint 2</summary>

`SELECT product_code, COUNT(*) AS above_average FROM (SELECT p.product_code, m.thickness_nm, AVG(m.thickness_nm) OVER (PARTITION BY p.___) AS avg_product FROM ... WHERE m.step = 'FINAL') WHERE thickness_nm > ___ GROUP BY product_code;`

</details>

<details>
<summary>Hint 3</summary>

The inner query has the four joins and only `WHERE m.step = 'FINAL'`. If you filter by lot or product there, the average changes. The outer query compares `thickness_nm > avg_product`.

</details>

**Checkpoint:** 4 rows: `FD-300` 10, `PHO-300` 5, `PWR-200` 4, `RF-300` 8. Together 27.

### Exercise 5: Worst wafer in each lot

**Maya asks:** "For every lot that has readings, which wafer collected the most defects over all its readings (SPLIT, ANNEAL and FINAL together)? One wafer per lot. If two wafers tie, show the one with the lower wafer ID."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

You want one row per lot, so rank the wafers inside each lot and keep rank 1. First the wafer totals come from `GROUP BY lot, wafer`. Then `ROW_NUMBER() OVER (PARTITION BY lot ...)` ranks those lines. Then an outer query keeps rank 1.

</details>

<details>
<summary>Hint 2</summary>

`ROW_NUMBER() OVER (PARTITION BY w.lot_id ORDER BY SUM(m.defect_count) DESC, w.wafer_id) AS rn` sits in the inner `SELECT` next to `SUM(m.defect_count)` with `GROUP BY w.lot_id, w.wafer_id`. The outer query is `WHERE rn = 1`.

</details>

<details>
<summary>Hint 3</summary>

The second sort key in the window (`w.wafer_id`) is the tie-breaker Maya asked for: the lower wafer ID wins. Without it the choice between tied wafers would be arbitrary.

</details>

**Checkpoint:** 15 rows (lot `L26-012` has no readings). For `L26-003` the wafer is `L26-003-05` with 85 defects, and for `L26-007` it is `L26-007-04` with 87.

### Exercise 6: Ties and quarters

**Maya asks:** "Part a: Give me the three SPLIT readings with the most defects. Run it as FETCH FIRST 3 ROWS ONLY and again with WITH TIES, and tell me the difference. Part b: split the lots into four groups by total defects, worst first, and list the lots in the worst group."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Part a: `FETCH FIRST 3 ROWS ONLY` after an `ORDER BY ... DESC`, then change `ONLY` to `WITH TIES`. Part b: `NTILE(4)` over the lot totals, worst first. The window sits next to a `SUM`, so `GROUP BY` first; filter the quartile in an outer query.

</details>

<details>
<summary>Hint 2</summary>

Part b: `SELECT lot_id, total_defects FROM (SELECT w.lot_id, SUM(m.defect_count) AS total_defects, NTILE(4) OVER (ORDER BY SUM(m.defect_count) ___) AS quartile FROM ... GROUP BY w.lot_id) WHERE quartile = 1;`

</details>

<details>
<summary>Hint 3</summary>

In `NTILE(4) OVER (ORDER BY SUM(m.defect_count) DESC)` the biggest total gets group 1. Join `measurements` to `wafers` for the lot.

</details>

**Checkpoint:** Part a: 3 rows with `ONLY`, 4 rows with `WITH TIES` (the extra one is `L26-010-02`, 57 defects, tied with `L26-004-01`). Part b: 4 lots: `L26-011`, `L26-009`, `L26-007`, `L26-010`.

## Finishing

You changed nothing, so there is nothing to undo. Keep the add-on tables: Labs 9 and 10 and all of Day 4 use them.
