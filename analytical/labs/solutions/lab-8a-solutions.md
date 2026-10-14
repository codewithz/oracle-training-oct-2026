# Lab 8a: Ranking solutions

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The outputs below were produced by running each query on the lab data (Oracle 21c XE; 19c gives the same result). The same queries are in [`lab8a_solutions.sql`](scripts/lab8a_solutions.sql).

## Exercise 1: ROW_NUMBER, one number per reading

**Maya asks:** "Number the FINAL readings from most defects to fewest. If two readings have the same count, the lower wafer ID comes first. Show me the first 8."

```sql
SELECT wafer_id,
       tool_id,
       defect_count,
       ROW_NUMBER() OVER (ORDER BY defect_count DESC, wafer_id) AS row_num
FROM   measurements
WHERE  step = 'FINAL'
ORDER  BY row_num
FETCH FIRST 8 ROWS ONLY;
```
<!--gen-->
```text
WAFER_ID         TOOL_I DEFECT_COUNT    ROW_NUM
---------------- ------ ------------ ----------
L26-003B-02      MET01            20          1
L26-008-01       MET01            20          2
L26-008-03       MET03            20          3
L26-008-04       MET03            20          4
L26-008-02       MET02            19          5
L26-003B-01      MET02            15          6
L26-001-04       MET03             6          7
L26-002-04       MET03             6          8
```

**Why it works / what to notice.** Four readings have 20 defects, yet they get 1, 2, 3 and 4: `ROW_NUMBER` never repeats a number. The `wafer_id` inside `OVER` decides who gets which. Take it out and the four 20s still get 1 to 4, but Oracle may hand those numbers out in a different order on another run. Row 8 cuts through the eleven readings with 6 defects; only the tie-breaker decides which two make the list.

## Exercise 2: RANK, ties share a place

**Maya asks:** "Same list, but readings with the same defect count should share a place, like runners who cross the line together. Show me the first 8. What place does a reading with 6 defects get?"

```sql
SELECT wafer_id,
       tool_id,
       defect_count,
       RANK() OVER (ORDER BY defect_count DESC) AS rnk
FROM   measurements
WHERE  step = 'FINAL'
ORDER  BY rnk, wafer_id
FETCH FIRST 8 ROWS ONLY;
```
<!--gen-->
```text
WAFER_ID         TOOL_I DEFECT_COUNT        RNK
---------------- ------ ------------ ----------
L26-003B-02      MET01            20          1
L26-008-01       MET01            20          1
L26-008-03       MET03            20          1
L26-008-04       MET03            20          1
L26-008-02       MET02            19          5
L26-003B-01      MET02            15          6
L26-001-04       MET03             6          7
L26-002-04       MET03             6          7
```

**Why it works / what to notice.** The four 20s all get place 1. The 19 gets place 5, not 2, because four readings are ahead of it: `RANK` skips 2, 3 and 4. A reading with 6 defects is place 7, and all eleven of them share it. The tie-breaker `wafer_id` is in the outer `ORDER BY`, not in `OVER`. Inside `OVER` it would break every tie and `RANK` would give the same numbers as `ROW_NUMBER`.

## Exercise 3: DENSE_RANK, the three worst values

**Maya asks:** "I don't want the three worst readings, I want every reading that has one of the three worst defect counts."

```sql
SELECT wafer_id, tool_id, defect_count, dense_rnk
FROM  (SELECT wafer_id,
              tool_id,
              defect_count,
              DENSE_RANK() OVER (ORDER BY defect_count DESC) AS dense_rnk
       FROM   measurements
       WHERE  step = 'FINAL')
WHERE  dense_rnk <= 3
ORDER  BY dense_rnk, wafer_id;
```
<!--gen-->
```text
WAFER_ID         TOOL_I DEFECT_COUNT  DENSE_RNK
---------------- ------ ------------ ----------
L26-003B-02      MET01            20          1
L26-008-01       MET01            20          1
L26-008-03       MET03            20          1
L26-008-04       MET03            20          1
L26-008-02       MET02            19          2
L26-003B-01      MET02            15          3
```

**Why it works / what to notice.** The three worst values are 20, 19 and 15, and `DENSE_RANK` numbers them 1, 2, 3 with no gap. With `RANK` the 19 would be 5 and the 15 would be 6, so `rnk <= 3` would return only the four 20s. The inline view is needed because a ranking function cannot be used in `WHERE` (`ORA-30483`).

## Exercise 4: Top 2 readings per tool

**Maya asks:** "For each FINAL tool (MET01, MET02, MET03), show me its two readings with the most defects. Exactly two per tool; on a tie the lower wafer ID wins."

```sql
SELECT tool_id, wafer_id, defect_count, rn
FROM  (SELECT tool_id,
              wafer_id,
              defect_count,
              ROW_NUMBER() OVER (PARTITION BY tool_id
                                 ORDER BY defect_count DESC, wafer_id) AS rn
       FROM   measurements
       WHERE  step = 'FINAL')
WHERE  rn <= 2
ORDER  BY tool_id, rn;
```
<!--gen-->
```text
TOOL_I WAFER_ID         DEFECT_COUNT         RN
------ ---------------- ------------ ----------
MET01  L26-003B-02                20          1
MET01  L26-008-01                 20          2
MET02  L26-008-02                 19          1
MET02  L26-003B-01                15          2
MET03  L26-008-03                 20          1
MET03  L26-008-04                 20          2
```

**Why it works / what to notice.** `PARTITION BY tool_id` restarts the numbering at 1 for each tool, so `rn <= 2` keeps two rows per tool. This is the standard top-N-per-group pattern: rank in the inner query, filter in the outer one. `FETCH FIRST` cannot do this, because it cuts the whole list once, not once per group. If Maya wanted ties included ("everybody tied for the top two places"), you would use `RANK` instead and could get more than two rows for a tool.

## Exercise 5: Rank the lots inside each product

**Maya asks:** "Add up the FINAL defects per lot and rank the lots inside each product, worst first. Lots with the same total share a place. Show all lots."

```sql
SELECT p.product_code,
       w.lot_id,
       SUM(m.defect_count) AS final_defects,
       RANK() OVER (PARTITION BY p.product_code
                    ORDER BY SUM(m.defect_count) DESC) AS rank_in_product
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
GROUP  BY p.product_code, w.lot_id
ORDER  BY p.product_code, rank_in_product, w.lot_id;
```
<!--gen-->
```text
PRODUCT_CODE LOT_ID       FINAL_DEFECTS RANK_IN_PRODUCT
------------ ------------ ------------- ---------------
FD-300       L26-003B                35               1
FD-300       L26-011                 26               2
FD-300       L26-007                 20               3
FD-300       L26-003                 15               4
FD-300       L26-001                 11               5
FD-300       L26-003B1                9               6
FD-300       L26-003A                 2               7
FD-300       L26-007A                 1               8
PHO-300      L26-005                 14               1
PHO-300      L26-009                 13               2
PWR-200      L26-008                 79               1
PWR-200      L26-004                 15               2
RF-300       L26-002                 15               1
RF-300       L26-006                 14               2
RF-300       L26-010                 14               2
```

**Why it works / what to notice.** `GROUP BY` runs first and makes one row per lot. The window then works on those rows, so `ORDER BY SUM(m.defect_count)` inside `OVER` ranks lot totals. `RF-300` shows the tie: `L26-006` and `L26-010` both have 14 and share place 2. No place 3 follows only because `RF-300` has no more lots. No inline view is needed here, since you keep every row.

## Exercise 6: Second-worst value per tool

**Maya asks:** "For each FINAL tool, which readings have the second-highest defect count of that tool? Try it with RANK first, then with DENSE_RANK, and explain the difference."

With `RANK`:

```sql
SELECT tool_id, wafer_id, defect_count
FROM  (SELECT tool_id,
              wafer_id,
              defect_count,
              RANK() OVER (PARTITION BY tool_id ORDER BY defect_count DESC) AS rnk
       FROM   measurements
       WHERE  step = 'FINAL')
WHERE  rnk = 2
ORDER  BY tool_id, wafer_id;
```
<!--gen-->
```text
TOOL_I WAFER_ID         DEFECT_COUNT
------ ---------------- ------------
MET02  L26-003B-01                15
```

With `DENSE_RANK`:

```sql
SELECT tool_id, wafer_id, defect_count
FROM  (SELECT tool_id,
              wafer_id,
              defect_count,
              DENSE_RANK() OVER (PARTITION BY tool_id ORDER BY defect_count DESC) AS dense_rnk
       FROM   measurements
       WHERE  step = 'FINAL')
WHERE  dense_rnk = 2
ORDER  BY tool_id, wafer_id;
```
<!--gen-->
```text
TOOL_I WAFER_ID         DEFECT_COUNT
------ ---------------- ------------
MET01  L26-007-04                  6
MET01  L26-011-02                  6
MET01  L26-011-03                  6
MET02  L26-003B-01                15
MET03  L26-001-04                  6
MET03  L26-002-04                  6
MET03  L26-004-01                  6
MET03  L26-009-05                  6
MET03  L26-011-01                  6
MET03  L26-011-05                  6
```

**Why it works / what to notice.** `MET01` and `MET03` each have two readings tied on 20. `RANK` gives both of them 1 and jumps straight to 3 for the next value, so no row in those tools has rank 2 and they vanish from the answer. Only `MET02`, which has no tie at the top, comes back. `DENSE_RANK` gives the next value 2 in every tool, which is what "second-highest value" means. Rule: when the question is about the Nth *value*, use `DENSE_RANK`.
