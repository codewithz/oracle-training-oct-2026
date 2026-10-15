# Lab 11 solutions: Trees and text

Try each exercise yourself first. Your query may differ from these and still be right: compare the output, not the spelling. The script with all of them is [`lab11_solutions.sql`](scripts/lab11_solutions.sql).

Each exercise has the same four parts: the problem in plain words, the query, how the query builds the answer step by step, and the output with what to notice.

All outputs and the in-between rows in the breakdowns were produced by running the queries, and parts of them, on the lab data (Oracle 21c XE; 19c gives the same rows).

Two things to keep in mind for the tree exercises (1 to 4):

- The tree lives in one table. Each row of `LOTS` has a `parent_lot_id` that points to another row of `LOTS`. Twelve lots have no parent; four were split or reworked from another lot:

  ```text
  LOT_ID       PARENT_LOT_ID LOT_TYPE STATUS
  ------------ ------------- -------- --------
  L26-003A     L26-003       SPLIT    SHIPPED
  L26-003B     L26-003       SPLIT    HOLD
  L26-003B1    L26-003B      REWORK   ACTIVE
  L26-007A     L26-007       SPLIT    ACTIVE
  ```

- A hierarchical query runs in its own order: `START WITH` picks the first rows, `CONNECT BY` walks from each row to the next generation, and only then are `WHERE` and the `SELECT` list applied to the rows the walk found.

## Exercise 1: The family tree of lots

**Maya asks:** "Show me every lot as a family tree. Indent the children, show the generation number, the type and the status. Children go under their parent, sorted by lot id."

### The problem in plain words

All 16 lots, one row each, laid out like a family tree: each original lot on the left, its children indented under it, their children indented further. Each row shows the generation (1 for an original lot, 2 for a child, 3 for a grandchild), the indented lot ID, the lot type and the status. Lots on the same level under the same parent are sorted by lot ID.

### The query

```sql
SELECT LEVEL AS lvl,
       LPAD(' ', 2 * (LEVEL - 1)) || lot_id AS lot_tree,
       lot_type, status
FROM   lots
START  WITH parent_lot_id IS NULL
CONNECT BY PRIOR lot_id = parent_lot_id
ORDER  SIBLINGS BY lot_id;
```

### How the query builds the answer

**Step 1. START WITH parent_lot_id IS NULL.** The walk starts from every lot that has no parent: 12 lots. These are level 1.

**Step 2. CONNECT BY PRIOR lot_id = parent_lot_id.** `PRIOR` means "the row I came from". So from each row, Oracle looks for rows whose `parent_lot_id` equals the `lot_id` of the row it is on: its children. From L26-003 it finds L26-003A and L26-003B (level 2). From L26-003B it finds L26-003B1 (level 3). From L26-003B1 it finds nothing, so that branch ends.

**Step 3. ORDER SIBLINGS BY lot_id.** A plain `ORDER BY` would sort all 16 rows and break the tree apart. `ORDER SIBLINGS BY` sorts only lots that share a parent, so each child stays right under its parent.

**Step 4. SELECT.** `LEVEL` is the generation number the walk assigned. `LPAD(' ', 2 * (LEVEL - 1))` makes a string of spaces, 0 for level 1, 2 for level 2, 4 for level 3, and it is glued in front of the lot ID to make the indent.

### Output

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

### What to notice

12 roots plus 4 descendants is 16 rows, one per lot, which is the check that the tree is right.

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

21 rows for 16 lots. Each lot is listed once as its own root, and again under every ancestor. L26-003B1, for example, appears three times: as a root on its own, under L26-003B, and under L26-003.

## Exercise 2: Path, root and leaf

**Maya asks:** "For every lot that has a parent, show the path from the original lot down to it, written like `L26-003/L26-003B`. Add the original lot and say whether this lot has children of its own."

### The problem in plain words

Only the 4 lots that have a parent appear in the answer. For each one Maya wants: the chain of lot IDs from the original lot down to this one, joined with "/"; the original lot at the top of that chain; and a flag saying whether this lot is a dead end (no children) or has children of its own.

### The query

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

### How the query builds the answer

**Step 1. START WITH and CONNECT BY.** The same walk as exercise 1: all 16 lots, each with its level.

**Step 2. The three tree functions, worked out during the walk.**

- `SYS_CONNECT_BY_PATH(lot_id, '/')` adds "/" and the current lot ID to the path of the row it came from. It always starts with a "/":

  ```text
         LVL LOT_ID       SYS_CONNECT_BY_PATH
  ---------- ------------ ---------------------------
           1 L26-003      /L26-003
           2 L26-003A     /L26-003/L26-003A
           2 L26-003B     /L26-003/L26-003B
           3 L26-003B1    /L26-003/L26-003B/L26-003B1
  ```

- `CONNECT_BY_ROOT lot_id` is the lot ID of the row the walk started from.
- `CONNECT_BY_ISLEAF` is 1 if the walk found no children below this row, 0 if it did.

**Step 3. WHERE LEVEL > 1.** Now the level 1 rows (the 12 original lots) are removed. This runs after the walk, so the 4 remaining rows keep the path and root that were built from the true start.

**Step 4. SELECT.** `LTRIM(..., '/')` cuts the leading "/" off the path.

### Output

```text
LOT_ID       PATH                                         ROOT_LOT        IS_LEAF
------------ -------------------------------------------- ------------ ----------
L26-003A     L26-003/L26-003A                             L26-003               1
L26-003B     L26-003/L26-003B                             L26-003               0
L26-003B1    L26-003/L26-003B/L26-003B1                   L26-003               1
L26-007A     L26-007/L26-007A                             L26-007               1
```

### What to notice

Only L26-003B has a child, so it is the only row with `is_leaf` = 0. If you had written `START WITH parent_lot_id IS NOT NULL` instead of filtering with `WHERE`, the walk would have started at the children, and every path and root would be wrong.

## Exercise 3: Where did this lot come from?

**Maya asks:** "A customer complained about a wafer from `L26-003B1`. Which lots is it descended from?"

### The problem in plain words

This time we walk up the tree, not down. Start at L26-003B1, go to its parent, then to that lot's parent, until we reach a lot with no parent. One row per lot on that chain, with how many steps up it is, its type and its status.

### The query

```sql
SELECT LEVEL AS steps_up, lot_id, lot_type, status
FROM   lots
START  WITH lot_id = 'L26-003B1'
CONNECT BY lot_id = PRIOR parent_lot_id;
```

### How the query builds the answer

**Step 1. START WITH lot_id = 'L26-003B1'.** The walk starts at one row. Its `parent_lot_id` is L26-003B.

**Step 2. CONNECT BY lot_id = PRIOR parent_lot_id.** Read it as "the next row is the one whose `lot_id` equals the parent of the row I am on". From L26-003B1 that is L26-003B (level 2). L26-003B's parent is L26-003 (level 3). L26-003 has no parent, so the walk stops.

**Step 3. SELECT.** `LEVEL` now counts steps up from the starting lot.

### Output

```text
  STEPS_UP LOT_ID       LOT_TYPE STATUS
---------- ------------ -------- --------
         1 L26-003B1    REWORK   ACTIVE
         2 L26-003B     SPLIT    HOLD
         3 L26-003      PROD     ACTIVE
```

### What to notice

The side `PRIOR` sits on sets the direction. `PRIOR lot_id = parent_lot_id` walks down (from parent to children); `lot_id = PRIOR parent_lot_id` walks up (from child to parent). Quality can now walk down from L26-003 to see every lot that shares the origin.

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

One row, because nothing has L26-003B1 as its parent.

## Exercise 4: One filter, two places

**Maya asks:** "The L26-003 family without the lots on hold." Then: "Follow the family, but stop at a lot on hold."

### The problem in plain words

The L26-003 family is four lots: L26-003 (ACTIVE), its children L26-003A (SHIPPED) and L26-003B (HOLD), and L26-003B1 (ACTIVE), the child of L26-003B. Maya asks two questions that sound alike:

- The first: show the family, but leave out any lot on hold. Only L26-003B is on hold, so the answer is the other three lots.
- The second: walk down the family, and do not go past a lot on hold. The walk stops at L26-003B, so nothing below it is reached either.

The same condition, `status <> 'HOLD'`, answers each one depending on where you put it.

### The queries

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

### How the queries build the answer

**4a, step 1. The walk.** `START WITH` and `CONNECT BY` find all four lots of the family, exactly as in exercise 1.

**4a, step 2. WHERE status <> 'HOLD'.** `WHERE` runs after the walk is finished. It removes the L26-003B row from the result. Its child L26-003B1 was already found, and it is not on hold, so it stays at level 3 with no parent shown above it.

**4b, step 1. The walk with a condition.** Here `status <> 'HOLD'` is part of `CONNECT BY`, so it is checked at every step of the walk. From L26-003 the walk may step to L26-003A (SHIPPED) but not to L26-003B (HOLD).

**4b, step 2. Nothing below the stop.** The walk never stood on L26-003B, so it never looked for its children, and L26-003B1 is never reached.

### Output of 4b

```text
       LVL LOT_TREE                 STATUS
---------- ------------------------ --------
         1 L26-003                  ACTIVE
         2   L26-003A               SHIPPED
```

### What to notice

L26-003B1 is in 4a and not in 4b. A filter in `WHERE` removes single rows after the walk. A filter in `CONNECT BY` prunes the whole branch below the row. Ask Maya which one she means before you send either. (The condition in `START WITH` is not checked against `CONNECT BY`, so if L26-003 itself had been on hold, 4b would still start there.)

## Exercise 5: What do the operators write about?

**Maya asks:** "Which tool is named most often in the notes?" and "How many notes name a tool but no other number?"

### The problem in plain words

The `note` column of `LOT_HISTORY` is free text typed by operators. Tool IDs look like three capital letters and two digits (MET01, SPL02). There is no tool column to group by, so we have to find the tool ID inside the text.

5a: one row per tool ID, with how many notes mention it, most mentioned first.

5b: one number. Count notes that name a tool but contain no other number, such as a reading or a ticket. The difficulty is that tool IDs and lot IDs contain digits themselves, so "contains a digit" is not a good enough test on the raw note.

### The queries

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

### How the queries build the answer

**5a, step 1. FROM and WHERE.** All 147 history rows, 126 of which have a note. `REGEXP_LIKE(note, '[A-Z]{3}[0-9]{2}')` keeps only notes that contain the tool pattern: 69 notes. `[A-Z]{3}` means exactly three capital letters, `[0-9]{2}` exactly two digits.

**5a, step 2. GROUP BY REGEXP_SUBSTR(...).** `REGEXP_SUBSTR` returns the part of the note that matched the pattern, which is the tool ID. Grouping by that expression gives one group per tool:

```text
TOOL      HIST_ID NOTE
------ ---------- ------------------------------------------------------------
MET03           2 Held by shift lead. particle count 61 on MET03
ANL01           4 wafer bow suspected - L26-001 on hold pending ANL01 check
SPL02           5 re-meas on SPL02 ok, 59.2nm within spec
IMP01           9 RELEASED. recheck IMP01 pass (INC-20666)
```

**5a, step 3. SELECT, COUNT and ORDER BY.** Count per tool, most notes first, tool name to settle ties.

**5b, step 1. Remove the IDs.** `REGEXP_REPLACE(note, '[A-Z]{3}[0-9]{2}|L26-[0-9A-Z]+')` deletes every tool ID and every lot ID (the `|` means "or"). With no replacement text given, the matches are replaced by nothing:

```text
HIST_ID NOTE                                                       AFTER REPLACE                                DIGIT LEFT
------- ---------------------------------------------------------- -------------------------------------------- ----------
      2 Held by shift lead. particle count 61 on MET03             Held by shift lead. particle count 61 on     yes
      4 wafer bow suspected - L26-001 on hold pending ANL01 check  wafer bow suspected -  on hold pending  check no
      5 re-meas on SPL02 ok, 59.2nm within spec                    re-meas on  ok, 59.2nm within spec           yes
      9 RELEASED. recheck IMP01 pass (INC-20666)                   RELEASED. recheck  pass (INC-20666)          yes
     11 ok to continue   MET01                                     ok to continue                               no
```

**5b, step 2. Test what is left.** `NOT REGEXP_LIKE(..., '[0-9]')` keeps a note only if no digit at all is left. Notes 4 and 11 pass; notes 2, 5 and 9 still have a count, a reading or a ticket number.

**5b, step 3. COUNT.** 18 notes pass both tests.

### Output of 5b

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

### What to notice

The nine counts in 5a add up to 69, the number of notes that name a tool. `REGEXP_SUBSTR` returns only the first match, so a note naming two tools would count once, for the first. In this data no note names two (`REGEXP_COUNT(note, '[A-Z]{3}[0-9]{2}') > 1` finds none), so the counts are complete. In 5b, without the `REGEXP_REPLACE` step every note with a tool ID would count as having a number, and the answer would be 0.

## Exercise 6: Numbers and tickets hiding in the notes

**Maya asks:** "Pull the readings out as numbers: how many, lowest, highest, average?"

### The problem in plain words

Some notes contain a thickness reading written by hand, like "59.2nm" or "58.1 nm". Maya wants those readings turned into real numbers she can calculate with.

6a: one row with four numbers: how many notes have a reading, and the lowest, highest and average reading.

6b: the three notes with the highest readings, showing the history ID, lot, reading and status.

6c: the notes also mention tickets, written as INC-12345 or FAB-OPS-123. One row per kind of ticket, with how many notes mention one.

### The queries

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

### How the queries build the answer

**6a, step 1. WHERE.** `REGEXP_LIKE(note, '[0-9] ?nm')` keeps notes where a digit is followed by "nm", with or without one space between. 26 notes.

**6a, step 2. Read the pattern.** `([0-9]+(\.[0-9]+)?) ?nm` says: one or more digits, then optionally a dot and more digits, then an optional space, then "nm". The outer brackets mark the number part as subexpression 1.

**6a, step 3. Take only the number.** The six arguments of `REGEXP_SUBSTR` are: the text, the pattern, start at character 1, the 1st match, no special options (`NULL`), and return subexpression 1. Without the last argument you would get "59.2nm"; with it you get "59.2":

```text
   HIST_ID NOTE                                          WHOLE MATCH  SUBEXPRESSION 1
---------- --------------------------------------------- ------------ ---------------
         5 re-meas on SPL02 ok, 59.2nm within spec       59.2nm       59.2
         6 hold per FAB-OPS-113, thickness 58.1 nm       58.1 nm      58.1
        14 hold per FAB-OPS-121, thickness 87.7 nm       87.7 nm      87.7
        24 hold - thk OOS at FINAL, SPL01 read 38.4nm... 38.4nm       38.4
```

**6a, step 4. TO_NUMBER and the aggregates.** `TO_NUMBER(..., '9999.99')` turns the text into a number, and `COUNT`, `MIN`, `MAX` and `AVG` work on the 26 numbers.

**6b, step 1. Inner query.** The same 26 notes, each with its reading as a number, sorted highest first.

**6b, step 2. Outer WHERE ROWNUM <= 3.** `ROWNUM` numbers rows as they leave the inner query, so after the sort the first three are the three highest. The note behind the top value is "scrap - fails FINAL, ANL01 read 1104 nm".

**6c, step 1. WHERE.** Notes containing either INC- or FAB-OPS- followed by digits. `(INC|FAB-OPS)` means "INC or FAB-OPS".

**6c, step 2. GROUP BY subexpression 1.** The bracketed part is the kind of ticket. For "hold per FAB-OPS-113, ..." the whole match is FAB-OPS-113 and subexpression 1 is FAB-OPS. Grouping by that gives one group per kind.

### Output of 6c

```text
KIND       TICKETS
-------- ----------
FAB-OPS           8
INC              23
```

### What to notice

The 1104 is from a scrap note, far above every other reading. The average of 100.2 mixes ordinary readings with that one, so it is not a measure of anything; tell the reader. In 6b the sort has to happen in the inline view, before `ROWNUM` is applied, otherwise you would get three arbitrary rows. (`FETCH FIRST 3 ROWS ONLY` after `ORDER BY` does the same job without the inline view.)

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

### The problem in plain words

Some notes have runs of two or more spaces where operators pressed the space bar too often, and a few contain a person's email address. Maya wants a new table, a copy of the notes with every run of spaces made into one space and every email address replaced by `***`. The original `LOT_HISTORY` must not change. We count the messy notes before, check the copy after, and remove the copy at the end.

### The queries

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

### How the queries build the answer

**7a.** `\s` means any white-space character and `{2,}` means two or more in a row. 16 notes have such a run.

**7b, step 1. The inner REGEXP_REPLACE.** `REGEXP_REPLACE(note, '\s{2,}', ' ')` replaces every run of two or more spaces with one space. These are three of the original notes, with brackets added to show where they start and end:

```text
   HIST_ID NOTE
---------- ------------------------------------------------------------
         8 [Audit hold. contact j.tan@fabops.example (ext 4198)]
        11 [ok to continue   MET01]
        28 [eng req  hold  re-meas on CMP01, see INC-20978]
```

**7b, step 2. The outer REGEXP_REPLACE.** It works on the result of step 1. `[[:alnum:]._]+@[[:alnum:].]+` means letters, digits, dots or underscores, then @, then letters, digits or dots: the shape of an email address. Each match is replaced by `***`.

**7b, step 3. CREATE TABLE ... AS SELECT.** The query result is saved as a new table, one row per history row.

**7b, step 4. The checks.** Count all rows, count rows that still have a double space, count rows that still have an @. Then look at the three sample notes again.

### Output of the checks

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

Then remove the copy:

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

### What to notice

The 147 rows include the 21 whose note is `NULL`. `REGEXP_REPLACE` on `NULL` gives `NULL`, so those rows are copied as they are. The original `LOT_HISTORY` was never touched. The extension (`ext 4198`) stayed, because Maya only asked for the address. The order of the two replaces does not matter here, but it is a good habit to clean spaces first so later patterns see tidy text. If your own table list was not empty at the end, those are tables from other labs, not this one.

## Stretch: the genealogy as a recursive WITH

### The problem in plain words

The same family tree as exercise 1, written with standard SQL instead of Oracle's `CONNECT BY`. A recursive `WITH` builds the tree in rounds: a starting query gives the first generation, then a second query is run again and again, each time finding the children of the rows from the previous round, until a round finds nothing.

### The query

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

### How the query builds the answer

**Step 1. The anchor (above `UNION ALL`).** The 12 lots with no parent, each with `lvl` = 1. This plays the part of `START WITH`.

**Step 2. The recursive part, round 1.** `family f JOIN lots c ON c.parent_lot_id = f.lot_id` looks for lots whose parent is one of the 12 rows just found. It finds L26-003A, L26-003B and L26-007A, each with `lvl` = 1 + 1 = 2. This plays the part of `CONNECT BY PRIOR`.

**Step 3. Round 2.** The join now runs only against the 3 rows from round 1. It finds L26-003B1, with `lvl` = 3.

**Step 4. Round 3.** Nobody has L26-003B1 as a parent, so the round returns no rows and the recursion stops. In total 12 + 3 + 1 = 16 rows.

**Step 5. SEARCH DEPTH FIRST BY lot_id SET walk_order.** The rows were found generation by generation. This clause numbers them in tree order instead: each lot, then all of its descendants, then the next lot, with siblings sorted by `lot_id`. The number is stored in the new column `walk_order`.

**Step 6. SELECT and ORDER BY walk_order.** Indent by `lvl` as before and sort by the tree order.

### Output

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

### What to notice

You keep the level yourself in `lvl`; there is no `LEVEL` here. A `CYCLE lot_id SET is_cycle TO 'Y' DEFAULT 'N'` clause, placed just after the `)` and before `SELECT`, would mark any row whose lot_id has already appeared on its own path, and stop the walk below it.
