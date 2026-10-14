# The Day 3 and 4 data add-on

Days 1 and 2 used the five FAB_LAB tables: PRODUCTS, LOTS, WAFERS, TOOLS and MEASUREMENTS. Days 3 and 4 need more to work with: a history of what happened to each lot, a table big enough for tuning to matter, and an empty log table for error handling. This add-on creates those three tables and two sequences. It does not touch the original five.

## Setting it up

Connect as FAB_LAB (password Lab_2026) to your PDB in DBeaver. The five original tables must already be loaded. Then open each file below and run it with Execute Script (Alt+X), in this order.

| Order | File | What it does |
|---|---|---|
| 0 | `day34_addon_0_reset.sql` | Drops the add-on tables and sequences, if they exist |
| 1 | `day34_addon_1_tables.sql` | Creates LOT_HISTORY, its index and the two sequences |
| 2 | `day34_addon_2_lot_history_data.sql` | Inserts the 147 LOT_HISTORY rows and commits |
| 3 | `day34_addon_3_big_table_and_check.sql` | Creates and fills MEASUREMENTS_BIG, creates ERROR_LOG, then counts the rows |

The last query in file 3 should show:

| TABLE_NAME | ROW_COUNT |
|---|---|
| LOT_HISTORY | 147 |
| MEASUREMENTS_BIG | 200000 |
| ERROR_LOG | 0 |

Some things to know:

- File 0 is only needed if you ran the add-on before, or if a run stopped halfway. On a clean schema it reports "table or view does not exist" or "sequence does not exist". That is expected; click Skip all.
- File 3 inserts 200,000 rows and takes a few seconds.
- To start again at any time, run files 0 to 3 again. Every laptop gets exactly the same rows, because the data is fixed values and arithmetic, not random numbers.
- The files are plain SQL, with no `SET` lines and no PL/SQL blocks. That is on purpose. DBeaver's script runner fails on SQL*Plus `SET` commands (ORA-00922) and splits PL/SQL blocks that contain functions in the wrong place (PLS-00103). The older single file, `day34_addon.sql`, has both problems in DBeaver. Use the four files instead.

## LOT_HISTORY: what happened to each lot

One row each time a lot changed status. 147 rows covering all 16 lots, from 3 August to 8 October 2026.

| Column | Meaning |
|---|---|
| `hist_id` | Row number, 1 to 147, in time order within each lot |
| `lot_id` | The lot (references LOTS) |
| `old_status` | Status before the change. NULL on the first row of each lot |
| `new_status` | Status after the change: ACTIVE, HOLD, SHIPPED or SCRAPPED |
| `changed_at` | When the change happened (DATE, with time) |
| `changed_by` | Who made it: RKUMAR, LTAN, SOKAFOR, PDIAZ or MAYA |
| `note` | Free text written the way operators write. NULL on 21 rows |

Each lot starts ACTIVE, then goes on and off HOLD a few times. Some lots end SHIPPED or SCRAPPED, and the last row of each lot matches the status in LOTS. The table records when each change happened, not how long a status lasted. Working that out with `LEAD` is one of the Day 3 exercises.

The `note` column is messy on purpose, for the regular expressions topic. It mixes upper and lower case, double spaces, tool IDs (MET01, SPL02), readings such as `38.4nm` and `38.4 nm`, ticket numbers (INC-20408, FAB-OPS-117), an email address and phone extensions. The first rows of lot L26-003:

| hist_id | old_status | new_status | changed_at | changed_by | note |
|---|---|---|---|---|---|
| 21 | | ACTIVE | 2026-08-10 06:45 | LTAN | lot started |
| 22 | ACTIVE | HOLD | 2026-08-11 14:45 | SOKAFOR | |
| 23 | HOLD | ACTIVE | 2026-08-13 05:45 | PDIAZ | released by eng - defect cnt 18 within limit |
| 24 | ACTIVE | HOLD | 2026-08-14 18:45 | MAYA | hold - thk OOS at FINAL, SPL01 read 38.4nm vs target |
| 25 | HOLD | ACTIVE | 2026-08-16 12:45 | RKUMAR | RELEASED. recheck IMP01 pass (INC-20408) |

Counts by `new_status`: ACTIVE 77, HOLD 64, SHIPPED 5, SCRAPPED 1.

## MEASUREMENTS_BIG: the same readings, many more of them

Same columns as MEASUREMENTS: `meas_id`, `wafer_id`, `step`, `tool_id`, `meas_time`, `thickness_nm` and `defect_count`. 200,000 rows covering the same 66 wafers and 7 tools, from 4 August to 10 October 2026, split evenly across the three steps (SPLIT, ANNEAL and FINAL).

MEASUREMENTS is too small to show a difference in speed. With 200,000 rows, indexes, execution plans and bulk processing make a difference you can measure. The only constraint is the primary key: there is no foreign key to WAFERS and no index on `wafer_id`, so the tuning lab can add one and compare. Oracle collects statistics while the rows are inserted, so execution plans are realistic from the start.

## ERROR_LOG: empty, for the error-handling demos

| Column | Meaning |
|---|---|
| `log_id` | Taken from `error_log_seq` |
| `logged_at` | Fills itself in (`DEFAULT SYSTIMESTAMP`) |
| `module` | Which program wrote the row |
| `err_code` | The Oracle error number (`SQLCODE`) |
| `err_msg` | The error text (`SQLERRM`) |

It starts empty. Day 4 code writes to it when it catches an error.

## The two sequences

- `lot_history_seq` starts at 1000. Use it when a lab adds a new LOT_HISTORY row, so new rows never clash with the 147 loaded ones.
- `error_log_seq` starts at 1, for ERROR_LOG.

## Where each table is used

| Table | Day 3 | Day 4 |
|---|---|---|
| LOT_HISTORY | Lab 8 (setup check), Lab 9 (how long each hold lasted, with `LAG` and `LEAD`), Lab 10 (report shapes), Lab 11 (regular expressions on `note`); topics 03 and 06 | Topics 03 (exceptions), 05 (packages and triggers) and 08 (good habits); Lab 17 (a trigger that writes history) |
| MEASUREMENTS_BIG | Lab 8 (setup check) | Topic 06 and Lab 18 (tuning), topic 08 |
| ERROR_LOG | Lab 8 (setup check) | Topic 07 (autonomous transaction demo) |

Day 3 Lab 12, on read consistency and flashback, uses its own private copy of LOTS (`MY_LOTS_COPY`) and does not depend on this add-on.
