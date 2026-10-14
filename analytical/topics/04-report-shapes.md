# Report shapes: subtotals, grids and lists

So far each query returned one flat list. Maya's reports look different. She wants subtotals under each product family and a grand total at the bottom. She wants steps across the top of the page like a timetable. She wants the tools used by a lot on one line. This page covers `ROLLUP`, `CUBE`, `GROUPING SETS`, `PIVOT` and `LISTAGG`, the tools that give a query result the shape of a report.

Watch the animated page first: [Report shapes, animated](../tutorials/04-report-shapes.html).

**By the end of this page you can:**

- add subtotals and a grand total with `GROUP BY ROLLUP`
- produce every combination of subtotals with `CUBE`, or pick exactly the ones you want with `GROUPING SETS`
- tell a subtotal row from a genuine `NULL` with `GROUPING` and `GROUPING_ID`
- turn rows into columns with `PIVOT`, and the same with `CASE`
- put many values into one text cell with `LISTAGG`

## The question this answers

A plain `GROUP BY` gives Maya one line per product and lot type. She wanted more: a total under each product, a total for the whole fab, a grid she can read across, and the lot IDs written out. Without the report clauses she would run one query per level and stitch them together with `UNION ALL`, or paste the result into a spreadsheet. Doing it outside the query makes the numbers hard to check. The report clauses build the totals in the same pass over the data as the detail, so subtotals always agree with the lines above them.

## The analogy: the night manager's room sheet

Dana is the night manager at the Harbour Hotel. After the last check-in she tallies the rooms occupied by floor and room type. Floor 1 has 4 singles and 6 doubles, floor 2 has 3 singles, 5 doubles and 2 suites, floor 3 has 3 suites. Six lines: that is the plain `GROUP BY` result. The owner asks for four versions of the same sheet.

1. Subtotals. "Add a line after each floor and a grand total." Dana works from the right: she rolls the room type up, then the floor. This is `ROLLUP`. Ten lines: six details, three floor subtotals, one grand total of 23.
2. Totals both ways. "Also the total of singles, doubles and suites." That is `CUBE`: every combination. Thirteen lines.
3. A grid. "Floors down the page, types across." Dana must write the column headings first. A penthouse checked in tomorrow has no column until she adds one. Empty combinations get 0. This is `PIVOT`.
4. A list. "Which rooms are suites, one line per floor?" She writes the room numbers in order, separated by commas. This is `LISTAGG`.

| Floor | Type | Rooms |
|---|---|---|
| 1 | Single | 4 |
| 1 | Double | 6 |
| 1 | all types | 10 |
| 2 | Single | 3 |
| 2 | Double | 5 |
| 2 | Suite | 2 |
| 2 | all types | 10 |
| 3 | Suite | 3 |
| 3 | all types | 3 |
| all floors | all types | 23 |

**Where the analogy breaks.**

- Dana writes "all types" in words. Oracle writes NULL in the rolled-up column, and a real room with no type would also show NULL. You need `GROUPING()` to tell them apart.
- Dana adds a penthouse column in ten seconds. A `PIVOT` column list is part of the query text. Values you forget are left out without a warning.
- Dana can carry a long list to a second page. A `LISTAGG` string cannot pass 4000 bytes, and by default Oracle raises `ORA-01489`.

## What Oracle actually does

1. Build the row set with `FROM`, joins and `WHERE`.
2. Group at several levels in one pass. `ROLLUP(a, b)` means the levels (a, b), (a) and (). `CUBE(a, b)` adds (b). Oracle calculates each level and stacks the results.
3. Fill the gaps with NULL. A row from the level (a) has no value for b, so b is NULL. `GROUPING(b)` is 1 on those rows and 0 elsewhere. `GROUPING_ID(a, b)` packs both flags into one number: 0 detail, 1 subtotal, 2 total over a, 3 grand total.
4. `PIVOT` is a rewrite of `GROUP BY`. For each value in the `IN` list Oracle creates one column aggregating only the matching rows. Every inner column not used in the aggregate or the `FOR` clause becomes a grouping column, so the inner query should select only what you want in the rows.
5. `LISTAGG` is an ordinary aggregate for text. Oracle sorts each group by `WITHIN GROUP (ORDER BY ...)`, joins the values with your separator and skips NULLs. Past 4000 bytes it fails with `ORA-01489` unless you write `ON OVERFLOW TRUNCATE`.
6. Rows come back in no promised order, so add an `ORDER BY` if subtotals must sit under their groups.

| In Oracle | At the Harbour Hotel |
|---|---|
| `ROLLUP(a, b)` | floor subtotals and a grand total |
| `CUBE(a, b)` | also the totals by room type |
| NULL in a rolled-up column | "all types" written on the line |
| `GROUPING(col)` | asking "is this a total line?" |
| `PIVOT ... FOR col IN (...)` | the grid, headings written first |
| `LISTAGG` | room numbers on one line |

## The tables you will use

Defects by product family and step, joining `MEASUREMENTS` to `WAFERS`, `LOTS` and `PRODUCTS` as before. The Day 3 add-on is not needed on this page.

## Step 1: ROLLUP, subtotals and a grand total

Maya: "Defects per product family and step, with a subtotal for each family and a grand total."

```sql
SELECT p.family,
       m.step,
       SUM(m.defect_count) AS defects
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY ROLLUP (p.family, m.step)
ORDER  BY p.family, m.step;
```
<!--gen-->
```text
FAMILY               STEP        DEFECTS
-------------------- -------- ----------
FD-SOI               ANNEAL          511
FD-SOI               FINAL           119
FD-SOI               SPLIT          1123
FD-SOI                              1753
Photonics-SOI        ANNEAL          141
Photonics-SOI        FINAL            27
Photonics-SOI        SPLIT           389
Photonics-SOI                        557
Power-SOI            ANNEAL          137
Power-SOI            FINAL            94
Power-SOI            SPLIT           340
Power-SOI                            571
RF-SOI               ANNEAL          226
RF-SOI               FINAL            43
RF-SOI               SPLIT           484
RF-SOI                               753
                                    3634
```

Count what came out: four families times three steps are 12 detail rows, plus four family subtotals (the rows where `STEP` is blank), plus one grand total (both blank). Seventeen rows from one query, with the order of the columns deciding the levels. `ROLLUP (family, step)` gives: (family, step), then (family), then () for the whole. It rolls up from the right.

Check one by hand: 511 + 119 + 1123 = 1753 for `FD-SOI`. The grand total, 3634, is the same number you get from `SELECT SUM(defect_count) FROM measurements`.

The order of the columns matters. `ROLLUP (step, family)` would give subtotals per step instead.

## Step 2: the NULL problem, and GROUPING

In step 1 the subtotal rows show a blank where the family or step should be. That blank is a `NULL`. It is also what a real missing value looks like. Here is a case where both occur: wafers have a grade, and two wafers have none yet.

```sql
SELECT grade, COUNT(*) AS wafers
FROM   wafers
GROUP  BY ROLLUP (grade)
ORDER  BY grade;
```
<!--gen-->
```text
GRADE      WAFERS
------ ----------
PRIME          51
SCRAP           4
TEST            9
                2
               66
```

Two rows with a blank grade: 2 wafers with no grade, and 66 for everything. You cannot tell which is which by looking. `GROUPING(column)` returns 1 on a row where that column was rolled up (a subtotal row) and 0 on a normal row.

```sql
SELECT grade,
       COUNT(*)        AS wafers,
       GROUPING(grade) AS is_total
FROM   wafers
GROUP  BY ROLLUP (grade)
ORDER  BY GROUPING(grade), grade;
```
<!--gen-->
```text
GRADE      WAFERS   IS_TOTAL
------ ---------- ----------
PRIME          51          0
SCRAP           4          0
TEST            9          0
                2          0
               66          1
```

Now the row with a real `NULL` grade has `is_total = 0` and the total row has 1. Use it to print labels in the report. Maya: "Put 'ALL STEPS' and 'ALL FAMILIES' in the blank cells."

```sql
SELECT CASE GROUPING(p.family) WHEN 1 THEN 'ALL FAMILIES' ELSE p.family END AS family,
       CASE GROUPING(m.step)   WHEN 1 THEN 'ALL STEPS'    ELSE m.step   END AS step,
       SUM(m.defect_count) AS defects
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY ROLLUP (p.family, m.step)
ORDER  BY GROUPING(p.family), p.family, GROUPING(m.step), m.step;
```
<!--gen-->
```text
FAMILY               STEP         DEFECTS
-------------------- --------- ----------
FD-SOI               ANNEAL           511
FD-SOI               FINAL            119
FD-SOI               SPLIT           1123
FD-SOI               ALL STEPS       1753
Photonics-SOI        ANNEAL           141
Photonics-SOI        FINAL             27
Photonics-SOI        SPLIT            389
Photonics-SOI        ALL STEPS        557
Power-SOI            ANNEAL           137
Power-SOI            FINAL             94
Power-SOI            SPLIT            340
Power-SOI            ALL STEPS        571
RF-SOI               ANNEAL           226
RF-SOI               FINAL             43
RF-SOI               SPLIT            484
RF-SOI               ALL STEPS        753
ALL FAMILIES         ALL STEPS       3634
```

The `ORDER BY` uses `GROUPING` too. Without it, sorting by the label would put `ALL STEPS` among the real step names. Sorting by `GROUPING(m.step)` second puts each subtotal at the end of its family, like the receipt.

### GROUPING_ID: one number per level

With several columns, `GROUPING_ID(a, b)` combines the `GROUPING` bits into one number: 0 for a detail row, 1 when only `b` was rolled up, 2 when only `a` was, 3 when both were. It is handy for sorting and for filtering a level in an outer query.

```sql
SELECT p.family,
       m.step,
       SUM(m.defect_count)             AS defects,
       GROUPING_ID(p.family, m.step)   AS level_id
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY ROLLUP (p.family, m.step)
HAVING GROUPING_ID(p.family, m.step) IN (1, 3)
ORDER  BY level_id, p.family;
```
<!--gen-->
```text
FAMILY               STEP        DEFECTS   LEVEL_ID
-------------------- -------- ---------- ----------
FD-SOI                              1753          1
Photonics-SOI                        557          1
Power-SOI                            571          1
RF-SOI                               753          1
                                    3634          3
```

`HAVING` can keep only the subtotal levels you want, here the family subtotals and the grand total, so the report has five lines.

## Step 3: CUBE, every combination

`ROLLUP` goes one way. `CUBE (family, step)` gives totals for every combination: each family and step together, each family alone, each step alone, and the grand total. Maya: "I also want the total per step across all families."

```sql
SELECT p.family,
       m.step,
       SUM(m.defect_count)           AS defects,
       GROUPING_ID(p.family, m.step) AS level_id
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY CUBE (p.family, m.step)
ORDER  BY level_id, p.family, m.step;
```
<!--gen-->
```text
FAMILY               STEP        DEFECTS   LEVEL_ID
-------------------- -------- ---------- ----------
FD-SOI               ANNEAL          511          0
FD-SOI               FINAL           119          0
FD-SOI               SPLIT          1123          0
Photonics-SOI        ANNEAL          141          0
Photonics-SOI        FINAL            27          0
Photonics-SOI        SPLIT           389          0
Power-SOI            ANNEAL          137          0
Power-SOI            FINAL            94          0
Power-SOI            SPLIT           340          0
RF-SOI               ANNEAL          226          0
RF-SOI               FINAL            43          0
RF-SOI               SPLIT           484          0
FD-SOI                              1753          1
Photonics-SOI                        557          1
Power-SOI                            571          1
RF-SOI                               753          1
                     ANNEAL         1015          2
                     FINAL           283          2
                     SPLIT          2336          2
                                    3634          3
```

That is 12 detail rows (`level_id` 0), 4 family subtotals (1), 3 step totals (2) and the grand total (3): 20 rows. `CUBE` over `n` columns makes `2^n` kinds of lines, so it grows quickly with more columns.

## Step 4: GROUPING SETS, exactly the ones you ask for

If you want the family totals and the step totals and the grand total, but not the 12 detail rows, name the sets yourself.

```sql
SELECT p.family,
       m.step,
       SUM(m.defect_count)           AS defects,
       GROUPING_ID(p.family, m.step) AS level_id
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY GROUPING SETS ((p.family), (m.step), ())
ORDER  BY level_id, p.family, m.step;
```
<!--gen-->
```text
FAMILY               STEP        DEFECTS   LEVEL_ID
-------------------- -------- ---------- ----------
FD-SOI                              1753          1
Photonics-SOI                        557          1
Power-SOI                            571          1
RF-SOI                               753          1
                     ANNEAL         1015          2
                     FINAL           283          2
                     SPLIT          2336          2
                                    3634          3
```

Each pair of brackets is one `GROUP BY` of its own, and the empty brackets `()` mean the grand total. The result is the same as writing three queries with `UNION ALL`, but Oracle reads the data once. `ROLLUP (a, b)` is shorthand for `GROUPING SETS ((a, b), (a), ())`, and `CUBE (a, b)` for `((a, b), (a), (b), ())`.

## Step 5: PIVOT, rows into columns

Back to the timetable. Maya: "A grid please: one row per product family, one column per step, with the defect totals."

```sql
SELECT *
FROM  (SELECT p.family, m.step, m.defect_count
       FROM   measurements m
       JOIN   wafers   w ON w.wafer_id   = m.wafer_id
       JOIN   lots     l ON l.lot_id     = w.lot_id
       JOIN   products p ON p.product_id = l.product_id)
PIVOT (SUM(defect_count) AS defects
       FOR step IN ('SPLIT' AS split, 'ANNEAL' AS anneal, 'FINAL' AS final))
ORDER  BY family;
```
<!--gen-->
```text
FAMILY               SPLIT_DEFECTS ANNEAL_DEFECTS FINAL_DEFECTS
-------------------- ------------- -------------- -------------
FD-SOI                        1123            511           119
Photonics-SOI                  389            141            27
Power-SOI                      340            137            94
RF-SOI                         484            226            43
```

The numbers match step 1. `PIVOT` has three parts: the aggregate to calculate (`SUM(defect_count)`), the column whose values become headings (`FOR step`), and the list of those values (`IN (...)`). The names after `AS` become part of the column headings, so you get `SPLIT_DEFECTS` and so on.

Three things to know:

- The list in `IN (...)` is fixed. A step that is not in the list is silently left out of the grid.
- Every column of the inner query that is not used by the aggregate or the `FOR` column becomes a grouping column. That is why the inner query above carries only `family`, `step` and `defect_count`. If you also selected `wafer_id`, you would get one row per wafer and family.
- The aggregate must stand alone. `ROUND(AVG(x))` inside the `PIVOT` fails with `ORA-56902`. Do the rounding outside.

```sql
SELECT lot_id,
       ROUND(split, 1)  AS split_nm,
       ROUND(anneal, 1) AS anneal_nm,
       ROUND(final, 1)  AS final_nm
FROM  (SELECT w.lot_id, m.step, m.thickness_nm
       FROM   measurements m
       JOIN   wafers w ON w.wafer_id = m.wafer_id
       WHERE  w.lot_id IN ('L26-001', 'L26-002', 'L26-006'))
PIVOT (AVG(thickness_nm) FOR step IN ('SPLIT' AS split, 'ANNEAL' AS anneal, 'FINAL' AS final))
ORDER  BY lot_id;
```
<!--gen-->
```text
LOT_ID         SPLIT_NM  ANNEAL_NM   FINAL_NM
------------ ---------- ---------- ----------
L26-001            15.4       13.3         12
L26-002            97.1       82.5       74.9
L26-006            98.2         82       74.5
```

Each lot's wafers thin down from SPLIT to FINAL.

### The same grid with CASE

`PIVOT` is shorthand. The older way, which works everywhere and allows more freedom, is one `SUM(CASE ...)` per column:

```sql
SELECT p.family,
       SUM(CASE WHEN m.step = 'SPLIT'  THEN m.defect_count END) AS split_defects,
       SUM(CASE WHEN m.step = 'ANNEAL' THEN m.defect_count END) AS anneal_defects,
       SUM(CASE WHEN m.step = 'FINAL'  THEN m.defect_count END) AS final_defects
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY p.family
ORDER  BY p.family;
```
<!--gen-->
```text
FAMILY               SPLIT_DEFECTS ANNEAL_DEFECTS FINAL_DEFECTS
-------------------- ------------- -------------- -------------
FD-SOI                        1123            511           119
Photonics-SOI                  389            141            27
Power-SOI                      340            137            94
RF-SOI                         484            226            43
```

Same numbers, no special syntax. If a family had no reading at some step, the cell would be `NULL`, as it is with `PIVOT`.

## Step 6: LISTAGG, many rows in one cell

Maya: "For lots L26-001 and L26-003B1, list the wafers on one line."

```sql
SELECT lot_id,
       COUNT(*) AS wafers,
       LISTAGG(wafer_id, ', ') WITHIN GROUP (ORDER BY wafer_id) AS wafer_list
FROM   wafers
WHERE  lot_id IN ('L26-001', 'L26-003B1')
GROUP  BY lot_id
ORDER  BY lot_id;
```
<!--gen-->
```text
LOT_ID           WAFERS WAFER_LIST
------------ ---------- ------------------------------------------------------------
L26-001               5 L26-001-01, L26-001-02, L26-001-03, L26-001-04, L26-001-05
L26-003B1             2 L26-003B1-01, L26-003B1-02
```

`LISTAGG(value, separator) WITHIN GROUP (ORDER BY ...)` glues the values of each group into one string. The `ORDER BY` inside decides the order in the string. It is an aggregate, so it needs a `GROUP BY` as any other aggregate does.

Maya: "Which tools touched lot L26-001?" A tool measures several wafers, so it appears many times. `DISTINCT` inside `LISTAGG` keeps each tool once. (This works from Oracle 19c. Older versions need an inline view with `SELECT DISTINCT` first.)

```sql
SELECT w.lot_id,
       LISTAGG(DISTINCT m.tool_id, ', ') WITHIN GROUP (ORDER BY m.tool_id) AS tools_used
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id = 'L26-001'
GROUP  BY w.lot_id;
```
<!--gen-->
```text
LOT_ID  TOOLS_USED
------- ------------------------------------------------------------
L26-001 ANL01, ANL02, MET01, MET02, MET03, SPL01, SPL02
```

Two limits to remember. `LISTAGG` returns a `VARCHAR2`, so a very long list fails with `ORA-01489: result of string concatenation is too long` (4000 bytes by default). And `NULL` values are skipped, they do not add a separator.

## Three common misreadings

**"A NULL in a ROLLUP result means the data is missing."** It usually means "all values". A NULL in `lot_type` next to FD-300 is the FD-300 subtotal. If `lot_type` could also be genuinely NULL, the two look identical, so use `GROUPING(lot_type)`: 1 means rolled up. For printing, `CASE WHEN GROUPING(...) = 1 THEN 'all types' ELSE ... END` is the usual pattern.

**"ROLLUP(a, b) and ROLLUP(b, a) give the same report."** `ROLLUP` works from the right. `ROLLUP(lot_type, product_code)` gives a subtotal per lot type (PROD 57, REWORK 2, SPLIT 7) and 10 rows, instead of four product subtotals and 11 rows. Put the column you want subtotals for on the left. For both directions use `CUBE`.

**"PIVOT works out which rows and columns I want."** The columns are exactly the values in your `IN` list, and the rows are every other column of the inner query. Add `l.lot_id` to the inner `SELECT` and the pivot returns 16 rows, one per lot, instead of 4, one per product.

## Common mistakes

- Reading a blank cell in a `ROLLUP` result as "unknown". It may be a subtotal. Use `GROUPING` or `GROUPING_ID`.
- Putting the `ROLLUP` columns in the wrong order and getting subtotals for the wrong thing.
- Using `CUBE` with five or six columns. The number of lines doubles with each column.
- Sorting a labelled report by the label text. Sort by `GROUPING` first, so subtotals land after their rows.
- Leaving a spare column in the inner query of a `PIVOT`, which becomes an extra grouping column.
- Expecting a step that is missing from the `IN (...)` list of a `PIVOT` to show up. It will not.
- Using `LISTAGG` on a very long list without thinking about the 4000 byte limit.

## Check your understanding

1. `GROUP BY ROLLUP (a, b)` returns which levels of totals?
2. A `ROLLUP` result has two blank cells in column `grade`. How do you tell the subtotal from the real `NULL`?
3. What is the difference between `CUBE (a, b)` and `GROUPING SETS ((a), (b), ())`?
4. Why does `PIVOT (ROUND(AVG(x)) FOR ...)` fail?

<details>
<summary>Answers</summary>

1. `(a, b)`, then `(a)`, then `()`, the grand total. Not `(b)` alone.
2. `GROUPING(grade)` is 1 on the subtotal row and 0 on the row with a real `NULL`.
3. `CUBE (a, b)` also returns the detail level `(a, b)`. The `GROUPING SETS` version returns only the three levels you named.
4. The `PIVOT` clause needs a plain aggregate function. Calculate the pivot and apply `ROUND` to the result columns in the outer query.

</details>

## Further reading

- [Oracle Database 19c SQL Language Reference: SELECT, the GROUP BY clause](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
- [Oracle Database 19c SQL Language Reference: LISTAGG](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LISTAGG.html)
- [ORACLE-BASE: GROUP BY ROLLUP, CUBE and GROUPING SETS](https://oracle-base.com/articles/misc/rollup-cube-grouping-functions-and-grouping-sets)
- [ORACLE-BASE: PIVOT and UNPIVOT](https://oracle-base.com/articles/11g/pivot-and-unpivot-operators-11gr1)
