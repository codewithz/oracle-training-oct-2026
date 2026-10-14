# Ranking: ROW_NUMBER, RANK, DENSE_RANK and top-N per group

"Which wafer has the most defects?" is a one-line query. "Which wafer has the most defects on each tool?" is a different kind of question, and the answer needs ranking inside groups. This page shows the three ranking functions, what each does with ties, and the standard way to keep only the top rows of every group.

Watch the animated page first: [Ranking, animated](../tutorials/02-ranking.html).

**By the end of this page you can:**

- number rows with `ROW_NUMBER`, `RANK` and `DENSE_RANK` and predict the output when there are ties
- choose between the three for a given question
- write a "top N per group" query with an inline view or `WITH`
- use `FETCH FIRST n ROWS WITH TIES` for a plain top N and explain what it cannot do
- split rows into equal buckets with `NTILE`

## The question this answers

Maya wants the best wafers of each lot: the two with the fewest defects. Topic 01 put a group figure beside every row, but "best two" needs something different: each row's position in a sorted list, restarting at 1 for every lot. Without a ranking function she would sort and count by hand, or write a subquery that counts how many rows are better than this one, for every row. The part that needs thought is a tie. Two wafers with zero defects are equally good, and the three functions answer "what position is the next wafer?" in three different ways.

## The analogy: a school race

Five pupils run a race and the teacher writes down the times. Two of them finish with the same time. Now she has to put a number next to each name, and she has three ways to do it.

| Pupil | Time | Just count | Share, skip | Share, no skip |
|---|---|---|---|---|
| Asha | 12.0 | 1 | 1 | 1 |
| Ben | 12.1 | 2 | 2 | 2 |
| Chen | 12.1 | 3 | 2 | 2 |
| Dev | 13.0 | 4 | 4 | 3 |
| Eli | 13.4 | 5 | 5 | 4 |

- Just count: 1, 2, 3, 4, 5. Ben and Chen ran the same time but get different numbers. This is `ROW_NUMBER`.
- Share, skip: tied pupils share a number and the next number is skipped, like at the Olympics. Two pupils are 2nd, so nobody is 3rd. This is `RANK`.
- Share, no skip: tied pupils share a number and the next number follows on. Dev is 3rd. This is `DENSE_RANK`.

The difference matters when you pick winners. "Give a medal to everyone in the top 2": with just counting, Chen misses out although Chen ran exactly the same time as Ben. With either sharing method, Chen gets a medal too.

If there were two races, 100 m and 200 m, each race would be numbered on its own. That is `PARTITION BY`.

**Where the picture breaks.**

- The teacher can say "Ben registered first". Oracle will not guess. With `ROW_NUMBER` and a tie, it picks one row and does not say which, and it can pick the other one next week. Add a second sort column, such as `wafer_id`, to make the order certain.
- Nothing is written down. The numbers exist only in the result of the query and are worked out again each time it runs.

## What Oracle actually does

1. Build the row set with `FROM`, joins, `WHERE`, `GROUP BY` and `HAVING`. Rows removed here are not ranked and do not count as ahead of anyone.
2. Split into partitions by `PARTITION BY`. With none, the whole result is one list.
3. Sort each partition by the `ORDER BY` inside `OVER`. It is required: a ranking function without it fails with `ORA-30485`. A plan shows the sort as `WINDOW SORT`.
4. Walk down each sorted list once, comparing every row with the one above. A tie means every `ORDER BY` column equals the row above. `ROW_NUMBER` ignores the comparison and counts. `RANK` copies the number above on a tie, otherwise writes the row's place in the list. `DENSE_RANK` copies on a tie, otherwise writes the number above plus one.
5. Attach the number as a new column. No row is removed. At the first row of the next partition the numbering restarts at 1.
6. Finish the query. To keep only the first N, rank in an inner query and filter in an outer one.

| In Oracle | In the race |
|---|---|
| `PARTITION BY` | one race, numbered on its own |
| `ORDER BY` inside `OVER` | fastest first |
| `ROW_NUMBER` | just count |
| `RANK` | share, skip: a gap after a tie |
| `DENSE_RANK` | share, no skip |
| second sort column | "who registered first?" |
| `WHERE rk <= 2` in an outer query | hand out medals after the numbers are written |

## Step 1: the three functions side by side

Maya: "Rank the ANNEAL readings by defect count, worst first. Show me the top ten."

```sql
SELECT wafer_id,
       tool_id,
       defect_count,
       ROW_NUMBER() OVER (ORDER BY defect_count DESC) AS row_num,
       RANK()       OVER (ORDER BY defect_count DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY defect_count DESC) AS dense_rnk
FROM   measurements
WHERE  step = 'ANNEAL'
ORDER  BY defect_count DESC, wafer_id
FETCH FIRST 10 ROWS ONLY;
```
<!--gen-->
```text
WAFER_ID         TOOL_I DEFECT_COUNT    ROW_NUM        RNK  DENSE_RNK
---------------- ------ ------------ ---------- ---------- ----------
L26-003-05       ANL02            25          1          1          1
L26-003-01       ANL01            24          2          2          2
L26-003-02       ANL02            24          3          2          2
L26-007-02       ANL01            24          4          2          2
L26-011-02       ANL02            24          5          2          2
L26-001-01       ANL02            23          6          6          3
L26-001-04       ANL02            23          7          6          3
L26-005-01       ANL02            23          8          6          3
L26-007-05       ANL02            23          9          6          3
L26-010-04       ANL02            23         10          6          3
```

One reading has 25 defects and is alone in first place. Then four readings share 24, and five share 23:

| defects | row_num | rnk | dense_rnk |
| --- | --- | --- | --- |
| 25 | 1 | 1 | 1 |
| 24 (four readings) | 2, 3, 4, 5 | 2, 2, 2, 2 | 2, 2, 2, 2 |
| 23 (next group) | 6 and on | 6 | 3 |

`RANK` jumps from 2 to 6, because four readings stand ahead of the next one. `DENSE_RANK` goes from 2 to 3 and never skips. `ROW_NUMBER` never repeats, so it has to pick an order among the four readings that tied. Oracle makes that choice arbitrarily, and a second run, or a different server, may order those four differently.

You need an `ORDER BY` inside `OVER`. A ranking without an order has no meaning, and Oracle raises `ORA-30485` if you leave it out.

> Rule of thumb: `ROW_NUMBER` when you need exactly one row per group. `RANK` when ties should share a place and you want everyone who is tied. `DENSE_RANK` when you want "second highest value" with no gaps.

## Step 2: make ROW_NUMBER repeatable

If you must have exactly one row, give the window a tie-breaker. Add a second column to the `ORDER BY` inside `OVER`, one that is unique.

```sql
SELECT wafer_id,
       defect_count,
       ROW_NUMBER() OVER (ORDER BY defect_count DESC, wafer_id) AS row_num
FROM   measurements
WHERE  step = 'ANNEAL'
ORDER  BY row_num
FETCH FIRST 6 ROWS ONLY;
```
<!--gen-->
```text
WAFER_ID         DEFECT_COUNT    ROW_NUM
---------------- ------------ ----------
L26-003-05                 25          1
L26-003-01                 24          2
L26-003-02                 24          3
L26-007-02                 24          4
L26-011-02                 24          5
L26-001-01                 23          6
```

Now the four readings with 24 defects are numbered in wafer order, and the same query gives the same answer every day. Choose the tie-breaker by what makes business sense. Here it is just alphabetical, which is honest but arbitrary. "Latest `meas_time` first" is often a better rule.

## Step 3: ranking within groups

`PARTITION BY` restarts the numbering for every group. Maya: "Rank the lots of each product by their total defects."

```sql
SELECT p.product_code,
       l.lot_id,
       SUM(m.defect_count) AS total_defects,
       RANK() OVER (PARTITION BY p.product_code
                    ORDER BY SUM(m.defect_count) DESC) AS rank_in_product
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY p.product_code, l.lot_id
ORDER  BY p.product_code, rank_in_product, l.lot_id;
```
<!--gen-->
```text
PRODUCT_CODE LOT_ID       TOTAL_DEFECTS RANK_IN_PRODUCT
------------ ------------ ------------- ---------------
FD-300       L26-011                344               1
FD-300       L26-007                302               2
FD-300       L26-001                295               3
FD-300       L26-003                282               4
FD-300       L26-003A               172               5
FD-300       L26-003B1              123               6
FD-300       L26-003B               122               7
FD-300       L26-007A               113               8
PHO-300      L26-009                317               1
PHO-300      L26-005                240               2
PWR-200      L26-004                295               1
PWR-200      L26-008                276               2
RF-300       L26-010                299               1
RF-300       L26-006                235               2
RF-300       L26-002                219               3
```

The query groups first (one line per lot), then the window ranks those lines inside each product. This is the "window on top of `GROUP BY`" idea from the last page: the `SUM` inside `OVER` is the group total. Each product has its own 1, 2, 3 ... and the numbering starts again at the next product.

Across all lots, without a partition, a tie shows up like this:

```sql
SELECT w.lot_id,
       SUM(m.defect_count) AS total_defects,
       RANK()       OVER (ORDER BY SUM(m.defect_count) DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY SUM(m.defect_count) DESC) AS dense_rnk
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
GROUP  BY w.lot_id
ORDER  BY total_defects DESC, w.lot_id
FETCH FIRST 8 ROWS ONLY;
```
<!--gen-->
```text
LOT_ID       TOTAL_DEFECTS        RNK  DENSE_RNK
------------ ------------- ---------- ----------
L26-011                344          1          1
L26-009                317          2          2
L26-007                302          3          3
L26-010                299          4          4
L26-001                295          5          5
L26-004                295          5          5
L26-003                282          7          6
L26-008                276          8          7
```

Lots `L26-001` and `L26-004` have the same total and share fifth place. The next lot is seventh with `RANK` and sixth with `DENSE_RANK`.

## Step 4: top N per group

This is the most common reason people learn ranking. Maya: "For each tool, which reading had the most defects?"

You cannot filter on a window function in `WHERE`, as the last page showed. So the recipe has two layers: rank in an inner query, keep rank 1 in the outer query.

```sql
SELECT tool_id, wafer_id, step, defect_count
FROM  (SELECT tool_id, wafer_id, step, defect_count,
              ROW_NUMBER() OVER (PARTITION BY tool_id
                                 ORDER BY defect_count DESC, wafer_id) AS rn
       FROM   measurements)
WHERE  rn = 1
ORDER  BY tool_id;
```
<!--gen-->
```text
TOOL_I WAFER_ID         STEP     DEFECT_COUNT
------ ---------------- -------- ------------
ANL01  L26-003-01       ANNEAL             24
ANL02  L26-003-05       ANNEAL             25
MET01  L26-003B-02      FINAL              20
MET02  L26-008-02       FINAL              19
MET03  L26-008-03       FINAL              20
SPL01  L26-007-04       SPLIT              60
SPL02  L26-004-01       SPLIT              57
```

Seven tools, seven lines: exactly one reading per tool. Now the same question with `RANK`:

```sql
SELECT tool_id, wafer_id, step, defect_count
FROM  (SELECT tool_id, wafer_id, step, defect_count,
              RANK() OVER (PARTITION BY tool_id
                           ORDER BY defect_count DESC) AS rnk
       FROM   measurements)
WHERE  rnk = 1
ORDER  BY tool_id, wafer_id;
```
<!--gen-->
```text
TOOL_I WAFER_ID         STEP     DEFECT_COUNT
------ ---------------- -------- ------------
ANL01  L26-003-01       ANNEAL             24
ANL01  L26-007-02       ANNEAL             24
ANL02  L26-003-05       ANNEAL             25
MET01  L26-003B-02      FINAL              20
MET01  L26-008-01       FINAL              20
MET02  L26-008-02       FINAL              19
MET03  L26-008-03       FINAL              20
MET03  L26-008-04       FINAL              20
SPL01  L26-007-04       SPLIT              60
SPL02  L26-004-01       SPLIT              57
SPL02  L26-010-02       SPLIT              57
```

Eleven lines. Four tools had a tie for the worst reading (`ANL01`, `MET01`, `MET03` and `SPL02`), and `RANK` keeps everyone who tied. Neither answer is wrong. The question to ask Maya is: "If two wafers tie for the worst, do you want one of them or both?" That decides `ROW_NUMBER` or `RANK`.

For "top 2 per group", change the filter to `rnk <= 2` (or `rn <= 2`). With `RANK`, the number of rows can exceed 2 when there are ties.

```sql
SELECT tool_id, wafer_id, defect_count, rnk
FROM  (SELECT tool_id, wafer_id, defect_count,
              RANK() OVER (PARTITION BY tool_id
                           ORDER BY defect_count DESC) AS rnk
       FROM   measurements)
WHERE  rnk <= 2
AND    tool_id IN ('ANL02', 'MET02')
ORDER  BY tool_id, rnk, wafer_id;
```
<!--gen-->
```text
TOOL_I WAFER_ID         DEFECT_COUNT        RNK
------ ---------------- ------------ ----------
ANL02  L26-003-05                 25          1
ANL02  L26-003-02                 24          2
ANL02  L26-011-02                 24          2
MET02  L26-008-02                 19          1
MET02  L26-003B-01                15          2
```

`ANL02` has one reading in first place and two tied in second. `MET02` has first and second place with a single reading each. The same recipe written with `WITH` reads from top to bottom:

```sql
WITH ranked AS (
  SELECT tool_id, wafer_id, defect_count,
         DENSE_RANK() OVER (PARTITION BY tool_id
                            ORDER BY defect_count DESC) AS drnk
  FROM   measurements
)
SELECT tool_id, wafer_id, defect_count, drnk
FROM   ranked
WHERE  drnk = 2
ORDER  BY tool_id, wafer_id;
```
<!--gen-->
```text
TOOL_I WAFER_ID         DEFECT_COUNT       DRNK
------ ---------------- ------------ ----------
ANL01  L26-006-01                 22          2
ANL01  L26-008-01                 22          2
ANL01  L26-009-05                 22          2
ANL02  L26-003-02                 24          2
ANL02  L26-011-02                 24          2
MET01  L26-007-04                  6          2
MET01  L26-011-02                  6          2
MET01  L26-011-03                  6          2
MET02  L26-003B-01                15          2
MET03  L26-001-04                  6          2
MET03  L26-002-04                  6          2
MET03  L26-004-01                  6          2
MET03  L26-009-05                  6          2
MET03  L26-011-01                  6          2
MET03  L26-011-05                  6          2
SPL01  L26-003B1-01               59          2
SPL02  L26-003-05                 55          2
```

`DENSE_RANK = 2` means "the second highest value, however many readings share it". That is the right tool for questions like "what is the second worst count on each tool?".

## Step 5: FETCH FIRST n ROWS WITH TIES

You may know `FETCH FIRST 3 ROWS ONLY` from the basics. It cuts the sorted list after three rows, even if the third and fourth are tied. `WITH TIES` keeps every row that ties with the last one.

```sql
SELECT wafer_id, step, defect_count
FROM   measurements
ORDER  BY defect_count DESC
FETCH FIRST 3 ROWS ONLY;
```
<!--gen-->
```text
WAFER_ID         STEP     DEFECT_COUNT
---------------- -------- ------------
L26-007-04       SPLIT              60
L26-003B1-01     SPLIT              59
L26-004-01       SPLIT              57
```

```sql
SELECT wafer_id, step, defect_count
FROM   measurements
ORDER  BY defect_count DESC
FETCH FIRST 3 ROWS WITH TIES;
```
<!--gen-->
```text
WAFER_ID         STEP     DEFECT_COUNT
---------------- -------- ------------
L26-007-04       SPLIT              60
L26-003B1-01     SPLIT              59
L26-004-01       SPLIT              57
L26-010-02       SPLIT              57
```

The first query silently drops one of the two readings with 57 defects, and which one is arbitrary. The second returns both, so four rows came back for "top 3". It behaves like `RANK() ... <= 3`.

`FETCH FIRST` is the simplest way to ask for a top N over the whole result, and it needs no inline view. It cannot do "per group". For that, use the window recipe from step 4.

## Step 6: NTILE, equal buckets

`NTILE(n)` deals the ordered rows into `n` buckets of nearly equal size. Use it for quartiles or for "the worst quarter of lots". Maya: "Split the lots into four groups by total defects, worst first."

```sql
SELECT lot_id, total_defects,
       NTILE(4) OVER (ORDER BY total_defects DESC) AS quartile
FROM  (SELECT w.lot_id, SUM(m.defect_count) AS total_defects
       FROM   measurements m
       JOIN   wafers w ON w.wafer_id = m.wafer_id
       GROUP  BY w.lot_id)
ORDER  BY total_defects DESC, lot_id;
```
<!--gen-->
```text
LOT_ID       TOTAL_DEFECTS   QUARTILE
------------ ------------- ----------
L26-011                344          1
L26-009                317          1
L26-007                302          1
L26-010                299          1
L26-001                295          2
L26-004                295          2
L26-003                282          2
L26-008                276          2
L26-005                240          3
L26-006                235          3
L26-002                219          3
L26-003A               172          3
L26-003B1              123          4
L26-003B               122          4
L26-007A               113          4
```

Fifteen lots do not divide evenly by four. The first buckets get one extra row: sizes 4, 4, 4, 3 (the 16th lot, `L26-012`, has no measurements, so it is not in the list). `NTILE` makes buckets of equal row count, not equal value ranges, and it can split a group of tied rows across two buckets.

## Three common misreadings

**"RANK skips numbers, so something went wrong."** The gap is the design. `RANK` writes the place the row holds in the line, and after a tie several rows stand ahead of the next one. `DENSE_RANK` never leaves a gap, and its highest value equals the number of different values in the partition.

**"WHERE rk <= 2 gives me two rows per lot."** It gives every row whose number is 2 or less. With `RANK` or `DENSE_RANK` that is two rows only when nobody ties. In L26-002 it is four. For exactly N rows use `ROW_NUMBER`. For "everyone who ties for a place" use `RANK`.

**"ROW_NUMBER sorts tied rows fairly."** It sorts them in whichever order Oracle meets them, and that can change after an index is added or the table grows. Put a column that makes every row unique at the end of the `ORDER BY`, such as `wafer_id`, and say how the tie was broken.

## Common mistakes

- Using `ROW_NUMBER` when ties matter. Two wafers tie for the worst reading and one of them vanishes from the report, chosen by chance. Add a tie-breaker or use `RANK`.
- Expecting `RANK` to give exactly N rows. It returns everyone who ties.
- Forgetting that `RANK` skips numbers and `DENSE_RANK` does not.
- Filtering a ranking in `WHERE`. This raises `ORA-30483`. Rank in an inner query, filter outside.
- Ranking without `PARTITION BY` when the question says "per" something.
- Reading `NTILE` as a value range. It counts rows.

## Check your understanding

1. Scores are 90, 85, 85, 70. Write the `ROW_NUMBER`, `RANK` and `DENSE_RANK` values in order of score, best first.
2. Which of the three would you use for "the second highest defect count per tool"?
3. Why does `FETCH FIRST 3 ROWS WITH TIES` sometimes return more than three rows?
4. How do you get the single best reading per tool, with the earliest `meas_time` winning a tie?

<details>
<summary>Answers</summary>

1. `ROW_NUMBER`: 1, 2, 3, 4 (the order of the two 85s is arbitrary). `RANK`: 1, 2, 2, 4. `DENSE_RANK`: 1, 2, 2, 3.
2. `DENSE_RANK`, filtered with `= 2`. It gives the second distinct value and includes all readings that have it.
3. It keeps every row that ties with the last row of the top three.
4. `ROW_NUMBER() OVER (PARTITION BY tool_id ORDER BY defect_count DESC, meas_time)` in an inner query, then `WHERE rn = 1` outside.

</details>

## Further reading

- [Oracle Database 19c SQL Language Reference: RANK](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/RANK.html)
- [Oracle Database 19c SQL Language Reference: ROW_NUMBER](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ROW_NUMBER.html)
- [ORACLE-BASE: Analytic functions](https://oracle-base.com/articles/misc/analytic-functions)
