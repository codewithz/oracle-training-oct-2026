# Lab 4 solutions: Summarising with GROUP BY

Try each exercise yourself first. Your query may differ from these and still be right: compare the **output**, not the spelling. The outputs below were produced by running each query on the lab data.

## Exercise 1: How many lots, and how many products

**Maya asks:** "How many lots do we have in total, and how many different products do those lots use?"

```sql
SELECT COUNT(*) AS lots, COUNT(DISTINCT product_id) AS products_used
FROM   lots;
```

<!--gen-->
```text
      LOTS PRODUCTS_USED
---------- -------------
        16             4
```

**Why it works / what to notice.** `COUNT(*)` counts rows: 16 lots. `COUNT(DISTINCT product_id)` counts each product once: 4. The `PRODUCTS` table holds 5, so one product has no lot yet. You just found a gap without a join. Topic 06 will name that product.

## Exercise 2: Graded and ungraded wafers

**Maya asks:** "How many wafers are there, and how many of them already have a grade?"

```sql
SELECT COUNT(*)     AS all_wafers,
       COUNT(grade) AS graded_wafers
FROM   wafers;
```

<!--gen-->
```text
ALL_WAFERS GRADED_WAFERS
---------- -------------
        66            64
```

**Why it works / what to notice.** `COUNT(*)` counts every row (66). `COUNT(grade)` skips rows where `grade` is `NULL` (64). The difference, 2, is the number of wafers still waiting for a grade. This is the cleanest way to count missing values: subtract the two counts.

## Exercise 3: Defects at ANNEAL

**Maya asks:** "Looking only at the ANNEAL step, what are the lowest and highest defect counts, the average (one decimal) and the total?"

```sql
SELECT MIN(defect_count)           AS fewest,
       MAX(defect_count)           AS most,
       ROUND(AVG(defect_count), 1) AS average,
       SUM(defect_count)           AS total
FROM   measurements
WHERE  step = 'ANNEAL';
```

<!--gen-->
```text
    FEWEST       MOST    AVERAGE      TOTAL
---------- ---------- ---------- ----------
         5         25       16.4       1015
```

**Why it works / what to notice.** `WHERE` sieves the receipts first, so only the 62 ANNEAL readings go into the single bowl. Then each aggregate looks into that bowl. If you leave out the `WHERE`, the numbers describe all three steps mixed together and mean much less.

## Exercise 4: Lots per status

**Maya asks:** "How many lots are in each status? Put the biggest group first."

```sql
SELECT status, COUNT(*) AS lots
FROM   lots
GROUP  BY status
ORDER  BY lots DESC;
```

<!--gen-->
```text
STATUS         LOTS
-------- ----------
ACTIVE            8
SHIPPED           5
HOLD              2
SCRAPPED          1
```

**Why it works / what to notice.** Four bowls, one per status. `ORDER BY` runs last, so it can use the alias `lots`. Add the four numbers: 8 + 5 + 2 + 1 = 16, the total from exercise 1. When your group counts add up to the table total, you know no row fell out of a bowl.

## Exercise 5: Defects per tool

**Maya asks:** "What is the total defect count per tool? Show the tool with the most defects first."

```sql
SELECT tool_id, SUM(defect_count) AS total_defects
FROM   measurements
GROUP  BY tool_id
ORDER  BY total_defects DESC;
```

<!--gen-->
```text
TOOL_ID TOTAL_DEFECTS
------- -------------
SPL02            1442
SPL01             894
ANL02             578
ANL01             437
MET01             110
MET03              99
MET02              74
```

Seven lines, not nine.

**Why it works / what to notice.** A bowl only exists if at least one row falls in it. `CMP01` and `IMP01` have no measurements, so they have no bowl, and they do not appear. The two splitting tools lead by a wide margin, which matches the defect counts falling from SPLIT to ANNEAL to FINAL that you saw in the reading. To show the missing tools with a zero you need a join, which is lab 5.

## Exercise 6: Lots per product and status

**Maya asks:** "For each product_id, how many lots are in each status?"

```sql
SELECT product_id, status, COUNT(*) AS lots
FROM   lots
GROUP  BY product_id, status
ORDER  BY product_id, status;
```

<!--gen-->
```text
PRODUCT_ID STATUS         LOTS
---------- -------- ----------
         1 ACTIVE            5
         1 HOLD              1
         1 SHIPPED           2
         2 ACTIVE            1
         2 SHIPPED           2
         3 SCRAPPED          1
         3 SHIPPED           1
         4 ACTIVE            2
         4 HOLD              1
```

**Why it works / what to notice.** Every different (product_id, status) pair is a bowl, so you get nine lines. Product 1 has the most lots, five of them still active. Product 5 is absent for the same reason as `CMP01` earlier: no lots, no bowl.

## Exercise 7: Lots with several bad wafers

**Maya asks:** "Which lots have at least 2 wafers that are not PRIME grade, and how many?"

```sql
SELECT lot_id, COUNT(*) AS not_prime
FROM   wafers
WHERE  grade <> 'PRIME'
GROUP  BY lot_id
HAVING COUNT(*) >= 2;
```

<!--gen-->
```text
LOT_ID      NOT_PRIME
---------- ----------
L26-008             4
```

**Why it works / what to notice.** Only `L26-008` appears: all four of its wafers are not PRIME. That is the scrapped lot. Wafers with a `NULL` grade are not counted at all, because `NULL <> 'PRIME'` is not true, it is unknown, and `WHERE` keeps only rows where the test is true. If you wanted to include ungraded wafers you would write `WHERE grade <> 'PRIME' OR grade IS NULL`.

## Exercise 8: Busy months

**Maya asks:** "For each month (like 2026-08), how many lots started, and what was the average priority to one decimal? Only show months with more than 7 lots."

```sql
SELECT TO_CHAR(start_date, 'YYYY-MM') AS yr_mon,
       COUNT(*)                       AS lots_started,
       ROUND(AVG(priority), 1)        AS avg_priority
FROM   lots
GROUP  BY TO_CHAR(start_date, 'YYYY-MM')
HAVING COUNT(*) > 7;
```

<!--gen-->
```text
YR_MON  LOTS_STARTED AVG_PRIORITY
------- ------------ ------------
2026-08            9          1.9
```

**Why it works / what to notice.** August has 9 lots and September has 7. The bowl for September is thrown away because 7 is not more than 7. The average priority is 1.9, where priority 1 is the most urgent. Try `HAVING COUNT(*) > 6` to see the second bowl come back. The `GROUP BY` expression must match the one in `SELECT`.

## Exercise 9: Fix the broken query

**Maya asks:** "I tried to get the number of wafers per lot with the grade next to it, and Oracle shouted at me. Can you fix it so it gives one line per lot and grade?"

Maya's attempt fails on purpose. Read the message: it points a `*` at `grade`.

```sql
SELECT lot_id, grade, COUNT(*) AS wafers
FROM   wafers
GROUP  BY lot_id
ORDER  BY lot_id;
```

<!--gen-->
```text
SELECT lot_id, grade, COUNT(*) AS wafers
               *
ERROR at line 1:
ORA-00979: not a GROUP BY expression
```

The fixed query:

```sql
SELECT lot_id, grade, COUNT(*) AS wafers
FROM   wafers
GROUP  BY lot_id, grade
ORDER  BY lot_id, grade
FETCH FIRST 8 ROWS ONLY;
```

<!--gen-->
```text
LOT_ID     GRADE      WAFERS
---------- ------ ----------
L26-001    PRIME           4
L26-001    TEST            1
L26-002    PRIME           4
L26-002    TEST            1
L26-003    PRIME           4
L26-003    TEST            1
L26-003A   PRIME           3
L26-003B   PRIME           2
```

**Why it works / what to notice.** The bowl for a lot holds wafers of several grades, so Oracle cannot decide which grade to print on the single line for that lot. Adding `grade` to `GROUP BY` makes a bowl per (lot, grade) pair, and each bowl has exactly one grade. The alternative fix is to remove `grade` from the `SELECT`. Which one is right depends on what Maya wanted. Here she asked for the grade, so the first fix is the one. The `FETCH FIRST 8 ROWS ONLY` is only there to keep this printout short.

## Stretch: tools with a high average

**Maya asks:** "Which tools have an average defect count above 20 across all their measurements?"

```sql
SELECT tool_id,
       ROUND(AVG(defect_count), 1) AS avg_defects,
       COUNT(*)                    AS measurements
FROM   measurements
GROUP  BY tool_id
HAVING AVG(defect_count) > 20
ORDER  BY avg_defects DESC;
```

<!--gen-->
```text
TOOL_ID AVG_DEFECTS MEASUREMENTS
------- ----------- ------------
SPL02            39           37
SPL01          35.8           25
```

**Why it works / what to notice.** `HAVING AVG(defect_count) > 20` throws away every bowl whose average is 20 or less. Only `SPL01` and `SPL02` survive: the splitting tools are where the defects pile up, and the counts fall at the later steps. Showing `COUNT(*)` next to an average tells the reader how many readings stand behind it.
