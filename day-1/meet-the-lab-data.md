# Meet the lab data

All the SQL on Day 1, and most of the rest of the week, runs against one small schema called FAB_LAB. It is an invented wafer fab: five products, nine tools, sixteen lots, sixty-six wafers and a few measurements per wafer. The names and numbers are made up for the course, so nothing here describes a real company's process. The point of the schema is that it is small enough to check by eye and close enough to a real fab that the questions make sense.

Slides: 21 of the Day 1 deck.

Ten minutes spent on this page makes Labs 3 to 5 much easier. Most mistakes in those labs come from joining the wrong columns. The SQL feature being practised is rarely the problem.

## The five tables

Read the diagram left to right: a product is made in lots, a lot holds wafers, each wafer is measured at three process steps, and each measurement is taken on a tool.

```text
PRODUCTS (5)  1 ──< n  LOTS (16)  1 ──< n  WAFERS (66)  1 ──< n  MEASUREMENTS (186)  n >── 1  TOOLS (9)
                        │    ^
                        └────┘  LOTS.parent_lot_id points to the lot it came from
```

| Table | Rows | One row is | Key columns |
| --- | --- | --- | --- |
| PRODUCTS | 5 | A substrate product | `product_id`, `product_code`, `family`, `diameter_mm`, `target_thk_nm` |
| TOOLS | 9 | A process or metrology tool | `tool_id`, `tool_type`, `bay` |
| LOTS | 16 | A group of wafers that moves through the fab together | `lot_id`, `product_id`, `lot_type`, `parent_lot_id`, `start_date`, `status`, `priority`, `hold_reason` |
| WAFERS | 66 | One wafer in one slot of a lot | `wafer_id`, `lot_id`, `slot_no`, `grade` |
| MEASUREMENTS | 186 | One reading of one wafer at one step | `meas_id`, `wafer_id`, `step`, `tool_id`, `meas_time`, `thickness_nm`, `defect_count` |

The joins you will write all week:

```sql
lots.product_id         = products.product_id
wafers.lot_id           = lots.lot_id
measurements.wafer_id   = wafers.wafer_id
measurements.tool_id    = tools.tool_id
lots.parent_lot_id      = lots.lot_id      -- a lot and its parent: the family tree
```

The units are in the column names: `thickness_nm` and `target_thk_nm` are nanometres, `diameter_mm` is millimetres. That habit is worth copying. In 1999 NASA lost the Mars Climate Orbiter because one team's software produced thruster data in pound-force seconds while the navigation software expected newton-seconds. A column called `thickness` with no unit invites the same kind of mistake.

## Products and tools

```text
PRODUCT_ID PRODUCT_ FAMILY         DIAMETER_MM TARGET_THK_NM
---------- -------- -------------- ----------- -------------
         1 FD-300   FD-SOI                 300            12
         2 RF-300   RF-SOI                 300            75
         3 PWR-200  Power-SOI              200          1500
         4 PHO-300  Photonics-SOI          300           220
         5 SIC-150  SiC                    150           500
```

`target_thk_nm` is the thickness each product should have at the FINAL step. FD-300 aims for 12 nm, PWR-200 for 1,500 nm, so never compare raw thickness across products. Compare each reading with its own product's target.

```text
TOOL_I TOOL_TYPE  BAY
------ ---------- ------
ANL01  ANNEAL     B2
ANL02  ANNEAL     B2
CMP01  POLISH     B4
IMP01  IMPLANT    B1
MET01  METROLOGY  B3
MET02  METROLOGY  B3
MET03  METROLOGY  B4
SPL01  SPLIT      B1
SPL02  SPLIT      B1
```

## Lots, and why they have parents

A lot starts life as a production lot (`lot_type = 'PROD'`). Sometimes it is split into smaller lots, for example to run part of it through a different recipe, and sometimes a lot that failed a check is reworked into a new lot. Each child lot records where it came from in `parent_lot_id`.

```text
LOT_ID     PRODUCT_ID LOT_TYPE PARENT_LOT START_DATE       STATUS     PRIORITY HOLD_REASON
---------- ---------- -------- ---------- ---------------- -------- ---------- -----------------------------
L26-001             1 PROD                2026-08-03 07:30 SHIPPED           3
L26-002             2 PROD                2026-08-05 09:00 SHIPPED           2
L26-003             1 PROD                2026-08-10 06:45 ACTIVE            1
L26-003A            1 SPLIT    L26-003    2026-08-14 10:00 SHIPPED           1
L26-003B            1 SPLIT    L26-003    2026-08-14 10:05 HOLD              1 Thickness out of spec at FINAL
L26-003B1           1 REWORK   L26-003B   2026-08-20 13:00 ACTIVE            1
```

L26-003 was split into L26-003A and L26-003B. L26-003B came out too thick at FINAL, went on HOLD, and was reworked into L26-003B1. That gives a three-level family tree, and it is what the hierarchical queries in Lab 5 walk. A second, smaller tree starts at L26-007.

In a substrate fab the family tree can matter a great deal: when a customer reports a problem, you need every lot that shares an ancestor with the bad one. A family tree of people is the easiest way to picture it, with the one difference that a lot can only ever have one parent.

The 16 lots started between 3 August and 29 September 2026. By type there are 12 PROD, 3 SPLIT and 1 REWORK lots; by status, 8 ACTIVE, 5 SHIPPED, 2 HOLD and 1 SCRAPPED. `priority` 1 is the most urgent.

## Wafers

```text
WAFER_ID     LOT_ID       SLOT_NO GRADE
------------ ---------- ---------- ------
L26-001-01   L26-001             1 PRIME
L26-001-02   L26-001             2 PRIME
L26-001-03   L26-001             3 PRIME
L26-001-04   L26-001             4 PRIME
L26-001-05   L26-001             5 TEST
```

A wafer ID is its lot ID plus the slot number. Each lot holds between 2 and 5 wafers. `grade` is PRIME (51 wafers), TEST (9) or SCRAP (4), and two wafers have no grade yet.

## Measurements: one wafer's journey

Each wafer is measured after three steps, always in this order: SPLIT, ANNEAL, FINAL. Here is the first wafer of the first lot:

```text
   MEAS_ID WAFER_ID     STEP     TOOL_I MEAS_TIME        THICKNESS_NM DEFECT_COUNT
---------- ------------ -------- ------ ---------------- ------------ ------------
         1 L26-001-01   SPLIT    SPL02  2026-08-04 08:00        15.81           42
         2 L26-001-01   ANNEAL   ANL02  2026-08-05 08:15        13.53           23
         3 L26-001-01   FINAL    MET01  2026-08-06 08:54        11.89            4
```

The layer gets thinner at each step and the defect count falls. The FINAL reading of 11.89 nm is close to the FD-300 target of 12 nm. Questions such as "how much thinner did the wafer get at each step?" are what LAG answers in Lab 4.

You can read this wafer's history yourself:

```sql
SELECT m.step, m.tool_id, m.thickness_nm, p.target_thk_nm, m.defect_count
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
WHERE  m.wafer_id = 'L26-001-01'
ORDER  BY m.meas_time;
```

## A few things are missing on purpose

Real data is never complete, and this data set is built to show what happens to SQL when something is missing. You will meet these gaps in the labs. They are there for you to find:

- One product has no lots yet.
- Two tools have never taken a measurement.
- One lot has wafers but no measurements yet.
- One lot on hold has an empty hold reason.
- Two wafers have no grade yet.

Each gap changes the answer of at least one lab question if you write the query carelessly. Missing values cause real trouble outside training too. A technology journalist called Christopher Null wrote in Wired in 2015 about how often computer systems reject or mangle his surname, and a security researcher who chose the California licence plate "NULL" ended up being sent other people's parking fines. Module 2 shows how Oracle treats NULL so that your queries do not make the same mistakes.

## Load or reload the data

The data is loaded in Lab 1 by [`fab_lab_data.sql`](labs/scripts/fab_lab_data.sql), run as FAB_LAB. The script drops and re-creates its own tables, so you can run it again at any time to get back to a clean copy. Do that if you committed a change by accident and your lab results no longer match the checkpoints. The last query in the script prints the row counts, which should be PRODUCTS 5, TOOLS 9, LOTS 16, WAFERS 66 and MEASUREMENTS 186.

Lab 2 shows you how to read the same structure from the data dictionary: which foreign keys link the tables, which indexes exist, and how much space each table takes.

## Check your understanding

1. Which column links a measurement to the lot it belongs to? (Careful: there is no `lot_id` in MEASUREMENTS.)
2. Why is comparing the raw `thickness_nm` of an FD-300 wafer with a PWR-200 wafer meaningless?
3. Which lot is the parent of L26-003B1, and which lot is its grandparent?
4. A query counts wafers per grade and finds 64. The table has 66 rows. Where are the other two?

### Answers

1. None directly. Go through WAFERS: `measurements.wafer_id = wafers.wafer_id`, then `wafers.lot_id`.
2. The products have different targets (12 nm and 1,500 nm). Compare each reading with its own product's `target_thk_nm`.
3. Its parent is L26-003B; its grandparent is L26-003.
4. Two wafers have a NULL grade. `GROUP BY grade` puts them in their own group with a NULL key, and `WHERE grade IN (...)` leaves them out.

## Further reading

- [Oracle Database SQL Language Reference 19c: Joins](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Joins.html)
- [Oracle Database SQL Language Reference 19c: Nulls](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Nulls.html)
- [Oracle Database Concepts 19c: Tables and Table Clusters](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/tables-and-table-clusters.html)
- [Christopher Null on Wikipedia](https://en.wikipedia.org/wiki/Christopher_Null), for the background to his Wired article
