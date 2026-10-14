# Lab 9: Running totals, LAG and LEAD solutions

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The same queries are in [`lab9_solutions.sql`](scripts/lab9_solutions.sql).

Each exercise has the same four parts: the problem in plain words, the query, how the query builds the answer (taken apart in the order Oracle runs it: `FROM` and joins, `WHERE`, `GROUP BY`, window functions, `SELECT`, `ORDER BY`, `FETCH FIRST`), and the output with what to notice.

All outputs and the in-between rows in the breakdowns were produced by running the queries, and parts of them, on the lab data (Oracle 21c XE; 19c gives the same rows).

Two ideas carry this whole lab:

- **LAG and LEAD** look at another row: `LAG` at the row before, `LEAD` at the row after, in the order you give inside `OVER`. `PARTITION BY` stops them from looking across into another wafer or lot.
- **A frame** decides which rows a running `SUM` or `AVG` adds up. `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` means "from the first row up to this one". `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` means "this row and the two before it".

## Exercise 1: Change since the previous reading

**Maya asks:** "For lot L26-006, show every reading of every wafer with the thickness, the previous thickness of the same wafer, and the change. The first reading of a wafer has nothing to compare with, and that is fine."

### The problem in plain words

Each wafer in lot L26-006 is measured three times: SPLIT, then ANNEAL, then FINAL. Maya wants one row per reading (15 rows: 5 wafers × 3 steps). On each row she wants the thickness, the thickness of the same wafer's previous reading, and the change between them. "Previous" means earlier in time for the same wafer, never a different wafer. The first reading of each wafer has no previous reading, so those two columns stay empty.

### The query

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

### How the query builds the answer

**Step 1. FROM, JOIN and WHERE.** Readings are joined to wafers so the lot is known, and only lot L26-006 stays: 15 rows.

**Step 2. The window `LAG(m.thickness_nm) OVER (PARTITION BY m.wafer_id ORDER BY m.meas_time)`.** `PARTITION BY m.wafer_id` puts each wafer's three readings in their own group. `ORDER BY m.meas_time` lines them up in time order inside the group. `LAG` then takes the thickness from the row just above. For wafer L26-006-01: the SPLIT row has nobody above it, so it gets `NULL`; the ANNEAL row gets 100.73 from SPLIT; the FINAL row gets 81.12 from ANNEAL.

**Step 3. SELECT.** `change_nm` is this reading minus the previous one. Anything minus `NULL` is `NULL`, so the first reading of each wafer has no change either.

**Step 4. ORDER BY.** Wafer by wafer, in time order, so the rows read naturally.

To see why `PARTITION BY` matters, here is the same `LAG` with only an `ORDER BY` and no partition. Look at the fourth row:

```text
WAFER_ID         STEP     THICKNESS_NM PREV_NO_PARTITION
---------------- -------- ------------ -----------------
L26-006-01       SPLIT          100.73
L26-006-01       ANNEAL          81.12            100.73
L26-006-01       FINAL           73.77             81.12
L26-006-02       SPLIT          101.01             73.77
L26-006-02       ANNEAL          81.42            101.01
```

Wafer 02's SPLIT reading is compared with wafer 01's FINAL reading, which is meaningless.

### Output

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

### What to notice

Each wafer starts with a blank, and that blank is correct: there really is no earlier reading. Every change is negative: each wafer gets thinner from one step to the next.

## Exercise 2: Defects collected so far

**Maya asks:** "For lot L26-009, list every reading in time order with the defects found by that reading and the total number of defects found in the lot so far."

### The problem in plain words

One row per reading of lot L26-009 (15 rows), sorted by the time it was taken. Each row shows that reading's defect count and a running total: the sum of this reading's defects and all the readings before it in the lot. The running total starts at the first reading's count and ends at the lot's grand total.

### The query

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

### How the query builds the answer

**Step 1. FROM, JOIN and WHERE.** The 15 readings of lot L26-009.

**Step 2. The window's ORDER BY.** `ORDER BY m.meas_time, m.meas_id` lines the 15 rows up in time order. `meas_id` is unique, so even two readings at the same minute have a fixed order.

**Step 3. The frame `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.** For each row, `SUM` adds the rows from the first one down to this one. Row 1 adds only itself: 54. Row 2 adds rows 1 and 2: 54 + 29 = 83. Row 3 adds rows 1 to 3: 83 + 51 = 134. And so on. No `PARTITION BY`, because the whole lot is one running total.

**Step 4. SELECT and ORDER BY.** The time is formatted for display, and the rows are shown in the same order the window used, so the running total reads top to bottom.

### Output

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

### What to notice

The last row, 317, must equal the lot's plain `SUM(defect_count)`, and it does. That is a handy cross-check for any running total. A reading with 0 defects (row 14) leaves the total unchanged, as it should.

## Exercise 3: The running total that stays at 204

**Maya asks:** "A colleague wrote the query below for the SPLIT readings of lot L26-001. Maya says the running total shows 204 on every line, which cannot be right. Find out why and fix it so the total grows reading by reading."

### The problem in plain words

This is a debugging exercise. The query should give a running total of SPLIT defects for lot L26-001, one row per reading (5 rows), growing from the first reading's count up to the lot total of 204. Instead every row shows 204. The job is to explain what the window did, then change it so each row adds only the readings up to itself.

The broken query:

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

### Why the broken query shows 204

**Step 1. What the window sorts by.** `TRUNC(m.meas_time)` cuts the time off a date, leaving midnight. All five SPLIT readings were taken on the same morning, so all five get the same sort value:

```text
WAFER_ID         MEAS_TIME        TRUNC(MEAS_TIME)  DEFECT_COUNT
---------------- ---------------- ----------------  ------------
L26-001-01       2026-08-04 08:00 2026-08-04 00:00            42
L26-001-02       2026-08-04 08:30 2026-08-04 00:00            37
L26-001-03       2026-08-04 09:00 2026-08-04 00:00            44
L26-001-04       2026-08-04 09:30 2026-08-04 00:00            48
L26-001-05       2026-08-04 10:00 2026-08-04 00:00            33
```

**Step 2. The hidden default frame.** When a window has an `ORDER BY` but no frame, Oracle uses `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. `RANGE` means "every row whose sort value is up to and including mine", and that includes rows that tie with the current one. All five rows tie, so every row's frame is all five rows, and every row gets 42 + 37 + 44 + 48 + 33 = 204.

### The query

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

### How the fixed query builds the answer

**Step 1. FROM, JOIN and WHERE.** The same 5 SPLIT readings.

**Step 2. A unique order.** Adding `m.meas_id` gives each row its own position, so there are no ties left.

**Step 3. A ROWS frame.** `ROWS` counts physical rows, not sort values, so the frame stops exactly at the current row. Row 1 sums 42, row 2 sums 42 + 37 = 79, and so on up to 204. Either fix alone would work here; doing both is the safe habit.

**Step 4. ORDER BY m.meas_id.** Display order matches the window order.

### Output

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

### What to notice

The broken query did not raise an error; it just gave a wrong number. That is why the habit matters: write the frame out, and make the order unique.

## Exercise 4: Moving average of FINAL thickness

**Maya asks:** "For the RF-300 product, take the FINAL readings in time order. Next to each reading show the average of that reading and the two before it."

### The problem in plain words

We want the FINAL readings of every wafer of product RF-300 (15 readings across three lots), sorted by time. Next to each reading Maya wants a three-reading moving average: the average of this reading and the two readings just before it. A moving average smooths out the noise so a drift is easier to see. Each row is one reading.

The product code is in `PRODUCTS`, so we join `MEASUREMENTS` → `WAFERS` → `LOTS` → `PRODUCTS`.

### The query

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

### How the query builds the answer

**Step 1. FROM, JOINs and WHERE.** 15 FINAL readings of RF-300 wafers.

**Step 2. The window's ORDER BY.** Readings in time order, with `meas_id` as a tie-breaker.

**Step 3. The frame `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`.** For each row, the frame is at most three rows: two above and itself. It slides down one row at a time:

- Row 1: only itself, average 75.57.
- Row 2: rows 1 and 2, (75.57 + 74.37) / 2 = 74.97.
- Row 3: rows 1 to 3, (75.57 + 74.37 + 75.02) / 3 = 74.99.
- Row 4: rows 2 to 4. Row 1 has dropped out.
- Row 6: rows 4 to 6, (74.52 + 75.19 + 73.77) / 3 = 74.49. The frame crosses from lot L26-002 into L26-006, which is fine because Maya asked for the product, not a lot.

**Step 4. SELECT and ORDER BY.** Rounded to two decimals and shown in time order.

### Output

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

### What to notice

On the first two rows the frame is shorter, so those averages use one and two values. Reports should say that, or hide the first two rows. The thickness itself ranges over about 2 nm (73.66 to 75.64), but once the frame is full the moving average stays between 74.48 and 75.27. That calmer line is the point of smoothing.

## Exercise 5: How long was each hold of one lot?

**Maya asks:** "For lot L26-001, list each time it went on hold, when that was, and how many hours until it was released. Then give me the total hours on hold."

### The problem in plain words

`LOT_HISTORY` has one row per status change: when the lot changed, from what, to what. A hold starts on a row where `new_status` is HOLD and ends at the next change of the same lot. So the length of a hold is the time between a HOLD row and the row after it.

The answer has one row per hold of lot L26-001: when it started, how many hours it lasted, and on every row the total hours of all holds together.

### The query

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

### How the query builds the answer

**Step 1. Inner FROM and WHERE.** All 12 history rows of lot L26-001, of every status.

**Step 2. Inner window `LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at)`.** For each row, `LEAD` fetches the time of the next change. Subtracting two Oracle dates gives days, so `* 24` turns it into hours. The inner query gives this:

```text
OLD_STAT NEW_STAT CHANGED_AT       NEXT_CHANGE           HOURS
-------- -------- ---------------- ---------------- ----------
         ACTIVE   2026-08-03 07:30 2026-08-04 01:30         18
ACTIVE   HOLD     2026-08-04 01:30 2026-08-04 18:30         17
HOLD     ACTIVE   2026-08-04 18:30 2026-08-05 17:30         23
ACTIVE   HOLD     2026-08-05 17:30 2026-08-06 13:30         20
...
ACTIVE   HOLD     2026-08-12 17:30 2026-08-13 22:30         29
HOLD     ACTIVE   2026-08-13 22:30 2026-08-14 15:30         17
ACTIVE   SHIPPED  2026-08-14 15:30
```

(`NEXT_CHANGE` is shown here to make `LEAD` visible; the real inner query only keeps the hours.) On a HOLD row, the hours are the length of the hold. On an ACTIVE row, they are the time the lot was running, which we do not want.

**Step 3. Outer WHERE new_status = 'HOLD'.** Only the five HOLD rows stay, each carrying its own length.

**Step 4. Outer window `SUM(hours_on_hold) OVER ()`.** Adds the five lengths (17 + 20 + 23 + 26 + 29 = 115) and puts the total on every row. This window runs after the outer `WHERE`, so it only sees the holds.

**Step 5. SELECT and ORDER BY.** Format, round, and sort by start time.

### Output

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

### What to notice

The order of the two filters is the trick. The inner filter is on the lot, so the lot's history stays complete and `LEAD` can see the release row after each hold. If you filtered on `new_status = 'HOLD'` inside, the release rows would be gone and `LEAD` would measure from one hold to the next hold.

## Exercise 6: Longest hold, and holds still open

**Maya asks:** "Part a: Which single hold was the longest of all, which lot, when did it start, how many hours? Part b: which lots are on hold right now, since when, and how many hours so far (count up to 2026-10-10 12:00, the time the data was cut)?"

### The problem in plain words

Both parts use the same idea as exercise 5, now for all 16 lots.

Part a: of all holds that have ended, find the longest one. The answer is one row (or more, if two holds are equally long) with the lot, the start time and the length in hours.

Part b: a hold is still open if the HOLD row is the lot's last history row, so nothing came after it. The answer is one row per lot on hold now, with when the hold started and how many hours it has lasted up to the data cut-off time.

### The queries

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

### How the queries build the answer

**Part a, step 1. Inner query.** All 147 history rows, each with the hours to the next change of the same lot (as in exercise 5, but no lot filter).

**Part a, step 2. Outer WHERE.** Keep HOLD rows only (64 of them), and drop the ones where the hours are `NULL`. Sorted by length, the top of the list before that `NULL` filter looks like this:

```text
LOT_ID       STARTED          HOURS_ON_HOLD
------------ ---------------- -------------
L26-003B     2026-08-19 08:05
L26-005      2026-09-05 00:00
L26-003      2026-08-14 18:45            42
L26-004      2026-08-26 13:15            41
L26-009      2026-09-22 14:00            41
```

Oracle sorts `NULL` first when sorting `DESC`. Without the `IS NOT NULL` filter, the two open holds would sit at the top and `FETCH FIRST` would return one of them.

**Part a, step 3. ORDER BY and FETCH FIRST 1 ROW WITH TIES.** The longest ended hold is 42 hours. `WITH TIES` would also return any other 42-hour hold.

**Part b, step 1. Inner query.** All history rows, each with the time of the next change in `next_change`.

**Part b, step 2. Outer WHERE.** A HOLD row with `next_change IS NULL` is a hold nothing has ended yet. Of the 16 lots, two have HOLD as their last row: L26-003B and L26-005.

**Part b, step 3. SELECT.** Hours so far = (cut-off time - hold start) × 24.

### Output of part b

<!--gen-->
```text
LOT_ID       ON_HOLD_SINCE    HOURS_SO_FAR
------------ ---------------- ------------
L26-003B     2026-08-19 08:05         1252
L26-005      2026-09-05 00:00          852
```

### What to notice

In this data, `NULL` from `LEAD` means "not ended yet", and you use it on purpose: filtered out in part a, filtered for in part b. The two open holds are far longer than any ended hold (1252 hours is about 52 days), so a report of "longest hold" that ignores open holds can mislead. Say which one you mean. Use `SYSDATE` instead of the fixed time when you want "so far, right now".

## Exercise 7: Lots that bounced back and forth

**Maya asks:** "Which lots went on hold five times or more? For each, show the number of holds and the average length of the holds that have ended, in hours (one decimal), longest average first."

### The problem in plain words

One row per lot, but only lots with at least five holds. Each row shows how many holds the lot had and the average length of those holds that have ended. Open holds count towards the number of holds but cannot be part of the average, since they have no length yet.

This needs both tools: `LEAD` to get each hold's length (a window, row by row), then `GROUP BY` to collapse to one row per lot.

### The query

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

### How the query builds the answer

**Step 1. Inner query.** Every history row with the hours to the next change, as in exercise 6.

**Step 2. Outer WHERE new_status = 'HOLD'.** Only hold rows. For lot L26-005 these are six rows, and the last one is still open:

```text
LOT_ID       NEW_STAT CHANGED_AT       HOURS_ON_HOLD
------------ -------- ---------------- -------------
L26-005      HOLD     2026-08-25 04:00            14
L26-005      HOLD     2026-08-26 16:00            17
L26-005      HOLD     2026-08-28 12:00            20
L26-005      HOLD     2026-08-30 16:00            23
L26-005      HOLD     2026-09-02 04:00            26
L26-005      HOLD     2026-09-05 00:00
```

**Step 3. GROUP BY lot_id.** One row per lot. `COUNT(*)` counts rows, so L26-005 gets 6. `AVG(hours_on_hold)` skips `NULL`, so its average is (14 + 17 + 20 + 23 + 26) / 5 = 20.

**Step 4. HAVING COUNT(*) >= 5.** `HAVING` filters groups after they are made. Lots with fewer than five holds drop out.

**Step 5. ORDER BY.** Longest average first, lot ID to settle ties.

### Output

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

### What to notice

`COUNT(*)` and `AVG(...)` cover different rows for L26-005: six holds counted, five averaged. That is correct, but say so in the report. A lot that bounced often is not always a lot with long holds: L26-007A had five holds averaging only 13 hours.
