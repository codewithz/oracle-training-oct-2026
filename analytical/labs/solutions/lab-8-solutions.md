# Lab 8: Window functions and ranking solutions

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The same queries are in [`lab8_solutions.sql`](scripts/lab8_solutions.sql).

Each exercise is laid out the same way:

1. **The problem.** Maya's request, then the same request in plain words: which tables, what one row of the answer means, and what the result should look like.
2. **The query.**
3. **How the query builds the answer.** The query taken apart in the order Oracle runs it, not the order you type it. Oracle starts with `FROM` and the joins, then `WHERE`, then `GROUP BY`, then the window functions, then `SELECT`, and finishes with `ORDER BY` and `FETCH FIRST`.
4. **The output and what to notice.**

All outputs and all the in-between rows shown in the breakdowns were produced by running the queries, and parts of them, on the lab data. They were run on Oracle 21c XE; Oracle 19c gives the same rows.

## Exercise 1: Lot average next to each reading

**Maya asks:** "Lot L26-005 is on hold. Show each of its FINAL readings with the average FINAL thickness of the lot next to it, and how far each wafer is from that average (two decimals)."

### The problem in plain words

We look at one lot, L26-005, and only at its FINAL step readings. Each wafer in that lot has one FINAL reading, so the answer has one row per wafer. On every row Maya wants three numbers: the wafer's own thickness, the average thickness of all FINAL readings in this lot, and the difference between the two. A positive difference means the wafer is thicker than the lot average, a negative one means thinner.

The readings are in `MEASUREMENTS`, but that table does not know which lot a wafer belongs to. `WAFERS` does, so we join the two on `wafer_id`.

The key point: Maya wants every wafer listed and also an average. `GROUP BY` would collapse the four readings into one row. A window function keeps all four rows and adds the average to each.

### The query

```sql
SELECT m.wafer_id,
       m.thickness_nm,
       ROUND(AVG(m.thickness_nm) OVER (), 2)                  AS avg_lot,
       ROUND(m.thickness_nm - AVG(m.thickness_nm) OVER (), 2) AS diff
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id = 'L26-005'
AND    m.step = 'FINAL'
ORDER  BY m.wafer_id;
```

### How the query builds the answer

**Step 1. FROM and JOIN.** Every reading in `MEASUREMENTS` (186 rows) is paired with its wafer row, so each reading now carries a `lot_id`.

**Step 2. WHERE.** Only readings from lot L26-005 at step FINAL are kept. L26-005 has 12 readings (4 wafers, each measured at SPLIT, ANNEAL and FINAL), and the step filter keeps 4 of them:

```text
WAFER_ID         THICKNESS_NM
---------------- ------------
L26-005-01             221.07
L26-005-02             219.76
L26-005-03             216.63
L26-005-04             215.62
```

**Step 3. The window `AVG(m.thickness_nm) OVER ()`.** The empty brackets mean "the window is every row that is left". There are 4 rows left, so the average is (221.07 + 219.76 + 216.63 + 215.62) / 4 = 218.27, and that number is written onto each of the four rows. Because the window runs after `WHERE`, it never sees other lots or other steps.

**Step 4. SELECT.** `avg_lot` is that average rounded to two decimals. `diff` subtracts the same average from each row's own thickness, for example 221.07 - 218.27 = 2.8.

**Step 5. ORDER BY.** The rows are sorted by wafer ID.

### Output

<!--gen-->
```text
WAFER_ID         THICKNESS_NM    AVG_LOT       DIFF
---------------- ------------ ---------- ----------
L26-005-01             221.07     218.27        2.8
L26-005-02             219.76     218.27       1.49
L26-005-03             216.63     218.27      -1.64
L26-005-04             215.62     218.27      -2.65
```

### What to notice

The four differences add up to about zero (2.8 + 1.49 - 1.64 - 2.65 = 0). That is a quick check for any difference-from-average column. If you get a different average, check that your `WHERE` keeps only FINAL readings: without the step filter the window would average 12 readings across three steps.

## Exercise 2: Compare with the product average

**Maya asks:** "Show every FINAL reading with its product code, the average FINAL thickness of that product, and the difference. I only want the three readings that are furthest from their product average, in either direction."

### The problem in plain words

This is exercise 1 widened to the whole fab, with one twist. Different products have very different thicknesses (FD-300 wafers are about 12 nm, PWR-200 wafers about 1,500 nm), so comparing a wafer with the average of all wafers would be meaningless. Each reading must be compared with the average of its own product.

To get from a reading to its product we need a chain of joins: `MEASUREMENTS` to `WAFERS` (which lot), `WAFERS` to `LOTS` (which product), `LOTS` to `PRODUCTS` (the product code).

One row of the answer is one FINAL reading with its product code, its product's average and the difference. "Furthest in either direction" means we sort by the size of the difference and ignore its sign, then keep the top three.

### The query

```sql
SELECT p.product_code,
       m.wafer_id,
       m.thickness_nm,
       ROUND(AVG(m.thickness_nm) OVER (PARTITION BY p.product_code), 2) AS avg_product,
       ROUND(m.thickness_nm - AVG(m.thickness_nm) OVER (PARTITION BY p.product_code), 2) AS diff
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
ORDER  BY ABS(m.thickness_nm - AVG(m.thickness_nm) OVER (PARTITION BY p.product_code)) DESC
FETCH FIRST 3 ROWS ONLY;
```

### How the query builds the answer

**Step 1. FROM and the three JOINs.** Each reading picks up its lot, then its product, then the product code.

**Step 2. WHERE.** Only FINAL readings stay: 62 rows, spread over four products.

**Step 3. The window `AVG(...) OVER (PARTITION BY p.product_code)`.** `PARTITION BY` splits the 62 rows into one group per product, and the average is worked out inside each group separately. Every row gets the average of its own group. These are the four groups the window builds:

```text
PRODUCT_CODE   ROWS   AVG_PRODUCT
------------ ------ -------------
FD-300           29         12.03
PHO-300           9        219.11
PWR-200           9       1528.04
RF-300           15         74.83
```

**Step 4. SELECT.** `diff` is each reading's thickness minus its own product's average.

**Step 5. ORDER BY.** `ABS(...)` turns -46.55 into 46.55, so big differences in both directions sort to the top. The sort can use the window function directly because windows are calculated before `ORDER BY`. The first five rows after sorting:

```text
PRODUCT_CODE WAFER_ID         THICKNESS_NM AVG_PRODUCT       DIFF   ABS_DIFF
------------ ---------------- ------------ ----------- ---------- ----------
PWR-200      L26-008-04             1582.6     1528.04      54.56      54.56
PWR-200      L26-008-02            1580.16     1528.04      52.12      52.12
PWR-200      L26-004-03            1481.49     1528.04     -46.55      46.55
PWR-200      L26-008-03            1570.47     1528.04      42.43      42.43
PWR-200      L26-004-04            1489.32     1528.04     -38.72      38.72
```

**Step 6. FETCH FIRST 3 ROWS ONLY.** The top three of that sorted list are returned.

### Output

<!--gen-->
```text
PRODUCT_CODE WAFER_ID         THICKNESS_NM AVG_PRODUCT       DIFF
------------ ---------------- ------------ ----------- ----------
PWR-200      L26-008-04             1582.6     1528.04      54.56
PWR-200      L26-008-02            1580.16     1528.04      52.12
PWR-200      L26-004-03            1481.49     1528.04     -46.55
```

### What to notice

No inline view is needed, because `FETCH FIRST` runs after the window has been calculated. All three winners are PWR-200. That is not because PWR-200 is the worst product: its wafers are over 100 times thicker than FD-300 wafers, so a difference measured in nanometres is naturally bigger. If Maya wanted "furthest in relative terms", you would divide `diff` by `avg_product` before sorting. A plain `OVER ()` here would have mixed all four products into one meaningless average.

## Exercise 3: Share of defects per product family

**Maya asks:** "What percentage of all defects (all steps) comes from each product family? One line per family, biggest share first, one decimal. The shares should add up to 100."

### The problem in plain words

This time Maya does want rows collapsed: one line per product family, not one line per reading. Each line shows the family's total defects and that total as a percentage of the defects of all families together.

The percentage needs two numbers on the same row: the family's total (a normal `GROUP BY` sum) and the grand total over all families. The grand total is where a window function comes in. All steps count, so there is no `WHERE`.

### The query

```sql
SELECT p.family,
       SUM(m.defect_count) AS defects,
       ROUND(100 * SUM(m.defect_count) / SUM(SUM(m.defect_count)) OVER (), 1) AS pct_of_all
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY p.family
ORDER  BY defects DESC;
```

### How the query builds the answer

**Step 1. FROM and JOINs.** All 186 readings, each tagged with its product family. The first few look like this:

```text
FAMILY               WAFER_ID         STEP     DEFECT_COUNT
-------------------- ---------------- -------- ------------
FD-SOI               L26-001-01       SPLIT              42
FD-SOI               L26-001-01       ANNEAL             23
FD-SOI               L26-001-01       FINAL               4
FD-SOI               L26-001-02       SPLIT              37
```

**Step 2. GROUP BY p.family.** The 186 rows collapse into 4, one per family, and `SUM(m.defect_count)` adds up each family's defects.

**Step 3. The window `SUM(SUM(m.defect_count)) OVER ()`.** Read it from the inside out. The inner `SUM` is the group total you just made (1753 for FD-SOI and so on). The outer `SUM ... OVER ()` adds those group totals across all four rows and writes the result on every row. The window runs after `GROUP BY`, so it works on the 4 grouped rows, not on the 186 readings:

```text
FAMILY                  DEFECTS ALL_DEFECTS
-------------------- ---------- -----------
FD-SOI                     1753        3634
RF-SOI                      753        3634
Power-SOI                   571        3634
Photonics-SOI               557        3634
```

**Step 4. SELECT.** Now each row has both numbers, so the share is 100 × 1753 / 3634 = 48.2 for FD-SOI, rounded to one decimal.

**Step 5. ORDER BY defects DESC.** Biggest share first.

### Output

<!--gen-->
```text
FAMILY                  DEFECTS PCT_OF_ALL
-------------------- ---------- ----------
FD-SOI                     1753       48.2
RF-SOI                      753       20.7
Power-SOI                   571       15.7
Photonics-SOI               557       15.3
```

### What to notice

`SUM(m.defect_count) OVER ()` on its own would not work here: once you have grouped, the single readings are gone, so the window must be built from the group totals. The shares add to 99.9, not 100, because each is rounded to one decimal. Say so in the report rather than fudging a number. FD-SOI has the most defects partly because it has the most readings (87 of 186), so a share of defects is not the same as a defect rate.

## Exercise 4: Above-average readings, counted per product

**Maya asks:** "How many FINAL readings are thicker than the average FINAL thickness of their own product? Give me the count for each product."

### The problem in plain words

The answer is one row per product with a single count. To get that count we have to look at each FINAL reading, compare it with its own product's average (as in exercise 2), keep only the readings that are above it, and then count what is left per product.

So there are two jobs in a fixed order: first calculate the average next to each reading, then filter and count. That order is the whole difficulty of the exercise.

First the wrong attempt, which you should see once:

```sql
SELECT p.product_code, COUNT(*) AS above_average
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
AND    m.thickness_nm > AVG(m.thickness_nm) OVER (PARTITION BY p.product_code)
GROUP  BY p.product_code;
```
<!--gen-->
```text
AND    m.thickness_nm > AVG(m.thickness_nm) OVER (PARTITION BY p.product_code)
                        *
ERROR at line 7:
ORA-00934: group function is not allowed here
```

Why it fails: `WHERE` runs at step 2, and window functions are not calculated until after `GROUP BY`. When `WHERE` is checking a row, the product average does not exist yet.

### The query

The working version moves the window into an inline view (a query in the `FROM` clause), so the average is finished before the outer query filters on it.

```sql
SELECT product_code,
       COUNT(*) AS above_average
FROM  (SELECT p.product_code,
              m.thickness_nm,
              AVG(m.thickness_nm) OVER (PARTITION BY p.product_code) AS avg_product
       FROM   measurements m
       JOIN   wafers   w ON w.wafer_id   = m.wafer_id
       JOIN   lots     l ON l.lot_id     = w.lot_id
       JOIN   products p ON p.product_id = l.product_id
       WHERE  m.step = 'FINAL')
WHERE  thickness_nm > avg_product
GROUP  BY product_code
ORDER  BY product_code;
```

### How the query builds the answer

Oracle runs the inner query completely first, then treats its result like a table.

**Step 1. Inner query.** Same joins and FINAL filter as exercise 2, giving 62 rows, each with its product's average beside it. Here are the 9 PWR-200 rows, sorted by thickness so the split is easy to see:

```text
PRODUCT_CODE WAFER_ID         THICKNESS_NM AVG_PRODUCT
------------ ---------------- ------------ -----------
PWR-200      L26-008-04             1582.6     1528.04
PWR-200      L26-008-02            1580.16     1528.04
PWR-200      L26-008-03            1570.47     1528.04
PWR-200      L26-008-01            1551.89     1528.04
PWR-200      L26-004-05            1509.67     1528.04
PWR-200      L26-004-01            1496.48     1528.04
PWR-200      L26-004-02            1490.27     1528.04
PWR-200      L26-004-04            1489.32     1528.04
PWR-200      L26-004-03            1481.49     1528.04
```

**Step 2. Outer WHERE.** `avg_product` is now an ordinary column, so `WHERE thickness_nm > avg_product` is allowed. For PWR-200 the top 4 rows survive (all from lot L26-008).

**Step 3. Outer GROUP BY and COUNT.** The surviving rows are counted per product. PWR-200 gets 4.

**Step 4. ORDER BY.** Products in alphabetical order.

### Output

<!--gen-->
```text
PRODUCT_CODE ABOVE_AVERAGE
------------ -------------
FD-300                  10
PHO-300                  5
PWR-200                  4
RF-300                   8
```

### What to notice

The pattern is window inside, filter outside. You will use the same recipe for every "top N per group" question. Two error codes go with it: a window aggregate such as `AVG(...) OVER` in `WHERE` raises `ORA-00934`, and a ranking function such as `ROW_NUMBER() OVER` in `WHERE` raises `ORA-30483`. The cause is the same for both.

## Exercise 5: Worst wafer in each lot

**Maya asks:** "For every lot that has readings, which wafer collected the most defects over all its readings (SPLIT, ANNEAL and FINAL together)? One wafer per lot. If two wafers tie, show the one with the lower wafer ID."

### The problem in plain words

A wafer is measured up to three times, so first we need one total per wafer: its defects added up over all its readings. Then, inside each lot, we pick the wafer with the highest total. The answer has exactly one row per lot: the lot, its worst wafer, and that wafer's total.

"One wafer per lot, and if two tie take the lower ID" tells us which ranking function to use: `ROW_NUMBER`, which never gives two rows the same number, with the wafer ID as a tie-breaker.

### The query

```sql
SELECT lot_id, wafer_id, wafer_defects
FROM  (SELECT w.lot_id,
              w.wafer_id,
              SUM(m.defect_count) AS wafer_defects,
              ROW_NUMBER() OVER (PARTITION BY w.lot_id
                                 ORDER BY SUM(m.defect_count) DESC, w.wafer_id) AS rn
       FROM   measurements m
       JOIN   wafers w ON w.wafer_id = m.wafer_id
       GROUP  BY w.lot_id, w.wafer_id)
WHERE  rn = 1
ORDER  BY lot_id;
```

### How the query builds the answer

**Step 1. Inner FROM and JOIN.** Each reading gets its lot. Wafer L26-005-01, for example, has three readings: 45 (SPLIT), 23 (ANNEAL) and 4 (FINAL).

**Step 2. Inner GROUP BY w.lot_id, w.wafer_id.** One row per wafer, with `SUM(m.defect_count)` as its total. L26-005-01 becomes one row with 45 + 23 + 4 = 72.

**Step 3. The window `ROW_NUMBER() OVER (PARTITION BY w.lot_id ORDER BY ... DESC, w.wafer_id)`.** Inside each lot, the wafers are sorted by total defects, highest first, and numbered 1, 2, 3 and so on. Lot L26-006 shows why the tie-breaker matters:

```text
LOT_ID       WAFER_ID         WAFER_DEFECTS   RN
------------ ---------------- ------------- ----
L26-006      L26-006-02                  54    1
L26-006      L26-006-03                  49    2
L26-006      L26-006-05                  49    3
L26-006      L26-006-01                  45    4
L26-006      L26-006-04                  38    5
```

Wafers 03 and 05 both have 49. Without `w.wafer_id` in the `ORDER BY`, Oracle could give either of them number 2, and could choose differently next time. Here it does not change the winner, but the same thing happens at the top whenever two wafers tie for worst.

**Step 4. Outer WHERE rn = 1.** Only the first wafer of each lot stays.

**Step 5. ORDER BY lot_id.** One line per lot, in lot order.

### Output

<!--gen-->
```text
LOT_ID       WAFER_ID         WAFER_DEFECTS
------------ ---------------- -------------
L26-001      L26-001-04                  77
L26-002      L26-002-05                  60
L26-003      L26-003-05                  85
L26-003A     L26-003A-02                 66
L26-003B     L26-003B-02                 72
L26-003B1    L26-003B1-01                76
L26-004      L26-004-01                  79
L26-005      L26-005-01                  72
L26-006      L26-006-02                  54
L26-007      L26-007-04                  87
L26-007A     L26-007A-02                 66
L26-008      L26-008-03                  76
L26-009      L26-009-01                  75
L26-010      L26-010-02                  78
L26-011      L26-011-02                  79
```

### What to notice

`ROW_NUMBER` always gives exactly one row per lot, and the tie-breaker makes the answer repeatable. If Maya had said "show all wafers that tie for worst", the function would have been `RANK`, which gives tied rows the same number. The grouping happens before the window, so the window ranks wafer totals, not single readings. That is why `ORDER BY SUM(m.defect_count)` is allowed inside the `OVER` brackets. There are 15 lines, not 16, because lot L26-012 has no readings yet and the inner join leaves it out.

## Exercise 6: Ties and quarters

**Maya asks:** "Part a: Give me the three SPLIT readings with the most defects. Run it as FETCH FIRST 3 ROWS ONLY and again with WITH TIES, and tell me the difference. Part b: split the lots into four groups by total defects, worst first, and list the lots in the worst group."

### The problem in plain words

Part a is a top-3 list of single readings: only SPLIT step readings, sorted by defect count, highest first. Maya wants it twice so you can see what happens when the third and fourth readings have the same count. One row is one reading.

Part b works on lots, not readings. First each lot needs its total defects over all its readings. Then the lots are sorted from worst to best and dealt into four groups of nearly equal size (quartiles). Maya only wants the lots in group 1, the worst quarter. One row of the answer is one lot with its total.

### The queries

```sql
-- Part a, ROWS ONLY
SELECT wafer_id, defect_count
FROM   measurements
WHERE  step = 'SPLIT'
ORDER  BY defect_count DESC
FETCH FIRST 3 ROWS ONLY;
```
<!--gen-->
```text
WAFER_ID         DEFECT_COUNT
---------------- ------------
L26-007-04                 60
L26-003B1-01               59
L26-004-01                 57
```

```sql
-- Part a, WITH TIES
SELECT wafer_id, defect_count
FROM   measurements
WHERE  step = 'SPLIT'
ORDER  BY defect_count DESC
FETCH FIRST 3 ROWS WITH TIES;
```
<!--gen-->
```text
WAFER_ID         DEFECT_COUNT
---------------- ------------
L26-007-04                 60
L26-003B1-01               59
L26-004-01                 57
L26-010-02                 57
```

```sql
-- Part b
SELECT lot_id, total_defects
FROM  (SELECT w.lot_id,
              SUM(m.defect_count) AS total_defects,
              NTILE(4) OVER (ORDER BY SUM(m.defect_count) DESC) AS quartile
       FROM   measurements m
       JOIN   wafers w ON w.wafer_id = m.wafer_id
       GROUP  BY w.lot_id)
WHERE  quartile = 1
ORDER  BY total_defects DESC;
```

### How the queries build the answer

**Part a, steps 1 to 3. FROM, WHERE, ORDER BY.** All readings, then only SPLIT ones, then sorted by defect count, highest first. The top five after sorting:

```text
WAFER_ID         DEFECT_COUNT
---------------- ------------
L26-007-04                 60
L26-003B1-01               59
L26-004-01                 57
L26-010-02                 57
L26-003-05                 55
```

**Part a, step 4. FETCH FIRST.** `3 ROWS ONLY` stops after exactly three rows, cutting between the two readings with 57. `3 ROWS WITH TIES` also takes three rows, then keeps going for as long as the next row has the same value as row 3, so it returns four.

**Part b, step 1. Inner FROM, JOIN and GROUP BY.** Readings are joined to their wafers and grouped by lot, giving one row per lot (15 lots) with its total defects.

**Part b, step 2. The window `NTILE(4) OVER (ORDER BY SUM(m.defect_count) DESC)`.** The 15 lot totals are sorted worst first and dealt into 4 buckets of nearly equal size. 15 does not divide by 4, so the leftover rows go to the first buckets: sizes 4, 4, 4 and 3.

```text
LOT_ID       TOTAL_DEFECTS   QUARTILE
------------ ------------- ----------
L26-011                344          1
L26-009                317          1
L26-007                302          1
L26-010                299          1
L26-001                295          2
L26-004                295          2
L26-003                282          2
L26-008                276          2
L26-005                240          3
...
L26-007A               113          4
```

**Part b, step 3. Outer WHERE quartile = 1.** Only the four lots in the worst bucket stay.

**Part b, step 4. ORDER BY total_defects DESC.** Worst first.

### Output of part b

<!--gen-->
```text
LOT_ID       TOTAL_DEFECTS
------------ -------------
L26-011                344
L26-009                317
L26-007                302
L26-010                299
```

### What to notice

`ONLY` picked one of the two readings with 57 defects, and which one is not guaranteed. `WITH TIES` keeps both, so it is the honest choice when ties are possible. `NTILE` cares only about position, not about values: two lots with the same total can land in different buckets if the boundary falls between them. Here L26-001 and L26-004 tie at 295 and happen to sit in the same bucket, but that is luck, not a rule.
