# Lab 2 solutions: Your first queries

These are the answers to the lab, with the output the test database gave. Your row counts must match. Your query may differ in spacing or in the order of the columns and still be right: what matters is the same rows.

## Exercise 1: Which tools are in bay B1?

**Maya asks:** "Which tools are in bay B1? Show me the tool id and the type, sorted by tool id."

```sql
SELECT tool_id, tool_type
FROM   tools
WHERE  bay = 'B1'
ORDER  BY tool_id;
```

<!--gen-->
```text
TOOL_ID TOOL_TYPE
------- ------------
IMP01   IMPLANT
SPL01   SPLIT
SPL02   SPLIT
```

**Why it works / what to notice.** Four steps again: looking for tools, in `TOOLS`, rows where the bay is B1, columns tool and type. Three tools sit in bay B1, and they are sorted by the text of their ids. Text sorts character by character, so `IMP01` comes before `SPL01`.

## Exercise 2: What kinds of tool do we have?

**Maya asks:** "What different types of tool do we have? Each type once, in alphabetical order."

```sql
SELECT DISTINCT tool_type
FROM   tools
ORDER  BY tool_type;
```

<!--gen-->
```text
TOOL_TYPE
------------
ANNEAL
IMPLANT
METROLOGY
POLISH
SPLIT
```

**Why it works / what to notice.** Nine tools but only five types. `DISTINCT` removes repeated values from the answer, it does not change the table. Compare with the same query without `DISTINCT` if you want to see the difference.

## Exercise 3: Two products at once

**Maya asks:** "Show me the lots of the RF-300 and PWR-200 products. Those are product ids 2 and 3. I want the lot, the product id and the status, in lot order."

```sql
SELECT lot_id, product_id, status
FROM   lots
WHERE  product_id IN (2, 3)
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     PRODUCT_ID STATUS
---------- ---------- --------
L26-002             2 SHIPPED
L26-004             3 SHIPPED
L26-006             2 SHIPPED
L26-008             3 SCRAPPED
L26-010             2 ACTIVE
```

**Why it works / what to notice.** `IN (2, 3)` is the short way to write `product_id = 2 OR product_id = 3`. Product 5 has no lots at all, which is why it never appears even if you added it to the list.

## Exercise 4: The worst readings

**Maya asks:** "Which FINAL measurements had between 15 and 20 defects? Show the measurement id, the wafer and the defect count, with the worst first. If two are equal, sort them by wafer."

```sql
SELECT meas_id, wafer_id, defect_count
FROM   measurements
WHERE  step = 'FINAL'
AND    defect_count BETWEEN 15 AND 20
ORDER  BY defect_count DESC, wafer_id;
```

<!--gen-->
```text
   MEAS_ID WAFER_ID     DEFECT_COUNT
---------- ------------ ------------
        60 L26-003B-02            20
       132 L26-008-01             20
       138 L26-008-03             20
       141 L26-008-04             20
       135 L26-008-02             19
        57 L26-003B-01            15
```

**Why it works / what to notice.** `BETWEEN` includes both ends, so a reading with exactly 15 or exactly 20 defects is in. The `DESC` belongs only to the column right before it: `wafer_id` is still sorted from A to Z.

## Exercise 5: The LIKE trap

**Maya asks:** Three small questions in a row.

- **a)** "Show me lot L26-003 and everything that came out of it." Show the lot, its type and its parent.
- **b)** "Sorry, I only wanted the lot L26-003 itself." Write the query again.
- **c)** "Now all the original lots numbered 001 to 009, nothing with a letter after the number." Show the lot and its type.

**Part a**

```sql
SELECT lot_id, lot_type, parent_lot_id
FROM   lots
WHERE  lot_id LIKE 'L26-003%'
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     LOT_TYPE PARENT_LOT_ID
---------- -------- -------------
L26-003    PROD
L26-003A   SPLIT    L26-003
L26-003B   SPLIT    L26-003
L26-003B1  REWORK   L26-003B
```

**Part b**

```sql
SELECT lot_id, lot_type, parent_lot_id
FROM   lots
WHERE  lot_id = 'L26-003';
```

<!--gen-->
```text
LOT_ID     LOT_TYPE PARENT_LOT_ID
---------- -------- -------------
L26-003    PROD
```

**Part c**

```sql
SELECT lot_id, lot_type
FROM   lots
WHERE  lot_id LIKE 'L26-00_'
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     LOT_TYPE
---------- --------
L26-001    PROD
L26-002    PROD
L26-003    PROD
L26-004    PROD
L26-005    PROD
L26-006    PROD
L26-007    PROD
L26-008    PROD
L26-009    PROD
```

**Why it works / what to notice.** Part a returns four lots, not one. `LIKE 'L26-003%'` means "starts with L26-003", so the children `L26-003A`, `L26-003B` and `L26-003B1` match too. Whether that is right depends on what Maya meant, which is why you read the result and not just the query. Part b uses `=`, which matches the whole text. In part c, `_` stands for exactly one character. `L26-001` to `L26-009` match. `L26-003A` does not, because two characters follow `L26-00`, and `L26-010` does not, because its fifth character is `1` where the pattern wants `0`.

## Exercise 6: AND and OR with brackets

**Maya asks:** "Show me the lots that are ACTIVE or on HOLD, and that are urgent. Urgent means priority 1." Show the lot, status and priority.

Write it two ways. First **without** brackets, and count the rows. Then add brackets so it says what Maya means, and count again.

**Without brackets**

```sql
SELECT lot_id, status, priority
FROM   lots
WHERE  status = 'ACTIVE' OR status = 'HOLD' AND priority = 1
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     STATUS     PRIORITY
---------- -------- ----------
L26-003    ACTIVE            1
L26-003B   HOLD              1
L26-003B1  ACTIVE            1
L26-007    ACTIVE            2
L26-007A   ACTIVE            2
L26-009    ACTIVE            2
L26-010    ACTIVE            1
L26-011    ACTIVE            3
L26-012    ACTIVE            2
```

**With brackets**

```sql
SELECT lot_id, status, priority
FROM   lots
WHERE  (status = 'ACTIVE' OR status = 'HOLD')
AND    priority = 1
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     STATUS     PRIORITY
---------- -------- ----------
L26-003    ACTIVE            1
L26-003B   HOLD              1
L26-003B1  ACTIVE            1
L26-010    ACTIVE            1
```

**Why it works / what to notice.** Without brackets the database worked out `status = 'HOLD' AND priority = 1` first, then added every ACTIVE lot of any priority, so lots with priority 2 and 3 sneaked in. With brackets you get the four lots that are really urgent. If you ever mix `AND` and `OR`, bracket it, even when you think you do not need to.

## Exercise 7: Lots started in August

**Maya asks:** "Which lots started in August 2026? Show the lot and the start date, oldest first."

```sql
SELECT lot_id, start_date
FROM   lots
WHERE  start_date >= DATE '2026-08-01'
AND    start_date <  DATE '2026-09-01'
ORDER  BY start_date;
```

<!--gen-->
```text
LOT_ID     START_DATE
---------- ----------------
L26-001    2026-08-03 07:30
L26-002    2026-08-05 09:00
L26-003    2026-08-10 06:45
L26-003A   2026-08-14 10:00
L26-003B   2026-08-14 10:05
L26-004    2026-08-18 08:15
L26-003B1  2026-08-20 13:00
L26-005    2026-08-24 11:00
L26-006    2026-08-28 07:00
```

**Why it works / what to notice.** Nine lots. The pair "on or after the first, before the first of next month" never loses a lot that started late on the 31st. `BETWEEN` with the 31st would stop at midnight and miss it.

## Exercise 8: The latest measurements

**Maya asks:** "What are the five most recent measurements? Show the measurement id, the wafer, the tool and the time, newest first."

```sql
SELECT meas_id, wafer_id, tool_id, meas_time
FROM   measurements
ORDER  BY meas_time DESC
FETCH FIRST 5 ROWS ONLY;
```

<!--gen-->
```text
   MEAS_ID WAFER_ID     TOOL_ID MEAS_TIME
---------- ------------ ------- ----------------
       186 L26-011-05   MET03   2026-09-25 10:15
       183 L26-011-04   MET02   2026-09-25 09:51
       180 L26-011-03   MET01   2026-09-25 09:27
       177 L26-011-02   MET01   2026-09-25 09:03
       174 L26-011-01   MET03   2026-09-25 08:39
```

**Why it works / what to notice.** `FETCH FIRST` goes at the very end and only makes sense after an `ORDER BY`. Without the `DESC`, you would get the five *oldest*. All five readings belong to lot L26-011, taken on the same morning.

## Stretch: a tidy board

**Maya asks:** "Give me a board of the three most urgent lots that are not yet shipped. Most urgent first, and among equals the newest start first. Name the columns Lot, Status and Urgency."

```sql
SELECT lot_id AS "Lot", status AS "Status", priority AS "Urgency"
FROM   lots
WHERE  status <> 'SHIPPED'
ORDER  BY priority, start_date DESC
FETCH FIRST 3 ROWS ONLY;
```

<!--gen-->
```text
Lot          Status      Urgency
------------ -------- ----------
L26-010      ACTIVE            1
L26-003B1    ACTIVE            1
L26-003B     HOLD              1
```

**Why it works / what to notice.** Aliases only rename the heading, so `ORDER BY` still uses the real column names. The top three are all priority 1: `L26-010` started most recently, then `L26-003B1`, then `L26-003B`.
