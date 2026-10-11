# Lab 4: Analytic functions

In this lab you use analytic functions on the FAB_LAB measurements: ranking with ties, the top row per group, comparing a row with an average or with the previous row, running totals, moving averages and distribution. The questions are B1 to B7. Each one replaces something that would otherwise take a self-join, a second query or a loop.

Slides: 28 of the Day 1 deck.

| | |
| --- | --- |
| Time | 30 minutes |
| Connection | FAB_LAB, password `Lab_2026`, on your PDB service, as in [Lab 3](lab-3-sql-review.md) |
| Script | [`lab4_analytic_functions.sql`](scripts/lab4_analytic_functions.sql): the questions and hints, with space for your answers |
| Core questions | B1, B2, B4. Do these first, then the rest if you have time |
| You finish with | Your own working query for each question you tackled, checked against the checkpoints |

## What this lab practises

| Questions | Topic page and section |
| --- | --- |
| B1, B2 | [Analytic functions](../module-2/03-analytic-functions.md): "Ranking: ROW_NUMBER, RANK and DENSE_RANK" and "Top-N per group" |
| B3 | [Analytic functions](../module-2/03-analytic-functions.md): "Keep every row, add a computed column" and "The OVER clause" |
| B4 | [Analytic functions](../module-2/03-analytic-functions.md): "Comparing rows: LAG and LEAD" |
| B5, B6 | [Analytic functions](../module-2/03-analytic-functions.md): "Windows: running totals and moving averages" |
| B7 | [Analytic functions](../module-2/03-analytic-functions.md): "Distribution: RATIO_TO_REPORT, NTILE and PERCENT_RANK" |

## Tables you need

The schema is described in [Lab 3](lab-3-sql-review.md#the-lab-schema). This lab mostly uses:

- MEASUREMENTS: `wafer_id`, `step` (SPLIT, ANNEAL, FINAL), `tool_id`, `meas_time`, `thickness_nm`, `defect_count`. Each measured wafer has one reading per step.
- WAFERS: `wafer_id`, `lot_id`. Join it to get from a measurement to its lot.
- LOTS: `lot_id`, `product_id`, `start_date`. Join it to get to the product.
- PRODUCTS: `product_id`, `product_code`, `target_thk_nm` (the target thickness).

The wafers of lot L26-003 are `L26-003-01` to `L26-003-05`. The filter `wafer_id LIKE 'L26-003-%'` finds them and not the wafers of L26-003A or L26-003B, because of the hyphen.

## How to work

1. Connect as FAB_LAB and open `lab4_analytic_functions.sql`. Run its first statement, `ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI';`, so that `meas_time` shows the time.
2. Try each question without the hint first.
3. Write your query under the question and run it with Ctrl+Enter.
4. Compare your result with the checkpoint.

## Questions

| Q | Question | Hint |
| --- | --- | --- |
| B1 (core) | Rank the wafers of lot L26-003 by FINAL thickness: ROW_NUMBER, RANK, DENSE_RANK | `ROW_NUMBER()`, `RANK()`, `DENSE_RANK() OVER (ORDER BY ...)` |
| B2 (core) | The thickest FINAL wafer in each product (top-1 per group) | `ROW_NUMBER() OVER (PARTITION BY product ...)` in an inline view, then `WHERE rn = 1` |
| B3 | For lots L26-003A and L26-003B: deviation of each FINAL reading from the product target and from the lot average | `AVG(...) OVER (PARTITION BY lot_id)` |
| B4 (core) | Thickness change from one step to the next for wafer L26-001-01 (LAG) | `LAG(thickness_nm) OVER (PARTITION BY wafer_id ORDER BY meas_time)` |
| B5 | Running total of wafers started, by lot start date (window SUM) | `SUM(COUNT(...)) OVER (ORDER BY ...)`: an analytic over an aggregate |
| B6 | Moving average of defects over the last 3 readings on tool MET01 (first 8 readings) | `AVG(...) OVER (... ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` |
| B7 | Share of each product's FINAL defects (RATIO_TO_REPORT) and quartile of each lot (NTILE) | `RATIO_TO_REPORT(...) OVER ()` and `NTILE(4) OVER (ORDER BY ...)` |

Notes on some questions:

- B1: put the three functions side by side in one query, so that you can compare them row by row. At the Tokyo Olympics in 2021, high jumpers Mutaz Essa Barshim and Gianmarco Tamberi tied and chose to share the gold. No silver was awarded and the next athlete took bronze: that is RANK (1, 1, 3). DENSE_RANK would have given him silver.
- B4: order by `meas_time`, not by `step`. Think about what alphabetical order does to SPLIT, ANNEAL and FINAL.
- B5: first count the wafers per lot (GROUP BY the lot and its start date), then add the running SUM over the grouped rows.
- B7: two queries. For the share, sum the FINAL defects per product in an inline view and apply RATIO_TO_REPORT outside. For the quartiles, compute the average FINAL defects per lot and put the lots into four groups.

## Checkpoints

Spacing and column headings may differ from yours; the values must match.

| Q | Check |
| --- | --- |
| B1 | ROW_NUMBER 1 to 5; RANK 1, 1, 3, 3, 5; DENSE_RANK 1, 1, 2, 2, 3 |
| B2 | 4 rows, for example FD-300 L26-003B-02 12.64 |
| B3 | L26-003B-02: +0.64 from target, +0.07 from its lot average |
| B4 | 3 rows; the change is empty on the first, then -2.28, then -1.64 |
| B5 | 16 rows; the running total ends at 66 |
| B6 | 8 rows; the moving average jumps to 7.67 at L26-003B-02 |
| B7 | FD-300 has 42% of the FINAL defects; 15 lots get a quartile, and L26-008 is in quartile 4 |

## Debrief questions

- Which of these queries would have needed a PL/SQL loop or a self-join before today?
- Why must the `rn = 1` filter in B2 go in an outer query?
- In B1, how would you make the ROW_NUMBER order of the tied wafers repeatable?

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| ORA-30483: window functions are not allowed here | An analytic function in WHERE. Analytic functions are computed after WHERE, so wrap the query in an inline view and filter outside |
| ORA-00979: not a GROUP BY expression | In B5 or B7 a column in the SELECT list is neither in GROUP BY nor inside an aggregate. The analytic's ORDER BY can only use grouped columns or aggregates |
| ORA-25154: column part of USING clause cannot have qualifier | With `JOIN ... USING (lot_id)`, write `lot_id`, not `l.lot_id`, everywhere in the query |
| B1 returns more than 5 rows | The filter also matches L26-003A and L26-003B. Use `LIKE 'L26-003-%'`, with the hyphen |
| B4 shows the steps in the wrong order | You ordered by `step`. Order the window by `meas_time` |
| B6 averages are off | Check the frame is `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`, the window is ordered by `meas_time`, and the WHERE keeps only tool MET01 |
| Dates show without the time | Run the `ALTER SESSION SET NLS_DATE_FORMAT` line at the top of the script |

## Further reading

- [CBS Sports: Tokyo Olympics high jumpers Mutaz Essa Barshim and Gianmarco Tamberi share gold medal](https://www.cbssports.com/olympics/news/2020-tokyo-olympics-high-jumpers-mutaz-essa-barshim-of-qatar-and-gianmarco-tamberi-of-italy-share-gold-medal)
- [Oracle Database Data Warehousing Guide, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/index.html) (chapter "SQL for Analysis and Reporting")
- [Oracle Database SQL Language Reference, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/index.html) (section "Analytic Functions" in the chapter "Functions")
