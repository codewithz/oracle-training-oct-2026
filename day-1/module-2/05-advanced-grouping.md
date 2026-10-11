# Advanced grouping: ROLLUP, CUBE, GROUPING SETS, PIVOT and LISTAGG

Reports with subtotals and grand totals are among the most common requests a database person gets. This page shows the GROUP BY extensions that produce several levels of totals in one query (ROLLUP, CUBE and GROUPING SETS), the GROUPING and GROUPING_ID functions that tell a subtotal row from a detail row, and two ways of reshaping a result: PIVOT, which turns rows into columns, and LISTAGG, which joins values into one string.

Slides: 31 and 32 of the Day 1 deck.

## Why one query instead of several

Suppose you need FINAL readings and defects per metrology tool, a subtotal per bay and a grand total. With plain GROUP BY that is three queries glued together with UNION ALL, and the table is read three times. A GROUP BY extension computes all levels in one pass over the data and returns them in one result.

## ROLLUP

`GROUP BY ROLLUP (a, b)` groups by (a, b), then by (a), then by nothing at all (the grand total). With n columns you get n + 1 levels, rolling up from right to left, so the column order matters: put the coarsest level first.

```sql
SELECT t.bay, m.tool_id, COUNT(*) AS readings, SUM(m.defect_count) AS defects
FROM   measurements m
JOIN   tools t ON t.tool_id = m.tool_id
WHERE  m.step = 'FINAL'
GROUP  BY ROLLUP (t.bay, m.tool_id)
ORDER  BY t.bay, m.tool_id;
```

```text
BAY   TOOL_ID   READINGS    DEFECTS
----- ------- ---------- ----------
B3    MET01           21        110
B3    MET02           20         74
B3                    41        184
B4    MET03           21         99
B4                    21         99
                      62        283
```

The rows with an empty TOOL_ID are the bay subtotals, and the row with both columns empty is the grand total. On a subtotal row, the columns that were rolled up are NULL. It reads like a supermarket receipt that prints a subtotal under each bag and the grand total at the bottom, with the bays as the bags and the tools as the items.

### The NULL problem

That NULL is ambiguous when the data itself contains NULLs. Two PHO-300 wafers have no grade yet. Group the PHO-300 wafers by product and grade with ROLLUP:

```sql
SELECT p.product_code AS product, w.grade, COUNT(*) AS wafers
FROM   wafers w
JOIN   lots l     ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  p.product_code = 'PHO-300'
GROUP  BY ROLLUP (p.product_code, w.grade)
ORDER  BY p.product_code, w.grade;
```

```text
PRODUCT  GRADE      WAFERS
-------- ------ ----------
PHO-300  PRIME          10
PHO-300  TEST            1
PHO-300                  2
PHO-300                 13
                        13
```

The third row is a detail row (two wafers whose grade is NULL); the fourth is the product subtotal. Nothing in the output tells them apart, and that is the job of the GROUPING function below.

## CUBE

`GROUP BY CUBE (a, b)` produces every combination: (a, b), (a), (b) and (). With n columns that is 2 to the power n groupings. If ROLLUP is the receipt with subtotals per bag, CUBE also adds them up the other way: how much you spent on milk across all the bags. Use it for cross-tab reports where the reader wants totals in both directions, for example "per product, per grade, and both".

## GROUPING and GROUPING_ID

`GROUPING(col)` returns 1 on a row where col was rolled up into a total, and 0 where col is a real grouping value (including a real NULL). Use it in a CASE expression to print a label such as ALL instead of a NULL that looks like missing data. Think of it as a sticker on the subtotal line that says "this NULL means everything", so nobody files it as a missing value.

`GROUPING_ID(a, b, ...)` combines the GROUPING bits of its arguments into one number, read as a binary number with the first column as the highest bit. For two columns: 0 is a detail row, 1 means b is rolled up (a total per a), 2 means a is rolled up (a total per b), and 3 is the grand total. It is handy for sorting the levels, or for filtering levels with HAVING.

Here is CUBE over product and grade for two products, with labels:

```sql
SELECT CASE GROUPING(p.product_code) WHEN 1 THEN 'ALL' ELSE p.product_code END AS product,
       CASE GROUPING(w.grade) WHEN 1 THEN 'ALL' ELSE NVL(w.grade, '(none)') END AS grade,
       COUNT(*) AS wafers,
       GROUPING(p.product_code) AS g_prod,
       GROUPING(w.grade)        AS g_grade,
       GROUPING_ID(p.product_code, w.grade) AS gid
FROM   wafers w
JOIN   lots l     ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  p.product_code IN ('PHO-300', 'PWR-200')
GROUP  BY CUBE (p.product_code, w.grade)
ORDER  BY gid, product, grade;
```

```text
PRODUCT  GRADE      WAFERS     G_PROD    G_GRADE        GID
-------- ------ ---------- ---------- ---------- ----------
PHO-300  (none)          2          0          0          0
PHO-300  PRIME          10          0          0          0
PHO-300  TEST            1          0          0          0
PWR-200  PRIME           4          0          0          0
PWR-200  SCRAP           4          0          0          0
PWR-200  TEST            1          0          0          0
PHO-300  ALL            13          0          1          1
PWR-200  ALL             9          0          1          1
ALL      (none)          2          1          0          2
ALL      PRIME          14          1          0          2
ALL      SCRAP           4          1          0          2
ALL      TEST            2          1          0          2
ALL      ALL            22          1          1          3
```

Now the real NULL grade shows as (none), with G_GRADE 0, and the subtotals show ALL, with G_GRADE 1. GID numbers the four levels: 6 detail rows, 2 per-product totals, 4 per-grade totals and the grand total of 22 wafers.

Test GROUPING first and apply NVL only to detail values, as above. `NVL(w.grade, 'ALL')` on its own would label the real NULL grade as ALL too, which brings the ambiguity straight back.

## GROUPING SETS

ROLLUP and CUBE give you a fixed pattern of levels. `GROUPING SETS` lets you list exactly the groupings you want, and nothing else. `()` is the grand total. Defects per process step and per bay, with a grand total, and no detail rows:

```sql
SELECT m.step, t.bay, SUM(m.defect_count) AS defects
FROM   measurements m
JOIN   tools t ON t.tool_id = m.tool_id
GROUP  BY GROUPING SETS ((m.step), (t.bay), ())
ORDER  BY m.step, t.bay;
```

```text
STEP   BAY      DEFECTS
------ ----- ----------
ANNEAL             1015
FINAL               283
SPLIT              2336
       B1          2336
       B2          1015
       B3           184
       B4            99
                   3634
```

ROLLUP and CUBE are shorthands for particular grouping sets: `ROLLUP (a, b)` is `GROUPING SETS ((a, b), (a), ())`, and `CUBE (a, b)` is `GROUPING SETS ((a, b), (a), (b), ())`. GROUPING and GROUPING_ID work with GROUPING SETS in the same way.

## PIVOT: rows into columns

PIVOT turns the values of one column into separate columns, aggregating as it goes. If you have built a pivot table in Excel, with statuses dragged into the column area and a count in the values area, this is the same report written in SQL. The number of lots of each product in each status:

```sql
SELECT *
FROM  (SELECT p.product_code AS product, l.status, l.lot_id
       FROM   lots l
       JOIN   products p ON p.product_id = l.product_id)
PIVOT (COUNT(lot_id) FOR status IN ('ACTIVE' AS active, 'HOLD' AS hold,
                                    'SHIPPED' AS shipped, 'SCRAPPED' AS scrapped))
ORDER  BY product;
```

```text
PRODUCT      ACTIVE       HOLD    SHIPPED   SCRAPPED
-------- ---------- ---------- ---------- ----------
FD-300            5          1          2          0
PHO-300           2          1          0          0
PWR-200           0          0          1          1
RF-300            1          0          2          0
```

How PIVOT works:

- The inline view supplies the input columns. PIVOT groups implicitly by every input column that is neither aggregated nor named after FOR, so keep the inline view to exactly the columns you need. An extra column (for example start_date) would split the result into one row per value.
- `COUNT(lot_id)` is the aggregate, `FOR status` names the column whose values become columns, and the IN list names those values and their column aliases. The list is fixed when you write the query: a new status value does not appear as a new column by itself.
- The aggregate must be a plain aggregate function. To round an average, round it in the outer select list:

```sql
SELECT lot_id, ROUND(split, 2) AS split, ROUND(anneal, 2) AS anneal, ROUND(final, 2) AS final
FROM  (SELECT w.lot_id, m.step, m.thickness_nm
       FROM   measurements m
       JOIN   wafers w ON w.wafer_id = m.wafer_id
       WHERE  w.lot_id IN ('L26-002', 'L26-006', 'L26-010'))
PIVOT (AVG(thickness_nm) FOR step IN ('SPLIT' AS split, 'ANNEAL' AS anneal, 'FINAL' AS final))
ORDER  BY lot_id;
```

```text
LOT_ID        SPLIT     ANNEAL      FINAL
-------- ---------- ---------- ----------
L26-002        97.1      82.51      74.93
L26-006       98.23      82.04      74.54
L26-010       98.89      83.54      75.02
```

Writing `ROUND(AVG(thickness_nm), 2)` inside the PIVOT clause instead raises ORA-56902: expect aggregate function inside pivot operation.

Before PIVOT existed (11g), the same report was written with one CASE expression per column, for example `COUNT(CASE WHEN l.status = 'HOLD' THEN 1 END) AS hold` with an ordinary GROUP BY. You will still see that form, and it is still useful when the columns need different conditions.

## LISTAGG: values into one string

LISTAGG is an aggregate function that concatenates the values of a group into one string, in the order given by WITHIN GROUP. Picture someone reading out the RSVP list for a party in a fixed order; the guests who never replied are not read out at all, which is how LISTAGG treats NULLs.

```text
LISTAGG( [DISTINCT] expr [, 'delimiter'] ) WITHIN GROUP (ORDER BY ...)
```

The lots of each product in start order, and the distinct parent lots that the product's split and rework lots came from:

```sql
SELECT p.product_code AS product,
       LISTAGG(l.lot_id, ', ') WITHIN GROUP (ORDER BY l.start_date) AS lots_in_start_order,
       LISTAGG(DISTINCT l.parent_lot_id, ', ') WITHIN GROUP (ORDER BY l.parent_lot_id) AS parent_lots
FROM   lots l
JOIN   products p ON p.product_id = l.product_id
GROUP  BY p.product_code
ORDER  BY p.product_code;
```

```text
PRODUCT  LOTS_IN_START_ORDER                                                         PARENT_LOTS
-------- --------------------------------------------------------------------------- ----------------------------
FD-300   L26-001, L26-003, L26-003A, L26-003B, L26-003B1, L26-007, L26-007A, L26-011 L26-003, L26-003B, L26-007
PHO-300  L26-005, L26-009, L26-012
PWR-200  L26-004, L26-008
RF-300   L26-002, L26-006, L26-010
```

Two things to notice in PARENT_LOTS:

- LISTAGG ignores NULLs. Most FD-300 lots have no parent, and they simply do not appear in the list. For the other products every parent_lot_id is NULL, so the result is NULL. If you need a placeholder for missing values, wrap the expression in NVL.
- The `DISTINCT` keyword removes duplicates from the list. It is new in Oracle 19c; before 19c you had to remove duplicates in an inline view first. The difference is easy to see on lot L26-007A, where two wafers were measured on the same FINAL tool:

```sql
SELECT w.lot_id,
       LISTAGG(m.tool_id, ',')          WITHIN GROUP (ORDER BY m.tool_id) AS tools,
       LISTAGG(DISTINCT m.tool_id, ',') WITHIN GROUP (ORDER BY m.tool_id) AS distinct_tools
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id = 'L26-007A'
GROUP  BY w.lot_id;
```

```text
LOT_ID   TOOLS                                DISTINCT_TOOLS
-------- ------------------------------------ ------------------------------
L26-007A ANL01,ANL02,MET03,MET03,SPL01,SPL02  ANL01,ANL02,MET03,SPL01,SPL02
```

The result of LISTAGG is a VARCHAR2, limited to 4000 bytes by default (32767 bytes if the database uses MAX_STRING_SIZE = EXTENDED). A longer result raises ORA-01489 unless you add `ON OVERFLOW TRUNCATE`, which cuts the list and appends an indicator and, by default, a count of the values left out.

## Common mistakes

- Reading a NULL on a ROLLUP or CUBE row as missing data, or a real NULL as a subtotal. Use GROUPING to tell them apart, and label totals with a CASE on GROUPING, not with NVL.
- Putting the ROLLUP columns in the wrong order. `ROLLUP (tool_id, bay)` gives totals per tool and a grand total, but no bay subtotals.
- Ordering the result by the grouping columns alone and finding the subtotal rows in odd places. Order by GROUPING_ID, or by the columns and their GROUPING values.
- Feeding PIVOT an inline view with extra columns, which splits the result into more rows than expected.
- Wrapping the PIVOT aggregate in another function (ORA-56902). Apply ROUND and similar functions in the outer select list.
- Expecting LISTAGG to show NULL values. It skips them.

## Check your understanding

1. How many grouping levels does `ROLLUP (product, month, tool)` produce, and how many does `CUBE (product, month, tool)` produce?
2. On a ROLLUP result, a row has product FD-300 and an empty month. How do you find out whether it is the FD-300 subtotal or a group of FD-300 rows with a NULL month?
3. Write the GROUP BY clause that returns wafer counts per grade, per lot and a grand total, with no detail rows.
4. What does GROUPING_ID(product, grade) return on the per-grade total rows of a CUBE (product, grade)?
5. A product has three lots. Only one of them, on hold, has a hold reason: 'Particles'. What does `LISTAGG(hold_reason, '; ') WITHIN GROUP (ORDER BY lot_id)` return for that product?

## Further reading

- [Oracle Database Data Warehousing Guide 19c: SQL for Aggregation in Data Warehouses](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/sql-aggregation-data-warehouses.html)
- [Oracle Database Data Warehousing Guide 19c: SQL for Analysis and Reporting](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/sql-analysis-reporting-data-warehouses.html)
- [Oracle Database SQL Language Reference 19c: GROUPING](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/GROUPING.html)
- [Oracle Database SQL Language Reference 19c: GROUPING_ID](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/GROUPING_ID.html)
- [Oracle Database SQL Language Reference 19c: LISTAGG](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LISTAGG.html)
- [Oracle Database SQL Language Reference 19c: SELECT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html) (the group_by_clause and pivot_clause sections)
- [ORACLE-BASE: ROLLUP, CUBE, GROUPING Functions and GROUPING SETS](https://oracle-base.com/articles/misc/rollup-cube-grouping-functions-and-grouping-sets)
- [ORACLE-BASE: PIVOT and UNPIVOT Operators in Oracle Database 11g Release 1](https://oracle-base.com/articles/11g/pivot-and-unpivot-operators-11gr1)
- [ORACLE-BASE: LISTAGG DISTINCT in Oracle Database 19c](https://oracle-base.com/articles/19c/listagg-distinct-19c)

To practise, work through Part D of [Lab 5: Hierarchies and grouping](../labs/lab-5-hierarchies-and-grouping.md).

### Answers

1. ROLLUP: 4 levels (product, month, tool), (product, month), (product), (). CUBE: 2 to the power 3, which is 8.
2. Look at `GROUPING(month)`. It is 1 on the subtotal row and 0 on a row whose month is really NULL.
3. `GROUP BY GROUPING SETS ((grade), (lot_id), ())`.
4. 2. The product column is rolled up (bit value 2) and the grade column is not (bit value 0).
5. `Particles`. LISTAGG skips the two NULL hold reasons, so no empty entries or extra delimiters appear.
