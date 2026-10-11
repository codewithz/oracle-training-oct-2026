# SQL review: joins, subqueries, set operators and NULLs

This page reviews the SQL you already write every day and concentrates on the places where it goes wrong in production: outer joins combined with COUNT, NOT IN against a column that can hold NULL, the difference between UNION and UNION ALL, and Oracle's habit of storing an empty string as NULL. It ends with the row limiting clause (FETCH FIRST). All examples run as FAB_LAB against the invented wafer-fab tables you loaded in Lab 1.

Slides: 20, 22 and 23 of the Day 1 deck.

## The FAB_LAB tables

The lab schema is a small, invented wafer fab. Product names and numbers are illustrative.

| Table | Rows | Columns used on this page |
| --- | --- | --- |
| PRODUCTS | 5 | product_id, product_code, family, target_thk_nm |
| TOOLS | 9 | tool_id, tool_type, bay |
| LOTS | 16 | lot_id, product_id, lot_type, parent_lot_id, start_date, status, hold_reason |
| WAFERS | 66 | wafer_id, lot_id, slot_no, grade |
| MEASUREMENTS | 186 | meas_id, wafer_id, step, tool_id, meas_time, thickness_nm, defect_count |

PRODUCTS has many LOTS, a lot has many WAFERS, a wafer has many MEASUREMENTS, and each measurement is taken on one TOOL. `lots.parent_lot_id` points to the lot that a split or rework lot came from.

## Joins

### Inner joins in ANSI and in Oracle syntax

An inner join returns only the rows that have a match on both sides. Oracle accepts two notations. The ANSI form puts the join condition in the FROM clause with `JOIN ... ON`:

```sql
SELECT m.wafer_id, m.tool_id, t.bay, m.thickness_nm
FROM   measurements m
JOIN   tools t ON t.tool_id = m.tool_id
WHERE  m.step = 'FINAL'
AND    m.wafer_id LIKE 'L26-009-%'
ORDER  BY m.wafer_id;
```

```text
WAFER_ID     TOOL_ID BAY  THICKNESS_NM
------------ ------- ---- ------------
L26-009-01   MET02   B3         222.79
L26-009-02   MET01   B3         220.11
L26-009-03   MET02   B3         217.67
L26-009-04   MET02   B3          216.6
L26-009-05   MET03   B4         221.72
```

The older Oracle form lists the tables with commas and puts the join condition in WHERE, next to the filters:

```sql
SELECT m.wafer_id, m.tool_id, t.bay, m.thickness_nm
FROM   measurements m, tools t
WHERE  t.tool_id = m.tool_id
AND    m.step = 'FINAL'
AND    m.wafer_id LIKE 'L26-009-%'
ORDER  BY m.wafer_id;
```

Both return the same five rows. The ANSI form keeps "how the tables relate" apart from "which rows I want", which makes long queries easier to read and makes a forgotten join condition easy to spot. Use it for new code.

`JOIN ... USING (col)` is a shorter ANSI form when the column has the same name on both sides. With USING, the join column has no table qualifier anywhere in the query: writing `l.lot_id` raises ORA-25154.

### Outer joins

An outer join also keeps the rows that have no match. `LEFT [OUTER] JOIN` keeps every row of the left table, `RIGHT [OUTER] JOIN` every row of the right table, and `FULL [OUTER] JOIN` every row of both. Where there is no match, the columns of the other table are NULL.

```sql
SELECT p.product_code AS product, l.lot_id
FROM   products p
FULL   OUTER JOIN lots l ON l.product_id = p.product_id
WHERE  l.lot_id IS NULL OR p.product_id IS NULL;
```

```text
PRODUCT  LOT_ID
-------- ----------
SIC-150
```

### The (+) operator in older code

Before ANSI joins, Oracle wrote an outer join by putting `(+)` after the columns of the table that may be missing (the "deficient" side). `WHERE l.product_id(+) = p.product_id` means "keep every product, and add lot columns where there is a match". You will meet it in older code, so you need to read it. For new code, Oracle's own SQL Language Reference recommends the ANSI syntax, and there is no `(+)` form of a full outer join.

The rule that catches people: every condition on the deficient table needs its own `(+)`. Here is "how many HOLD lots does each product have" written with `(+)`:

```sql
SELECT p.product_code AS product, COUNT(l.lot_id) AS hold_lots
FROM   products p, lots l
WHERE  l.product_id(+) = p.product_id
AND    l.status(+) = 'HOLD'
GROUP  BY p.product_code
ORDER  BY p.product_code;
```

```text
PRODUCT   HOLD_LOTS
-------- ----------
FD-300            1
PHO-300           1
PWR-200           0
RF-300            0
SIC-150           0
```

Forget the `(+)` on `l.status` and the query silently turns into an inner join. Oracle raises no error:

```sql
SELECT p.product_code AS product, COUNT(l.lot_id) AS hold_lots
FROM   products p, lots l
WHERE  l.product_id(+) = p.product_id
AND    l.status = 'HOLD'
GROUP  BY p.product_code
ORDER  BY p.product_code;
```

```text
PRODUCT   HOLD_LOTS
-------- ----------
FD-300            1
PHO-300           1
```

The ANSI version has the same trap in a different place. A filter on the right-hand table belongs in the ON clause. Put it in WHERE and it runs after the join, removes the NULL rows that the outer join added, and you are back to an inner join:

```sql
-- Wrong: same two rows as above
SELECT p.product_code AS product, COUNT(l.lot_id) AS hold_lots
FROM   products p
LEFT   JOIN lots l ON l.product_id = p.product_id
WHERE  l.status = 'HOLD'
GROUP  BY p.product_code
ORDER  BY p.product_code;

-- Right: the filter is part of the join
SELECT p.product_code AS product, COUNT(l.lot_id) AS hold_lots
FROM   products p
LEFT   JOIN lots l ON l.product_id = p.product_id
                  AND l.status = 'HOLD'
GROUP  BY p.product_code
ORDER  BY p.product_code;
```

### The outer-join count trap

`COUNT(*)` counts rows. `COUNT(column)` counts the rows where that column is not NULL. After an outer join, a parent with no match still produces one row, filled with NULLs on the child side, and `COUNT(*)` counts it:

```sql
SELECT p.product_code AS product,
       COUNT(*)        AS count_star,
       COUNT(l.lot_id) AS hold_lots
FROM   products p
LEFT   JOIN lots l ON l.product_id = p.product_id
                  AND l.status = 'HOLD'
GROUP  BY p.product_code
ORDER  BY p.product_code;
```

```text
PRODUCT  COUNT_STAR  HOLD_LOTS
-------- ---------- ----------
FD-300            1          1
PHO-300           1          1
PWR-200           1          0
RF-300            1          0
SIC-150           1          0
```

COUNT_STAR claims every product has one lot on hold. It is like counting a restaurant's guests table by table and writing down 1 for every empty table. Count a column from the outer-joined table, preferably its primary key, which is NULL only on the added row.

## Subqueries

A subquery is a SELECT inside another statement. Where you put it decides what it may return.

### Scalar subqueries and inline views

A **scalar subquery** returns at most one row and one column, so it can stand wherever a single value can, for example in the select list:

```sql
SELECT l.lot_id, l.status,
       (SELECT COUNT(*) FROM wafers w WHERE w.lot_id = l.lot_id) AS wafers
FROM   lots l
WHERE  l.product_id = 4
ORDER  BY l.lot_id;
```

```text
LOT_ID     STATUS       WAFERS
---------- -------- ----------
L26-005    HOLD              4
L26-009    ACTIVE            5
L26-012    ACTIVE            4
```

An **inline view** is a subquery in the FROM clause. It behaves like a table that exists only for this query, which lets you aggregate twice: first wafers per lot, then lots per product.

```sql
SELECT p.product_code AS product, COUNT(*) AS lots,
       ROUND(AVG(x.wafers), 1) AS avg_wafers_per_lot
FROM  (SELECT l.lot_id, l.product_id, COUNT(w.wafer_id) AS wafers
       FROM   lots l
       JOIN   wafers w ON w.lot_id = l.lot_id
       GROUP  BY l.lot_id, l.product_id) x
JOIN   products p ON p.product_id = x.product_id
GROUP  BY p.product_code
ORDER  BY p.product_code;
```

```text
PRODUCT        LOTS AVG_WAFERS_PER_LOT
-------- ---------- ------------------
FD-300            8                3.6
PHO-300           3                4.3
PWR-200           2                4.5
RF-300            3                  5
```

Inline views come back on the analytic functions page: they are how you filter on the result of an analytic function.

### Correlated subqueries

A **correlated subquery** refers to a column of the outer query, so logically it is evaluated once for each outer row. The question "which SPLIT readings in lot L26-007 had more defects than the lot's own SPLIT average" needs one:

```sql
SELECT w.lot_id, m.wafer_id, m.defect_count
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  m.step = 'SPLIT'
AND    w.lot_id = 'L26-007'
AND    m.defect_count > (SELECT AVG(m2.defect_count)
                         FROM   measurements m2
                         JOIN   wafers w2 ON w2.wafer_id = m2.wafer_id
                         WHERE  m2.step = 'SPLIT'
                         AND    w2.lot_id = w.lot_id)      -- refers to the outer row
ORDER  BY m.defect_count DESC;
```

```text
LOT_ID     WAFER_ID     DEFECT_COUNT
---------- ------------ ------------
L26-007    L26-007-04             60
L26-007    L26-007-05             48
```

The lot average is 38.6, so these are the two readings above it. Because the inner query uses `w.lot_id` from the outer row, the same statement works for any lot or for all lots at once. The analytic functions page shows a shorter way to write this kind of "compare a row with its group" query.

### EXISTS and NOT EXISTS

`EXISTS (subquery)` is true as soon as the subquery returns one row. The database can stop at the first match, and what the subquery selects does not matter, which is why people write `SELECT 1`. Products that have at least one lot on hold:

```sql
SELECT p.product_code AS product, p.family
FROM   products p
WHERE  EXISTS (SELECT 1 FROM lots l
               WHERE  l.product_id = p.product_id
               AND    l.status = 'HOLD')
ORDER  BY p.product_code;
```

```text
PRODUCT  FAMILY
-------- --------------------
FD-300   FD-SOI
PHO-300  Photonics-SOI
```

### NOT IN and NULL

This is the classic production bug. Suppose you want the lots that are nobody's parent, and you write the obvious query:

```sql
SELECT lot_id FROM lots
WHERE  lot_id NOT IN (SELECT parent_lot_id FROM lots);
```

```text
no rows selected
```

There are 16 lots and only 3 of them are parents, yet the query returns nothing. `parent_lot_id` is NULL for the 12 lots that have no parent. `x NOT IN (a, b, NULL)` means `x <> a AND x <> b AND x <> NULL`, and `x <> NULL` is never true (it is unknown), so no row qualifies. One NULL in the subquery is enough to empty the report, and nothing warns you. Picture asking "who is not on this list?" when one name on the list is smudged and unreadable. The smudge could be anybody, so Oracle will not say of anyone that they are definitely not on it.

NOT EXISTS has no such problem, because it only asks whether a matching row exists:

```sql
SELECT l.lot_id, l.lot_type
FROM   lots l
WHERE  l.lot_type <> 'PROD'
AND    NOT EXISTS (SELECT 1 FROM lots c WHERE c.parent_lot_id = l.lot_id)
ORDER  BY l.lot_id;
```

```text
LOT_ID     LOT_TYPE
---------- --------
L26-003A   SPLIT
L26-003B1  REWORK
L26-007A   SPLIT
```

Without the `lot_type` filter the NOT EXISTS version finds 13 lots that are nobody's parent. You can also rescue NOT IN by adding `WHERE parent_lot_id IS NOT NULL` inside the subquery, which also returns 13. Prefer NOT EXISTS: it stays correct when somebody later makes a column nullable.

## Set operators

Set operators combine the results of two queries with the same number of columns and compatible types. The examples compare the tools that measured two wafers of lot L26-001:

```text
WAFER_ID     STEP   TOOL_ID
------------ ------ -------
L26-001-01   SPLIT  SPL02
L26-001-01   ANNEAL ANL02
L26-001-01   FINAL  MET01
L26-001-02   SPLIT  SPL02
L26-001-02   ANNEAL ANL01
L26-001-02   FINAL  MET02
```

`UNION ALL` simply appends the second result to the first: 6 rows, with SPL02 twice. `UNION` removes duplicates: 5 rows. With two guest lists for one party, UNION ALL staples them together, and UNION merges them into one list and crosses out the people who appear twice. The crossing out is the part that costs time.

```sql
SELECT tool_id FROM measurements WHERE wafer_id = 'L26-001-01'
UNION
SELECT tool_id FROM measurements WHERE wafer_id = 'L26-001-02';
```

```text
TOOL_ID
-------
SPL02
ANL02
MET01
ANL01
MET02
```

To remove duplicates, the database has to sort or hash the whole result, which costs time and memory on large sets. UNION ALL does no such work. When the two branches cannot overlap (for example, different steps or different date ranges), or when duplicates are what you want, use UNION ALL. Notice also that the UNION output above is not in alphabetical order: if you need an order, add ORDER BY at the end of the whole statement.

`INTERSECT` returns the rows that are in both results, and `MINUS` the rows of the first result that are not in the second:

```sql
SELECT tool_id FROM measurements WHERE wafer_id = 'L26-001-01'
INTERSECT
SELECT tool_id FROM measurements WHERE wafer_id = 'L26-001-02';
```

```text
TOOL_ID
-------
SPL02
```

```sql
SELECT tool_id FROM measurements WHERE wafer_id = 'L26-001-01'
MINUS
SELECT tool_id FROM measurements WHERE wafer_id = 'L26-001-02';
```

```text
TOOL_ID
-------
ANL02
MET01
```

INTERSECT and MINUS also remove duplicates.

## NULL handling

NULL means "no value" or "unknown". Any comparison with NULL (`=`, `<>`, `<`, and so on) is unknown, never true, which is why the NOT IN query above failed. Test for NULL with `IS NULL` and `IS NOT NULL`.

Keep the missing value apart from the four-letter text `'NULL'`, too. Security researcher Joseph Tartaro chose the California vanity plate "NULL" in late 2016 and then received about $12,000 of other people's parking fines: tickets with no readable plate ended up matched to "NULL". He spoke about it at DEF CON in August 2019, and the initial fines were removed. A missing plate and a plate that says NULL are different things, and the ticket system treated them as the same. The technology journalist Christopher Null has the same trouble with his surname: in a 2015 Wired article he described how often computer systems reject or mangle it.

Other rules worth remembering:

- Aggregate functions skip NULLs. `COUNT(parent_lot_id)` counts only lots with a parent, and AVG divides by the number of non-NULL values, not by the number of rows.
- `NVL(expr, replacement)` returns the replacement when expr is NULL. `COALESCE(a, b, c, ...)` returns the first non-NULL argument.
- Concatenation with `||` treats NULL as an empty string, so `'L26' || NULL || '-001'` gives `L26-001`. Most other operators return NULL when one operand is NULL.

```sql
SELECT COUNT(*) AS all_lots, COUNT(parent_lot_id) AS with_parent,
       COUNT(hold_reason) AS with_reason
FROM   lots;
```

```text
  ALL_LOTS WITH_PARENT WITH_REASON
---------- ----------- -----------
        16           4           1
```

```sql
SELECT lot_id, NVL(parent_lot_id, '(root)') AS parent,
       COALESCE(hold_reason, parent_lot_id, 'none') AS note
FROM   lots
WHERE  product_id = 1
ORDER  BY lot_id;
```

```text
LOT_ID     PARENT       NOTE
---------- ------------ ------------------------------
L26-001    (root)       none
L26-003    (root)       none
L26-003A   L26-003      L26-003
L26-003B   L26-003      Thickness out of spec at FINAL
L26-003B1  L26-003B     L26-003B
L26-007    (root)       none
L26-007A   L26-007      L26-007
L26-011    (root)       none
```

### Oracle stores the empty string as NULL

In Oracle, a character value of length zero is NULL. If you come from SQL Server or PostgreSQL, where `''` and NULL are different values, this one will surprise you. Inserting `''` into a VARCHAR2 column stores NULL, and a condition `col = ''` compares with NULL, so it never matches:

```sql
SELECT CASE WHEN '' IS NULL THEN 'empty string is NULL' ELSE 'not null' END AS test,
       LENGTH('')     AS len,
       NVL('', 'n/a') AS nvl_result,
       'L26' || NULL || '-001' AS concat
FROM   dual;
```

```text
TEST                        LEN NVL CONCAT
-------------------- ---------- --- -------
empty string is NULL            n/a L26-001
```

`LENGTH('')` is NULL, not 0. On real data:

```sql
SELECT COUNT(*) AS eq_empty FROM lots WHERE parent_lot_id = '';
SELECT COUNT(*) AS is_null  FROM lots WHERE parent_lot_id IS NULL;
```

The first query returns 0 and the second returns 12.

The Oracle documentation notes that this behaviour may change in a future release and recommends that you do not rely on empty strings being treated as NULL. In practice, write `IS NULL` when you mean "no value", and do not write `= ''` at all.

Silent conversions like this one cause trouble far beyond Oracle. In 2020 the HUGO Gene Nomenclature Committee renamed 27 human genes, for example MARCH1 to MARCHF1 and SEPT2 to SEPTIN2, because spreadsheets kept converting the symbols to dates. A 2016 study had found Excel-caused gene name errors in 704 of 3,597 papers, almost 20%. The software changed the value on the way in without asking, which is what Oracle does with `''`.

## Limiting rows: FETCH FIRST

Since Oracle 12c the row limiting clause gives you top-N queries without ROWNUM tricks. It runs after ORDER BY, so you get the first rows of the sorted result.

```sql
SELECT wafer_id, tool_id, defect_count
FROM   measurements
WHERE  step = 'SPLIT'
ORDER  BY defect_count DESC
FETCH  FIRST 3 ROWS ONLY;
```

```text
WAFER_ID     TOOL_ID DEFECT_COUNT
------------ ------- ------------
L26-007-04   SPL01             60
L26-003B1-01 SPL01             59
L26-004-01   SPL02             57
```

Two readings share 57 defects, and ROWS ONLY picked one of them. `WITH TIES` also returns every row that ties with the last one:

```sql
SELECT wafer_id, tool_id, defect_count
FROM   measurements
WHERE  step = 'SPLIT'
ORDER  BY defect_count DESC
FETCH  FIRST 3 ROWS WITH TIES;
```

```text
WAFER_ID     TOOL_ID DEFECT_COUNT
------------ ------- ------------
L26-007-04   SPL01             60
L26-003B1-01 SPL01             59
L26-004-01   SPL02             57
L26-010-02   SPL02             57
```

`OFFSET n ROWS` skips rows first, which is how you page through a result. Give the ORDER BY a unique tie-breaker so that each page is repeatable:

```sql
SELECT wafer_id, tool_id, defect_count
FROM   measurements
WHERE  step = 'SPLIT'
ORDER  BY defect_count DESC, wafer_id
OFFSET 3 ROWS FETCH NEXT 3 ROWS ONLY;
```

```text
WAFER_ID     TOOL_ID DEFECT_COUNT
------------ ------- ------------
L26-010-02   SPL02             57
L26-003-05   SPL02             55
L26-004-05   SPL01             54
```

FETCH FIRST limits the whole result. For "the top N in each group" you need an analytic function, covered in [Analytic functions](03-analytic-functions.md).

## Common mistakes

- Counting `COUNT(*)` after an outer join. The unmatched parent row is counted as 1. Count a column of the outer-joined table.
- Putting a filter on the outer-joined table in WHERE (ANSI) or forgetting one `(+)` (Oracle syntax). Both silently turn the outer join into an inner join.
- Writing `NOT IN (subquery)` where the subquery column can be NULL. The query returns no rows. Use NOT EXISTS.
- Using UNION where UNION ALL would do, and paying for a duplicate-removing sort or hash that changes nothing.
- Expecting UNION to return sorted rows. Only ORDER BY guarantees an order.
- Writing `WHERE col = ''`. In Oracle it never matches. Use `IS NULL`.
- Mixing `JOIN ... USING (col)` with a qualified `t.col`, which raises ORA-25154.

## Check your understanding

1. A report lists every tool with `COUNT(*)` of its measurements, using `tools LEFT JOIN measurements`. A tool that never measured anything shows 1. Why, and what do you change?
2. `SELECT wafer_id FROM wafers WHERE lot_id NOT IN (SELECT parent_lot_id FROM lots)` returns no rows. Explain why, and give two ways to fix it.
3. You combine last month's and this month's measurement extracts, which cannot overlap. Should you use UNION or UNION ALL, and why?
4. A colleague's script inserts `''` into `lots.hold_reason` and later counts `WHERE hold_reason = ''`. What count do they get, and what should they write instead?
5. What does `FETCH FIRST 5 ROWS WITH TIES` return that `FETCH FIRST 5 ROWS ONLY` does not?

## Further reading

- [Oracle Database SQL Language Reference 19c: Joins](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Joins.html)
- [Oracle Database SQL Language Reference 19c: Using Subqueries](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Using-Subqueries.html)
- [Oracle Database SQL Language Reference 19c: Set Operators](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Set-Operators.html)
- [Oracle Database SQL Language Reference 19c: Nulls](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Nulls.html)
- [Oracle Database SQL Language Reference 19c: SELECT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html) (the row_limiting_clause section)
- [ORACLE-BASE: ANSI ISO SQL Support In Oracle 9i](https://oracle-base.com/articles/9i/ansi-iso-sql-support) (the Joins section)
- [ORACLE-BASE: Row Limiting Clause for Top-N Queries in Oracle Database 12c Release 1 (12.1)](https://oracle-base.com/articles/12c/row-limiting-clause-for-top-n-queries-12cr1)
- [IOActive: How a NULL License Plate Landed One Hacker in Ticket Hell](https://www.ioactive.com/article/how-a-null-license-plate-landed-one-hacker-in-ticket-hell)
- [Schneier on Security: post on the NULL licence plate](https://www.schneier.com/?p=12193)
- [Christopher Null on Wikipedia](https://en.wikipedia.org/wiki/Christopher_Null), for the background to his Wired article
- [GIGAZINE (August 2020): human genes renamed because Excel kept turning them into dates](https://www.gigazine.net/gsc_news/en/20200807-genes-rename-microsoft-excel)

To practise these techniques, work through [Lab 3: SQL review](../labs/lab-3-sql-review.md).

### Answers

1. The outer join produces one row for the unmatched tool, with NULLs in the measurement columns, and `COUNT(*)` counts that row. Use `COUNT(m.meas_id)` (or another measurement column that is never NULL on a real row), which ignores the NULL.
2. `parent_lot_id` is NULL for root lots, and `x NOT IN (..., NULL)` is never true, so every row is rejected. Rewrite it with `NOT EXISTS (SELECT 1 FROM lots p WHERE p.parent_lot_id = w.lot_id)`, or add `WHERE parent_lot_id IS NOT NULL` inside the subquery.
3. UNION ALL. The sets cannot overlap, so UNION would sort or hash the whole result to remove duplicates that do not exist.
4. Zero. Oracle stored the `''` as NULL, and `= ''` is a comparison with NULL, which is never true. Write `WHERE hold_reason IS NULL`.
5. It also returns any further rows whose ORDER BY values are equal to those of the fifth row, so the result can have more than five rows.
