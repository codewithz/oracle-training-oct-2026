# Lab 10: Report shapes solutions

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The same queries are in [`lab10_solutions.sql`](scripts/lab10_solutions.sql).

Each exercise has the same four parts: the problem in plain words, the query, how the query builds the answer (taken apart in the order Oracle runs it: `FROM` and joins, `WHERE`, `GROUP BY`, `SELECT`, `ORDER BY`), and the output with what to notice.

All outputs and the in-between rows in the breakdowns were produced by running the queries, and parts of them, on the lab data (Oracle 21c XE; 19c gives the same rows).

The idea behind this lab: a normal `GROUP BY` makes one level of totals. `ROLLUP`, `CUBE` and `GROUPING SETS` make several levels in one query, and Oracle stacks them into one result. `PIVOT` and `LISTAGG` then turn rows sideways, into columns or into one line of text.

## Exercise 1: Subtotals per family and step

**Maya asks:** "Defects per product family and step, with a subtotal for each family and a grand total at the bottom. Family by family, steps in alphabetical order, the subtotal under its family."

### The problem in plain words

The report has three kinds of line. Detail lines: one per family and step, with the defects for that pair. Subtotal lines: one per family, adding up its three steps. One grand total line: all defects. The lines are sorted so each family's steps come first and its subtotal sits right under them, with the grand total at the very end.

The family is in `PRODUCTS`, so readings are joined through `WAFERS` and `LOTS` to reach it. There is no `WHERE`: all readings count.

### The query

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

### How the query builds the answer

**Step 1. FROM and JOINs.** All 186 readings, each tagged with its family.

**Step 2. GROUP BY ROLLUP (p.family, m.step).** `ROLLUP` runs three groupings and stacks the results. It works from the right, dropping one column at a time:

- `GROUP BY p.family, m.step`: the 12 detail lines (4 families × 3 steps).
- `GROUP BY p.family`: 4 subtotal lines. There is no single step on these lines, so `STEP` is `NULL`.
- `GROUP BY ()`, meaning no grouping at all: 1 grand total line, with both `FAMILY` and `STEP` set to `NULL`.

**Step 3. SELECT.** `SUM(m.defect_count)` is worked out for each line at its own level.

**Step 4. ORDER BY p.family, m.step.** Oracle sorts `NULL` last in ascending order. So inside a family the subtotal (step `NULL`) falls after the three steps, and the grand total (family `NULL`) falls after every family.

### Output

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

### What to notice

Count the lines: 12 detail + 4 subtotals + 1 total = 17. Check one by hand: 511 + 119 + 1123 = 1753. The blank cells are `NULL`s made by `ROLLUP`, not missing data. The order of columns inside `ROLLUP (...)` matters: `ROLLUP (m.step, p.family)` would give subtotals per step instead.

## Exercise 2: Which blank is which?

**Maya asks:** "Count the wafers by grade, with a total line. But the blank cells confuse people: label the two wafers without a grade as 'NO GRADE YET' and the total line as 'ALL WAFERS'. Put the total last."

### The problem in plain words

One line per wafer grade with the number of wafers, plus a total line. The catch: two wafers have no grade yet (`grade` is `NULL`), and the total line made by `ROLLUP` also shows `NULL` in the grade column. Both lines look blank but mean different things. Maya wants each labelled with words, and the total at the bottom.

Only `WAFERS` is needed.

### The query

```sql
SELECT CASE
         WHEN GROUPING(grade) = 1 THEN 'ALL WAFERS'
         WHEN grade IS NULL       THEN 'NO GRADE YET'
         ELSE grade
       END AS grade_label,
       COUNT(*) AS wafers
FROM   wafers
GROUP  BY ROLLUP (grade)
ORDER  BY GROUPING(grade), grade;
```

### How the query builds the answer

**Step 1. FROM.** All 66 wafers.

**Step 2. GROUP BY ROLLUP (grade).** One line per grade value, including one for the `NULL` grade, plus a grand total. Before labelling, with `GROUPING(grade)` shown as its own column, it looks like this:

```text
GRADE      WAFERS GROUPING(GRADE)
------ ---------- ---------------
PRIME          51               0
SCRAP           4               0
TEST            9               0
                2               0
               66               1
```

Both of the last two lines have a blank grade. `GROUPING(grade)` tells them apart: it is 1 only on a line that `ROLLUP` made by adding grades together, and 0 on a line where the grade is a real value, even a real `NULL`.

**Step 3. SELECT with CASE.** `CASE` checks its conditions top to bottom and stops at the first true one. The total line is caught by `GROUPING(grade) = 1` first. Only then does `grade IS NULL` catch the two ungraded wafers.

**Step 4. ORDER BY GROUPING(grade), grade.** Sorting by `GROUPING` first puts all the 0 lines before the 1 line, so the total goes last.

### Output

<!--gen-->
```text
GRADE_LABEL      WAFERS
------------ ----------
PRIME                51
SCRAP                 4
TEST                  9
NO GRADE YET          2
ALL WAFERS           66
```

### What to notice

Always test `GROUPING` before `IS NULL`. If the two `WHEN` lines were swapped, the total line would also match `grade IS NULL` and be labelled 'NO GRADE YET'.

## Exercise 3: Totals per family, per step, and overall

**Maya asks:** "I do not need the detail lines this time. Give me only three kinds of line: defects per product family, defects per step, and one grand total. Add a column that says which kind of line it is."

### The problem in plain words

Three kinds of line and no detail: 4 lines with each family's total over all steps, 3 lines with each step's total over all families, and 1 grand total. A fourth column names the kind of line in words. `ROLLUP` cannot do this, because it would include the detail lines and never makes per-step totals. `GROUPING SETS` lets us list exactly the groupings we want.

### The query

```sql
SELECT p.family,
       m.step,
       SUM(m.defect_count) AS defects,
       CASE GROUPING_ID(p.family, m.step)
         WHEN 1 THEN 'family total'
         WHEN 2 THEN 'step total'
         WHEN 3 THEN 'grand total'
       END AS line_type
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY GROUPING SETS ((p.family), (m.step), ())
ORDER  BY GROUPING_ID(p.family, m.step), p.family, m.step;
```

### How the query builds the answer

**Step 1. FROM and JOINs.** All 186 readings with their family.

**Step 2. GROUP BY GROUPING SETS ((p.family), (m.step), ()).** Three separate groupings, stacked: by family (4 lines), by step (3 lines), and by nothing (1 line). Nothing else.

**Step 3. GROUPING_ID(p.family, m.step).** This builds a number from two `GROUPING` flags, read like a two-digit binary number: the family flag is worth 2, the step flag is worth 1. A flag is 1 when that column was added up on this line.

```text
LINE                 FAMILY FLAG  STEP FLAG  GROUPING_ID
-------------------- ----------- ---------- ------------
family total                   0          1            1
step total                     1          0            2
grand total                    1          1            3
```

(A detail line would be 0, but there are none here.)

**Step 4. SELECT with CASE.** The number is turned into a label.

**Step 5. ORDER BY GROUPING_ID(...), p.family, m.step.** Family totals (1) first, then step totals (2), then the grand total (3).

### Output

<!--gen-->
```text
FAMILY               STEP        DEFECTS LINE_TYPE
-------------------- -------- ---------- ------------
FD-SOI                              1753 family total
Photonics-SOI                        557 family total
Power-SOI                            571 family total
RF-SOI                               753 family total
                     ANNEAL         1015 step total
                     FINAL           283 step total
                     SPLIT          2336 step total
                                    3634 grand total
```

### What to notice

`CUBE (p.family, m.step)` would give these same 8 lines plus the 12 detail lines. `GROUPING SETS` is the way to ask for exactly the lines you want. Both the family totals and the step totals add up to 3634, which is a good check.

## Exercise 4: A grid of lots by step

**Maya asks:** "For the FD-SOI lots, give me one line per lot with the total defects at SPLIT, ANNEAL and FINAL in three columns."

### The problem in plain words

The answer is a grid. Each row is one lot of the FD-SOI family. There are three number columns, one per step, holding the lot's total defects at that step. In the data the step is a value in a column (`step` = 'SPLIT' and so on); in the answer it becomes a column heading. That turn is what `PIVOT` does.

### The query

```sql
SELECT *
FROM  (SELECT l.lot_id, m.step, m.defect_count
       FROM   measurements m
       JOIN   wafers   w ON w.wafer_id   = m.wafer_id
       JOIN   lots     l ON l.lot_id     = w.lot_id
       JOIN   products p ON p.product_id = l.product_id
       WHERE  p.family = 'FD-SOI')
PIVOT (SUM(defect_count)
       FOR step IN ('SPLIT' AS split_defects, 'ANNEAL' AS anneal_defects, 'FINAL' AS final_defects))
ORDER  BY lot_id;
```

### How the query builds the answer

**Step 1. Inner query.** Joins and filters down to the 87 FD-SOI readings, keeping only three columns: lot, step and defect count. For lot L26-001 that is 15 rows:

```text
LOT_ID       WAFER_ID         STEP     DEFECT_COUNT
------------ ---------------- -------- ------------
L26-001      L26-001-01       SPLIT              42
L26-001      L26-001-02       SPLIT              37
L26-001      L26-001-03       SPLIT              44
L26-001      L26-001-04       SPLIT              48
L26-001      L26-001-05       SPLIT              33
L26-001      L26-001-01       ANNEAL             23
...
L26-001      L26-001-05       FINAL               1
```

(The wafer is shown here to tell the rows apart; the real inner query leaves it out on purpose. Any column left in would become an extra grouping column and split the grid into one row per wafer.)

**Step 2. PIVOT.** `PIVOT` groups by every column that is not named in it, which here is only `lot_id`. For each lot, `FOR step IN (...)` makes one output column per listed step, and `SUM(defect_count)` adds up the matching rows into that cell. For L26-001 at SPLIT: 42 + 37 + 44 + 48 + 33 = 204.

**Step 3. SELECT * and ORDER BY.** `*` returns the lot plus the three new columns, named by the `AS` aliases, sorted by lot.

### Output

<!--gen-->
```text
LOT_ID       SPLIT_DEFECTS ANNEAL_DEFECTS FINAL_DEFECTS
------------ ------------- -------------- -------------
L26-001                204             80            11
L26-003                159            108            15
L26-003A               125             45             2
L26-003B                52             35            35
L26-003B1               88             26             9
L26-007                193             89            20
L26-007A                79             33             1
L26-011                223             95            26
```

### What to notice

Check against exercise 1: the SPLIT column adds up to 1123, the FD-SOI SPLIT detail line there. The list of steps in `IN (...)` must be written out in advance; `PIVOT` cannot discover new values by itself. You could write the same grid with `GROUP BY lot_id` and three `SUM(CASE WHEN step = 'SPLIT' THEN defect_count END)` columns, which some people find easier to read.

## Exercise 5: Lists on one line

**Maya asks:** "Part a: for each lot of product FD-SOI that has wafers, list its wafers on one line. Part b: for each lot, the history of its statuses in time order on one line, like ACTIVE > HOLD > ACTIVE. Show lots L26-003B and L26-008 only."

### The problem in plain words

Part a: one row per lot of the FD-SOI product (product ID 1, code FD-300, the only product in the FD-SOI family) that has wafers. Each row shows how many wafers the lot has and their slot numbers joined into one piece of text, like "01, 02, 03".

Part b: one row per lot for the two lots named. Each row shows the lot's statuses from `LOT_HISTORY`, oldest first, joined with " > " so you can read the lot's life from left to right.

Both parts collapse many rows into one line per lot, so both use `GROUP BY` with `LISTAGG`.

### The queries

```sql
-- Part a (first four FD-SOI lots shown)
SELECT w.lot_id,
       COUNT(*) AS wafers,
       LISTAGG(SUBSTR(w.wafer_id, -2), ', ') WITHIN GROUP (ORDER BY w.wafer_id) AS slots
FROM   wafers w
JOIN   lots l ON l.lot_id = w.lot_id
WHERE  l.product_id = 1
GROUP  BY w.lot_id
ORDER  BY w.lot_id
FETCH FIRST 4 ROWS ONLY;
```
<!--gen-->
```text
LOT_ID           WAFERS
------------ ----------
SLOTS
----------------------------------------------------------------------------------------------------------------------------------------------------------------
L26-001               5
01, 02, 03, 04, 05

L26-003               5
01, 02, 03, 04, 05

L26-003A              3
01, 02, 03

L26-003B              2
01, 02
```

```sql
-- Part b
SELECT lot_id,
       LISTAGG(new_status, ' > ') WITHIN GROUP (ORDER BY changed_at) AS status_path
FROM   lot_history
WHERE  lot_id IN ('L26-003B', 'L26-008')
GROUP  BY lot_id
ORDER  BY lot_id;
```

### How the queries build the answer

**Part a, step 1. FROM, JOIN and WHERE.** Wafers joined to lots, kept only for product 1. That covers 8 lots.

**Part a, step 2. GROUP BY w.lot_id.** The wafers of each lot form one group. For L26-003B the group is two rows:

```text
LOT_ID       WAFER_ID         SUBSTR(WAFER_ID,-2)
------------ ---------------- -------------------
L26-003B     L26-003B-01      01
L26-003B     L26-003B-02      02
```

**Part a, step 3. SELECT with COUNT and LISTAGG.** `SUBSTR(w.wafer_id, -2)` takes the last two characters, the slot number. `LISTAGG(..., ', ')` glues the group's values into one string with ", " between them. `WITHIN GROUP (ORDER BY w.wafer_id)` decides the order inside the string. L26-003B becomes "01, 02".

**Part a, step 4. ORDER BY and FETCH FIRST 4 ROWS ONLY.** Sorted by lot and cut to four lots to keep the output short.

**Part b, step 1. FROM and WHERE.** Only the history rows of the two named lots. For L26-003B:

```text
LOT_ID       CHANGED_AT       NEW_STAT
------------ ---------------- --------
L26-003B     2026-08-14 10:05 ACTIVE
L26-003B     2026-08-16 08:05 HOLD
L26-003B     2026-08-17 05:05 ACTIVE
L26-003B     2026-08-19 08:05 HOLD
```

**Part b, step 2. GROUP BY lot_id and LISTAGG.** The four rows become one string, in `changed_at` order, joined with " > ".

### Output of part b

<!--gen-->
```text
LOT_ID
------------
STATUS_PATH
----------------------------------------------------------------------------------------------------------------------------------------------------------------
L26-003B
ACTIVE > HOLD > ACTIVE > HOLD

L26-008
ACTIVE > HOLD > ACTIVE > HOLD > ACTIVE > HOLD > SCRAPPED
```

### What to notice

The `ORDER BY` inside `WITHIN GROUP` controls the order inside the list, and it is separate from the query's own `ORDER BY`, which sorts the rows. Without it the list order is not guaranteed. L26-003B ends on HOLD, which matches the open hold found in Lab 9. L26-008 went on hold three times and was then scrapped. (The two-line layout of the output is just SQL*Plus wrapping a long column; DBeaver shows each lot on one line.)
