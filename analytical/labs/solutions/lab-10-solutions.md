# Lab 10: Report shapes solutions

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The outputs below were produced by running each query on the lab data. The same queries are in [`lab10_solutions.sql`](scripts/lab10_solutions.sql).

## Exercise 1: Subtotals per family and step

**Maya asks:** "Defects per product family and step, with a subtotal for each family and a grand total at the bottom. Family by family, steps in alphabetical order, the subtotal under its family."

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

**Why it works / what to notice.** Count: 4 families times 3 steps give 12 detail rows, plus 4 subtotals, plus 1 total. Check one by hand: 511 + 119 + 1123 = 1753. The blank cells are `NULL`s made by `ROLLUP`.

## Exercise 2: Which blank is which?

**Maya asks:** "Count the wafers by grade, with a total line. But the blank cells confuse people: label the two wafers without a grade as 'NO GRADE YET' and the total line as 'ALL WAFERS'. Put the total last."

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

**Why it works / what to notice.** The two blank lines had the same look and different meanings. `GROUPING(grade)` is 1 for the total and 0 for the real `NULL`. Always test `GROUPING` before `IS NULL`.

## Exercise 3: Totals per family, per step, and overall

**Maya asks:** "I do not need the detail lines this time. Give me only three kinds of line: defects per product family, defects per step, and one grand total. Add a column that says which kind of line it is."

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

**Why it works / what to notice.** No detail lines this time, because they are not in the grouping sets. This is the shape `CUBE` would produce minus the detail rows. `GROUPING_ID` doubles as a sort key, which keeps the report in the order family, step, total.

## Exercise 4: A grid of lots by step

**Maya asks:** "For the FD-SOI lots, give me one line per lot with the total defects at SPLIT, ANNEAL and FINAL in three columns."

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

**Why it works / what to notice.** Check one cell against exercise 1: FD-SOI at SPLIT sums to 1123 across the eight lots. The list of steps in `IN (...)` is fixed in advance. You could write the same grid with three `SUM(CASE ...)` columns.

## Exercise 5: Lists on one line

**Maya asks:** "Part a: for each lot of product FD-SOI that has wafers, list its wafers on one line. Part b: for each lot, the history of its statuses in time order on one line, like ACTIVE > HOLD > ACTIVE. Show lots L26-003B and L26-008 only."

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

**Why it works / what to notice.** The `ORDER BY` inside `WITHIN GROUP` controls the order of the list. In part b it is the time order of the changes, so you can read each lot's life from left to right. `L26-008` went on hold three times and was then scrapped.

