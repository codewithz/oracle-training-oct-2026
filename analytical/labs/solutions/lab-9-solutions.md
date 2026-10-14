# Lab 9: Running totals, LAG and LEAD solutions

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The outputs below were produced by running each query on the lab data. The same queries are in [`lab9_solutions.sql`](scripts/lab9_solutions.sql).

## Exercise 1: Change since the previous reading

**Maya asks:** "For lot L26-006, show every reading of every wafer with the thickness, the previous thickness of the same wafer, and the change. The first reading of a wafer has nothing to compare with, and that is fine."

```sql
SELECT m.wafer_id,
       m.step,
       m.thickness_nm,
       LAG(m.thickness_nm) OVER (PARTITION BY m.wafer_id ORDER BY m.meas_time) AS prev_nm,
       ROUND(m.thickness_nm
             - LAG(m.thickness_nm) OVER (PARTITION BY m.wafer_id ORDER BY m.meas_time), 2) AS change_nm
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id = 'L26-006'
ORDER  BY m.wafer_id, m.meas_time;
```
<!--gen-->
```text
WAFER_ID         STEP     THICKNESS_NM    PREV_NM  CHANGE_NM
---------------- -------- ------------ ---------- ----------
L26-006-01       SPLIT          100.73
L26-006-01       ANNEAL          81.12     100.73     -19.61
L26-006-01       FINAL           73.77      81.12      -7.35
L26-006-02       SPLIT          101.01
L26-006-02       ANNEAL          81.42     101.01     -19.59
L26-006-02       FINAL           74.49      81.42      -6.93
L26-006-03       SPLIT           94.17
L26-006-03       ANNEAL          82.63      94.17     -11.54
L26-006-03       FINAL           75.47      82.63      -7.16
L26-006-04       SPLIT           99.12
L26-006-04       ANNEAL           83.1      99.12     -16.02
L26-006-04       FINAL           74.17       83.1      -8.93
L26-006-05       SPLIT           96.11
L26-006-05       ANNEAL          81.95      96.11     -14.16
L26-006-05       FINAL           74.79      81.95      -7.16
```

**Why it works / what to notice.** Each wafer starts with a blank, because there is no earlier reading. Without `PARTITION BY m.wafer_id` the first row of wafer 2 would be compared with the last row of wafer 1.

## Exercise 2: Defects collected so far

**Maya asks:** "For lot L26-009, list every reading in time order with the defects found by that reading and the total number of defects found in the lot so far."

```sql
SELECT m.wafer_id,
       m.step,
       TO_CHAR(m.meas_time, 'MM-DD HH24:MI') AS measured,
       m.defect_count,
       SUM(m.defect_count) OVER (ORDER BY m.meas_time, m.meas_id
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS defects_so_far
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id = 'L26-009'
ORDER  BY m.meas_time, m.meas_id;
```
<!--gen-->
```text
WAFER_ID         STEP     MEASURED    DEFECT_COUNT DEFECTS_SO_FAR
---------------- -------- ----------- ------------ --------------
L26-009-01       SPLIT    09-13 10:30           54             54
L26-009-02       SPLIT    09-13 11:00           29             83
L26-009-03       SPLIT    09-13 11:30           51            134
L26-009-04       SPLIT    09-13 12:00           48            182
L26-009-05       SPLIT    09-13 12:30           43            225
L26-009-01       ANNEAL   09-14 10:45           18            243
L26-009-02       ANNEAL   09-14 11:30           14            257
L26-009-03       ANNEAL   09-14 12:15           10            267
L26-009-04       ANNEAL   09-14 13:00           15            282
L26-009-05       ANNEAL   09-14 13:45           22            304
L26-009-01       FINAL    09-15 11:24            3            307
L26-009-02       FINAL    09-15 11:48            2            309
L26-009-03       FINAL    09-15 12:12            2            311
L26-009-04       FINAL    09-15 12:36            0            311
L26-009-05       FINAL    09-15 13:00            6            317
```

**Why it works / what to notice.** With an explicit `ROWS` frame and a unique order, the running total can only grow one reading at a time. The last row must equal the lot's `SUM`: a handy cross-check.

## Exercise 3: The running total that stays at 204

**Maya asks:** "A colleague wrote the query below for the SPLIT readings of lot L26-001. Maya says the running total shows 204 on every line, which cannot be right. Find out why and fix it so the total grows reading by reading."

The broken query shows 204 on every line:

```sql
SELECT m.wafer_id,
       m.defect_count,
       SUM(m.defect_count) OVER (ORDER BY TRUNC(m.meas_time)) AS running_total
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id = 'L26-001'
AND    m.step = 'SPLIT'
ORDER  BY m.meas_id;
```
<!--gen-->
```text
WAFER_ID         DEFECT_COUNT RUNNING_TOTAL
---------------- ------------ -------------
L26-001-01                 42           204
L26-001-02                 37           204
L26-001-03                 44           204
L26-001-04                 48           204
L26-001-05                 33           204
```

The fixed version:

```sql
-- The fix: order by the day AND a unique column, and write the frame out.
SELECT m.wafer_id,
       m.defect_count,
       SUM(m.defect_count) OVER (ORDER BY TRUNC(m.meas_time), m.meas_id
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id = 'L26-001'
AND    m.step = 'SPLIT'
ORDER  BY m.meas_id;
```
<!--gen-->
```text
WAFER_ID         DEFECT_COUNT RUNNING_TOTAL
---------------- ------------ -------------
L26-001-01                 42            42
L26-001-02                 37            79
L26-001-03                 44           123
L26-001-04                 48           171
L26-001-05                 33           204
```

**Why it works / what to notice.** The broken query used `ORDER BY TRUNC(m.meas_time)` with no frame. The default is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, and `RANGE` includes all rows with the same sort value, so every line of the same day showed the day total. Habit: write the frame, and make the order unique.

## Exercise 4: Moving average of FINAL thickness

**Maya asks:** "For the RF-300 product, take the FINAL readings in time order. Next to each reading show the average of that reading and the two before it."

```sql
SELECT m.wafer_id,
       TO_CHAR(m.meas_time, 'MM-DD HH24:MI') AS measured,
       m.thickness_nm,
       ROUND(AVG(m.thickness_nm) OVER (ORDER BY m.meas_time, m.meas_id
                                       ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  p.product_code = 'RF-300'
AND    m.step = 'FINAL'
ORDER  BY m.meas_time, m.meas_id;
```
<!--gen-->
```text
WAFER_ID         MEASURED    THICKNESS_NM MOVING_AVG_3
---------------- ----------- ------------ ------------
L26-002-01       08-08 10:24        75.57        75.57
L26-002-02       08-08 10:48        74.37        74.97
L26-002-03       08-08 11:12        75.02        74.99
L26-002-04       08-08 11:36        74.52        74.64
L26-002-05       08-08 12:00        75.19        74.91
L26-006-01       08-31 08:24        73.77        74.49
L26-006-02       08-31 08:48        74.49        74.48
L26-006-03       08-31 09:12        75.47        74.58
L26-006-04       08-31 09:36        74.17        74.71
L26-006-05       08-31 10:00        74.79        74.81
L26-010-01       09-20 10:09         75.6        74.85
L26-010-02       09-20 10:33        73.66        74.68
L26-010-03       09-20 10:57        75.64        74.97
L26-010-04       09-20 11:21        75.03        74.78
L26-010-05       09-20 11:45        75.15        75.27
```

**Why it works / what to notice.** On the first two rows the window is shorter, so the averages use fewer values. Reports should say that, or hide the first two rows.

## Exercise 5: How long was each hold of one lot?

**Maya asks:** "For lot L26-001, list each time it went on hold, when that was, and how many hours until it was released. Then give me the total hours on hold."

```sql
SELECT lot_id,
       TO_CHAR(went_on_hold, 'YYYY-MM-DD HH24:MI') AS went_on_hold,
       ROUND(hours_on_hold, 1)                      AS hours_on_hold,
       ROUND(SUM(hours_on_hold) OVER (), 1)         AS total_hours
FROM  (SELECT lot_id,
              new_status,
              changed_at AS went_on_hold,
              (LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at) - changed_at) * 24 AS hours_on_hold
       FROM   lot_history
       WHERE  lot_id = 'L26-001')
WHERE  new_status = 'HOLD'
ORDER  BY went_on_hold;
```
<!--gen-->
```text
LOT_ID       WENT_ON_HOLD     HOURS_ON_HOLD TOTAL_HOURS
------------ ---------------- ------------- -----------
L26-001      2026-08-04 01:30            17         115
L26-001      2026-08-05 17:30            20         115
L26-001      2026-08-07 17:30            23         115
L26-001      2026-08-10 01:30            26         115
L26-001      2026-08-12 17:30            29         115
```

**Why it works / what to notice.** The lot's own history stays complete because the filter is on the lot, not on the status. A filter on the status inside would hide the release row that marks the end of each hold. The total uses a second window over the finished list.

## Exercise 6: Longest hold, and holds still open

**Maya asks:** "Part a: Which single hold was the longest of all, which lot, when did it start, how many hours? Part b: which lots are on hold right now, since when, and how many hours so far (count up to 2026-10-10 12:00, the time the data was cut)?"

```sql
-- Part a
SELECT lot_id, started, hours_on_hold
FROM  (SELECT lot_id,
              new_status,
              TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI') AS started,
              ROUND((LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at) - changed_at) * 24, 1) AS hours_on_hold
       FROM   lot_history)
WHERE  new_status = 'HOLD'
AND    hours_on_hold IS NOT NULL
ORDER  BY hours_on_hold DESC
FETCH FIRST 1 ROW WITH TIES;
```
<!--gen-->
```text
LOT_ID       STARTED          HOURS_ON_HOLD
------------ ---------------- -------------
L26-003      2026-08-14 18:45            42
```

```sql
-- Part b
SELECT lot_id,
       TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI') AS on_hold_since,
       ROUND((TO_DATE('2026-10-10 12:00', 'YYYY-MM-DD HH24:MI') - changed_at) * 24) AS hours_so_far
FROM  (SELECT lot_id, new_status, changed_at,
              LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at) AS next_change
       FROM   lot_history)
WHERE  new_status = 'HOLD'
AND    next_change IS NULL
ORDER  BY lot_id;
```
<!--gen-->
```text
LOT_ID       ON_HOLD_SINCE    HOURS_SO_FAR
------------ ---------------- ------------
L26-003B     2026-08-19 08:05         1252
L26-005      2026-09-05 00:00          852
```

**Why it works / what to notice.** A hold with no next row is still open. `NULL` is the correct answer for "not ended", and you handle it on purpose, not by accident. `WITH TIES` makes sure that two equally long holds would both show. Use `SYSDATE` instead of the fixed time when you want "so far, right now".

## Exercise 7: Lots that bounced back and forth

**Maya asks:** "Which lots went on hold five times or more? For each, show the number of holds and the average length of the holds that have ended, in hours (one decimal), longest average first."

```sql
SELECT lot_id,
       COUNT(*)                       AS hold_episodes,
       ROUND(AVG(hours_on_hold), 1)   AS avg_hours_ended
FROM  (SELECT lot_id,
              new_status,
              (LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at) - changed_at) * 24 AS hours_on_hold
       FROM   lot_history)
WHERE  new_status = 'HOLD'
GROUP  BY lot_id
HAVING COUNT(*) >= 5
ORDER  BY avg_hours_ended DESC, lot_id;
```
<!--gen-->
```text
LOT_ID       HOLD_EPISODES AVG_HOURS_ENDED
------------ ------------- ---------------
L26-004                  5              30
L26-009                  6            29.8
L26-001                  5              23
L26-005                  6              20
L26-003                  6            19.8
L26-007A                 5              13
```

**Why it works / what to notice.** `L26-005` has 6 episodes but only 5 ended, so its average of 20 uses five values. This is a reminder to say in the report which rows an average covers. A lot that bounced often is not always a lot with long holds.

