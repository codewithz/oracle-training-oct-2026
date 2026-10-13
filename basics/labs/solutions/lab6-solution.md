# Lab 6 solutions: Subqueries and set operators

These are the answers for [Lab 6](../labs/lab-6-subqueries-and-sets.md). The same queries are in [`lab6_solutions.sql`](scripts/lab6_solutions.sql). If your query looks different but gives the same rows, it is probably fine. Check the "what to notice" paragraph to see whether you learned the point of the exercise.

## Exercise 1: Above the average

**1a.** The sticky note on its own:

```sql
SELECT ROUND(AVG(defect_count), 2) AS avg_defects
FROM   measurements;
```

<!--gen-->
```text
AVG_DEFECTS
-----------
      19.54
```

**1b.** The ten worst measurements above it:

```sql
SELECT meas_id, wafer_id, step, defect_count
FROM   measurements
WHERE  defect_count > (SELECT AVG(defect_count) FROM measurements)
ORDER  BY defect_count DESC, meas_id
FETCH FIRST 10 ROWS ONLY;
```

<!--gen-->
```text
   MEAS_ID WAFER_ID     STEP     DEFECT_COUNT
---------- ------------ -------- ------------
       118 L26-007-04   SPLIT              60
        61 L26-003B1-01 SPLIT              59
        67 L26-004-01   SPLIT              57
       160 L26-010-02   SPLIT              57
        43 L26-003-05   SPLIT              55
        79 L26-004-05   SPLIT              54
       142 L26-009-01   SPLIT              54
       163 L26-010-03   SPLIT              53
        28 L26-002-05   SPLIT              52
       148 L26-009-03   SPLIT              51
```

**Why it works / what to notice.** The bracketed query returns one number, so it can stand on the right of `>`. It is worked out first, then the outer query compares every row with it. All ten worst readings come from the SPLIT step. That is a hint worth following up: the first step in the process seems to be the noisiest. (You would confirm it with a `GROUP BY step`.)

## Exercise 2: Lots for the thicker products

```sql
SELECT lot_id, product_id, status
FROM   lots
WHERE  product_id IN (SELECT product_id
                      FROM   products
                      WHERE  target_thk_nm > 100)
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     PRODUCT_ID STATUS
---------- ---------- --------
L26-004             3 SHIPPED
L26-005             4 HOLD
L26-008             3 SCRAPPED
L26-009             4 ACTIVE
L26-012             4 ACTIVE
```

**Why it works / what to notice.** The inner query returns the product ids 3, 4 and 5 (targets 1500, 220 and 500). `IN` keeps the lots whose product is in that list. Product 5 has no lots, so it adds nothing to the result, and that is fine.

## Exercise 3: The NOT IN trap

**3a.** The natural but dangerous way:

```sql
SELECT lot_id
FROM   lots
WHERE  lot_id NOT IN (SELECT parent_lot_id FROM lots);
```

<!--gen-->
```text

```

No rows and no error. This cannot be right: 16 lots, only 3 of which are parents.

**3b.** Why: count the `NULL`s.

```sql
SELECT COUNT(*) AS rows_in_list, COUNT(parent_lot_id) AS non_null_values
FROM   lots;
```

<!--gen-->
```text
ROWS_IN_LIST NON_NULL_VALUES
------------ ---------------
          16               4
```

16 rows, but only 4 have a parent. The other 12 have `NULL`. `COUNT(column)` skips `NULL`s, which is why the two numbers differ.

**3c.** Fix 1: remove the `NULL`s from the list.

```sql
SELECT lot_id
FROM   lots
WHERE  lot_id NOT IN (SELECT parent_lot_id FROM lots WHERE parent_lot_id IS NOT NULL)
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID
----------
L26-001
L26-002
L26-003A
L26-003B1
L26-004
L26-005
L26-006
L26-007A
L26-008
L26-009
L26-010
L26-011
L26-012
```

**3d.** Fix 2: `NOT EXISTS`.

```sql
SELECT l.lot_id
FROM   lots l
WHERE  NOT EXISTS (SELECT 1 FROM lots child WHERE child.parent_lot_id = l.lot_id)
ORDER  BY l.lot_id;
```

<!--gen-->
```text
LOT_ID
----------
L26-001
L26-002
L26-003A
L26-003B1
L26-004
L26-005
L26-006
L26-007A
L26-008
L26-009
L26-010
L26-011
L26-012
```

**Why it works / what to notice.** `x NOT IN (a, b, NULL)` means `x <> a AND x <> b AND x <> NULL`. The last test is unknown, never true, so no row passes. Only three lots are parents (`L26-003`, `L26-003B` and `L26-007`), so 16 minus 3 leaves 13. `NOT EXISTS` never compares with `NULL`, it only asks "is there a child row?", so it gives the right answer without any extra filter. A good default: reach for `NOT EXISTS` when the question is "has no matching row".

## Exercise 4: Never measured, never used

**4a.** Lots that have never been measured:

```sql
SELECT l.lot_id, l.status
FROM   lots l
WHERE  NOT EXISTS (SELECT 1
                   FROM   wafers w
                   JOIN   measurements m ON m.wafer_id = w.wafer_id
                   WHERE  w.lot_id = l.lot_id);
```

<!--gen-->
```text
LOT_ID     STATUS
---------- --------
L26-012    ACTIVE
```

**4b.** Products with no lots:

```sql
SELECT p.product_code
FROM   products p
WHERE  NOT EXISTS (SELECT 1 FROM lots l WHERE l.product_id = p.product_id);
```

<!--gen-->
```text
PRODUCT_CODE
------------
SIC-150
```

**Why it works / what to notice.** For each outer row the inner query looks for at least one matching row. If it finds none, `NOT EXISTS` is true and the row is kept. `L26-012` has wafers, but none of them has a measurement, so the join inside finds nothing. `SIC-150` has no lots at all.

## Exercise 5: Tools that never measured anything

```sql
SELECT tool_id FROM tools
MINUS
SELECT tool_id FROM measurements
ORDER  BY tool_id;
```

<!--gen-->
```text
TOOL_ID
-------
CMP01
IMP01
```

**Why it works / what to notice.** `MINUS` keeps the rows of the first list that are not in the second. `CMP01` and `IMP01` are a polisher and an implanter, which do not measure. The `ORDER BY` is written once, at the end, and it applies to the combined result.

## Exercise 6: Above my own tool's average

```sql
SELECT m.meas_id, m.tool_id, m.defect_count
FROM   measurements m
WHERE  m.defect_count > (SELECT AVG(m2.defect_count)
                         FROM   measurements m2
                         WHERE  m2.tool_id = m.tool_id)
ORDER  BY m.defect_count DESC, m.meas_id
FETCH FIRST 8 ROWS ONLY;
```

<!--gen-->
```text
   MEAS_ID TOOL_ID DEFECT_COUNT
---------- ------- ------------
       118 SPL01             60
        61 SPL01             59
        67 SPL02             57
       160 SPL02             57
        43 SPL02             55
        79 SPL01             54
       142 SPL02             54
       163 SPL02             53
```

**Why it works / what to notice.** The line `m2.tool_id = m.tool_id` ties the inner query to the outer row. For a reading taken on `SPL01`, the inner query averages only `SPL01` readings. For one on `SPL02`, it averages only `SPL02` readings. Read it as "for each row, work out this tool's average, and compare". If you forget that line, every row is compared with the overall average and you get the answer to exercise 1 again.

## Exercise 7: Lots bigger than the average lot

```sql
WITH wafers_per_lot AS (
  SELECT lot_id, COUNT(*) AS wafer_count
  FROM   wafers
  GROUP  BY lot_id
)
SELECT lot_id, wafer_count
FROM   wafers_per_lot
WHERE  wafer_count > (SELECT AVG(wafer_count) FROM wafers_per_lot)
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     WAFER_COUNT
---------- -----------
L26-001              5
L26-002              5
L26-003              5
L26-004              5
L26-006              5
L26-007              5
L26-009              5
L26-010              5
L26-011              5
```

**Why it works / what to notice.** The `WITH` part is the named sticky note, a list of lots and their wafer counts. The main query uses it twice: once for the rows and once inside a subquery for the average (66 wafers over 16 lots, about 4.1). Nine lots have 5 wafers. Naming the list means you write the counting logic only once.

## Exercise 8: UNION, UNION ALL and INTERSECT

**8a.** UNION: each lot once.

```sql
SELECT lot_id FROM wafers WHERE grade = 'SCRAP'
UNION
SELECT lot_id FROM lots WHERE status = 'HOLD'
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID
----------
L26-003B
L26-005
L26-008
```

**8b.** UNION ALL: just staple.

```sql
SELECT lot_id FROM wafers WHERE grade = 'SCRAP'
UNION ALL
SELECT lot_id FROM lots WHERE status = 'HOLD'
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID
----------
L26-003B
L26-005
L26-008
L26-008
L26-008
L26-008
```

**8c.** INTERSECT: on both lists.

```sql
SELECT lot_id FROM wafers WHERE grade = 'SCRAP'
INTERSECT
SELECT lot_id FROM lots WHERE status = 'SCRAPPED';
```

<!--gen-->
```text
LOT_ID
----------
L26-008
```

**Why it works / what to notice.** `L26-008` appears four times in 8b because it has four `SCRAP` wafers, and list A has one row per wafer. `UNION ALL` does not remove repeats, not even inside a single list. `UNION` does, so 8a shows it once. Both lists have one column of the same type (`lot_id`), which is the rule for set operators. In 8c the lot that has a `SCRAP` wafer and is itself scrapped is `L26-008`.

## Stretch: products with no lots, as a join

```sql
SELECT p.product_code
FROM   products p
LEFT   JOIN lots l ON l.product_id = p.product_id
WHERE  l.lot_id IS NULL;
```

<!--gen-->
```text
PRODUCT_CODE
------------
SIC-150
```

**Why it works / what to notice.** `LEFT JOIN` keeps every product and fills the lot columns with `NULL` where there is no match. The `WHERE l.lot_id IS NULL` keeps only those. It gives the same answer as `NOT EXISTS`, and it is also safe with `NULL`s. Many people find `NOT EXISTS` easier to read as a sentence ("there is no lot for this product"). `NOT IN` is the one to be careful with.
