# Running totals, moving averages and LAG/LEAD

Some of Maya's questions are about neighbours. "How much did the thickness change since the last reading?" "How many defects have we collected so far this week?" "How long was this lot on hold?" Each one compares a row with the rows before or after it. This page covers `LAG` and `LEAD`, running totals, moving averages and the windowing clause, and ends with the hold-time report from the `LOT_HISTORY` table.

Watch the animated page first: [Running totals and LAG/LEAD, animated](../tutorials/03-running-totals-and-lag-lead.html).

**By the end of this page you can:**

- read the previous or next row's value with `LAG` and `LEAD`
- explain the `NULL` on the first or last row and handle it
- build a running total with `SUM(...) OVER (ORDER BY ...)`
- write a moving average with `ROWS BETWEEN n PRECEDING AND CURRENT ROW`
- explain the default `RANGE` window and why it surprises people when values tie
- calculate how long a lot spent on hold from `LOT_HISTORY`

You need the Day 3 add-on tables for the last part. Lab 8 loads them.

## The question this answers

Maya's next four questions all depend on order. How many defects have we collected so far, wafer by wafer? What is the average of the last three wafers? How much did this wafer change from the one before? How long did lot L26-003 sit on hold? Topic 01 gave every row a pile to look at, but a pile has no order inside it. "So far", "the last three" and "the one before" only mean something once the rows stand in a line. The word that puts them in a line is `ORDER BY` inside `OVER`.

## The analogy: a bank statement

A bank statement lists your spending in date order. Because the lines are in order, it can answer questions that a heap of receipts cannot.

| Day | Spent | Total so far | Average of last 3 days | Day before | Change |
|---|---|---|---|---|---|
| Mon | 30 | 30 | 30 | blank | blank |
| Tue | 60 | 90 | 45 | 30 | 30 |
| Wed | 90 | 180 | 60 | 60 | 30 |
| Thu | 30 | 210 | 60 | 90 | -60 |
| Fri | 60 | 270 | 60 | 30 | 30 |

- Total so far is a running total: this line plus every line above it. `SUM(...) OVER (ORDER BY day)`.
- Average of the last 3 days uses only this line and the two above it. The group of lines moves down with you. That group is the frame.
- Day before looks at the line above. That is `LAG`. Looking at the line below is `LEAD`. On Monday there is no line above, so the answer is blank (NULL).

One more use. A bus timetable lists when each bus arrives, but not the gap between buses. You get the gap by looking at the next line and subtracting.

| Bus | Arrives | Minutes until the next bus |
|---|---|---|
| 1 | 08:00 | 20 |
| 2 | 08:20 | 30 |
| 3 | 08:50 | blank |

Shuffle the statement lines and every column becomes nonsense. "So far" and "the line above" only mean something when the order is fixed.

**Where the picture breaks.**

- If two rows tie in the sort column, Oracle's default frame takes in both at once, so "so far" jumps instead of growing one line at a time.
- The order is the one you write in `ORDER BY` inside `OVER`, not the order the rows happen to be stored in.
- If `WHERE` removes a row first, the neighbours change. Cancel bus 2 before looking and the gap after bus 1 becomes 50 minutes.

## What Oracle actually does

1. Build the row set. A row that `WHERE` removed is in nobody's frame and is nobody's neighbour.
2. Cut into partitions if there is a `PARTITION BY`, then sort each by the `ORDER BY` inside `OVER`.
3. For every row, decide its frame. With no `ORDER BY` the frame is the whole partition. With `ORDER BY` and no frame clause it runs from the first row to the current row, plus rows that tie with the current row (`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`). With `ROWS BETWEEN a AND b` you choose, counted in physical rows: `2 PRECEDING` means two rows above, so at most three rows with the current one.
4. Apply the function to the frame. Near the top the frame has fewer rows.
5. `LAG(x, n, default)` and `LEAD(x, n, default)` use no frame. They step n rows back or forward in the sorted list (1 if omitted) and return that row's value, or the default, or NULL if the step falls off the partition.
6. Attach the answers as new columns. No rows are lost. Filtering on them needs an inner query.

| In Oracle | On the statement |
|---|---|
| `ORDER BY` inside `OVER` | the date order of the lines |
| `SUM(x) OVER (ORDER BY t)` | total so far |
| `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` | average of the last 3 days |
| `LAG(x)` / `LEAD(x)` | the line above / below |
| `LEAD(t) - t` | next bus time minus this one |
| inline view, then filter | work out the gaps first, then pick the lines you want |

## Step 1: LAG and LEAD

Maya: "For wafer L26-003-01, show every reading, the previous thickness and the change since then."

```sql
SELECT step,
       TO_CHAR(meas_time, 'MM-DD HH24:MI')                     AS measured,
       thickness_nm,
       LAG(thickness_nm)  OVER (ORDER BY meas_time)             AS prev_nm,
       thickness_nm - LAG(thickness_nm) OVER (ORDER BY meas_time) AS change_nm,
       LEAD(step)         OVER (ORDER BY meas_time)             AS next_step
FROM   measurements
WHERE  wafer_id = 'L26-003-01'
ORDER  BY meas_time;
```
<!--gen-->
```text
STEP     MEASURED    THICKNESS_NM    PREV_NM  CHANGE_NM NEXT_STE
-------- ----------- ------------ ---------- ---------- --------
SPLIT    08-11 07:15        15.78                       ANNEAL
ANNEAL   08-12 07:30        13.01      15.78      -2.77 FINAL
FINAL    08-13 08:09        12.07      13.01       -.94
```

`LAG(thickness_nm)` is "the thickness on the previous row, in the order given". `LEAD(step)` is "the step on the next row". The first row has no previous reading, so `prev_nm` and `change_nm` are `NULL`. The last row has no next row, so `next_step` is `NULL`. This is how the data should look. A blank is not an error.

You can give `LAG` and `LEAD` an offset and a default: `LAG(x, 2)` looks two rows back, and `LAG(x, 1, 0)` returns 0 instead of `NULL` when there is no previous row. Use the default with care. A change of 0 and a missing change are different facts.

### With PARTITION BY: restart for every wafer

The query above had one wafer in it. For many wafers at once, the "previous" row must stay within the same wafer. Add `PARTITION BY wafer_id`, as on the report card.

Maya: "For lot L26-003, how did each wafer's thickness change from step to step? Wafers 1 and 2 will do."

```sql
SELECT wafer_id,
       step,
       thickness_nm,
       LAG(thickness_nm) OVER (PARTITION BY wafer_id ORDER BY meas_time) AS prev_nm,
       ROUND(thickness_nm - LAG(thickness_nm) OVER (PARTITION BY wafer_id ORDER BY meas_time), 2) AS change_nm
FROM   measurements
WHERE  wafer_id IN ('L26-003-01', 'L26-003-02')
ORDER  BY wafer_id, meas_time;
```
<!--gen-->
```text
WAFER_ID         STEP     THICKNESS_NM    PREV_NM  CHANGE_NM
---------------- -------- ------------ ---------- ----------
L26-003-01       SPLIT           15.78
L26-003-01       ANNEAL          13.01      15.78      -2.77
L26-003-01       FINAL           12.07      13.01       -.94
L26-003-02       SPLIT           15.97
L26-003-02       ANNEAL          13.27      15.97       -2.7
L26-003-02       FINAL           12.07      13.27       -1.2
```

Each wafer starts with a blank. If you forget the `PARTITION BY`, the first reading of wafer 2 would be compared with the last reading of wafer 1, and the number would look plausible but mean nothing.

## Step 2: running totals

Put `SUM` in a window with `ORDER BY` and you get a running total. Maya: "How many defects have we collected, day by day, since the first reading?" First total the defects per day with `GROUP BY`, then run a window over the daily lines.

```sql
SELECT TO_CHAR(TRUNC(meas_time), 'YYYY-MM-DD')       AS day,
       COUNT(*)                                      AS readings,
       SUM(defect_count)                             AS defects,
       SUM(SUM(defect_count)) OVER (ORDER BY TRUNC(meas_time)) AS defects_to_date
FROM   measurements
GROUP  BY TRUNC(meas_time)
ORDER  BY TRUNC(meas_time)
FETCH FIRST 8 ROWS ONLY;
```
<!--gen-->
```text
DAY          READINGS    DEFECTS DEFECTS_TO_DATE
---------- ---------- ---------- ---------------
2026-08-04          5        204             204
2026-08-05          5         80             284
2026-08-06         10        155             439
2026-08-07          5         60             499
2026-08-08          5         15             514
2026-08-11          5        159             673
2026-08-12          5        108             781
2026-08-13          5         15             796
```

Check one line by hand: 204 + 80 = 284. There are no readings on 08-09 and 08-10, so those days do not appear. The running total simply carries on from 08-08 to 08-11.

A running total can restart for each group, as the bank would do per account. Maya: "For the two small lots L26-003A and L26-007A, show the defects collected so far in each lot, reading by reading."

```sql
SELECT w.lot_id,
       m.wafer_id,
       m.step,
       m.defect_count,
       SUM(m.defect_count) OVER (PARTITION BY w.lot_id ORDER BY m.meas_time) AS lot_defects_so_far
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id IN ('L26-003A', 'L26-007A')
ORDER  BY w.lot_id, m.meas_time;
```
<!--gen-->
```text
LOT_ID       WAFER_ID         STEP     DEFECT_COUNT LOT_DEFECTS_SO_FAR
------------ ---------------- -------- ------------ ------------------
L26-003A     L26-003A-01      SPLIT              50                 50
L26-003A     L26-003A-02      SPLIT              49                 99
L26-003A     L26-003A-03      SPLIT              26                125
L26-003A     L26-003A-01      ANNEAL             12                137
L26-003A     L26-003A-02      ANNEAL             15                152
L26-003A     L26-003A-03      ANNEAL             18                170
L26-003A     L26-003A-01      FINAL               0                170
L26-003A     L26-003A-02      FINAL               2                172
L26-003A     L26-003A-03      FINAL               0                172
L26-007A     L26-007A-01      SPLIT              29                 29
L26-007A     L26-007A-02      SPLIT              50                 79
L26-007A     L26-007A-01      ANNEAL             17                 96
L26-007A     L26-007A-02      ANNEAL             16                112
L26-007A     L26-007A-01      FINAL               1                113
L26-007A     L26-007A-02      FINAL               0                113
```

The total restarts at the start of the second lot. The last line of each lot equals that lot's total from the earlier ranking page: `L26-003A` 172 and `L26-007A` 113.

## Step 3: moving averages and the windowing clause

A running total looks back to the very first row. A moving average looks back only a few rows. You say how far with a **windowing clause**:

```sql
AVG(x) OVER (ORDER BY d ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
```

Read it as: for each row, take this row and the two rows before it. The window slides down by one row at a time, like a ruler held over a column of numbers. Maya: "Give me the three-day moving average of daily defects."

```sql
SELECT TO_CHAR(d, 'MM-DD') AS day,
       defects,
       ROUND(AVG(defects) OVER (ORDER BY d
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS moving_avg_3
FROM  (SELECT TRUNC(meas_time) AS d, SUM(defect_count) AS defects
       FROM   measurements
       GROUP  BY TRUNC(meas_time))
ORDER  BY d
FETCH FIRST 8 ROWS ONLY;
```
<!--gen-->
```text
DAY      DEFECTS MOVING_AVG_3
----- ---------- ------------
08-04        204          204
08-05         80          142
08-06        155        146.3
08-07         60         98.3
08-08         15         76.7
08-11        159           78
08-12        108           94
08-13         15           94
```

On the first row only one value exists, so the average is that value (204). On the second row there are two. From the third row on there are three: (204 + 80 + 155) / 3 = 146.3. The window is shorter at the start, which is worth saying in a report.

The common frame forms:

| Window | Meaning |
| --- | --- |
| `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | from the first row to this one (a running total) |
| `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` | this row and the two before it |
| `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING` | one before, this one, one after |
| `ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING` | this row to the end |

`ROWS` counts rows. `RANGE` counts values. Compare them over the same data. The dates 08-08 and 08-11 are three calendar days apart (there are no readings on 08-09 and 08-10), and the next query shows what each frame does across that gap.

```sql
SELECT TO_CHAR(d, 'MM-DD') AS day,
       defects,
       ROUND(AVG(defects) OVER (ORDER BY d ROWS  BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS last_3_rows,
       ROUND(AVG(defects) OVER (ORDER BY d RANGE BETWEEN INTERVAL '2' DAY PRECEDING AND CURRENT ROW), 1) AS last_3_days
FROM  (SELECT TRUNC(meas_time) AS d, SUM(defect_count) AS defects
       FROM   measurements
       GROUP  BY TRUNC(meas_time))
ORDER  BY d
FETCH FIRST 8 ROWS ONLY;
```
<!--gen-->
```text
DAY      DEFECTS LAST_3_ROWS LAST_3_DAYS
----- ---------- ----------- -----------
08-04        204         204         204
08-05         80         142         142
08-06        155       146.3       146.3
08-07         60        98.3        98.3
08-08         15        76.7        76.7
08-11        159          78         159
08-12        108          94       133.5
08-13         15          94          94
```

On 08-11, "last 3 rows" reaches back over the gap to 08-08 and 08-07, so the average is 78. "Last 3 days" covers 08-09 to 08-11, where only 08-11 has a reading, so it is 159. Decide which one Maya means before you choose.

## Step 4: the default window and the RANGE trap

If you write `ORDER BY` inside `OVER` and no windowing clause, Oracle uses this frame without telling you:

```sql
RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
```

For a column without repeated values this is a normal running total. With ties it is not. `RANGE` treats rows with the same `ORDER BY` value as one unit, so all of them get the same total, and that total already includes every tied row.

Five wafers of lot `L26-001` were measured on the same day at SPLIT. Here is the running total ordered by day only:

```sql
SELECT wafer_id,
       defect_count,
       SUM(defect_count) OVER (ORDER BY TRUNC(meas_time))                         AS default_range,
       SUM(defect_count) OVER (ORDER BY TRUNC(meas_time), meas_id
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  AS rows_running
FROM   measurements
WHERE  wafer_id LIKE 'L26-001-0%'
AND    step = 'SPLIT'
ORDER  BY meas_id;
```
<!--gen-->
```text
WAFER_ID         DEFECT_COUNT DEFAULT_RANGE ROWS_RUNNING
---------------- ------------ ------------- ------------
L26-001-01                 42           204           42
L26-001-02                 37           204           79
L26-001-03                 44           204          123
L26-001-04                 48           204          171
L26-001-05                 33           204          204
```

`default_range` shows 204 on every line, because all five rows share the same day and count as one unit. A reader of the report would think 204 defects were found on the first wafer. `rows_running` grows 42, 79, 123, 171, 204 as expected: the explicit `ROWS` frame counts one row at a time, and `meas_id` in the `ORDER BY` removes the tie.

Two habits keep you safe:

- When you want a running total, write the frame: `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
- Make the `ORDER BY` inside `OVER` unique, by adding a key such as `meas_id`. With a `ROWS` frame and ties, the order among the tied rows is arbitrary, and the running total at each row would be arbitrary too.

## Step 5: how long was each lot on hold?

Now a real reporting question. `LOT_HISTORY` has one row per status change: when it happened, the old and new status. A hold starts on a row with `new_status = 'HOLD'` and ends at the lot's next status change. So the length of a hold is "the next row's `changed_at`, minus this row's `changed_at`".

Look at one lot first. Maya: "Walk me through the history of L26-003B."

```sql
SELECT lot_id,
       old_status,
       new_status,
       TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI') AS changed,
       TO_CHAR(LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at),
               'YYYY-MM-DD HH24:MI')             AS next_change
FROM   lot_history
WHERE  lot_id = 'L26-003B'
ORDER  BY changed_at;
```
<!--gen-->
```text
LOT_ID       OLD_STAT NEW_STAT CHANGED          NEXT_CHANGE
------------ -------- -------- ---------------- ----------------
L26-003B              ACTIVE   2026-08-14 10:05 2026-08-16 08:05
L26-003B     ACTIVE   HOLD     2026-08-16 08:05 2026-08-17 05:05
L26-003B     HOLD     ACTIVE   2026-08-17 05:05 2026-08-19 08:05
L26-003B     ACTIVE   HOLD     2026-08-19 08:05
```

Each row's `next_change` is the time the status changed away from `new_status`. For the `HOLD` rows, that is the end of the hold. The last row has no next row. For `L26-003B` the last row is a `HOLD`, so that hold has not ended yet.

Date subtraction in Oracle gives days. Multiply by 24 for hours.

```sql
SELECT lot_id, started, hours_on_hold
FROM  (SELECT lot_id,
              new_status,
              TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI') AS started,
              ROUND((LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at)
                     - changed_at) * 24, 1)              AS hours_on_hold
       FROM   lot_history)
WHERE  new_status = 'HOLD'
AND    hours_on_hold IS NOT NULL
ORDER  BY hours_on_hold DESC, lot_id
FETCH FIRST 5 ROWS ONLY;
```
<!--gen-->
```text
LOT_ID       STARTED          HOURS_ON_HOLD
------------ ---------------- -------------
L26-003      2026-08-14 18:45            42
L26-004      2026-08-26 13:15            41
L26-009      2026-09-22 14:00            41
L26-010      2026-09-17 17:45            40
L26-003      2026-08-11 14:45            39
```

This is the pattern. The window function goes in the inner query. The filter `new_status = 'HOLD'` goes outside, because it must come after the `LEAD` has looked at the neighbour. Had you put `WHERE new_status = 'HOLD'` in the inner query, `LEAD` would look at the next `HOLD` row, not at the release, and the hours would be wrong. The first release after a hold is exactly the row you filtered away.

> The filter that picks the rows to report must come after the window function that looks at its neighbours.

### Holds that have not ended

Two lots are on hold right now, so the `LEAD` is `NULL` for their last hold. They are excluded above by `hours_on_hold IS NOT NULL`. To include them, count up to a reference time. The data were generated as of 2026-10-10 12:00, so the examples use that fixed time instead of `SYSDATE`, which gives the same answer on every laptop.

```sql
SELECT lot_id,
       TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI') AS hold_since,
       ROUND((COALESCE(next_change, TO_DATE('2026-10-10 12:00', 'YYYY-MM-DD HH24:MI'))
              - changed_at) * 24)               AS hours_so_far,
       CASE WHEN next_change IS NULL THEN 'still on hold' ELSE 'released' END AS state
FROM  (SELECT lot_id, new_status, changed_at,
              LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at) AS next_change
       FROM   lot_history)
WHERE  new_status = 'HOLD'
AND    next_change IS NULL
ORDER  BY lot_id;
```
<!--gen-->
```text
LOT_ID       HOLD_SINCE       HOURS_SO_FAR STATE
------------ ---------------- ------------ -------------
L26-003B     2026-08-19 08:05         1252 still on hold
L26-005      2026-09-05 00:00          852 still on hold
```

Those two are the open holds, matching the two lots with status `HOLD` in the `LOTS` table. In your own reports use `SYSDATE` when the question is "how long so far, right now".

### Total, longest and number of hold episodes per lot

Maya: "For every lot, how many times was it on hold, how many hours in total, and how long was the longest hold?" Wrap the neighbour calculation once, then use plain `GROUP BY` on top.

```sql
SELECT lot_id,
       COUNT(*)                   AS hold_episodes,
       ROUND(SUM(hours_on_hold))  AS total_hours,
       ROUND(MAX(hours_on_hold))  AS longest_hours
FROM  (SELECT lot_id,
              new_status,
              (LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at)
               - changed_at) * 24 AS hours_on_hold
       FROM   lot_history)
WHERE  new_status = 'HOLD'
GROUP  BY lot_id
ORDER  BY total_hours DESC NULLS LAST, lot_id
FETCH FIRST 6 ROWS ONLY;
```
<!--gen-->
```text
LOT_ID       HOLD_EPISODES TOTAL_HOURS LONGEST_HOURS
------------ ------------- ----------- -------------
L26-009                  6         179            41
L26-004                  5         150            41
L26-003                  6         119            42
L26-006                  4         118            34
L26-001                  5         115            29
L26-012                  4         106            31
```

`SUM` and `MAX` skip `NULL`, so an open hold adds nothing to the total here. Note how `COUNT(*)` still counts it as an episode. State this in the report, or add the open time with the `COALESCE` from the last query.

### Lots that bounced back and forth

Counting the `HOLD` rows is all you need for the number of episodes, and it needs no window function at all.

```sql
SELECT lot_id, COUNT(*) AS hold_episodes
FROM   lot_history
WHERE  new_status = 'HOLD'
GROUP  BY lot_id
HAVING COUNT(*) >= 5
ORDER  BY hold_episodes DESC, lot_id;
```
<!--gen-->
```text
LOT_ID       HOLD_EPISODES
------------ -------------
L26-003                  6
L26-005                  6
L26-009                  6
L26-001                  5
L26-004                  5
L26-007A                 5
```

Six lots went on hold five times or more. When the answer is a count, ask whether you need a window at all.

### A check with LAG: does the history chain up?

Each row's `old_status` should equal the previous row's `new_status` for the same lot. `LAG` tests it. A query for rows that break the rule should return nothing:

```sql
SELECT lot_id, hist_id, old_status, prev_new_status
FROM  (SELECT lot_id, hist_id, old_status,
              LAG(new_status) OVER (PARTITION BY lot_id ORDER BY changed_at) AS prev_new_status
       FROM   lot_history)
WHERE  old_status <> prev_new_status;
```
<!--gen-->
```text
no rows selected
```

No rows, so the history is consistent. Rows where either side is `NULL` (the first row of each lot) are not compared, since `NULL <> x` is not true. That is the behaviour you want here, but remember it.

## Three common misreadings

**"2 PRECEDING means an average of two rows."** It means two rows above plus the current row: three rows. The first two results use fewer rows.

**"ORDER BY alone gives a running total one row at a time."** Not with ties. The default frame takes in every row that ties with the current one. For the FINAL defect counts of lot L26-002 ordered by `defect_count` (0, 3, 3, 3, 6), `SUM(defect_count) OVER (ORDER BY defect_count)` gives 0, 9, 9, 9, 15, while adding `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` gives 0, 3, 6, 9, 15. With a column that never repeats, such as `meas_time`, both agree.

**"I can filter first and then use LAG or LEAD."** If `WHERE` removes rows, the neighbours change. Putting `new_status = 'HOLD'` in the same query as `LEAD` gives 290 hours for lot L26-003, the time from one hold to the next, instead of the real 119. Calculate in an inner query that has every row, then filter outside.

## Common mistakes

- Using `LAG` or `LEAD` without `ORDER BY` inside `OVER`. Oracle refuses it (`ORA-30485`), and it would have no meaning anyway.
- Forgetting `PARTITION BY`, so that the first row of one wafer or lot is compared with the last row of the previous one.
- Filtering the rows you want in the inner query before the `LEAD` has run. Look at the neighbours first, then filter outside.
- Leaving the `NULL` of the last row unexplained in a report. For open holds, say so or count to a reference time.
- Relying on the default `RANGE` window with tied `ORDER BY` values. Write `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` and add a unique column.
- Treating a `ROWS` moving average as "last N days". It is the last N rows.
- Date arithmetic: the difference of two dates is in days. Multiply by 24 for hours and by 1440 for minutes.

## Check your understanding

1. What does `LAG(thickness_nm)` return on the first row of its partition?
2. Why does a running total built with only `ORDER BY TRUNC(meas_time)` show the same value on several lines?
3. You write `WHERE new_status = 'HOLD'` in the same query as the `LEAD(changed_at)`. What goes wrong?
4. Write the window for "average of the current row and the 4 rows before it".

<details>
<summary>Answers</summary>

1. `NULL`, because there is no previous row. Use the second and third arguments (`LAG(x, 1, default)`) only if a default value makes sense.
2. The default frame is `RANGE`, which treats rows with the same `ORDER BY` value as one unit. All of them show the total including every tied row.
3. `WHERE` runs before the window, so `LEAD` looks at the next `HOLD` row instead of the release that follows. Calculate the `LEAD` in an inner query and filter outside.
4. `AVG(x) OVER (ORDER BY d ROWS BETWEEN 4 PRECEDING AND CURRENT ROW)`.

</details>

## Further reading

- [Oracle Database 19c SQL Language Reference: LAG](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LAG.html)
- [Oracle Database 19c SQL Language Reference: LEAD](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LEAD.html)
- [Oracle Database 19c SQL Language Reference: Analytic Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Analytic-Functions.html)
- [ORACLE-BASE: Analytic functions](https://oracle-base.com/articles/misc/analytic-functions)
