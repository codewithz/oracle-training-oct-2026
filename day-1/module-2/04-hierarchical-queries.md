# Hierarchical queries

A hierarchical query walks a table that refers to itself, such as an org chart, a bill of materials or, in the lab schema, a lot genealogy where a split or rework lot points to the lot it came from. This page covers Oracle's CONNECT BY syntax: START WITH, PRIOR, LEVEL, ORDER SIBLINGS BY, SYS_CONNECT_BY_PATH, CONNECT_BY_ROOT, CONNECT_BY_ISLEAF, walking up instead of down, and how to handle data that loops.

Slides: 30 of the Day 1 deck.

## The lot genealogy in FAB_LAB

In the invented fab, a production lot can be split into smaller lots (for an experiment, or to hold back suspect wafers), and a held lot can be reworked into a new lot. Each child lot stores its parent in `lots.parent_lot_id`; production lots have no parent, so the column is NULL for them.

```text
L26-003 (PROD)
  L26-003A (SPLIT)
  L26-003B (SPLIT, on hold)
    L26-003B1 (REWORK)
L26-007 (PROD)
  L26-007A (SPLIT)
```

The other production lots have no children. The data is illustrative.

If it helps, read this as a family tree in which every child has exactly one parent. L26-003 is the grandparent, L26-003A and L26-003B are siblings, and L26-003B1 is the grandchild. The vocabulary on the rest of this page (root, parent, child, sibling, leaf) comes straight from that picture.

## The basic form

```text
SELECT ...
FROM   table
[WHERE  filter]
START  WITH  <condition for the root rows>
CONNECT BY   PRIOR <parent key> = <child's reference to the parent>
[ORDER  SIBLINGS BY ...];
```

- `START WITH` picks the root rows, the rows the walk starts from. `START WITH parent_lot_id IS NULL` starts at every production lot; `START WITH lot_id = 'L26-007'` starts at one lot. Without START WITH, every row is used as a root, which is rarely what you want.
- `CONNECT BY` says how a parent row relates to its children. `PRIOR` marks the expression that is evaluated on the parent row. `CONNECT BY PRIOR lot_id = parent_lot_id` reads: "a row is a child of the previous row if its parent_lot_id equals the previous row's lot_id".
- `LEVEL` is a pseudocolumn: 1 for the root rows, 2 for their children, and so on. `LPAD(' ', 2 * (LEVEL - 1))` is the usual trick to indent the output.
- `ORDER SIBLINGS BY` sorts the children of each parent while keeping every child under its parent.

The genealogy of the FD-300 lots, with each lot's status and start date, children sorted by start date:

```sql
SELECT LEVEL AS lvl,
       LPAD(' ', 2 * (LEVEL - 1)) || lot_id AS lot_tree,
       status, start_date
FROM   lots
WHERE  product_id = 1
START  WITH parent_lot_id IS NULL
CONNECT BY PRIOR lot_id = parent_lot_id
ORDER  SIBLINGS BY start_date;
```

```text
       LVL LOT_TREE         STATUS   START_DATE
---------- ---------------- -------- ----------
         1 L26-001          SHIPPED  2026-08-03
         1 L26-003          ACTIVE   2026-08-10
         2   L26-003A       SHIPPED  2026-08-14
         2   L26-003B       HOLD     2026-08-14
         3     L26-003B1    ACTIVE   2026-08-20
         1 L26-007          ACTIVE   2026-09-02
         2   L26-007A       ACTIVE   2026-09-06
         1 L26-011          ACTIVE   2026-09-22
```

(The session's NLS_DATE_FORMAT was `YYYY-MM-DD` for this run.)

### Do not use a plain ORDER BY

A plain ORDER BY sorts the finished result and destroys the tree order. The same query with `ORDER BY lot_id DESC` instead of ORDER SIBLINGS BY puts children above their parents:

```text
       LVL LOT_TREE
---------- ----------------
         1 L26-011
         2   L26-007A
         1 L26-007
         3     L26-003B1
         2   L26-003B
         2   L26-003A
         1 L26-003
         1 L26-001
```

The same applies to GROUP BY: in a hierarchical query, sort siblings with ORDER SIBLINGS BY and do any grouping in an outer query.

### WHERE filters rows, CONNECT BY prunes branches

Oracle evaluates a hierarchical query in this order: joins first, then the CONNECT BY walk, then the remaining WHERE conditions. A WHERE condition removes individual rows from the finished tree. It does not remove their children:

```sql
SELECT LEVEL AS lvl, LPAD(' ', 2 * (LEVEL - 1)) || lot_id AS lot_tree, status
FROM   lots
WHERE  status <> 'HOLD'
START  WITH lot_id = 'L26-003'
CONNECT BY PRIOR lot_id = parent_lot_id
ORDER  SIBLINGS BY lot_id;
```

```text
       LVL LOT_TREE         STATUS
---------- ---------------- --------
         1 L26-003          ACTIVE
         2   L26-003A       SHIPPED
         3     L26-003B1    ACTIVE
```

The held lot L26-003B is gone, but its child L26-003B1 is still there, at level 3, now with no visible parent. In family-tree terms, WHERE cuts one person out of the photo and leaves their children standing in the gap. If you want to stop the walk at a held lot and skip everything below it, put the condition in CONNECT BY. That is pruning the whole branch:

```sql
SELECT LEVEL AS lvl, LPAD(' ', 2 * (LEVEL - 1)) || lot_id AS lot_tree, status
FROM   lots
START  WITH lot_id = 'L26-003'
CONNECT BY PRIOR lot_id = parent_lot_id
       AND status <> 'HOLD'
ORDER  SIBLINGS BY lot_id;
```

```text
       LVL LOT_TREE         STATUS
---------- ---------------- --------
         1 L26-003          ACTIVE
         2   L26-003A       SHIPPED
```

## Paths, roots and leaves

Three more features describe where a row sits in the tree:

- `SYS_CONNECT_BY_PATH(column, 'separator')` returns the values of the column from the root down to the current row, each preceded by the separator.
- `CONNECT_BY_ROOT column` is an operator that returns the column's value from the root row of the current row's tree.
- `CONNECT_BY_ISLEAF` is a pseudocolumn: 1 if the row has no children in this walk, 0 otherwise.

```sql
SELECT lot_id,
       SYS_CONNECT_BY_PATH(lot_id, ' > ')   AS path,
       SYS_CONNECT_BY_PATH(lot_type, '/')   AS type_path,
       CONNECT_BY_ROOT lot_id               AS root_lot,
       CONNECT_BY_ISLEAF                    AS is_leaf
FROM   lots
START  WITH lot_id = 'L26-007'
CONNECT BY PRIOR lot_id = parent_lot_id
ORDER  SIBLINGS BY lot_id;
```

```text
LOT_ID     PATH                                     TYPE_PATH                ROOT_LOT    IS_LEAF
---------- ---------------------------------------- ------------------------ -------- ----------
L26-007     > L26-007                               /PROD                    L26-007           0
L26-007A    > L26-007 > L26-007A                    /PROD/SPLIT              L26-007           1
```

The path always starts with the separator. Wrap it in `LTRIM(..., ' > ')` or `SUBSTR` if you do not want that.

CONNECT_BY_ROOT can return any column of the root, not only the key. Here every child lot is shown with its root lot and the number of days between the root's start and its own:

```sql
SELECT lot_id,
       CONNECT_BY_ROOT lot_id                            AS root_lot,
       ROUND(start_date - CONNECT_BY_ROOT start_date, 1) AS days_after_root
FROM   lots
WHERE  LEVEL > 1
START  WITH parent_lot_id IS NULL
CONNECT BY PRIOR lot_id = parent_lot_id
ORDER  BY lot_id;
```

```text
LOT_ID     ROOT_LOT DAYS_AFTER_ROOT
---------- -------- ---------------
L26-003A   L26-003              4.1
L26-003B   L26-003              4.1
L26-003B1  L26-003             10.3
L26-007A   L26-007              4.1
```

`WHERE LEVEL > 1` removes the roots after the walk. A plain ORDER BY is fine here, because this result is a list, not an indented tree. If you need totals per tree (lots or wafers per family), compute CONNECT_BY_ROOT in an inline view and GROUP BY it in the outer query.

## Walking up the tree

To go from a child to its ancestors, move PRIOR to the other side. `CONNECT BY lot_id = PRIOR parent_lot_id` reads: "the next row is the one whose lot_id equals the previous row's parent". Start with the lot you are interested in:

```sql
SELECT LEVEL AS steps_up, lot_id, lot_type, status
FROM   lots
START  WITH lot_id = 'L26-007A'
CONNECT BY lot_id = PRIOR parent_lot_id;
```

```text
  STEPS_UP LOT_ID     LOT_TYPE STATUS
---------- ---------- -------- --------
         1 L26-007A   SPLIT    ACTIVE
         2 L26-007    PROD     ACTIVE
```

When you walk up, LEVEL counts the steps away from the starting lot, the path runs from the start upwards, and CONNECT_BY_ISLEAF is 1 on the topmost ancestor (it has no "children" in this direction):

```sql
SELECT LEVEL AS steps_up, lot_id,
       SYS_CONNECT_BY_PATH(lot_id, ' < ') AS path,
       CONNECT_BY_ISLEAF                  AS is_top
FROM   lots
START  WITH lot_id = 'L26-003A'
CONNECT BY lot_id = PRIOR parent_lot_id;
```

```text
  STEPS_UP LOT_ID     PATH                                         IS_TOP
---------- ---------- ---------------------------------------- ----------
         1 L26-003A    < L26-003A                                       0
         2 L26-003     < L26-003A < L26-003                             1
```

This is the traceability question a fab asks all the time: a customer reports a problem with a wafer, so quality walks up from its lot to the production lot it came from, then walks down from there to find every related lot.

## Loops: NOCYCLE and CONNECT_BY_ISCYCLE

If bad data makes a row its own ancestor, the walk would never end, and Oracle stops with ORA-01436. It is the time-travel plot where someone turns out to be their own grandfather: fine in a film, impossible to draw as a tree. You can simulate that without changing the table, by building a broken copy of the genealogy in a WITH clause where L26-007 claims to be the child of its own child:

```sql
WITH lots_bad AS (
  SELECT lot_id,
         CASE lot_id WHEN 'L26-007' THEN 'L26-007A' ELSE parent_lot_id END AS parent_lot_id
  FROM   lots
)
SELECT LEVEL AS lvl, lot_id, parent_lot_id
FROM   lots_bad
START  WITH lot_id = 'L26-007'
CONNECT BY PRIOR lot_id = parent_lot_id;
```

```text
ORA-01436: CONNECT BY loop in user data
```

`CONNECT BY NOCYCLE` returns the rows anyway and stops at the loop. The pseudocolumn `CONNECT_BY_ISCYCLE` is 1 on the row whose child would close the loop, which tells you where to fix the data:

```sql
WITH lots_bad AS (
  SELECT lot_id,
         CASE lot_id WHEN 'L26-007' THEN 'L26-007A' ELSE parent_lot_id END AS parent_lot_id
  FROM   lots
)
SELECT LEVEL AS lvl, lot_id, parent_lot_id, CONNECT_BY_ISCYCLE AS is_cycle
FROM   lots_bad
START  WITH lot_id = 'L26-007'
CONNECT BY NOCYCLE PRIOR lot_id = parent_lot_id;
```

```text
       LVL LOT_ID     PARENT_LOT   IS_CYCLE
---------- ---------- ---------- ----------
         1 L26-007    L26-007A            0
         2 L26-007A   L26-007             1
```

CONNECT_BY_ISCYCLE can only be used together with NOCYCLE.

## Recursive WITH

CONNECT BY is Oracle-specific and short. Standard SQL does the same job with a recursive WITH clause (recursive subquery factoring), which Oracle also supports and which is more flexible. Day 4 covers it.

## Common mistakes

- Putting PRIOR on the wrong side. `PRIOR lot_id = parent_lot_id` walks down; `lot_id = PRIOR parent_lot_id` walks up. If the result has only the start rows, check the direction.
- Forgetting START WITH, so every row becomes a root and each subtree appears several times.
- Using ORDER BY instead of ORDER SIBLINGS BY and losing the tree order.
- Filtering in WHERE when you meant to prune a branch. WHERE removes single rows and leaves their children in the result; a condition in CONNECT BY stops the walk.
- Hitting ORA-01436 on bad data. Use NOCYCLE with CONNECT_BY_ISCYCLE to find the loop, then fix the data.

## Check your understanding

1. Write the START WITH and CONNECT BY clauses that list every lot below L26-003B.
2. A query walks up from a rework lot with `CONNECT BY PRIOR lot_id = parent_lot_id` and returns only one row. What is wrong?
3. What does `SYS_CONNECT_BY_PATH(lot_id, '/')` return for L26-003B1 in a walk that starts at L26-003?
4. You add `WHERE lot_type <> 'SPLIT'` to a genealogy query. Does L26-003B1 still appear? Why?
5. What is the difference between `CONNECT_BY_ROOT lot_id` and `LEVEL`?

## Further reading

- [Oracle Database SQL Language Reference 19c: Hierarchical Queries](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Hierarchical-Queries.html)
- [Oracle Database SQL Language Reference 19c: Hierarchical Query Pseudocolumns](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Hierarchical-Query-Pseudocolumns.html)
- [Oracle Database SQL Language Reference 19c: Hierarchical Query Operators](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Hierarchical-Query-Operators.html) (PRIOR and CONNECT_BY_ROOT)
- [Oracle Database SQL Language Reference 19c: SYS_CONNECT_BY_PATH](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SYS_CONNECT_BY_PATH.html)
- [ORACLE-BASE: Hierarchical Queries in Oracle](https://oracle-base.com/articles/misc/hierarchical-queries)

To practise, work through Part C of [Lab 5: Hierarchies and grouping](../labs/lab-5-hierarchies-and-grouping.md).

### Answers

1. `START WITH lot_id = 'L26-003B' CONNECT BY PRIOR lot_id = parent_lot_id`. (Add `AND LEVEL > 1` in WHERE, or use `START WITH parent_lot_id = 'L26-003B'`, if you want only the descendants without L26-003B itself.)
2. PRIOR is on the side that walks down. From a lot with no children, nothing qualifies, so only the start row comes back. Walk up with `CONNECT BY lot_id = PRIOR parent_lot_id`.
3. `/L26-003/L26-003B/L26-003B1`.
4. Yes. WHERE is applied after the walk and removes rows one by one, so L26-003B (a SPLIT lot) disappears but its REWORK child L26-003B1 stays. To drop the whole branch, put the condition in CONNECT BY.
5. CONNECT_BY_ROOT lot_id returns the lot_id of the root row of the current row's tree. LEVEL returns the depth of the current row (1 for the root).
