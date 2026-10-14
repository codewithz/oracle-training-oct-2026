# Lab 10: Report shapes

**Time:** 30 minutes. **Reading first:** [Report shapes: subtotals, grids and lists](../topics/04-report-shapes.md).

> This lab reads the five basics tables, and `LOT_HISTORY` for the last exercise. Nothing is changed.

## The story

Maya's weekly report goes on paper, and paper wants subtotals, grids and lists. "Defects by product family and step, with a subtotal for each family and a grand total. Then the same numbers as a grid, steps across the top. And for each lot, the tools or the statuses on one line." You will shape query results the way a report writer does.

## What you will do

- add subtotals and a grand total with `ROLLUP`
- label subtotal rows with `GROUPING`, and avoid the `NULL` trap
- choose exact levels with `GROUPING SETS`
- turn steps into columns with `PIVOT`
- put lists on one line with `LISTAGG`

## Scripts

| File | What it does |
| --- | --- |
| [`lab10_report_shapes.sql`](scripts/lab10_report_shapes.sql) | Your worksheet: each question is a comment with space below it for your query. Run as `FAB_LAB`. |

Solutions: [lab-10-solutions.md](../solutions/lab-10-solutions.md).

## Before you start

1. Connect to `FAB_LAB` in DBeaver (`fab-lab` connection) and open `lab10_report_shapes.sql` with **File > Open File**.
2. Run one statement at a time with `Ctrl + Enter` (the cursor must be inside the statement, which must end with a semicolon).
3. Auto-commit is fine. Nothing is changed.
4. Every exercise has three hints. Open Hint 1 first and use the next one only when you are stuck. Each exercise ends with a checkpoint: compare your row count and key value before you open the solutions page.

## The exercises

### Exercise 1: Subtotals per family and step

**Maya asks:** "Defects per product family and step, with a subtotal for each family and a grand total at the bottom. Family by family, steps in alphabetical order, the subtotal under its family."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

`ROLLUP` after `GROUP BY` adds subtotals. The first column named is the one that gets the subtotal.

</details>

<details>
<summary>Hint 2</summary>

`GROUP BY ROLLUP (p.family, m.step)`. The `SELECT` has `p.family`, `m.step`, `SUM(m.defect_count)`. Join `measurements`, `wafers`, `lots`, `products`. Order by `p.family, m.step`.

</details>

<details>
<summary>Hint 3</summary>

Rows where `STEP` is blank are family subtotals. The row where both are blank is the grand total.

</details>

**Checkpoint:** 17 rows: 12 detail, 4 family subtotals, 1 grand total. `FD-SOI` subtotal 1753, grand total 3634.

### Exercise 2: Which blank is which?

**Maya asks:** "Count the wafers by grade, with a total line. But the blank cells confuse people: label the two wafers without a grade as 'NO GRADE YET' and the total line as 'ALL WAFERS'. Put the total last."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Run `SELECT grade, COUNT(*) FROM wafers GROUP BY ROLLUP (grade)` first and see the problem: two blank grades. `GROUPING(grade)` returns 1 only on the total line.

</details>

<details>
<summary>Hint 2</summary>

`CASE WHEN GROUPING(grade) = 1 THEN 'ALL WAFERS' WHEN grade IS NULL THEN 'NO GRADE YET' ELSE grade END`. The order of the `WHEN`s matters. Sort with `ORDER BY GROUPING(grade), grade`.

</details>

<details>
<summary>Hint 3</summary>

On the total line `grade` is `NULL` as well. If you test `grade IS NULL` first, the total line gets the wrong label. Test `GROUPING` first.

</details>

**Checkpoint:** 5 rows: `PRIME` 51, `SCRAP` 4, `TEST` 9, `NO GRADE YET` 2, `ALL WAFERS` 66.

### Exercise 3: Totals per family, per step, and overall

**Maya asks:** "I do not need the detail lines this time. Give me only three kinds of line: defects per product family, defects per step, and one grand total. Add a column that says which kind of line it is."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

`GROUPING SETS` lists exactly the groupings you want: `((p.family), (m.step), ())`. `GROUPING_ID` tells the lines apart.

</details>

<details>
<summary>Hint 2</summary>

`GROUP BY GROUPING SETS ((p.family), (m.step), ())`. For the label column use `CASE GROUPING_ID(p.family, m.step) WHEN 1 THEN ... WHEN 2 THEN ... WHEN 3 THEN ... END`.

</details>

<details>
<summary>Hint 3</summary>

`GROUPING_ID` is 1 when only `m.step` was rolled up (a family line), 2 when only `p.family` was (a step line) and 3 when both were (the grand total).

</details>

**Checkpoint:** 8 rows: 4 family lines, 3 step lines, 1 grand total (3634).

### Exercise 4: A grid of lots by step

**Maya asks:** "For the FD-SOI lots, give me one line per lot with the total defects at SPLIT, ANNEAL and FINAL in three columns."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Rows into columns: `PIVOT`. The inner query must carry only the grouping column (the lot), the pivot column (the step) and the value to add up.

</details>

<details>
<summary>Hint 2</summary>

`SELECT * FROM (SELECT l.lot_id, m.step, m.defect_count FROM ... WHERE p.family = 'FD-SOI') PIVOT (SUM(defect_count) FOR step IN ('SPLIT' AS split_defects, ...)) ORDER BY lot_id;`

</details>

<details>
<summary>Hint 3</summary>

If you add `m.wafer_id` or `m.meas_id` to the inner query, `PIVOT` makes one line per wafer or reading, because every spare column becomes a grouping column. Keep the inner query to three columns.

</details>

**Checkpoint:** 8 lots. `L26-001` has 204, 80 and 11.

### Exercise 5: Lists on one line

**Maya asks:** "Part a: for each lot of product FD-SOI that has wafers, list its wafers on one line. Part b: for each lot, the history of its statuses in time order on one line, like ACTIVE > HOLD > ACTIVE. Show lots L26-003B and L26-008 only."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

`LISTAGG(value, separator) WITHIN GROUP (ORDER BY ...)` is an aggregate: use it with `GROUP BY`.

</details>

<details>
<summary>Hint 2</summary>

Part a: `LISTAGG(SUBSTR(w.wafer_id, -2), ', ') WITHIN GROUP (ORDER BY w.wafer_id)` with `GROUP BY w.lot_id`. Part b: `LISTAGG(new_status, ' > ') WITHIN GROUP (ORDER BY changed_at)` on `lot_history`.

</details>

<details>
<summary>Hint 3</summary>

Part a: join `lots` and filter `l.product_id = 1` (FD-SOI). Add `FETCH FIRST 4 ROWS ONLY`. Part b: `WHERE lot_id IN ('L26-003B', 'L26-008')`.

</details>

**Checkpoint:** Part a: 4 lots, `L26-001` has `01, 02, 03, 04, 05`. Part b: `L26-003B` is `ACTIVE > HOLD > ACTIVE > HOLD`, and `L26-008` ends in `SCRAPPED`.

## Finishing

Nothing was changed. If you finish early, try `CUBE (p.family, m.step)` in exercise 1 and compare it with `ROLLUP`: which extra lines appear?
