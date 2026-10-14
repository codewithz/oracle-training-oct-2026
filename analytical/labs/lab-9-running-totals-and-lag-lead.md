# Lab 9: Running totals, LAG and LEAD

**Time:** 45 minutes. **Reading first:** [Running totals, moving averages and LAG/LEAD](../topics/03-running-totals-and-lag-lead.md).

> This lab needs the add-on tables from Lab 8 (`LOT_HISTORY`). Check with `SELECT COUNT(*) FROM lot_history;`. You should get 147.

## The story

Maya wants to know what changed. "How much thinner did this wafer get since the last reading? How many defects have we collected so far in this lot? And the one that keeps me awake: how long do lots sit on hold, and which ones keep bouncing in and out?" The hold question lives in the `LOT_HISTORY` table, where every status change is one row. You will read the rows next to each other with `LAG` and `LEAD`.

## What you will do

- compare a reading with the previous one using `LAG`
- build a running total and a moving average with a windowing clause
- spot and fix the default `RANGE` trap
- work out the length of each hold with `LEAD`
- find the longest hold and the holds that are still open
- count the lots that bounced back and forth

## Scripts

| File | What it does |
| --- | --- |
| [`lab9_running_totals_and_lag_lead.sql`](scripts/lab9_running_totals_and_lag_lead.sql) | Your worksheet: each question is a comment with space below it for your query. Run as `FAB_LAB`. |

Solutions: [lab-9-solutions.md](../solutions/lab-9-solutions.md).

## Before you start

1. Connect to `FAB_LAB` in DBeaver (`fab-lab` connection) and open `lab9_running_totals_and_lag_lead.sql` with **File > Open File**.
2. Run one statement at a time with `Ctrl + Enter` (the cursor must be inside the statement, which must end with a semicolon).
3. Auto-commit is fine. Nothing is changed.
4. Every exercise has three hints. Open Hint 1 first and use the next one only when you are stuck. Each exercise ends with a checkpoint: compare your row count and key value before you open the solutions page.

## Part A: neighbours and running figures

### Exercise 1: Change since the previous reading

**Maya asks:** "For lot L26-006, show every reading of every wafer with the thickness, the previous thickness of the same wafer, and the change. The first reading of a wafer has nothing to compare with, and that is fine."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Previous reading of the same wafer: `LAG`. The window must restart for every wafer, and it needs the time order.

</details>

<details>
<summary>Hint 2</summary>

`LAG(m.thickness_nm) OVER (PARTITION BY m.___ ORDER BY m.___)`. Use it twice: once to show the previous value, once inside `ROUND(m.thickness_nm - LAG(...) OVER (...), 2)`. Join `wafers` to filter the lot.

</details>

<details>
<summary>Hint 3</summary>

Filter with `w.lot_id = 'L26-006'` after joining `wafers w ON w.wafer_id = m.wafer_id`. Order the output by `m.wafer_id, m.meas_time`.

</details>

**Checkpoint:** 15 rows, five of them (the first reading of each wafer) with empty `prev_nm` and `change_nm`. For `L26-006-01` the ANNEAL change is -19.61.

### Exercise 2: Defects collected so far

**Maya asks:** "For lot L26-009, list every reading in time order with the defects found by that reading and the total number of defects found in the lot so far."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

A running total is `SUM` with `ORDER BY` inside `OVER`. Time order is `meas_time`. No `PARTITION BY` is needed, as you filter one lot.

</details>

<details>
<summary>Hint 2</summary>

`SUM(m.defect_count) OVER (ORDER BY m.meas_time ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS defects_so_far`. Join `wafers` and filter `w.lot_id = 'L26-009'`.

</details>

<details>
<summary>Hint 3</summary>

Add `m.meas_id` as a second sort key inside `OVER` and in the final `ORDER BY` so that readings with identical times cannot swap places.

</details>

**Checkpoint:** 15 rows. The last line shows 317, which is also the lot total from the ranking page.

### Exercise 3: The running total that stays at 204

**Maya asks:** "A colleague wrote the query below for the SPLIT readings of lot L26-001. Maya says the running total shows 204 on every line, which cannot be right. Find out why and fix it so the total grows reading by reading."

The colleague's query (it is in your script):

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

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Look at the `OVER` clause. What frame does Oracle use when you give an `ORDER BY` and no frame? What happens to rows that have the same value in that `ORDER BY`?

</details>

<details>
<summary>Hint 2</summary>

Five readings share the same day. The default `RANGE` frame treats them as one unit, so all five get the total of the whole day. Order by something unique as well, and write the frame yourself.

</details>

<details>
<summary>Hint 3</summary>

`SUM(m.defect_count) OVER (ORDER BY TRUNC(m.meas_time), m.meas_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`.

</details>

**Checkpoint:** 5 rows with 42, 79, 123, 171 and 204.

### Exercise 4: Moving average of FINAL thickness

**Maya asks:** "For the RF-300 product, take the FINAL readings in time order. Next to each reading show the average of that reading and the two before it."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Average of the current row and two before: `AVG` over `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`, in time order. The product filter is on the product code.

</details>

<details>
<summary>Hint 2</summary>

Join `measurements`, `wafers`, `lots`, `products` and filter `p.product_code = 'RF-300'` and `m.step = 'FINAL'`. The window is `AVG(m.thickness_nm) OVER (ORDER BY m.meas_time, m.meas_id ROWS BETWEEN ___ PRECEDING AND CURRENT ROW)`.

</details>

<details>
<summary>Hint 3</summary>

Wrap it in `ROUND(..., 2)`. Sort the result by `m.meas_time, m.meas_id`.

</details>

**Checkpoint:** 15 rows. The first row equals its own thickness (75.57). The third row is (75.57 + 74.37 + 75.02) / 3 = 74.99.

## Part B: how long were the holds?

### Exercise 5: How long was each hold of one lot?

**Maya asks:** "For lot L26-001, list each time it went on hold, when that was, and how many hours until it was released. Then give me the total hours on hold."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

A hold starts on a row with `new_status = 'HOLD'` and ends at the next row of the same lot. `LEAD(changed_at)` gives that time. Subtract and multiply by 24. The `HOLD` filter must come after the `LEAD`.

</details>

<details>
<summary>Hint 2</summary>

Inner query: `SELECT lot_id, new_status, changed_at, (LEAD(changed_at) OVER (PARTITION BY lot_id ORDER BY changed_at) - changed_at) * 24 AS hours_on_hold FROM lot_history WHERE lot_id = 'L26-001'`. Outer query: `WHERE new_status = 'HOLD'`. For the total next to each line, use `SUM(hours_on_hold) OVER ()` in the outer query.

</details>

<details>
<summary>Hint 3</summary>

Putting `lot_id = 'L26-001'` in the inner `WHERE` is fine, since the whole history of that lot is still there. Putting `new_status = 'HOLD'` there would break the `LEAD`.

</details>

**Checkpoint:** 5 rows, hours 17, 20, 23, 26 and 29. `total_hours` is 115 on every row.

### Exercise 6: Longest hold, and holds still open

**Maya asks:** "Part a: Which single hold was the longest of all, which lot, when did it start, how many hours? Part b: which lots are on hold right now, since when, and how many hours so far (count up to 2026-10-10 12:00, the time the data was cut)?"

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Two questions. Part a is the biggest `hours_on_hold` over all completed holds. Part b is the holds with no next row, counted up to a fixed time.

</details>

<details>
<summary>Hint 2</summary>

Part a: same inner query as before without the lot filter, then `ORDER BY hours_on_hold DESC FETCH FIRST 1 ROW WITH TIES`. Skip the holds whose hours are `NULL`. Part b: keep rows where `LEAD(changed_at)` is `NULL` and subtract `changed_at` from `TO_DATE('2026-10-10 12:00', 'YYYY-MM-DD HH24:MI')`.

</details>

<details>
<summary>Hint 3</summary>

For part b, the inner query returns `next_change`. In the outer query: `WHERE new_status = 'HOLD' AND next_change IS NULL`.

</details>

**Checkpoint:** Part a: `L26-003`, hold from 2026-08-14 18:45, 42 hours. Part b: 2 rows: `L26-003B` since 2026-08-19 08:05, 1252 hours, and `L26-005` since 2026-09-05 00:00, 852 hours.

### Exercise 7: Lots that bounced back and forth

**Maya asks:** "Which lots went on hold five times or more? For each, show the number of holds and the average length of the holds that have ended, in hours (one decimal), longest average first."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Count the hold episodes (rows with `new_status = 'HOLD'`) and average the lengths of the ones that ended. Both come from the inner query with `LEAD`, then `GROUP BY lot_id` and `HAVING`.

</details>

<details>
<summary>Hint 2</summary>

`SELECT lot_id, COUNT(*) AS hold_episodes, ROUND(AVG(hours_on_hold), 1) AS avg_hours_ended FROM (inner query with LEAD) WHERE new_status = 'HOLD' GROUP BY lot_id HAVING COUNT(*) >= ___ ORDER BY avg_hours_ended DESC;`

</details>

<details>
<summary>Hint 3</summary>

`AVG` skips `NULL`, so an open hold counts as an episode in `COUNT(*)` but not in the average. That is the behaviour Maya asked for ("holds that have ended").

</details>

**Checkpoint:** 6 lots: `L26-004` (5 holds, 30 hours), `L26-009` (6, 29.8), `L26-001` (5, 23), `L26-005` (6, 20), `L26-003` (6, 19.8), `L26-007A` (5, 13).

## Finishing

Nothing was changed. Keep your worksheet: the hold-time pattern (`LEAD` in an inner query, filter outside) is the one to remember.
