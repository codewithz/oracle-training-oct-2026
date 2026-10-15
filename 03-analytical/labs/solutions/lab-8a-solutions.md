# Lab 8a: Ranking solutions

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The same queries are in [`lab8a_solutions.sql`](scripts/lab8a_solutions.sql).

Each exercise has the same four parts: the problem in plain words, the query, how the query builds the answer (taken apart in the order Oracle runs it: `FROM` and joins, `WHERE`, `GROUP BY`, window functions, `SELECT`, `ORDER BY`, `FETCH FIRST`), and the output with what to notice.

All outputs and the in-between rows in the breakdowns were produced by running the queries, and parts of them, on the lab data (Oracle 21c XE; 19c gives the same result).

The three ranking functions differ only in what they do with ties. This table, from the FINAL readings, is worth keeping open while you read the exercises:

```text
WAFER_ID         DEFECT_COUNT ROW_NUMBER       RANK DENSE_RANK
---------------- ------------ ---------- ---------- ----------
L26-003B-02                20          1          1          1
L26-008-01                 20          2          1          1
L26-008-03                 20          3          1          1
L26-008-04                 20          4          1          1
L26-008-02                 19          5          5          2
L26-003B-01                15          6          6          3
L26-001-04                  6          7          7          4
L26-002-04                  6          8          7          4
...           (eleven readings with 6 defects in total)
L26-011-05                  6         17          7          4
L26-003-01                  5         18         18          5
```

`ROW_NUMBER` counts rows and never repeats. `RANK` gives ties the same place and then skips, like a race. `DENSE_RANK` gives ties the same place and does not skip, so it counts distinct values.

## Exercise 1: ROW_NUMBER, one number per reading

**Maya asks:** "Number the FINAL readings from most defects to fewest. If two readings have the same count, the lower wafer ID comes first. Show me the first 8."

### The problem in plain words

We take the FINAL step readings only (one per wafer, 62 in all) and put them in a list from most defects to fewest. Each reading gets its position in that list: 1, 2, 3 and so on, with no two readings sharing a number. When two readings have the same defect count, the one with the lower wafer ID goes first. Maya wants to see the first 8 rows, showing wafer, tool, defect count and position.

### The query

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

### How the query builds the answer

**Step 1. FROM and WHERE.** All 186 readings, then only the 62 FINAL ones. No join is needed, because `MEASUREMENTS` already has the wafer and tool.

**Step 2. The window `ROW_NUMBER() OVER (ORDER BY defect_count DESC, wafer_id)`.** Oracle sorts the 62 rows by defect count, highest first, and inside each tie by wafer ID. Then it numbers them 1 to 62 down that sorted list. There is no `PARTITION BY`, so there is one numbering for the whole set.

**Step 3. SELECT.** The number comes out as the column `row_num`.

**Step 4. ORDER BY row_num.** The `ORDER BY` inside `OVER` only decides the numbering, not the order of the output. This outer `ORDER BY` is what puts the rows on screen in that order.

**Step 5. FETCH FIRST 8 ROWS ONLY.** Rows 1 to 8 are returned. Rows 7 to 17 all have 6 defects (see the table at the top), so the cut at row 8 falls in the middle of that tie.

### Output

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

### What to notice

Four readings have 20 defects, yet they get 1, 2, 3 and 4: `ROW_NUMBER` never repeats a number. The `wafer_id` inside `OVER` decides who gets which. Take it out and the four 20s still get 1 to 4, but Oracle may hand those numbers out in a different order on another run. Only the tie-breaker decides which two of the eleven 6-defect readings make the list.

## Exercise 2: RANK, ties share a place

**Maya asks:** "Same list, but readings with the same defect count should share a place, like runners who cross the line together. Show me the first 8. What place does a reading with 6 defects get?"

### The problem in plain words

Same 62 FINAL readings, same order, but now the number is a place in a race, not a row count. Readings with the same defect count share a place. The next different count gets the place it would have had if everyone ahead of it were counted, so places get skipped after a tie. Maya also wants to know which place the 6-defect readings get.

### The query

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

### How the query builds the answer

**Step 1. FROM and WHERE.** The same 62 FINAL readings as exercise 1.

**Step 2. The window `RANK() OVER (ORDER BY defect_count DESC)`.** Rows are sorted by defect count. Each row's rank is 1 plus the number of rows with a strictly higher count. For the 20s nobody is higher, so they all get 1. For the 19, four rows are higher, so it gets 5. For the 6s, six rows are higher (four 20s, one 19, one 15), so all eleven get 7.

**Step 3. ORDER BY rnk, wafer_id.** Sort by place, and inside a shared place by wafer ID so the display is repeatable.

**Step 4. FETCH FIRST 8 ROWS ONLY.** The first 8 rows of that list.

### Output

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

### What to notice

The answer to Maya's question is place 7, shared by all eleven 6-defect readings. Places 2, 3 and 4 do not exist, because four readings tied for first. The tie-breaker `wafer_id` is in the outer `ORDER BY`, not in `OVER`. Inside `OVER` it would break every tie and `RANK` would give the same numbers as `ROW_NUMBER`.

## Exercise 3: DENSE_RANK, the three worst values

**Maya asks:** "I don't want the three worst readings, I want every reading that has one of the three worst defect counts."

### The problem in plain words

The difference is between readings and values. The three worst defect *values* among FINAL readings are 20, 19 and 15. Maya wants every reading that has one of those values, however many readings that is. So the answer is a list of readings, each with a number that says whether its count is the worst value (1), the second worst (2) or the third worst (3).

### The query

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

### How the query builds the answer

**Step 1. Inner FROM and WHERE.** The 62 FINAL readings.

**Step 2. Inner window `DENSE_RANK() OVER (ORDER BY defect_count DESC)`.** Each distinct value gets the next number with no gaps: 20 is 1, 19 is 2, 15 is 3, 6 is 4, 5 is 5 and so on (see the table at the top). The 62 readings have only 10 different values, so the numbers run from 1 to 10.

**Step 3. Outer WHERE dense_rnk <= 3.** This filter is allowed because `dense_rnk` is now an ordinary column of the inline view. It keeps the four 20s, the 19 and the 15.

**Step 4. ORDER BY dense_rnk, wafer_id.** Worst value first, ties in wafer order.

### Output

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

### What to notice

With `RANK` the 19 would be 5 and the 15 would be 6, so `rnk <= 3` would return only the four 20s. The inline view is needed because a ranking function cannot be used in `WHERE` (`ORA-30483`).

## Exercise 4: Top 2 readings per tool

**Maya asks:** "For each FINAL tool (MET01, MET02, MET03), show me its two readings with the most defects. Exactly two per tool; on a tie the lower wafer ID wins."

### The problem in plain words

FINAL readings are taken on three metrology tools, MET01, MET02 and MET03, about 20 readings each. For each tool separately we want its two worst readings. The answer has exactly six rows: two per tool, each showing the tool, the wafer, the defect count and whether it is that tool's number 1 or number 2. "Exactly two" and "lower wafer ID wins" point to `ROW_NUMBER` with a tie-breaker.

### The query

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

### How the query builds the answer

**Step 1. Inner FROM and WHERE.** The 62 FINAL readings: 21 on MET01, 20 on MET02, 21 on MET03.

**Step 2. Inner window with `PARTITION BY tool_id`.** The rows are split into three groups, one per tool. Inside each group they are sorted by defect count (then wafer ID) and numbered from 1 again. The top four of each tool look like this:

```text
TOOL_I WAFER_ID         DEFECT_COUNT         RN
------ ---------------- ------------ ----------
MET01  L26-003B-02                20          1
MET01  L26-008-01                 20          2
MET01  L26-007-04                  6          3
MET01  L26-011-02                  6          4
MET02  L26-008-02                 19          1
MET02  L26-003B-01                15          2
MET02  L26-007-03                  6          3
MET02  L26-010-02                  6          4
MET03  L26-008-03                 20          1
MET03  L26-008-04                 20          2
MET03  L26-001-04                  6          3
MET03  L26-002-04                  6          4
```

**Step 3. Outer WHERE rn <= 2.** Numbers 1 and 2 of each tool stay, six rows in all.

**Step 4. ORDER BY tool_id, rn.** Grouped by tool, best first.

### Output

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

### What to notice

This is the standard top-N-per-group pattern: rank in the inner query with `PARTITION BY`, filter in the outer one. `FETCH FIRST` cannot do this, because it cuts the whole list once, not once per group. If Maya wanted ties included ("everybody tied for the top two places"), you would use `RANK` instead and could get more than two rows for a tool.

## Exercise 5: Rank the lots inside each product

**Maya asks:** "Add up the FINAL defects per lot and rank the lots inside each product, worst first. Lots with the same total share a place. Show all lots."

### The problem in plain words

One row of the answer is one lot. For each lot we need its total FINAL defects, which means adding up the FINAL readings of all its wafers. Then, within each product, the lots are ranked from most defects to fewest. "Share a place" means `RANK`. Every lot is shown, so nothing is filtered out after ranking.

The product code is in `PRODUCTS`, so the readings are joined through `WAFERS` and `LOTS` to reach it.

### The query

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

### How the query builds the answer

**Step 1. FROM and JOINs.** Each reading picks up its lot and product code.

**Step 2. WHERE.** Only FINAL readings stay. For product RF-300 these are 15 readings across three lots:

```text
LOT_ID       WAFER_ID         DEFECT_COUNT
------------ ---------------- ------------
L26-002      L26-002-01                  0
L26-002      L26-002-02                  3
...
L26-006      L26-006-05                  5
L26-010      L26-010-01                  0
...
L26-010      L26-010-05                  3
```

**Step 3. GROUP BY p.product_code, w.lot_id.** One row per lot with its total. For RF-300: L26-002 has 0 + 3 + 3 + 6 + 3 = 15, L26-006 has 14, L26-010 has 14.

**Step 4. The window `RANK() OVER (PARTITION BY p.product_code ORDER BY SUM(m.defect_count) DESC)`.** The window runs on the grouped rows, so it ranks lot totals. `PARTITION BY` restarts the ranking for each product. In RF-300, 15 gets place 1, and the two 14s share place 2.

**Step 5. ORDER BY.** By product, then place, then lot ID to make ties display in a fixed order.

### Output

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

### What to notice

`GROUP BY` runs before the window, which is why `SUM(...)` is allowed inside the `OVER` brackets. No place 3 follows the RF-300 tie only because RF-300 has no more lots. No inline view is needed here, since every row is kept and nothing is filtered on the rank.

## Exercise 6: Second-worst value per tool

**Maya asks:** "For each FINAL tool, which readings have the second-highest defect count of that tool? Try it with RANK first, then with DENSE_RANK, and explain the difference."

### The problem in plain words

For each of the three FINAL tools, find the second-highest defect *value* that tool recorded, and list every reading with that value. The answer can have more than one row per tool, if several readings share that value. Maya asks for two versions so you can see which ranking function matches the question.

### The queries

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

### How the queries build the answer

**Step 1. Inner FROM and WHERE.** The 62 FINAL readings.

**Step 2. Inner window, both versions side by side.** `PARTITION BY tool_id` ranks each tool separately. Here are the top four rows of each tool with both numbers:

```text
TOOL_I WAFER_ID         DEFECT_COUNT       RANK DENSE_RANK
------ ---------------- ------------ ---------- ----------
MET01  L26-003B-02                20          1          1
MET01  L26-008-01                 20          1          1
MET01  L26-007-04                  6          3          2
MET01  L26-011-02                  6          3          2
MET02  L26-008-02                 19          1          1
MET02  L26-003B-01                15          2          2
MET02  L26-007-03                  6          3          3
MET02  L26-010-02                  6          3          3
MET03  L26-008-03                 20          1          1
MET03  L26-008-04                 20          1          1
MET03  L26-001-04                  6          3          2
MET03  L26-002-04                  6          3          2
```

(That table was built with an extra `ROW_NUMBER` only to pick four rows per tool. The 6-defect readings continue below the cut: MET01 has three of them and MET03 has six.)

**Step 3. Outer WHERE.** `rnk = 2` finds a row only in MET02. In MET01 and MET03 two readings tie at 20, so `RANK` jumps from 1 to 3 and no row has 2. `dense_rnk = 2` finds the 6-defect readings in MET01 and MET03 and the 15 in MET02.

**Step 4. ORDER BY tool_id, wafer_id.** Grouped by tool.

### Output of the DENSE_RANK version

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

### What to notice

With `RANK`, two tools vanish from the answer, and nothing warns you: the query runs fine and just returns less. `DENSE_RANK` gives the next value 2 in every tool, which is what "second-highest value" means. Rule: when the question is about the Nth value, use `DENSE_RANK`; when it is about the Nth reading, use `ROW_NUMBER`.
