# Window functions: keep the rows, add the summary

`GROUP BY` answers "what is the average per product?" but it throws the individual rows away. Maya's next questions need both at once: "Show me every FINAL reading, and next to it the average for its product, so I can see which wafers drift." This page introduces window functions (also called analytic functions), which compute a group number and leave every row in place.

Watch the animated page first: [Window functions, animated](../tutorials/01-window-functions.html).

**By the end of this page you can:**

- explain the difference between `GROUP BY` and `OVER`
- put an aggregate function such as `AVG` or `SUM` next to the detail rows with `OVER ()`
- split the rows into groups with `PARTITION BY`
- add `ORDER BY` inside `OVER` and say what it changes
- explain why a window function cannot be used in `WHERE` (`ORA-30483`) and fix it with an inline view
- calculate a share of the total, such as "percent of all defects per tool"

## The question this answers

Maya has the FINAL readings of two lots and wants to know which wafers sit above their own lot's average, and by how much. She needs the wafer's own reading and its lot average on the same line. `GROUP BY` cannot give her that, because it folds the five wafer rows of each lot into one line. By the time the average exists, `wafer_id` has gone, and adding it to the `SELECT` list only gets you `ORA-00979`. The old workaround was a `GROUP BY` subquery joined back to the readings. It reads the data twice and no longer says what you meant. A window function says it directly: work out the lot average and leave every row where it is.

## The analogy: marks in a class

A teacher has the marks of two small classes. She can print them in two ways.

Notice board (`GROUP BY`): one line per class, and the pupils are gone.

| Class | Average |
|---|---|
| 7A | 70 |
| 7B | 60 |

Report cards (`OVER`): one line per pupil, with the class average printed beside each mark.

| Pupil | Class | Mark | Class average |
|---|---|---|---|
| Asha | 7A | 80 | 70 |
| Ben | 7A | 60 | 70 |
| Chen | 7B | 50 | 60 |
| Dev | 7B | 70 | 60 |

On a report card you can see at once that Asha is 10 above her class and Ben is 10 below. On the notice board you cannot. That is the whole idea: `GROUP BY` folds many rows into one, and `OVER` keeps every row and adds the answer beside it.

**Where the picture breaks.**

- Nothing is written down. Oracle does not store the average in `MEASUREMENTS`; it works it out again each time the query runs.
- The "class" is whatever `PARTITION BY` says. Leave it out and the whole school is one class.

## What Oracle actually does

1. Build the row set. `FROM`, joins and `WHERE` run first, then `GROUP BY` and `HAVING` if present. No window function has run yet, so one in `WHERE` has nothing to compare against and Oracle refuses it.
2. Bring each partition together. Oracle usually sorts the rows by the `PARTITION BY` columns, then by any `ORDER BY` columns inside `OVER`. A plan shows this as `WINDOW SORT`. If the rows already arrive in that order, for example through an index, it shows `WINDOW BUFFER`.
3. Calculate inside each partition. Without `ORDER BY` inside `OVER` the function sees the whole partition, so every row of a lot gets the same answer. With `ORDER BY` each row sees the rows from the start of its partition down to itself.
4. Attach the answer as a new column. As many rows leave this step as entered it.
5. Finish the query: expressions that use the answer are calculated, and the final `ORDER BY` sorts the rows for display. That last sort has nothing to do with any `ORDER BY` inside `OVER`.

Nothing is kept. The sorted rows live in memory and are thrown away when the query finishes.

| In Oracle | In the class |
|---|---|
| a row | one pupil's mark |
| `WHERE` | leaving out pupils who were absent, before averaging |
| `GROUP BY` | the notice board, one line per class |
| `PARTITION BY` | which class a pupil is in |
| `OVER (...)` | printing the average on every report card |
| `OVER ()` | the whole school as one class |
| inline view or `WITH` | print the report cards first, then pick out who is above average |

## The tables you will use

All queries here join the same four tables from the basics: `MEASUREMENTS` to `WAFERS` to `LOTS` to `PRODUCTS`. Every join follows a line on the map you know:

```sql
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
```

You do not need the Day 3 add-on tables on this page.

## Step 1: what GROUP BY does to the rows

Maya: "What is the average FINAL thickness per product?"

```sql
SELECT p.product_code,
       COUNT(*)                    AS readings,
       ROUND(AVG(m.thickness_nm),1) AS avg_nm
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
GROUP  BY p.product_code
ORDER  BY p.product_code;
```
<!--gen-->
```text
PRODUCT_CODE   READINGS     AVG_NM
------------ ---------- ----------
FD-300               29         12
PHO-300               9      219.1
PWR-200               9       1528
RF-300               15       74.8
```

62 readings went in and four lines came out. You can no longer see which wafer is the odd one. The individual rows are gone, and no extra column will bring them back: a plain column such as `m.wafer_id` in this `SELECT` would raise `ORA-00979`.

## Step 2: OVER () keeps the rows

Take just lot `L26-001` for now. Maya: "Show each FINAL reading of lot L26-001 and the average of the lot's readings next to it."

```sql
SELECT m.wafer_id,
       m.thickness_nm,
       ROUND(AVG(m.thickness_nm) OVER (), 2) AS avg_lot
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  m.step = 'FINAL'
AND    w.lot_id = 'L26-001'
ORDER  BY m.wafer_id;
```
<!--gen-->
```text
WAFER_ID         THICKNESS_NM    AVG_LOT
---------------- ------------ ----------
L26-001-01              11.89      11.97
L26-001-02              11.99      11.97
L26-001-03              12.06      11.97
L26-001-04              12.03      11.97
L26-001-05              11.86      11.97
```

Five rows in, five rows out. `AVG(...)` is the same function you know. The new part is `OVER ()`. It tells Oracle: do not collapse the rows, calculate the average over the whole result and write it on every row. The empty brackets mean "the window is everything".

Now the number can be used in a calculation on the same row. Maya: "How far is each wafer from the lot average?"

```sql
SELECT m.wafer_id,
       m.thickness_nm,
       ROUND(AVG(m.thickness_nm) OVER (), 2)                    AS avg_lot,
       ROUND(m.thickness_nm - AVG(m.thickness_nm) OVER (), 2)   AS diff
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  m.step = 'FINAL'
AND    w.lot_id = 'L26-001'
ORDER  BY m.wafer_id;
```
<!--gen-->
```text
WAFER_ID         THICKNESS_NM    AVG_LOT       DIFF
---------------- ------------ ---------- ----------
L26-001-01              11.89      11.97       -.08
L26-001-02              11.99      11.97        .02
L26-001-03              12.06      11.97        .09
L26-001-04              12.03      11.97        .06
L26-001-05              11.86      11.97       -.11
```

You can write several window functions in one `SELECT`, and each one calculates its own window. They do not slow each other down in any way you need to worry about at this size.

## Step 3: PARTITION BY gives each group its own average

One average for the whole result is rarely what Maya wants. Wafers of different products have different targets, so each wafer should be compared with its own product. `PARTITION BY` splits the rows into separate windows, like the subject columns on the report card.

Maya: "For three lots, show each FINAL reading beside the average of its product."

```sql
SELECT l.lot_id,
       p.product_code,
       m.wafer_id,
       m.thickness_nm,
       ROUND(AVG(m.thickness_nm) OVER (PARTITION BY p.product_code), 2) AS avg_product,
       ROUND(m.thickness_nm
             - AVG(m.thickness_nm) OVER (PARTITION BY p.product_code), 2) AS diff
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
AND    l.lot_id IN ('L26-001', 'L26-003A', 'L26-002')
ORDER  BY p.product_code, m.wafer_id;
```
<!--gen-->
```text
LOT_ID       PRODUCT_CODE WAFER_ID         THICKNESS_NM AVG_PRODUCT       DIFF
------------ ------------ ---------------- ------------ ----------- ----------
L26-001      FD-300       L26-001-01              11.89       11.97       -.08
L26-001      FD-300       L26-001-02              11.99       11.97        .03
L26-001      FD-300       L26-001-03              12.06       11.97         .1
L26-001      FD-300       L26-001-04              12.03       11.97        .07
L26-001      FD-300       L26-001-05              11.86       11.97       -.11
L26-003A     FD-300       L26-003A-01              12.1       11.97        .14
L26-003A     FD-300       L26-003A-02             11.81       11.97       -.16
L26-003A     FD-300       L26-003A-03             11.98       11.97        .02
L26-002      RF-300       L26-002-01              75.57       74.93        .64
L26-002      RF-300       L26-002-02              74.37       74.93       -.56
L26-002      RF-300       L26-002-03              75.02       74.93        .09
L26-002      RF-300       L26-002-04              74.52       74.93       -.41
L26-002      RF-300       L26-002-05              75.19       74.93        .26
```

The `FD-300` rows share one average and the `RF-300` rows share another. `PARTITION BY` looks like `GROUP BY`, and it makes the same groups, but nothing disappears.

Read the average carefully. It is the average of the rows in this result, which only holds three lots. That is a real trap: the window sees the rows left after `WHERE`. If Maya wants the average of every FINAL reading of the product, the filter on the lots must happen after the window is calculated. The inline view in step 6 shows how.

```mermaid
flowchart LR
    A["FROM + JOIN"] --> B["WHERE"]
    B --> C["GROUP BY + HAVING"]
    C --> D["window functions<br/>(OVER)"]
    D --> E["SELECT list"]
    E --> F["ORDER BY"]
```

This is the order Oracle works in. Window functions run after `WHERE`, `GROUP BY` and `HAVING`, and before the final `ORDER BY`. Two things follow. A window only sees rows that survived the earlier steps. And a window function cannot appear in `WHERE`, because `WHERE` is already finished before the window exists.

## Step 4: a window on top of GROUP BY

Because windows run after `GROUP BY`, you can put one around an aggregate. Maya: "What share of all defects does each tool produce?"

```sql
SELECT tool_id,
       SUM(defect_count) AS defects,
       ROUND(100 * SUM(defect_count) / SUM(SUM(defect_count)) OVER (), 1) AS pct_of_all
FROM   measurements
GROUP  BY tool_id
ORDER  BY defects DESC;
```
<!--gen-->
```text
TOOL_I    DEFECTS PCT_OF_ALL
------ ---------- ----------
SPL02        1442       39.7
SPL01         894       24.6
ANL02         578       15.9
ANL01         437         12
MET01         110          3
MET03          99        2.7
MET02          74          2
```

Read `SUM(SUM(defect_count)) OVER ()` from the inside. The inner `SUM` is the ordinary group total for each tool. The outer `SUM ... OVER ()` adds up those seven totals across all lines. Dividing one by the other gives the share. The seven percentages add up to 100, apart from rounding.

## Step 5: ORDER BY inside OVER

Put `ORDER BY` inside the brackets and the window changes shape. Instead of "all rows of the group" it becomes "from the first row of the group up to this row". The result is a running figure, like a bank statement balance that grows with every line. Topic 03 goes deep on this; here is the first look.

Maya: "For lot L26-003, show the readings in time order with the defects collected so far."

```sql
SELECT m.wafer_id,
       m.step,
       TO_CHAR(m.meas_time, 'MM-DD HH24:MI') AS measured,
       m.defect_count,
       SUM(m.defect_count) OVER (ORDER BY m.meas_time) AS defects_so_far
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id = 'L26-003'
AND    m.wafer_id IN ('L26-003-01', 'L26-003-02')
ORDER  BY m.meas_time;
```
<!--gen-->
```text
WAFER_ID         STEP     MEASURED    DEFECT_COUNT DEFECTS_SO_FAR
---------------- -------- ----------- ------------ --------------
L26-003-01       SPLIT    08-11 07:15           27             27
L26-003-02       SPLIT    08-11 07:45           20             47
L26-003-01       ANNEAL   08-12 07:30           24             71
L26-003-02       ANNEAL   08-12 08:15           24             95
L26-003-01       FINAL    08-13 08:09            5            100
L26-003-02       FINAL    08-13 08:33            2            102
```

Each line adds its own defects to everything above it. Two different things are controlling the output. The `ORDER BY` inside `OVER` decides how the running total is built. The `ORDER BY` at the end decides how the rows are displayed. They are separate, and you normally want the same column in both.

## Step 6: why not in WHERE, and the inline view

Maya: "Give me the three readings with the most defects." The natural first attempt puts the window function in `WHERE`:

```sql
SELECT m.wafer_id
FROM   measurements m
WHERE  RANK() OVER (ORDER BY m.defect_count DESC) <= 3;
```
<!--gen-->
```text
WHERE  RANK() OVER (ORDER BY m.defect_count DESC) <= 3
       *
ERROR at line 3:
ORA-30483: window  functions are not allowed here
```

`ORA-30483: window functions are not allowed here`. The cause is the order shown in the diagram: `WHERE` runs before any window exists. (Some aggregate functions with `OVER` report `ORA-00934` instead when placed in `WHERE`. The reason is the same.)

The fix is to calculate the window in an inner query and filter in an outer one. Here it is for another of Maya's questions: "Which RF-300 FINAL readings are thicker than the average of their own product?" The inner query is called an inline view: a `SELECT` in the `FROM` clause that gets a name and is used like a table.

```sql
SELECT wafer_id, product_code, thickness_nm, avg_product
FROM  (SELECT w.wafer_id,
              p.product_code,
              m.thickness_nm,
              ROUND(AVG(m.thickness_nm) OVER (PARTITION BY p.product_code), 2) AS avg_product
       FROM   measurements m
       JOIN   wafers   w ON w.wafer_id   = m.wafer_id
       JOIN   lots     l ON l.lot_id     = w.lot_id
       JOIN   products p ON p.product_id = l.product_id
       WHERE  m.step = 'FINAL')
WHERE  thickness_nm > avg_product
AND    product_code = 'RF-300'
ORDER  BY wafer_id;
```
<!--gen-->
```text
WAFER_ID         PRODUCT_CODE THICKNESS_NM AVG_PRODUCT
---------------- ------------ ------------ -----------
L26-002-01       RF-300              75.57       74.83
L26-002-03       RF-300              75.02       74.83
L26-002-05       RF-300              75.19       74.83
L26-006-03       RF-300              75.47       74.83
L26-010-01       RF-300               75.6       74.83
L26-010-03       RF-300              75.64       74.83
L26-010-04       RF-300              75.03       74.83
L26-010-05       RF-300              75.15       74.83
```

The inner query works out each product's average over all FINAL readings. The outer query now sees `avg_product` as an ordinary column and can filter on it. The filter on `product_code` sits outside too, so the average was not narrowed by it. Compare with the single-lot average from step 3: the numbers differ because the window had more rows to look at.

You can write the same thing with `WITH`, which many people find easier to read from top to bottom:

```sql
WITH final_readings AS (
  SELECT w.wafer_id,
         p.product_code,
         m.thickness_nm,
         ROUND(AVG(m.thickness_nm) OVER (PARTITION BY p.product_code), 2) AS avg_product
  FROM   measurements m
  JOIN   wafers   w ON w.wafer_id   = m.wafer_id
  JOIN   lots     l ON l.lot_id     = w.lot_id
  JOIN   products p ON p.product_id = l.product_id
  WHERE  m.step = 'FINAL'
)
SELECT COUNT(*) AS above_average
FROM   final_readings
WHERE  thickness_nm > avg_product;
```
<!--gen-->
```text
ABOVE_AVERAGE
-------------
           27
```

The same pattern, "window inside, filter outside", is the answer to almost every "top one per group" question on the next page.

## Three common misreadings

**"PARTITION BY is GROUP BY with another name."** They make the same groups and that is where the likeness ends. `GROUP BY lot_id` returns one row per lot. `PARTITION BY lot_id` returns every row, each with its lot's answer. A query whose only change is adding `OVER` always returns as many rows as passed its `WHERE`.

**"The window column is part of the row, so I can filter on it."** Not in the same query. `WHERE` has finished before the window is calculated. A window function in `WHERE` gives `ORA-30483` for functions such as `RANK`, and `ORA-00934` for an aggregate such as `AVG`. Its alias gives `ORA-00904`. Print the report cards first: calculate in an inline view or `WITH`, and filter outside.

**"ORDER BY inside OVER just sorts the output."** It changes which rows each row sees, so it changes the numbers. With `OVER (PARTITION BY lot_id ORDER BY wafer_id)` the average beside L26-001-01 is 11.89, the wafer on its own, and beside L26-001-02 it is 11.94. Only the last wafer gets the full 11.97. The order of the output comes from the `ORDER BY` at the end of the query.

## Common mistakes

- Expecting `PARTITION BY` to remove rows. It only labels them. If you want fewer rows, filter in an outer query or use `GROUP BY`.
- Putting a window function in `WHERE` or `HAVING`. Move it into an inline view or `WITH` and filter outside.
- Filtering in the inner `WHERE` and being surprised that the average changed. The window only sees rows that passed `WHERE`.
- Forgetting that `OVER ()` with nothing inside means "all rows", while `OVER (ORDER BY x)` builds a running figure.
- Mixing a window function and `GROUP BY` without thinking it through. The window works on the grouped result, so everything inside it must be a group column or an aggregate.
- Using a column alias that holds a window calculation in the `WHERE` of the same query. `WHERE diff > 0` fails with `ORA-00904`; use the inline view.

## Check your understanding

1. A table has 10 rows. What does `SELECT AVG(x) FROM t` return, and what does `SELECT x, AVG(x) OVER () FROM t` return?
2. What does `PARTITION BY product_code` do that `OVER ()` does not?
3. Why does `WHERE RANK() OVER (...) = 1` fail?
4. A query has `WHERE lot_id = 'L26-001'` and `AVG(thickness_nm) OVER (PARTITION BY product_code)`. Over which rows is the average calculated?

<details>
<summary>Answers</summary>

1. The first returns one row with the average. The second returns 10 rows, each with the same average next to its own `x`.
2. It gives each product its own window, so each row gets the average of its own product instead of the average of everything.
3. `WHERE` runs before window functions are calculated, so the rank does not exist yet. Calculate it in an inline view or `WITH`, then filter in the outer query.
4. Only over the rows of lot `L26-001`, because `WHERE` removes the other rows first. To use all rows for the average, calculate it in an inline view and filter outside.

</details>

## Further reading

- [Oracle Database 19c SQL Language Reference: Analytic Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Analytic-Functions.html)
- [ORACLE-BASE: Analytic functions](https://oracle-base.com/articles/misc/analytic-functions)
