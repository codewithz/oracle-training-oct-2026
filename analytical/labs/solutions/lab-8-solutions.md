# Lab 8: Window functions and ranking solutions

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The outputs below were produced by running each query on the lab data. The same queries are in [`lab8_solutions.sql`](scripts/lab8_solutions.sql).

## Exercise 1: Lot average next to each reading

**Maya asks:** "Lot L26-005 is on hold. Show each of its FINAL readings with the average FINAL thickness of the lot next to it, and how far each wafer is from that average (two decimals)."

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
<!--gen-->
```text
WAFER_ID         THICKNESS_NM    AVG_LOT       DIFF
---------------- ------------ ---------- ----------
L26-005-01             221.07     218.27        2.8
L26-005-02             219.76     218.27       1.49
L26-005-03             216.63     218.27      -1.64
L26-005-04             215.62     218.27      -2.65
```

**Why it works / what to notice.** The average sits on every row, and the four differences add up to about zero (2.8 + 1.49 - 1.64 - 2.65 = 0). That is a good check for any difference-from-average column. The window saw only the four rows that survived `WHERE`.

## Exercise 2: Compare with the product average

**Maya asks:** "Show every FINAL reading with its product code, the average FINAL thickness of that product, and the difference. I only want the three readings that are furthest from their product average, in either direction."

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
<!--gen-->
```text
PRODUCT_CODE WAFER_ID         THICKNESS_NM AVG_PRODUCT       DIFF
------------ ---------------- ------------ ----------- ----------
PWR-200      L26-008-04             1582.6     1528.04      54.56
PWR-200      L26-008-02            1580.16     1528.04      52.12
PWR-200      L26-004-03            1481.49     1528.04     -46.55
```

**Why it works / what to notice.** No inline view is needed here. The window is calculated before `ORDER BY` and `FETCH FIRST`, so the top 3 are cut from the finished list. Compare the product averages with the single-lot average from exercise 1: each product has its own scale, which is why a plain `OVER ()` would be wrong here.

## Exercise 3: Share of defects per product family

**Maya asks:** "What percentage of all defects (all steps) comes from each product family? One line per family, biggest share first, one decimal. The shares should add up to 100."

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
<!--gen-->
```text
FAMILY                  DEFECTS PCT_OF_ALL
-------------------- ---------- ----------
FD-SOI                     1753       48.2
RF-SOI                      753       20.7
Power-SOI                   571       15.7
Photonics-SOI               557       15.3
```

**Why it works / what to notice.** `SUM(SUM(m.defect_count)) OVER ()` reads from the inside: first the group total, then a total of group totals. The shares add to 99.9, not 100, because each is rounded to one decimal. Say so in the report.

## Exercise 4: Above-average readings, counted per product

**Maya asks:** "How many FINAL readings are thicker than the average FINAL thickness of their own product? Give me the count for each product."

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

And the working version:

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
<!--gen-->
```text
PRODUCT_CODE ABOVE_AVERAGE
------------ -------------
FD-300                  10
PHO-300                  5
PWR-200                  4
RF-300                   8
```

**Why it works / what to notice.** The pattern is window inside, filter outside. The same recipe answers every top-N-per-group question. Try the wrong version once so you recognise `ORA-30483` when you meet it: `WHERE thickness_nm > AVG(thickness_nm) OVER (PARTITION BY ...)` raises `ORA-00934` on this Oracle version (the pure ranking functions raise `ORA-30483`), and the cause is the same: `WHERE` runs before any window exists.

## Exercise 5: Worst wafer in each lot

**Maya asks:** "For every lot that has readings, which wafer collected the most defects over all its readings (SPLIT, ANNEAL and FINAL together)? One wafer per lot. If two wafers tie, show the one with the lower wafer ID."

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

**Why it works / what to notice.** `ROW_NUMBER` always gives exactly one row per lot, and the tie-breaker makes the answer repeatable. If Maya had said "show all wafers that tie", the function would have been `RANK`. The grouping happens first, so the window ranks wafer totals, not single readings.

## Exercise 6: Ties and quarters

**Maya asks:** "Part a: Give me the three SPLIT readings with the most defects. Run it as FETCH FIRST 3 ROWS ONLY and again with WITH TIES, and tell me the difference. Part b: split the lots into four groups by total defects, worst first, and list the lots in the worst group."

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
<!--gen-->
```text
LOT_ID       TOTAL_DEFECTS
------------ -------------
L26-011                344
L26-009                317
L26-007                302
L26-010                299
```

**Why it works / what to notice.** `ONLY` cuts after row 3 and picks one of the two readings with 57 defects by chance. `WITH TIES` keeps both. For `NTILE`, 15 lots into 4 buckets gives sizes 4, 4, 4 and 3, with the extra lot in the first buckets.

