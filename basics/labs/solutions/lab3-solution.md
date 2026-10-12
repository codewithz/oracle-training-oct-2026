# Lab 3 solutions: NULL and single-row functions

These are the answers to the lab, with the output the test database gave. Your row counts must match. Your query may differ in spacing or in the order of the columns and still be right: what matters is the same rows.

## Exercise 1: Lots on hold with no reason

**Maya asks:** "Which lots are on hold and nobody wrote down why?" Show the lot, the status and the reason.

Try two versions. Part **a**: use `hold_reason = ''` (an empty string) and look at the result. Part **b**: write it the correct way.

**Part a**

```sql
SELECT lot_id, status, hold_reason
FROM   lots
WHERE  status = 'HOLD'
AND    hold_reason = '';
```

<!--gen-->
```text

```

**Part b**

```sql
SELECT lot_id, status, hold_reason
FROM   lots
WHERE  status = 'HOLD'
AND    hold_reason IS NULL;
```

<!--gen-->
```text
LOT_ID     STATUS   HOLD_REASON
---------- -------- --------------------------------
L26-005    HOLD
```

**Why it works / what to notice.** Part a finds nothing because Oracle stores an empty string as `NULL`, and `NULL = NULL` is never true. Part b finds `L26-005`, the lot on hold with a blank reason. `IS NULL` is the only test that works on a missing value.

## Exercise 2: Wafers with no grade

**Maya asks:** "Which wafers have no grade yet?" Show the wafer and its lot.

Then a second question: "How many wafers are not PRIME, counting the ungraded ones too?" Count them.

**Part a**

```sql
SELECT wafer_id, lot_id
FROM   wafers
WHERE  grade IS NULL;
```

<!--gen-->
```text
WAFER_ID     LOT_ID
------------ ----------
L26-012-03   L26-012
L26-012-04   L26-012
```

**Part b**

```sql
SELECT COUNT(*) AS not_prime
FROM   wafers
WHERE  grade <> 'PRIME'
OR     grade IS NULL;
```

<!--gen-->
```text
 NOT_PRIME
----------
        15
```

**Part b, without the NULL test**

```sql
SELECT COUNT(*) AS not_prime
FROM   wafers
WHERE  grade <> 'PRIME';
```

<!--gen-->
```text
 NOT_PRIME
----------
        13
```

**Why it works / what to notice.** Two wafers, both in lot `L26-012`, have no grade. Without the `OR grade IS NULL` part, `<>` quietly leaves them out and you get 13. With it you get 15. A comparison with `NULL` is UNKNOWN, and `WHERE` only keeps rows that are clearly true.

## Exercise 3: Label the ungraded

**Maya asks:** "For the wafers of lots L26-011 and L26-012, show each wafer and its grade, but where nobody has graded it, write UNGRADED." Sort by wafer id.

```sql
SELECT wafer_id, NVL(grade, 'UNGRADED') AS label
FROM   wafers
WHERE  lot_id IN ('L26-011', 'L26-012')
ORDER  BY wafer_id;
```

<!--gen-->
```text
WAFER_ID     LABEL
------------ --------
L26-011-01   PRIME
L26-011-02   PRIME
L26-011-03   PRIME
L26-011-04   PRIME
L26-011-05   TEST
L26-012-01   PRIME
L26-012-02   PRIME
L26-012-03   UNGRADED
L26-012-04   UNGRADED
```

**Why it works / what to notice.** Nine wafers, two of them labelled `UNGRADED`. `NVL` changes only what lands on your plate. In the table the grade is still `NULL`. Wafers that already had a grade pass through unchanged.

## Exercise 4: The board with reasons

**Maya asks:** "Give me the lots on hold with the reason. If nobody wrote a reason, write NO REASON RECORDED." Use `COALESCE` this time.

```sql
SELECT lot_id, COALESCE(hold_reason, 'NO REASON RECORDED') AS reason
FROM   lots
WHERE  status = 'HOLD'
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     REASON
---------- ------------------------------------------------------------
L26-003B   Thickness out of spec at FINAL
L26-005    NO REASON RECORDED
```

**Why it works / what to notice.** One lot has its real reason and the other shows the replacement text. `COALESCE` does the same job as `NVL` here. It earns its place when you have more than two candidates, for example `COALESCE(a, b, c, 'none')`.

## Exercise 5: Words for lot types, and for priority

**Maya asks:** Two small boards.

- **a)** "Show each lot with a plain description of its type: PROD is 'normal production', SPLIT is 'split from a parent', REWORK is 'reworked from a parent'." Use a simple `CASE`.
- **b)** "For lots that are not shipped, show the priority as words: 1 is URGENT, 2 is SOON, anything else is WHEN READY." Use a searched `CASE`.

**Part a**

```sql
SELECT lot_id, lot_type,
       CASE lot_type
         WHEN 'PROD'   THEN 'normal production'
         WHEN 'SPLIT'  THEN 'split from a parent'
         ELSE 'reworked from a parent'
       END AS meaning
FROM   lots
WHERE  lot_id LIKE 'L26-00%'
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     LOT_TYPE MEANING
---------- -------- ----------------------
L26-001    PROD     normal production
L26-002    PROD     normal production
L26-003    PROD     normal production
L26-003A   SPLIT    split from a parent
L26-003B   SPLIT    split from a parent
L26-003B1  REWORK   reworked from a parent
L26-004    PROD     normal production
L26-005    PROD     normal production
L26-006    PROD     normal production
L26-007    PROD     normal production
L26-007A   SPLIT    split from a parent
L26-008    PROD     normal production
L26-009    PROD     normal production
```

**Part b**

```sql
SELECT lot_id, priority,
       CASE
         WHEN priority = 1 THEN 'URGENT'
         WHEN priority = 2 THEN 'SOON'
         ELSE 'WHEN READY'
       END AS when_label
FROM   lots
WHERE  status <> 'SHIPPED'
ORDER  BY priority, lot_id;
```

<!--gen-->
```text
LOT_ID       PRIORITY WHEN_LABEL
---------- ---------- ----------
L26-003             1 URGENT
L26-003B            1 URGENT
L26-003B1           1 URGENT
L26-010             1 URGENT
L26-005             2 SOON
L26-007             2 SOON
L26-007A            2 SOON
L26-009             2 SOON
L26-012             2 SOON
L26-008             3 WHEN READY
L26-011             3 WHEN READY
```

**Why it works / what to notice.** The first `CASE` whose condition is true wins, and the rest are skipped. In part a the `ELSE` catches REWORK, the only type left. In part b, order matters only if the tests overlap. Here they do not.

## Exercise 6: Too thin, on target, too thick

**Maya asks:** "For the FD-300 wafers, tell me whether each FINAL reading is TOO THIN, ON TARGET or TOO THICK. The target is 12 nm. Anything within 0.1 nm of it is on target." FD-300 wafers are in lots `L26-001`, `L26-003` (and its children), `L26-007` (and its child) and `L26-011`. Show the wafer, the thickness and the verdict.

```sql
SELECT wafer_id, thickness_nm,
       CASE
         WHEN thickness_nm < 12 - 0.1 THEN 'TOO THIN'
         WHEN thickness_nm > 12 + 0.1 THEN 'TOO THICK'
         ELSE 'ON TARGET'
       END AS verdict
FROM   measurements
WHERE  step = 'FINAL'
AND    (wafer_id LIKE 'L26-001%' OR wafer_id LIKE 'L26-003%'
        OR wafer_id LIKE 'L26-007%' OR wafer_id LIKE 'L26-011%')
ORDER  BY wafer_id;
```

<!--gen-->
```text
WAFER_ID     THICKNESS_NM VERDICT
------------ ------------ ---------
L26-001-01          11.89 TOO THIN
L26-001-02          11.99 ON TARGET
L26-001-03          12.06 ON TARGET
L26-001-04          12.03 ON TARGET
L26-001-05          11.86 TOO THIN
L26-003-01          12.07 ON TARGET
L26-003-02          12.07 ON TARGET
L26-003-03          11.88 TOO THIN
L26-003-04          11.95 ON TARGET
L26-003-05          11.95 ON TARGET
L26-003A-01          12.1 ON TARGET
L26-003A-02         11.81 TOO THIN
L26-003A-03         11.98 ON TARGET
L26-003B-01          12.5 TOO THICK
L26-003B-02         12.64 TOO THICK
L26-003B1-01         12.1 ON TARGET
L26-003B1-02        12.02 ON TARGET
L26-007-01          12.05 ON TARGET
L26-007-02          12.08 ON TARGET
L26-007-03          11.87 TOO THIN
L26-007-04          11.98 ON TARGET
L26-007-05          11.93 ON TARGET
L26-007A-01         12.02 ON TARGET
L26-007A-02         11.99 ON TARGET
L26-011-01          12.03 ON TARGET
L26-011-02          11.97 ON TARGET
L26-011-03          12.01 ON TARGET
L26-011-04          12.02 ON TARGET
L26-011-05          12.09 ON TARGET
```

**Why it works / what to notice.** Twenty-nine readings, with the verdicts side by side. A reading of exactly 12.1 (there are a few) counts as on target, because neither `<` nor `>` is true for it. Notice the two thick readings in `L26-003B`, the lot that went on hold for being out of spec at FINAL. Later, a join will let the database look up the 12 from `PRODUCTS` instead of you typing it.

## Exercise 7: Dates in a readable shape

**Maya asks:** "For the lots of the L26-007 family, show the start as day/month/year with the time, and a review date one month after the start, written as year-month-day." Show lot, start and review date.

```sql
SELECT lot_id,
       TO_CHAR(start_date, 'DD/MM/YYYY HH24:MI')      AS started,
       TO_CHAR(ADD_MONTHS(start_date, 1), 'YYYY-MM-DD') AS review
FROM   lots
WHERE  lot_id LIKE 'L26-007%'
ORDER  BY lot_id;
```

<!--gen-->
```text
LOT_ID     STARTED          REVIEW
---------- ---------------- ----------
L26-007    02/09/2026 08:00 2026-10-02
L26-007A   06/09/2026 09:30 2026-10-06
```

**Why it works / what to notice.** Two lots, three columns. The mask letters are a small language: `DD` day, `MM` month, `YYYY` year, `HH24` hour from 00 to 23, `MI` minutes. `ADD_MONTHS` keeps the time of day, but `TO_CHAR` with a date-only mask hides it. The result of `TO_CHAR` is text, so it sorts as text. If you need date order, sort by the original `start_date`.

## Exercise 8: Building a label

**Maya asks:** Two small jobs.

- **a)** "I want a one-line label for every lot that is not a normal production lot, like `L26-003B (SPLIT, HOLD)`." Join the lot id, the type and the status with `||`.
- **b)** "I typed l26-007a in lower case. Find that lot." Make the match ignore case.

**Part a**

```sql
SELECT lot_id || ' (' || lot_type || ', ' || status || ')' AS label
FROM   lots
WHERE  lot_type <> 'PROD'
ORDER  BY lot_id;
```

<!--gen-->
```text
LABEL
---------------------------------
L26-003A (SPLIT, SHIPPED)
L26-003B (SPLIT, HOLD)
L26-003B1 (REWORK, ACTIVE)
L26-007A (SPLIT, ACTIVE)
```

**Part b**

```sql
SELECT lot_id, status
FROM   lots
WHERE  UPPER(lot_id) = UPPER('l26-007a');
```

<!--gen-->
```text
LOT_ID     STATUS
---------- --------
L26-007A   ACTIVE
```

**Why it works / what to notice.** Part a gives four labels. `||` is Oracle's text glue, and `lot_type` and `status` are columns while ` (` is a piece of fixed text. Part b finds `L26-007A` although you typed it in lower case, because both sides were turned into capitals before the comparison. The stored value is unchanged.

## Stretch: how far from the target?

**Maya asks:** "For the FINAL readings of the L26-003B lot, how far is each from the 12 nm target? Just the size of the miss, rounded to one decimal, biggest miss first." Show the wafer, the thickness and the miss in nm.

```sql
SELECT wafer_id, thickness_nm,
       ABS(ROUND(thickness_nm - 12, 1)) AS miss_nm
FROM   measurements
WHERE  step = 'FINAL'
AND    wafer_id LIKE 'L26-003B-%'
ORDER  BY miss_nm DESC;
```

<!--gen-->
```text
WAFER_ID     THICKNESS_NM    MISS_NM
------------ ------------ ----------
L26-003B-02         12.64         .6
L26-003B-01          12.5         .5
```

**Why it works / what to notice.** `ORDER BY` can use the alias because sorting happens after the plate is built. The pattern `L26-003B-%` has the dash in it, so the child lot `L26-003B1` (whose wafers start `L26-003B1-`) does not match.
