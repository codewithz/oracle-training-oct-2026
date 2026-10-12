# Analytic functions

Analytic functions compute a value for each row from a group of related rows (its "window") without collapsing the rows the way GROUP BY does. This page explains the OVER clause with PARTITION BY, ORDER BY and the windowing clause, then works through ranking and top-N per group, comparing rows with LAG and LEAD, running totals, moving averages, and the distribution functions RATIO_TO_REPORT, NTILE and PERCENT_RANK. It also explains why you cannot use an analytic function in WHERE.

## Keep every row, add a computed column

GROUP BY collapses each group into one row. The average SPLIT defect count of lot L26-007 is one number:

```sql
SELECT w.lot_id, ROUND(AVG(m.defect_count), 1) AS avg_split_defects
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  m.step = 'SPLIT' AND w.lot_id = 'L26-007'
GROUP  BY w.lot_id;
```

```text
LOT_ID   AVG_SPLIT_DEFECTS
-------- -----------------
L26-007               38.6
```

Often you want both: each wafer's reading and the lot figure next to it, so you can compare them. The same aggregate function with an OVER clause does that. It keeps every row and adds a column computed over the row's group. GROUP BY is the teacher who announces the class average and sends everyone home; an analytic function hands each student their own report card with the class average printed next to their mark.

```sql
SELECT w.lot_id, m.wafer_id, m.defect_count,
       ROUND(AVG(m.defect_count) OVER (PARTITION BY w.lot_id), 1) AS lot_avg,
       MAX(m.defect_count) OVER (PARTITION BY w.lot_id)           AS lot_max,
       ROUND(m.defect_count - AVG(m.defect_count) OVER (PARTITION BY w.lot_id), 1) AS diff_from_avg
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  m.step = 'SPLIT' AND w.lot_id IN ('L26-007', 'L26-007A')
ORDER  BY w.lot_id, m.wafer_id;
```

```text
LOT_ID   WAFER_ID     DEFECT_COUNT    LOT_AVG    LOT_MAX DIFF_FROM_AVG
-------- ------------ ------------ ---------- ---------- -------------
L26-007  L26-007-01             32       38.6         60          -6.6
L26-007  L26-007-02             33       38.6         60          -5.6
L26-007  L26-007-03             20       38.6         60         -18.6
L26-007  L26-007-04             60       38.6         60          21.4
L26-007  L26-007-05             48       38.6         60           9.4
L26-007A L26-007A-01            29       39.5         50         -10.5
L26-007A L26-007A-02            50       39.5         50          10.5
```

Without analytic functions you would need a self-join or a correlated subquery (as on the [SQL review](01-sql-review.md) page) or a PL/SQL loop. One analytic query replaces all of these, and the database reads the data once.

## The OVER clause

The general form is:

```text
function(arguments) OVER ( [PARTITION BY expr, ...]
                           [ORDER BY expr [ASC|DESC], ...]
                           [windowing clause] )
```

- `PARTITION BY` splits the rows into groups. The function starts again for each partition. Without PARTITION BY the whole result is one partition: `AVG(x) OVER ()` is the average over all rows.
- `ORDER BY` orders the rows inside each partition. Ranking functions and LAG/LEAD need it. For aggregates such as SUM and AVG, adding ORDER BY changes the meaning: the function then works over a growing window, which is how you get running totals (see below).
- The **windowing clause** (`ROWS ...` or `RANGE ...`) says which rows around the current row belong to its window. It needs ORDER BY.

### When analytic functions run, and why they cannot go in WHERE

Analytic functions are the last thing Oracle computes in a query, apart from the final ORDER BY. All joins, WHERE, GROUP BY and HAVING are already done. That has three consequences:

- The window only ever contains rows that passed WHERE. In the query above, the lot average is the average of SPLIT readings only, because WHERE kept only SPLIT rows.
- An analytic function can appear only in the select list or in the ORDER BY clause. If you put one in WHERE, you get ORA-30483.
- You can apply an analytic function to the result of GROUP BY, for example `SUM(COUNT(*)) OVER (...)` or `RATIO_TO_REPORT(COUNT(*)) OVER (...)`.

Order of evaluation:

```mermaid
flowchart LR
    A["FROM and JOIN"] --> B["WHERE"] --> C["GROUP BY"] --> D["HAVING"] --> E["Analytic functions<br/>OVER (...)"] --> F["SELECT list"] --> G["ORDER BY"]
```

```sql
SELECT tool_id, wafer_id, defect_count
FROM   measurements
WHERE  step = 'SPLIT'
AND    ROW_NUMBER() OVER (PARTITION BY tool_id ORDER BY defect_count DESC) <= 2;
```

```text
ORA-30483: window  functions are not allowed here
```

The fix is to compute the analytic function in an inline view (or a WITH clause) and filter in the outer query. The next section shows it.

## Ranking: ROW_NUMBER, RANK and DENSE_RANK

All three number the rows of each partition in ORDER BY order. They differ only on ties:

- `ROW_NUMBER` gives every row a different number. Between tied rows the order is arbitrary.
- `RANK` gives tied rows the same rank, then skips: 1, 2, 2, 2, 5.
- `DENSE_RANK` gives tied rows the same rank without gaps: 1, 2, 2, 2, 3.

The high jump final at the Tokyo Olympics on 1 August 2021 is RANK in real life. Mutaz Essa Barshim (Qatar) and Gianmarco Tamberi (Italy) were tied and chose to share the gold instead of a jump-off. No silver was awarded, and Maksim Nedasekau (Belarus) took bronze: 1, 1, 3. Under DENSE_RANK the next athlete would have been 2, and ROW_NUMBER would have forced someone to take silver.

Here the wafers of lot L26-002 are ranked by FINAL defect count, fewest first. Three wafers tie on 3 defects:

```sql
SELECT wafer_id, defect_count,
       ROW_NUMBER() OVER (ORDER BY defect_count) AS row_num,
       RANK()       OVER (ORDER BY defect_count) AS rnk,
       DENSE_RANK() OVER (ORDER BY defect_count) AS dense_rnk
FROM   measurements
WHERE  step = 'FINAL' AND wafer_id LIKE 'L26-002-%'
ORDER  BY defect_count, wafer_id;
```

```text
WAFER_ID     DEFECT_COUNT    ROW_NUM        RNK  DENSE_RNK
------------ ------------ ---------- ---------- ----------
L26-002-01              0          1          1          1
L26-002-02              3          2          2          2
L26-002-03              3          3          2          2
L26-002-05              3          4          2          2
L26-002-04              6          5          5          3
```

ROW_NUMBER happened to number the tied wafers 02, 03, 05, but nothing guarantees that order. When the result must be repeatable, add a tie-breaker to the ORDER BY inside OVER, for example `ORDER BY defect_count, wafer_id`.

Which one do you use? ROW_NUMBER when you need exactly N rows per group. RANK or DENSE_RANK when tied rows should be treated alike, for example "every wafer that shares first place".

### Top-N per group

FETCH FIRST limits the whole result. For "the top N in each group" you number the rows per partition in an inline view and filter outside. The two SPLIT readings with the most defects on each split tool:

```sql
SELECT tool_id, wafer_id, defect_count, rn
FROM  (SELECT tool_id, wafer_id, defect_count,
              ROW_NUMBER() OVER (PARTITION BY tool_id
                                 ORDER BY defect_count DESC, wafer_id) AS rn
       FROM   measurements
       WHERE  step = 'SPLIT')
WHERE  rn <= 2
ORDER  BY tool_id, rn;
```

```text
TOOL_ID WAFER_ID     DEFECT_COUNT         RN
------- ------------ ------------ ----------
SPL01   L26-007-04             60          1
SPL01   L26-003B1-01           59          2
SPL02   L26-004-01             57          1
SPL02   L26-010-02             57          2
```

On SPL02 the first two readings tie on 57. The `wafer_id` tie-breaker makes the numbering repeatable. If a third reading also had 57, ROW_NUMBER would still return only two rows; with `RANK() ... WHERE rnk <= 2` you would get all tied rows.

## Comparing rows: LAG and LEAD

`LAG(expr, offset, default)` returns the value of expr from a row before the current row in the window order; `LEAD` returns it from a row after. A bathroom scale that shows "minus 0.4 kg since last time" is doing LAG: it keeps the previous reading and subtracts. The offset defaults to 1 and the default value (returned when there is no such row) defaults to NULL.

Each wafer is measured after SPLIT, ANNEAL and FINAL. How did the defect count change from step to step for two wafers of lot L26-010?

```sql
SELECT wafer_id, step, defect_count,
       LAG(defect_count)  OVER (PARTITION BY wafer_id ORDER BY meas_time) AS prev_defects,
       LEAD(defect_count) OVER (PARTITION BY wafer_id ORDER BY meas_time) AS next_defects,
       defect_count - LAG(defect_count) OVER (PARTITION BY wafer_id ORDER BY meas_time) AS change
FROM   measurements
WHERE  wafer_id IN ('L26-010-02', 'L26-010-03')
ORDER  BY wafer_id, meas_time;
```

```text
WAFER_ID     STEP   DEFECT_COUNT PREV_DEFECTS NEXT_DEFECTS     CHANGE
------------ ------ ------------ ------------ ------------ ----------
L26-010-02   SPLIT            57                        15
L26-010-02   ANNEAL           15           57            6        -42
L26-010-02   FINAL             6           15                      -9
L26-010-03   SPLIT            53                        10
L26-010-03   ANNEAL           10           53            0        -43
L26-010-03   FINAL             0           10                     -10
```

PARTITION BY wafer_id makes sure the first step of one wafer is never compared with the last step of the previous wafer. The first row of each partition has no previous row, so LAG returns NULL there, and so does the difference. A default value fills that gap:

```sql
SELECT wafer_id, step,
       LAG(step, 1, '(none)') OVER (PARTITION BY wafer_id ORDER BY meas_time) AS prev_step
FROM   measurements
WHERE  wafer_id = 'L26-010-02'
ORDER  BY meas_time;
```

```text
WAFER_ID     STEP   PREV_STEP
------------ ------ ---------
L26-010-02   SPLIT  (none)
L26-010-02   ANNEAL SPLIT
L26-010-02   FINAL  ANNEAL
```

FIRST_VALUE and LAST_VALUE are related: they return the value from the first or last row of the window.

## Windows: running totals and moving averages

When an aggregate such as SUM or AVG has an ORDER BY inside OVER, it no longer looks at the whole partition. It looks at a window of rows defined relative to the current row. The windowing clause sets that window:

```text
{ROWS | RANGE} BETWEEN <start> AND <end>
   start/end: UNBOUNDED PRECEDING | n PRECEDING | CURRENT ROW | n FOLLOWING | UNBOUNDED FOLLOWING
```

- `ROWS` counts physical rows: `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` is the current row and the two before it.
- `RANGE` is a logical offset on the ORDER BY value: `RANGE BETWEEN INTERVAL '1' DAY PRECEDING AND CURRENT ROW` is every row whose timestamp lies within one day before the current row's. RANGE with an offset needs a single numeric or date ORDER BY expression.

### The default window, and why ties matter

If you write ORDER BY and no windowing clause, the default is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. That gives a running total, but because it is RANGE, all rows with the same ORDER BY value are "the current row" together and get the same total.

The query below adds up the defects of two wafers of lot L26-002, day by day. The first total uses the default window; the second uses ROWS and a unique ordering:

```sql
SELECT TRUNC(meas_time) AS meas_day, wafer_id, step, defect_count,
       SUM(defect_count) OVER (ORDER BY TRUNC(meas_time))           AS range_default,
       SUM(defect_count) OVER (ORDER BY TRUNC(meas_time), meas_id
                               ROWS UNBOUNDED PRECEDING)             AS rows_running
FROM   measurements
WHERE  wafer_id IN ('L26-002-01', 'L26-002-02')
ORDER  BY meas_day, meas_id;
```

```text
MEAS_DAY         WAFER_ID     STEP   DEFECT_COUNT RANGE_DEFAULT ROWS_RUNNING
---------------- ------------ ------ ------------ ------------- ------------
2026-08-06 00:00 L26-002-01   SPLIT            20            40           20
2026-08-06 00:00 L26-002-02   SPLIT            20            40           40
2026-08-07 00:00 L26-002-01   ANNEAL           20            67           60
2026-08-07 00:00 L26-002-02   ANNEAL            7            67           67
2026-08-08 00:00 L26-002-01   FINAL             0            70           67
2026-08-08 00:00 L26-002-02   FINAL             3            70           70
```

RANGE_DEFAULT is a running total per day: both rows of a day show the total up to the end of that day. ROWS_RUNNING grows row by row. Both are correct answers to different questions. Decide which one you mean and write the window explicitly; if you rely on the default, ties in the ORDER BY column will give you per-value totals whether you wanted them or not. (`ROWS UNBOUNDED PRECEDING` is short for `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.)

You can also combine an analytic function with GROUP BY: `SUM(COUNT(*)) OVER (ORDER BY ...)` first counts per group, then runs the total over the grouped rows.

### Moving averages and time-based windows

A moving average smooths a noisy series, which makes drift easier to see. If you have worked with SPC charts, it is the same idea: look at the last few readings together so that one noisy measurement does not set off an alarm. This query looks at the first ten readings of split tool SPL02. AVG_LAST_3 averages the current reading and the two before it (ROWS). READINGS_24H counts how many readings the tool took in the 24 hours up to the current one (RANGE with an interval):

```sql
SELECT meas_time, wafer_id, defect_count,
       ROUND(AVG(defect_count) OVER (ORDER BY meas_time
                                     ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS avg_last_3,
       COUNT(*) OVER (ORDER BY meas_time
                      RANGE BETWEEN INTERVAL '1' DAY PRECEDING AND CURRENT ROW)   AS readings_24h
FROM   measurements
WHERE  tool_id = 'SPL02'
ORDER  BY meas_time
FETCH  FIRST 10 ROWS ONLY;
```

```text
MEAS_TIME        WAFER_ID     DEFECT_COUNT AVG_LAST_3 READINGS_24H
---------------- ------------ ------------ ---------- ------------
2026-08-04 08:00 L26-001-01             42         42            1
2026-08-04 08:30 L26-001-02             37       39.5            2
2026-08-04 09:00 L26-001-03             44         41            3
2026-08-04 09:30 L26-001-04             48         43            4
2026-08-06 09:30 L26-002-01             20       37.3            1
2026-08-06 10:30 L26-002-03             28         32            2
2026-08-06 11:30 L26-002-05             52       33.3            3
2026-08-11 07:15 L26-003-01             27       35.7            1
2026-08-11 08:15 L26-003-03             33       37.3            2
2026-08-11 09:15 L26-003-05             55       38.3            3
```

At the start of the series the window is shorter than three rows, so the first two averages use one and two readings. The ROWS window ignores the gap between 4 and 6 August; the RANGE window does not, which is why READINGS_24H drops back to 1. FETCH FIRST runs after the analytic functions, so every value above was computed over the tool's full series.

## Distribution: RATIO_TO_REPORT, NTILE and PERCENT_RANK

`RATIO_TO_REPORT(expr) OVER (PARTITION BY ...)` returns expr divided by the sum of expr over the partition: each row's share of its group. Quality engineers will recognise the numbers behind a Pareto chart. Applied to a GROUP BY result, it shows how the readings of each process step are spread over the tools:

```sql
SELECT step, tool_id, COUNT(*) AS readings,
       ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (PARTITION BY step), 1) AS pct_of_step
FROM   measurements
GROUP  BY step, tool_id
ORDER  BY step, tool_id;
```

```text
STEP   TOOL_ID   READINGS PCT_OF_STEP
------ ------- ---------- -----------
ANNEAL ANL01           28        45.2
ANNEAL ANL02           34        54.8
FINAL  MET01           21        33.9
FINAL  MET02           20        32.3
FINAL  MET03           21        33.9
SPLIT  SPL01           25        40.3
SPLIT  SPL02           37        59.7
```

RATIO_TO_REPORT takes only PARTITION BY in its OVER clause; adding ORDER BY raises ORA-30487. With an empty `OVER ()` the share is of the grand total.

`NTILE(n)` divides the ordered rows into n buckets of nearly equal size and returns the bucket number (quartiles with n = 4). `PERCENT_RANK` returns the relative position of the row, from 0 for the first row to 1 for the last. Here are the FINAL thicknesses of the PHO-300 wafers, split into thirds:

```sql
SELECT m.wafer_id, m.thickness_nm,
       NTILE(3)       OVER (ORDER BY m.thickness_nm)           AS third,
       ROUND(PERCENT_RANK() OVER (ORDER BY m.thickness_nm), 2) AS pct_rank
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
JOIN   lots   l ON l.lot_id   = w.lot_id
WHERE  m.step = 'FINAL' AND l.product_id = 4
ORDER  BY m.thickness_nm;
```

```text
WAFER_ID     THICKNESS_NM      THIRD   PCT_RANK
------------ ------------ ---------- ----------
L26-005-04         215.62          1          0
L26-009-04          216.6          1        .13
L26-005-03         216.63          1        .25
L26-009-03         217.67          2        .38
L26-005-02         219.76          2         .5
L26-009-02         220.11          2        .63
L26-005-01         221.07          3        .75
L26-009-05         221.72          3        .88
L26-009-01         222.79          3          1
```

When the rows do not divide evenly, the lower-numbered buckets get one extra row each. CUME_DIST is similar to PERCENT_RANK; it returns the fraction of rows with a value less than or equal to the current row's.

## Common mistakes

- Putting an analytic function in WHERE or HAVING (ORA-30483). Compute it in an inline view and filter outside.
- Using ROW_NUMBER without a tie-breaker and getting different rows from run to run.
- Relying on the default window (RANGE) for a running total when the ORDER BY column has ties. Tied rows get the same total. Write `ROWS ...` explicitly when you want row-by-row totals.
- Forgetting PARTITION BY in LAG or LEAD, so the first row of one group is compared with the last row of the previous group.
- Expecting the window to include rows that WHERE removed. Analytic functions only see rows that survived WHERE, GROUP BY and HAVING.

## Check your understanding

1. A query uses `WHERE RANK() OVER (ORDER BY defect_count DESC) = 1`. What happens, and how do you rewrite it?
2. Four readings have defect counts 9, 7, 7 and 4. What do ROW_NUMBER, RANK and DENSE_RANK return when ordered by defect count descending?
3. You write `SUM(defect_count) OVER (ORDER BY TRUNC(meas_time))` and several rows show the same running total. Why? How do you make the total grow row by row?
4. Which window gives a moving average of the current reading and the four before it?
5. What does `RATIO_TO_REPORT(SUM(defect_count)) OVER ()` return for each row of a query grouped by product?

## Further reading

- [Oracle Database SQL Language Reference 19c: Analytic Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Analytic-Functions.html)
- [Oracle Database Data Warehousing Guide 19c: SQL for Analysis and Reporting](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/sql-analysis-reporting-data-warehouses.html)
- [Oracle Database SQL Language Reference 19c: ROW_NUMBER](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ROW_NUMBER.html), [RANK](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/RANK.html), [DENSE_RANK](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/DENSE_RANK.html)
- [Oracle Database SQL Language Reference 19c: LAG](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LAG.html)
- [Oracle Database SQL Language Reference 19c: RATIO_TO_REPORT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/RATIO_TO_REPORT.html)
- [Oracle Database SQL Language Reference 19c: NTILE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/NTILE.html)
- [ORACLE-BASE: Analytic Functions](https://oracle-base.com/articles/misc/analytic-functions)
- [ORACLE-BASE: RANK and DENSE_RANK Analytic Functions](https://oracle-base.com/articles/misc/rank-dense-rank-first-last-analytic-functions)
- [ORACLE-BASE: LAG and LEAD Analytic Functions](https://oracle-base.com/articles/misc/lag-lead-analytic-functions)
- [CBS Sports: Tokyo Olympics high jumpers Mutaz Essa Barshim and Gianmarco Tamberi share gold medal](https://www.cbssports.com/olympics/news/2020-tokyo-olympics-high-jumpers-mutaz-essa-barshim-of-qatar-and-gianmarco-tamberi-of-italy-share-gold-medal)

To practise, work through [Lab 4: Analytic functions](../labs/lab-4-analytic-functions.md).

### Answers

1. Oracle raises ORA-30483, because analytic functions are computed after WHERE. Compute the rank in an inline view, `SELECT ... FROM (SELECT ..., RANK() OVER (ORDER BY defect_count DESC) AS rnk FROM ...) WHERE rnk = 1`.
2. ROW_NUMBER: 1, 2, 3, 4. RANK: 1, 2, 2, 4. DENSE_RANK: 1, 2, 2, 3.
3. With ORDER BY and no windowing clause the window is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. All rows with the same day are peers and get the same total. Add a unique column to the ORDER BY and write `ROWS UNBOUNDED PRECEDING`.
4. `AVG(...) OVER (ORDER BY ... ROWS BETWEEN 4 PRECEDING AND CURRENT ROW)`, with PARTITION BY if the series is per tool or per wafer.
5. Each product's defect total divided by the total over all products, that is, its share of all defects (a value between 0 and 1).
