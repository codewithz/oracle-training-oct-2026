# Lab 5: Hierarchies and grouping

In this lab you query the lot genealogy of FAB_LAB as a tree, and you build reports with subtotals, chosen totals, rows turned into columns and values joined into lists. Part C (C1 to C4) is about hierarchical queries; part D (D1 to D4) is about advanced grouping and aggregation.

Slides: 32 of the Day 1 deck.

| | |
| --- | --- |
| Time | 30 minutes. If you are still in part C after about 15 minutes, move on to part D |
| Connection | FAB_LAB, password `Lab_2026`, on your PDB service, as in [Lab 3](lab-3-sql-review.md) |
| Script | [`lab5_hierarchies_and_grouping.sql`](scripts/lab5_hierarchies_and_grouping.sql): the questions and hints, with space for your answers |
| Core questions | C1, C2, D1, D2. Do these first, then the rest if you have time |
| You finish with | Your own working query for each question you tackled, checked against the checkpoints |

## What this lab practises

| Questions | Topic page |
| --- | --- |
| C1 to C4 | [Hierarchical queries](../module-2/04-hierarchical-queries.md) |
| D1 to D4 | [Advanced grouping and aggregation](../module-2/05-advanced-grouping.md) |

## Tables you need

The schema is described in [Lab 3](lab-3-sql-review.md#the-lab-schema). This lab mostly uses:

- LOTS: `lot_id`, `product_id`, `lot_type` (PROD, SPLIT, REWORK), `parent_lot_id`, `start_date`, `status`. A split or rework lot has the lot it came from in `parent_lot_id`; a production lot has none. That makes LOTS a tree, for example L26-003, then its split L26-003B, then the rework L26-003B1. Read it like a family tree: `parent_lot_id` names each lot's parent, and CONNECT BY draws the generations.
- WAFERS: `wafer_id`, `lot_id`, `slot_no`, `grade` (empty when not graded yet).
- PRODUCTS: `product_id`, `product_code`.
- MEASUREMENTS: `wafer_id`, `step`, `defect_count`.

For the month in D1 and D2, use `TO_CHAR(start_date, 'YYYY-MM')` from LOTS.

## How to work

1. Connect as FAB_LAB and open `lab5_hierarchies_and_grouping.sql`. Run its first statement, `ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI';`.
2. Try each question without the hint first.
3. Write your query under the question and run it with Ctrl+Enter.
4. Compare your result with the checkpoint.

## Part C: Hierarchical queries (lot genealogy)

| Q | Question | Hint |
| --- | --- | --- |
| C1 (core) | The full genealogy tree (CONNECT BY, LEVEL, indentation) | `START WITH parent_lot_id IS NULL CONNECT BY PRIOR lot_id = parent_lot_id`; `ORDER SIBLINGS BY` |
| C2 (core) | Path, root and leaf flag for every lot that came from L26-003 | `SYS_CONNECT_BY_PATH`, `CONNECT_BY_ROOT`, `CONNECT_BY_ISLEAF` |
| C3 | Walk upwards: all ancestors of the rework lot L26-003B1 | Reverse the direction: `CONNECT BY lot_id = PRIOR parent_lot_id` |
| C4 | Wafers per family tree: total wafers under each root lot that has children | `CONNECT_BY_ROOT` in an inline view, then `GROUP BY ... HAVING` |

Notes:

- C1: indent each lot by its depth, for example `LPAD(' ', 2 * (LEVEL - 1)) || lot_id`.
- C4: in the inline view, tag every lot with its root lot and count its wafers (a scalar subquery on WAFERS works). In the outer query, group by the root and keep only the roots with more than one lot.

## Part D: Advanced grouping and aggregation

| Q | Question | Hint |
| --- | --- | --- |
| D1 (core) | Wafers started per product and month, with subtotals and grand total (ROLLUP) | `GROUP BY ROLLUP (product, month)` |
| D2 (core) | Label the subtotal rows with GROUPING() instead of showing NULL | `GROUP BY CUBE`, then `GROUPING()` and `GROUPING_ID()` |
| D3 | Only the totals you ask for: per status and per lot type, no detail rows (GROUPING SETS) | `GROUP BY GROUPING SETS ((status), (lot_type), ())` |
| D4 | Defects per step as columns for lots L26-001 to L26-009 (PIVOT); wafer grades by slot for L26-001, L26-008, L26-012 (LISTAGG) | `PIVOT (SUM(...) FOR step IN (...))`; `LISTAGG(...) WITHIN GROUP (ORDER BY ...)` |

Notes:

- D1 and D2: count wafers, so join LOTS, PRODUCTS and WAFERS. Use exactly the same month expression in SELECT, in GROUP BY and inside GROUPING().
- D2: show the word `ALL` on a subtotal row, for example with `CASE GROUPING(p.product_code) WHEN 1 THEN 'ALL' ELSE p.product_code END`.
- D4, PIVOT: lots L26-001 to L26-009 are the production lots only, not their splits and reworks. In the inline view, select just the lot, the step and the defect count. The values in the `IN` list are quoted strings: `'SPLIT'`, `'ANNEAL'`, `'FINAL'`.
- D4, LISTAGG: one row per lot, the grades in slot order.

## Checkpoints

Spacing and column headings may differ from yours; the values must match.

| Q | Check |
| --- | --- |
| C1 | 16 rows; L26-003B1 at level 3, under L26-003B |
| C2 | 4 rows; /L26-003/L26-003B/L26-003B1 is a leaf |
| C3 | 3 rows, from L26-003B1 up to L26-003 |
| C4 | 2 trees. L26-003: 4 lots, 12 wafers; L26-007: 2 lots, 7 wafers |
| D1 | 13 rows; FD-300 total 29; grand total 66 |
| D2 | 15 rows; 2026-08 total 36, 2026-09 total 30 |
| D3 | 8 rows; ACTIVE 8, PROD 12, total 16 |
| D4 | PIVOT: 9 rows, L26-008 FINAL 79. LISTAGG: L26-012 lists only 2 grades out of 4 wafers. Why? |

## Debrief questions

- In C1, what happens to the tree if you write `ORDER BY start_date` instead of `ORDER SIBLINGS BY lot_id`? Why does `ORDER BY lot_id` seem to work?
- In D1, how do you tell a subtotal row from a row whose month is really NULL?
- In D4, why does L26-012 show only two grades? Where have you met the same behaviour before (Lab 3, A6)?

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| ORA-01788: CONNECT BY clause required in this query block | LEVEL, SYS_CONNECT_BY_PATH, CONNECT_BY_ROOT and CONNECT_BY_ISLEAF only work in a query with CONNECT BY. In C4, put them in the inline view that has the CONNECT BY |
| C1 shows each lot once but children are not under their parent | A plain ORDER BY sorted the whole result. Use `ORDER SIBLINGS BY lot_id` |
| C1 returns more than 16 rows | START WITH is missing, so every lot is used as a root. Add `START WITH parent_lot_id IS NULL` |
| C3 returns only one row, or the descendants | PRIOR is on the wrong side. To walk up, write `CONNECT BY lot_id = PRIOR parent_lot_id` |
| ORA-00979: not a GROUP BY expression | The month expression in SELECT or in GROUPING() differs from the one in GROUP BY. Repeat exactly `TO_CHAR(l.start_date, 'YYYY-MM')` |
| ORA-56901: non-constant expression is not allowed for pivot\|unpivot values | The values in the PIVOT `IN` list are not quoted. Write `'SPLIT'`, not `SPLIT` |
| PIVOT returns more rows than lots | The inline view selects extra columns (for example `wafer_id`), which become implicit GROUP BY columns. Select only lot, step and defect count |

## Further reading

- [Oracle Database SQL Language Reference, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/index.html) (sections "Hierarchical Queries" and "SELECT")
- [Oracle Database Data Warehousing Guide, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/index.html) (chapter "SQL for Analysis and Reporting" covers ROLLUP, CUBE, GROUPING SETS and pivoting)
