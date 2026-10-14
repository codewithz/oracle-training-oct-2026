# Lab 11 solutions: Trees and text

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The outputs below were produced by running each query on the lab data. The script with all of them is [`lab11_solutions.sql`](scripts/lab11_solutions.sql).

## Exercise 1: The family tree of lots

**Maya asks:** "Show me every lot as a family tree. Indent the children, show the generation number, the type and the status. Children go under their parent, sorted by lot id."

```sql
SELECT LEVEL AS lvl,
       LPAD(' ', 2 * (LEVEL - 1)) || lot_id AS lot_tree,
       lot_type, status
FROM   lots
START  WITH parent_lot_id IS NULL
CONNECT BY PRIOR lot_id = parent_lot_id
ORDER  SIBLINGS BY lot_id;
```

```text
       LVL LOT_TREE                 LOT_TYPE STATUS
---------- ------------------------ -------- --------
         1 L26-001                  PROD     SHIPPED
         1 L26-002                  PROD     SHIPPED
         1 L26-003                  PROD     ACTIVE
         2   L26-003A               SPLIT    SHIPPED
         2   L26-003B               SPLIT    HOLD
         3     L26-003B1            REWORK   ACTIVE
         1 L26-004                  PROD     SHIPPED
         1 L26-005                  PROD     HOLD
         1 L26-006                  PROD     SHIPPED
         1 L26-007                  PROD     ACTIVE
         2   L26-007A               SPLIT    ACTIVE
         1 L26-008                  PROD     SCRAPPED
         1 L26-009                  PROD     ACTIVE
         1 L26-010                  PROD     ACTIVE
         1 L26-011                  PROD     ACTIVE
         1 L26-012                  PROD     ACTIVE
```

**What to notice.** `START WITH` picks the 12 lots that have no parent, and `CONNECT BY PRIOR` adds their children and grandchildren. 12 roots plus 4 descendants is 16 rows.

**The trap.** Without `START WITH`, every row is a root:

```sql
SELECT COUNT(*) AS rows_without_start_with
FROM   lots
CONNECT BY PRIOR lot_id = parent_lot_id;
```

```text
ROWS_WITHOUT_START_WITH
-----------------------
                     21
```

21 rows for 16 lots: each lot with a parent is listed once as its own root and again under every ancestor.

## Exercise 2: Path, root and leaf

**Maya asks:** "For every lot that has a parent, show the path from the original lot down to it, written like `L26-003/L26-003B`. Add the original lot and say whether this lot has children of its own."

```sql
SELECT lot_id,
       LTRIM(SYS_CONNECT_BY_PATH(lot_id, '/'), '/') AS path,
       CONNECT_BY_ROOT lot_id                       AS root_lot,
       CONNECT_BY_ISLEAF                            AS is_leaf
FROM   lots
WHERE  LEVEL > 1
START  WITH parent_lot_id IS NULL
CONNECT BY PRIOR lot_id = parent_lot_id
ORDER  SIBLINGS BY lot_id;
```

```text
LOT_ID       PATH                                         ROOT_LOT        IS_LEAF
------------ -------------------------------------------- ------------ ----------
L26-003A     L26-003/L26-003A                             L26-003               1
L26-003B     L26-003/L26-003B                             L26-003               0
L26-003B1    L26-003/L26-003B/L26-003B1                   L26-003               1
L26-007A     L26-007/L26-007A                             L26-007               1
```

**What to notice.** `WHERE LEVEL > 1` is applied after the walk, so the path and the root are still worked out from the true start. Only `L26-003B` has a child, so it is the only row with `is_leaf` = 0.

## Exercise 3: Where did this lot come from?

**Maya asks:** "A customer complained about a wafer from `L26-003B1`. Which lots is it descended from?"

```sql
SELECT LEVEL AS steps_up, lot_id, lot_type, status
FROM   lots
START  WITH lot_id = 'L26-003B1'
CONNECT BY lot_id = PRIOR parent_lot_id;
```

```text
  STEPS_UP LOT_ID       LOT_TYPE STATUS
---------- ------------ -------- --------
         1 L26-003B1    REWORK   ACTIVE
         2 L26-003B     SPLIT    HOLD
         3 L26-003      PROD     ACTIVE
```

**What to notice.** `PRIOR parent_lot_id` means "the parent of the row I am on". The row with that id is the next one. Quality can now walk down from `L26-003` to see every lot that shares the origin.

**The trap.** With `PRIOR` on the other side the walk goes down:

```sql
SELECT LEVEL AS steps, lot_id
FROM   lots
START  WITH lot_id = 'L26-003B1'
CONNECT BY PRIOR lot_id = parent_lot_id;
```

```text
     STEPS LOT_ID
---------- ------------
         1 L26-003B1
```

One row, because nothing has `L26-003B1` as its parent.

## Exercise 4: One filter, two places

**Maya asks:** "The L26-003 family without the lots on hold." Then: "Follow the family, but stop at a lot on hold."

```sql
-- 4a: WHERE
SELECT LEVEL AS lvl, LPAD(' ', 2 * (LEVEL - 1)) || lot_id AS lot_tree, status
FROM   lots
WHERE  status <> 'HOLD'
START  WITH lot_id = 'L26-003'
CONNECT BY PRIOR lot_id = parent_lot_id
ORDER  SIBLINGS BY lot_id;
```

```text
       LVL LOT_TREE                 STATUS
---------- ------------------------ --------
         1 L26-003                  ACTIVE
         2   L26-003A               SHIPPED
         3     L26-003B1            ACTIVE
```

```sql
-- 4b: CONNECT BY
SELECT LEVEL AS lvl, LPAD(' ', 2 * (LEVEL - 1)) || lot_id AS lot_tree, status
FROM   lots
START  WITH lot_id = 'L26-003'
CONNECT BY PRIOR lot_id = parent_lot_id AND status <> 'HOLD'
ORDER  SIBLINGS BY lot_id;
```

```text
       LVL LOT_TREE                 STATUS
---------- ------------------------ --------
         1 L26-003                  ACTIVE
         2   L26-003A               SHIPPED
```

**What to notice.** `L26-003B1` is in 4a and not in 4b. In 4a, `WHERE` removed only the held lot `L26-003B`, and its child stayed behind, now at level 3 under nothing. In 4b the walk refused to step onto `L26-003B`, so its child was never reached. Ask Maya which one she means before you send either.

## Exercise 5: What do the operators write about?

**Maya asks:** "Which tool is named most often in the notes?" and "How many notes name a tool but no other number?"

```sql
-- 5a
SELECT REGEXP_SUBSTR(note, '[A-Z]{3}[0-9]{2}') AS tool,
       COUNT(*) AS notes
FROM   lot_history
WHERE  REGEXP_LIKE(note, '[A-Z]{3}[0-9]{2}')
GROUP  BY REGEXP_SUBSTR(note, '[A-Z]{3}[0-9]{2}')
ORDER  BY notes DESC, tool;
```

```text
TOOL        NOTES
------ ----------
MET01          12
SPL02          12
ANL01          10
MET03           9
IMP01           7
SPL01           7
MET02           6
CMP01           4
ANL02           2
```

```sql
-- 5b
SELECT COUNT(*) AS tool_no_number
FROM   lot_history
WHERE  REGEXP_LIKE(note, '[A-Z]{3}[0-9]{2}')
AND    NOT REGEXP_LIKE(REGEXP_REPLACE(note, '[A-Z]{3}[0-9]{2}|L26-[0-9A-Z]+'), '[0-9]');
```

```text
TOOL_NO_NUMBER
--------------
            18
```

To look at some of those notes (the first ones):

```sql
SELECT hist_id, note
FROM   lot_history
WHERE  REGEXP_LIKE(note, '[A-Z]{3}[0-9]{2}')
AND    NOT REGEXP_LIKE(REGEXP_REPLACE(note, '[A-Z]{3}[0-9]{2}|L26-[0-9A-Z]+'), '[0-9]')
AND    hist_id <= 32
ORDER  BY hist_id;
```

```text
   HIST_ID NOTE
---------- ------------------------------------------------------------
         4 wafer bow suspected - L26-001 on hold pending ANL01 check
        11 ok to continue   MET01
        15 ok to continue   SPL02
        27 ok to continue   MET01
        32 wafer bow suspected - L26-003 on hold pending MET01 check
```

**What to notice.** The nine counts add up to 69 notes. In 5b, the inner `REGEXP_REPLACE` deletes the tool ids and lot ids, which contain digits of their own, and then `REGEXP_LIKE` asks whether any digit is left. Without that step, every note with a tool id would count as having a number.

## Exercise 6: Numbers and tickets hiding in the notes

**Maya asks:** "Pull the readings out as numbers: how many, lowest, highest, average?"

```sql
-- 6a
SELECT COUNT(*) AS readings,
       MIN(TO_NUMBER(REGEXP_SUBSTR(note, '([0-9]+(\.[0-9]+)?) ?nm', 1, 1, NULL, 1), '9999.99')) AS lowest,
       MAX(TO_NUMBER(REGEXP_SUBSTR(note, '([0-9]+(\.[0-9]+)?) ?nm', 1, 1, NULL, 1), '9999.99')) AS highest,
       ROUND(AVG(TO_NUMBER(REGEXP_SUBSTR(note, '([0-9]+(\.[0-9]+)?) ?nm', 1, 1, NULL, 1), '9999.99')), 1) AS average
FROM   lot_history
WHERE  REGEXP_LIKE(note, '[0-9] ?nm');
```

```text
  READINGS     LOWEST    HIGHEST    AVERAGE
---------- ---------- ---------- ----------
        26       11.2       1104      100.2
```

```sql
-- 6b
SELECT *
FROM  (SELECT hist_id, lot_id,
              TO_NUMBER(REGEXP_SUBSTR(note, '([0-9]+(\.[0-9]+)?) ?nm', 1, 1, NULL, 1), '9999.99') AS nm,
              new_status
       FROM   lot_history
       WHERE  REGEXP_LIKE(note, '[0-9] ?nm')
       ORDER  BY nm DESC)
WHERE  ROWNUM <= 3;
```

```text
   HIST_ID LOT_ID               NM NEW_STAT
---------- ------------ ---------- --------
       111 L26-008            1104 SCRAPPED
        63 L26-003B1          96.4 HOLD
       132 L26-010            92.8 HOLD
```

```sql
-- 6c
SELECT REGEXP_SUBSTR(note, '(INC|FAB-OPS)-[0-9]+', 1, 1, NULL, 1) AS kind,
       COUNT(*) AS tickets
FROM   lot_history
WHERE  REGEXP_LIKE(note, '(INC|FAB-OPS)-[0-9]+')
GROUP  BY REGEXP_SUBSTR(note, '(INC|FAB-OPS)-[0-9]+', 1, 1, NULL, 1)
ORDER  BY kind;
```

```text
KIND       TICKETS
-------- ----------
FAB-OPS           8
INC              23
```

**What to notice.** The subexpression argument (the last 1) returns only the bracketed number, so `TO_NUMBER` has clean digits to work on. The 1104 is the reading written in a scrap note, far above the others. A reader should be told that the average mixes ordinary and scrap readings, and is not a measure of anything. In 6b the sort has to happen in the inline view, before `ROWNUM` is applied, otherwise you would get three arbitrary rows.

**The trap.** A loose pattern:

```sql
SELECT hist_id, note, REGEXP_SUBSTR(note, '[0-9]+') AS first_digits
FROM   lot_history
WHERE  hist_id = 6;
```

```text
   HIST_ID NOTE                                                         FIRST_DI
---------- ------------------------------------------------------------ --------
         6 hold per FAB-OPS-113, thickness 58.1 nm                      113
```

The first run of digits is the ticket number. Describe the whole shape, digits followed by `nm`.

## Exercise 7: A cleaned copy for the weekly report

**Maya asks:** "Make a copy of the notes for the weekly report: single spaces only, and hide the email address."

```sql
-- 7a
SELECT COUNT(*) AS messy_before FROM lot_history WHERE REGEXP_LIKE(note, '\s{2,}');
```

```text
MESSY_BEFORE
------------
          16
```

```sql
-- 7b
CREATE TABLE my_notes_clean AS
SELECT hist_id, lot_id,
       REGEXP_REPLACE(
         REGEXP_REPLACE(note, '\s{2,}', ' '),
         '[[:alnum:]._]+@[[:alnum:].]+', '***') AS note
FROM   lot_history;

SELECT COUNT(*) AS rows_copied,
       SUM(CASE WHEN REGEXP_LIKE(note, '\s{2,}') THEN 1 ELSE 0 END) AS messy_after,
       SUM(CASE WHEN REGEXP_LIKE(note, '@') THEN 1 ELSE 0 END)      AS emails_left
FROM   my_notes_clean;

SELECT hist_id, note FROM my_notes_clean WHERE hist_id IN (8, 11, 28);
```

```text
ROWS_COPIED MESSY_AFTER EMAILS_LEFT
----------- ----------- -----------
        147           0           0

   HIST_ID NOTE
---------- ------------------------------------------------------------
         8 Audit hold. contact *** (ext 4198)
        11 ok to continue MET01
        28 eng req hold re-meas on CMP01, see INC-20978
```

```sql
-- 7c
DROP TABLE my_notes_clean PURGE;
SELECT COUNT(*) AS my_tables_left FROM user_tables WHERE table_name LIKE 'MY\_%' ESCAPE '\';
```

```text
MY_TABLES_LEFT
--------------
             0
```

**What to notice.** The 147 rows include the ones whose note is `NULL`. `REGEXP_REPLACE` on NULL gives NULL, so those rows are copied as they are. The original `LOT_HISTORY` was never touched. The extension (`ext 4198`) stayed, because Maya only asked for the address. If your own table list was not empty at the end, those are tables from other labs, not this one.

## Stretch: the genealogy as a recursive WITH

```sql
WITH family (lot_id, parent_lot_id, lvl) AS (
  SELECT lot_id, parent_lot_id, 1 FROM lots WHERE parent_lot_id IS NULL
  UNION ALL
  SELECT c.lot_id, c.parent_lot_id, f.lvl + 1
  FROM   family f JOIN lots c ON c.parent_lot_id = f.lot_id
)
SEARCH DEPTH FIRST BY lot_id SET walk_order
SELECT walk_order, LPAD(' ', 2 * (lvl - 1)) || lot_id AS lot_tree
FROM   family
ORDER  BY walk_order;
```

```text
WALK_ORDER LOT_TREE
---------- ------------------------
         1 L26-001
         2 L26-002
         3 L26-003
         4   L26-003A
         5   L26-003B
         6     L26-003B1
         7 L26-004
         8 L26-005
         9 L26-006
        10 L26-007
        11   L26-007A
        12 L26-008
        13 L26-009
        14 L26-010
        15 L26-011
        16 L26-012
```

**What to notice.** The anchor is `START WITH`, the join is `CONNECT BY PRIOR`, and you keep the level yourself in `lvl`. `SEARCH DEPTH FIRST BY lot_id` numbers the rows in tree order. A `CYCLE lot_id SET is_cycle TO 'Y' DEFAULT 'N'` clause, placed just after the `)` and before `SELECT`, would mark any row whose lot_id has already appeared on its own path, and stop the walk below it.
