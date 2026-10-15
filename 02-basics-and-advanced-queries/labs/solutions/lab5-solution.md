# Lab 5 solutions: Joins

Try each exercise yourself first. Your query may differ from these and still be right: compare the **output**, not the spelling. The outputs below were produced by running each query on the lab data.

## Exercise 1: Active lots with their product

**Maya asks:** "List the active lots with their product code and family, in lot order."

```sql
SELECT l.lot_id, p.product_code, p.family
FROM   lots l
JOIN   products p ON p.product_id = l.product_id
WHERE  l.status = 'ACTIVE'
ORDER  BY l.lot_id;
```

<!--gen-->
```text
LOT_ID     PRODUCT_CODE FAMILY
---------- ------------ --------------
L26-003    FD-300       FD-SOI
L26-003B1  FD-300       FD-SOI
L26-007    FD-300       FD-SOI
L26-007A   FD-300       FD-SOI
L26-009    PHO-300      Photonics-SOI
L26-010    RF-300       RF-SOI
L26-011    FD-300       FD-SOI
L26-012    PHO-300      Photonics-SOI
```

**Why it works / what to notice.** The `ON` line is the string between the two shelves: a lot and a product are paired when their `product_id` is the same. `WHERE` then works on the joined rows exactly as before. There are 8 rows because there are 8 active lots, and each lot found exactly one product.

## Exercise 2: Scrap wafers and their product

**Maya asks:** "Which wafers have grade SCRAP? For each, show the wafer, its lot and the product code."

```sql
SELECT w.wafer_id, l.lot_id, p.product_code
FROM   wafers w
JOIN   lots l     ON l.lot_id = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  w.grade = 'SCRAP'
ORDER  BY w.wafer_id;
```

<!--gen-->
```text
WAFER_ID     LOT_ID     PRODUCT_CODE
------------ ---------- ------------
L26-008-01   L26-008    PWR-200
L26-008-02   L26-008    PWR-200
L26-008-03   L26-008    PWR-200
L26-008-04   L26-008    PWR-200
```

**Why it works / what to notice.** Each extra `JOIN` brings one more shelf, tied to the one before it. All four scrap wafers are in `L26-008`, the lot whose status is SCRAPPED, which makes sense. Data that agrees with itself from two directions is a good sign.

## Exercise 3: Which tool measured which wafer

**Maya asks:** "For the wafers of lot L26-003B, show every measurement with the step, the tool, the tool type and the bay. Order by wafer and time."

```sql
SELECT m.wafer_id, m.step, m.tool_id, t.tool_type, t.bay
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
JOIN   tools t  ON t.tool_id = m.tool_id
WHERE  w.lot_id = 'L26-003B'
ORDER  BY m.wafer_id, m.meas_time;
```

<!--gen-->
```text
WAFER_ID     STEP     TOOL_ID TOOL_TYPE    BAY
------------ -------- ------- ------------ ----
L26-003B-01  SPLIT    SPL02   SPLIT        B1
L26-003B-01  ANNEAL   ANL02   ANNEAL       B2
L26-003B-01  FINAL    MET02   METROLOGY    B3
L26-003B-02  SPLIT    SPL01   SPLIT        B1
L26-003B-02  ANNEAL   ANL02   ANNEAL       B2
L26-003B-02  FINAL    MET01   METROLOGY    B3
```

**Why it works / what to notice.** `measurements` has the tool name but not its type or bay, so the join to `TOOLS` adds those. It also has the wafer but not its lot, so the join to `WAFERS` lets you filter by lot. Two small joins, each one a line on the map. Count the rows: 2 wafers times 3 steps is 6, which is what you got. Doing that sum is a cheap way to catch a bad join.

## Exercise 4: Reading against target

**Maya asks:** "For lot L26-006, show each FINAL reading next to the product target, and how far apart they are (thickness minus target, two decimals)."

```sql
SELECT m.wafer_id,
       m.thickness_nm,
       p.target_thk_nm,
       ROUND(m.thickness_nm - p.target_thk_nm, 2) AS diff_nm
FROM   measurements m
JOIN   wafers w   ON w.wafer_id = m.wafer_id
JOIN   lots l     ON l.lot_id = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
AND    l.lot_id = 'L26-006'
ORDER  BY m.wafer_id;
```

<!--gen-->
```text
WAFER_ID     THICKNESS_NM TARGET_THK_NM    DIFF_NM
------------ ------------ ------------- ----------
L26-006-01          73.77            75      -1.23
L26-006-02          74.49            75       -.51
L26-006-03          75.47            75        .47
L26-006-04          74.17            75       -.83
L26-006-05          74.79            75       -.21
```

**Why it works / what to notice.** The target lives only on `PRODUCTS`, three hops from the reading. The chain is measurement to wafer to lot to product, and each `ON` joins a foreign key to its primary key. The differences are small and mixed in sign, around one nanometre either side. Keep this query: it is the base of the capstone.

## Exercise 5: Products with no lots, tools never used

**Maya asks:** "Which products have no lots at all? And which tools have never taken a measurement? Two queries."

Products with no lots:

```sql
SELECT p.product_code, p.family
FROM   products p
LEFT   JOIN lots l ON l.product_id = p.product_id
WHERE  l.lot_id IS NULL;
```

<!--gen-->
```text
PRODUCT_CODE FAMILY
------------ --------------
SIC-150      SiC
```

Tools never used:

```sql
SELECT t.tool_id, t.tool_type, t.bay
FROM   tools t
LEFT   JOIN measurements m ON m.tool_id = t.tool_id
WHERE  m.meas_id IS NULL
ORDER  BY t.tool_id;
```

<!--gen-->
```text
TOOL_ID TOOL_TYPE    BAY
------- ------------ ----
CMP01   POLISH       B4
IMP01   IMPLANT      B1
```

**Why it works / what to notice.** The left join pairs every product with its lots, and a product with none gets one row with `NULL` on the lot side. Testing the right-hand primary key for `NULL` picks out exactly those rows. A real lot can never have a `NULL` lot_id, so the test is safe. It is the same trick as in lab 4, where `CMP01` and `IMP01` were missing from the bowls. Now you can name them.

## Exercise 6: Lots with wafers but no readings

**Maya asks:** "Which lots have wafers, but none of those wafers has been measured yet? Show the lot and how many wafers are waiting."

```sql
SELECT l.lot_id, COUNT(*) AS wafers_waiting
FROM   lots l
JOIN   wafers w ON w.lot_id = l.lot_id
LEFT   JOIN measurements m ON m.wafer_id = w.wafer_id
WHERE  m.meas_id IS NULL
GROUP  BY l.lot_id
ORDER  BY l.lot_id;
```

<!--gen-->
```text
LOT_ID     WAFERS_WAITING
---------- --------------
L26-012                 4
```

**Why it works / what to notice.** Inner join first, then the left join, in the order of the map. Wafers with no readings get `NULL` in every `m.` column, and the `WHERE` keeps only those. Then `GROUP BY` counts them per lot. `L26-012` is the lot. If you filtered `m.step = 'FINAL'` in the `WHERE` instead, you would lose these `NULL` rows.

## Exercise 7: Lots per product, with zeros

**Maya asks:** "How many lots does each product have? I want to see products with none, showing 0."

```sql
SELECT p.product_code,
       COUNT(*)        AS count_star,
       COUNT(l.lot_id) AS lots
FROM   products p
LEFT   JOIN lots l ON l.product_id = p.product_id
GROUP  BY p.product_code
ORDER  BY p.product_code;
```

<!--gen-->
```text
PRODUCT_CODE COUNT_STAR       LOTS
------------ ---------- ----------
FD-300                8          8
PHO-300               3          3
PWR-200               2          2
RF-300                3          3
SIC-150               1          0
```

**Why it works / what to notice.** `COUNT(*)` counts the one row the left join invented for `SIC-150`, so it says 1. `COUNT(l.lot_id)` counts only real lots, so it says 0. On an outer join always count a column from the right-hand table. This is the trap from the reading, and it is the single most common mistake with `LEFT JOIN`.

## Exercise 8: Children of a lot on hold

**Maya asks:** "Which split or reworked lots came from a parent lot that is on HOLD? Show the child, its type, the parent and the parent's hold reason."

```sql
SELECT child.lot_id,
       child.lot_type,
       parent.lot_id AS parent_lot,
       parent.hold_reason
FROM   lots child
JOIN   lots parent ON child.parent_lot_id = parent.lot_id
WHERE  parent.status = 'HOLD';
```

<!--gen-->
```text
LOT_ID     LOT_TYPE PARENT_LOT   HOLD_REASON
---------- -------- ------------ --------------------------------
L26-003B1  REWORK   L26-003B     Thickness out of spec at FINAL
```

**Why it works / what to notice.** A self join is an ordinary join where both shelves happen to be the same table. The aliases `child` and `parent` give the table two roles. The reworked lot `L26-003B1` came from `L26-003B`, which is on hold because the thickness was out of spec at FINAL. That is the story from the reading, now found by a query.

## Exercise 9: Capstone: readings far from target

**Maya asks:** "Which lots had a FINAL reading more than 0.3 nm away from their product target, and on which tool?"

Level 2: all FINAL readings against target (first 10 rows only).

```sql
SELECT l.lot_id,
       m.tool_id,
       m.thickness_nm,
       p.target_thk_nm,
       ROUND(m.thickness_nm - p.target_thk_nm, 2) AS diff_nm
FROM   measurements m
JOIN   wafers w   ON w.wafer_id = m.wafer_id
JOIN   lots l     ON l.lot_id = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
ORDER  BY l.lot_id, m.wafer_id
FETCH FIRST 10 ROWS ONLY;
```

<!--gen-->
```text
LOT_ID     TOOL_ID THICKNESS_NM TARGET_THK_NM    DIFF_NM
---------- ------- ------------ ------------- ----------
L26-001    MET01          11.89            12       -.11
L26-001    MET02          11.99            12       -.01
L26-001    MET02          12.06            12        .06
L26-001    MET03          12.03            12        .03
L26-001    MET01          11.86            12       -.14
L26-002    MET03          75.57            75        .57
L26-002    MET01          74.37            75       -.63
L26-002    MET02          75.02            75        .02
L26-002    MET03          74.52            75       -.48
L26-002    MET01          75.19            75        .19
```

Level 3: keep only the readings more than 0.3 nm away from the target, too thick or too thin. All of them, 28 rows:

```sql
SELECT l.lot_id,
       m.tool_id,
       m.thickness_nm,
       p.target_thk_nm,
       ROUND(m.thickness_nm - p.target_thk_nm, 2) AS diff_nm
FROM   measurements m
JOIN   wafers w   ON w.wafer_id = m.wafer_id
JOIN   lots l     ON l.lot_id = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
AND    ABS(m.thickness_nm - p.target_thk_nm) > 0.3
ORDER  BY l.lot_id, m.tool_id, m.wafer_id;
```

<!--gen-->
```text
LOT_ID     TOOL_ID THICKNESS_NM TARGET_THK_NM    DIFF_NM
---------- ------- ------------ ------------- ----------
L26-002    MET01          74.37            75       -.63
L26-002    MET03          75.57            75        .57
L26-002    MET03          74.52            75       -.48
L26-003B   MET01          12.64            12        .64
L26-003B   MET02           12.5            12         .5
L26-004    MET01        1490.27          1500      -9.73
L26-004    MET01        1481.49          1500     -18.51
L26-004    MET02        1509.67          1500       9.67
L26-004    MET03        1496.48          1500      -3.52
L26-004    MET03        1489.32          1500     -10.68
L26-005    MET01         221.07           220       1.07
L26-005    MET01         216.63           220      -3.37
L26-005    MET01         215.62           220      -4.38
L26-006    MET01          74.49            75       -.51
L26-006    MET02          73.77            75      -1.23
L26-006    MET02          75.47            75        .47
L26-006    MET03          74.17            75       -.83
L26-008    MET01        1551.89          1500      51.89
L26-008    MET02        1580.16          1500      80.16
L26-008    MET03        1570.47          1500      70.47
L26-008    MET03         1582.6          1500       82.6
L26-009    MET02         222.79           220       2.79
L26-009    MET02         217.67           220      -2.33
L26-009    MET02          216.6           220       -3.4
L26-009    MET03         221.72           220       1.72
L26-010    MET02          73.66            75      -1.34
L26-010    MET03           75.6            75         .6
L26-010    MET03          75.64            75        .64
```

Level 4: the short answer for Maya, one line per lot and tool.

```sql
SELECT l.lot_id,
       p.product_code,
       m.tool_id,
       COUNT(*) AS bad_readings,
       ROUND(MAX(ABS(m.thickness_nm - p.target_thk_nm)), 2) AS worst_nm
FROM   measurements m
JOIN   wafers w   ON w.wafer_id = m.wafer_id
JOIN   lots l     ON l.lot_id = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
AND    ABS(m.thickness_nm - p.target_thk_nm) > 0.3
GROUP  BY l.lot_id, p.product_code, m.tool_id
ORDER  BY l.lot_id, m.tool_id;
```

<!--gen-->
```text
LOT_ID     PRODUCT_CODE TOOL_ID BAD_READINGS   WORST_NM
---------- ------------ ------- ------------ ----------
L26-002    RF-300       MET01              1        .63
L26-002    RF-300       MET03              2        .57
L26-003B   FD-300       MET01              1        .64
L26-003B   FD-300       MET02              1         .5
L26-004    PWR-200      MET01              2      18.51
L26-004    PWR-200      MET02              1       9.67
L26-004    PWR-200      MET03              2      10.68
L26-005    PHO-300      MET01              3       4.38
L26-006    RF-300       MET01              1        .51
L26-006    RF-300       MET02              2       1.23
L26-006    RF-300       MET03              1        .83
L26-008    PWR-200      MET01              1      51.89
L26-008    PWR-200      MET02              1      80.16
L26-008    PWR-200      MET03              2       82.6
L26-009    PHO-300      MET02              3        3.4
L26-009    PHO-300      MET03              1       1.72
L26-010    RF-300       MET02              1       1.34
L26-010    RF-300       MET03              2        .64
```

**Why it works / what to notice.** The four-step method gave the plan: look for FINAL readings, in the four tables on the path from reading to target, keeping rows where the absolute difference exceeds 0.3, showing the lot and the tool. Layer by layer: the join chain first (check 62 rows), then the filter (28 rows), then the summary. Three details matter. `ABS` catches both too thick and too thin. The expression is repeated in `WHERE` because `WHERE` runs before `SELECT` and cannot see the alias. And the tool comes straight from the measurement row, so no join to `TOOLS` is needed. Read the result as Maya would: lot `L26-008` (the scrapped lot) is far off, and so are several others. Note that `L26-003B`, the lot that went on hold, shows up with only slightly bad readings. The 0.3 nm cut-off is generous for thin products like FD-300 (target 12 nm) and tight for PWR-200 (target 1500 nm), which a real engineer would probably scale by the target. That is a good question to put back to Maya.

## Stretch: bad readings per tool

**Maya asks:** "Per tool, how many FINAL readings were more than 0.3 nm from the target, out of how many FINAL readings it took?"

```sql
SELECT m.tool_id,
       COUNT(*) AS final_readings,
       SUM(CASE WHEN ABS(m.thickness_nm - p.target_thk_nm) > 0.3 THEN 1 ELSE 0 END) AS bad_readings
FROM   measurements m
JOIN   wafers w   ON w.wafer_id = m.wafer_id
JOIN   lots l     ON l.lot_id = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.step = 'FINAL'
GROUP  BY m.tool_id
ORDER  BY m.tool_id;
```

<!--gen-->
```text
TOOL_ID FINAL_READINGS BAD_READINGS
------- -------------- ------------
MET01               21            9
MET02               20            9
MET03               21           10
```

**Why it works / what to notice.** The `CASE` turns each reading into 1 (bad) or 0 (fine), and `SUM` adds them up inside each tool's bowl. `COUNT(*)` in the same bowl gives the total, so you can compare. The numbers are similar across the three metrology tools, so the bad readings are more likely to come from the lots than from one tool. A single query cannot prove that, but it tells you where not to look first.
