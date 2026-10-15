# Lab 17: Packages and triggers

**Time:** 45 minutes. **Reading first:** [Packages and triggers](../topics/05-packages-and-triggers.md).

> **Do Lab 16 first.** This lab builds a package from the four objects you wrote there: `wafer_yield`, `thickness_status`, `print_lot_report` and `hold_lot`. If you skipped Lab 16, run [`lab17_catchup.sql`](scripts/lab17_catchup.sql) once. It recreates the four objects with the behaviour the lab expects.

> **Your tables are safe.** The lab changes two lots and adds three rows to `LOT_HISTORY`. The last exercise puts everything back. Do not skip it.

## The story

Maya is pleased with the little reports, but she has noticed that nobody knows which routines belong together. "I want one thing I can hand to the night shift," she says. "And when a lot changes status, I want it written down, even if somebody forgets."

You will wrap your routines in a package called `FAB_REPORTS`, then add a trigger that keeps the lot history up to date.

## What you will do

- write a package specification and body
- add a private helper and a package variable
- call package functions from a `SELECT`
- create a row trigger that uses `:OLD` and `:NEW`
- disable and enable a trigger, and see `ORA-04091`
- clean up

## Before you start

1. Switch DBeaver to **Manual Commit** (the toolbar button that shows Auto), as in Lab 7. Remember that `CREATE`, `ALTER` and `DROP` commit by themselves, even in manual mode.
2. Open the Output panel (**Ctrl + Shift + O**, or **SQL Editor > Show Server Output**) before you run anything. `DBMS_OUTPUT` lines appear there.
3. Run each `CREATE OR REPLACE PACKAGE`, `CREATE OR REPLACE PACKAGE BODY` and `CREATE OR REPLACE TRIGGER` on its own: select the whole statement, from `CREATE` down to its `END ...;` line, and press **Ctrl + Enter**. Do the same with each `BEGIN ... END;` call. One at a time. Plain `SELECT`, `UPDATE`, `ALTER` and `DROP` statements run with the cursor inside them and **Ctrl + Enter**.
4. Do not leave blank lines inside a package or trigger. DBeaver can cut the statement in two at a blank line. If you want space between the routines of a body, use a line holding only `--`.
5. If a `CREATE` reports a compile error, read it with `SELECT line, position, text FROM user_errors WHERE name = 'FAB_REPORTS' ORDER BY sequence;`.

## Scripts

| File | What it does |
| --- | --- |
| [`lab17_packages_and_triggers.sql`](scripts/lab17_packages_and_triggers.sql) | Every exercise as a comment with space for your code. Run as `FAB_LAB`. |
| [`lab17_catchup.sql`](scripts/lab17_catchup.sql) | Recreates the four Lab 16 objects. Run it only if you skipped Lab 16. This file is safe to run whole with **Alt + X**, or block by block. |

Solutions: [lab-17-solutions.md](../solutions/lab-17-solutions.md).

## Exercise 1: The specification

Maya: "Put our four routines in a package called `FAB_REPORTS`. Start with the label on the lid."

Create the **specification** only, listing the four routines with the same parameters as before. Then call `fab_reports.wafer_yield('L26-003')` in a small block and read the error.

<details>
<summary>Hint 1: which statement?</summary>

`CREATE OR REPLACE PACKAGE fab_reports AS ... END fab_reports;` followed by a line with a single `/`. The specification contains headings only: no `IS`, no `BEGIN`, no code.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
CREATE OR REPLACE PACKAGE fab_reports AS
  FUNCTION  wafer_yield (p_lot_id VARCHAR2) RETURN NUMBER;
  FUNCTION  ___ (___) RETURN ___;
  PROCEDURE ___ (___);
  PROCEDURE ___ (___);
END fab_reports;
/
```
</details>

<details>
<summary>Hint 3: the error</summary>

You will see `ORA-04067: not executed, package body "..." does not exist`. The label is on the lid, but the box is empty.
</details>

**Checkpoint:** `USER_OBJECTS` shows `FAB_REPORTS` as a `PACKAGE`, `VALID`, and the call fails with `ORA-04067`.

## Exercise 2: The body

Maya: "Now put the tools in the box."

Create the **package body**, copying the code from your Lab 16 routines. Then check:

```sql
SELECT fab_reports.wafer_yield('L26-003') AS yield FROM dual;
BEGIN fab_reports.print_lot_report('L26-005'); END;
/
```

<details>
<summary>Hint 1: shape of a body</summary>

`CREATE OR REPLACE PACKAGE BODY fab_reports AS` then each routine written out in full, ending with `END fab_reports;`. Inside the body you write `FUNCTION name (...) RETURN type IS` with `IS`, where the specification had a semicolon.
</details>

<details>
<summary>Hint 2: matching</summary>

Every routine in the specification needs a matching routine in the body. Names, parameter names, parameter types and return types must be identical.
</details>

<details>
<summary>Hint 3: skeleton</summary>

```sql
CREATE OR REPLACE PACKAGE BODY fab_reports AS
  FUNCTION wafer_yield (p_lot_id VARCHAR2) RETURN NUMBER IS
    ... (your Lab 16 code, from DECLARE variables to RETURN)
  END wafer_yield;
  ... the other three, in any order ...
END fab_reports;
/
```
</details>

**Checkpoint:** the yield for `L26-003` is `80`. `BEGIN fab_reports.print_lot_report('L26-005'); END;` prints a header line and four wafer lines, and ends with `Wafers: 4   Yield: 100 %` (your layout may differ a little if you wrote the report your own way).

**Trap:** if you get `PLS-00323: subprogram ... is declared in a package specification and must be defined in the package body`, one routine is missing or its signature differs from the specification by a parameter name or type. Read the error line and compare. If your Lab 16 function says `DETERMINISTIC`, the specification must say it too.

## Exercise 3: A private helper and a counter

Maya: "How many reports have I printed today? And check that the lot exists in one place only."

Change the package so that:

- a **private** procedure `check_lot (p_lot_id, p_status OUT)` reads the lot's status and raises `-20101` ("Lot ... does not exist") when there is no such lot, the same error `hold_lot` raised in Lab 16. `hold_lot` calls it instead of repeating the query.
- a package variable counts how many reports were printed, and a public function `reports_printed` returns it.

Make `print_lot_report` add 1 to the counter after it prints. Print the reports for `L26-008` and `L26-012`, then read the counter. Finally try to call `fab_reports.check_lot` from outside.

<details>
<summary>Hint 1: what changes where</summary>

The new public function goes in **both** the specification and the body. The private procedure goes in the **body only**. Put it above the routines that call it, or Oracle will not know it yet.
</details>

<details>
<summary>Hint 2: the counter</summary>

Declare `g_printed PLS_INTEGER := 0;` at the top of the body, add 1 at the end of `print_lot_report`, and return it from `reports_printed`.
</details>

<details>
<summary>Hint 3: private test</summary>

Call it in a block: `fab_reports.check_lot('L26-003', v);` with a `VARCHAR2` variable `v`. Expect `PLS-00302: component 'CHECK_LOT' must be declared`.
</details>

**Checkpoint:** `reports_printed` returns `0` before and `2` after the two reports.

**Trap:** disconnect and reconnect (or open a new editor with its own connection) and read the counter again. It is `0`. Package state belongs to a session.

## Exercise 4: Package members in a SELECT

Maya: "Show every lot with its yield, worst first. Then count the thickness verdicts for all measurements, step by step."

- **4a.** `lot_id`, `status`, `yield_pct`, lowest yield first. A lot with no yield should come first.
- **4b.** `step`, `verdict`, `readings`: how many readings fall into each verdict, using `fab_reports.thickness_status(thickness_nm, target_thk_nm)`. You need `MEASUREMENTS`, `WAFERS`, `LOTS` and `PRODUCTS`.
- **4c.** Try to put `hold_lot` in a `SELECT` and read the error.

<details>
<summary>Hint 1: 4a</summary>

`SELECT lot_id, status, fab_reports.wafer_yield(lot_id) AS yield_pct FROM lots ORDER BY ...`. `NULLS FIRST` puts lots without a yield at the top, and you can use the alias in `ORDER BY`.
</details>

<details>
<summary>Hint 2: 4b joins</summary>

`measurements` joins `wafers` on `wafer_id`, `wafers` joins `lots` on `lot_id`, `lots` joins `products` on `product_id`. The target thickness is `products.target_thk_nm`.
</details>

<details>
<summary>Hint 3: 4b grouping</summary>

Group by the step and by the whole function call (repeat the call in `GROUP BY`; a column alias is not allowed there in Oracle 19c).
</details>

**Checkpoint:** 4a starts with `L26-008` at `0` and has 16 rows. 4b returns 4 rows, and `FINAL` / `OK` has 62 readings. 4c fails with `ORA-00904`.

**Trap:** do not rewrite `thickness_status` so that it changes data. A function inside a query must only read.

## Exercise 5: A trigger that writes LOT_HISTORY

Maya: "Whenever a lot's status changes, I want a history row, whoever makes the change."

Create the trigger `lots_status_hist_trg`: after an update of `status` on `LOTS`, for each row, and only when the status is different. It inserts a row into `LOT_HISTORY` with `hist_id` from `lot_history_seq.NEXTVAL`, the lot, old and new status, `SYSDATE`, `USER` and a short note.

Then run `BEGIN fab_reports.hold_lot('L26-003', 'Particle check'); END;`, look at `LOT_HISTORY` rows with `hist_id >= 1000`, and try `hold_lot` on the same lot again.

<details>
<summary>Hint 1: the parts</summary>

`CREATE OR REPLACE TRIGGER name AFTER UPDATE OF status ON lots FOR EACH ROW WHEN (...) BEGIN ... END;` and a `/` line.
</details>

<details>
<summary>Hint 2: old and new</summary>

Inside the block write `:OLD.status` and `:NEW.status`. Inside the `WHEN (...)` clause write them without colons: `OLD.status <> NEW.status`.
</details>

<details>
<summary>Hint 3: the insert</summary>

```sql
INSERT INTO lot_history (hist_id, lot_id, old_status, new_status, changed_at, changed_by, note)
VALUES (lot_history_seq.NEXTVAL, :NEW.lot_id, ___, ___, SYSDATE, USER, 'set by trigger');
```
</details>

**Checkpoint:** `LOT_HISTORY` goes from 147 to 148 rows. The new row has `old_status` `ACTIVE`, `new_status` `HOLD`, and a `hist_id` of 1000 or more. The second `hold_lot` call fails with `ORA-20102`.

**Trap:** update only the `hold_reason` of the lot afterwards. No new row appears, because the status did not change. Without the `WHEN` clause you would get a row with identical old and new status, which is noise.

## Exercise 6: Manage the trigger and meet ORA-04091

- **6a.** Query `USER_TRIGGERS`. Disable your trigger, put `L26-007` on hold with a plain `UPDATE`, count the `LOT_HISTORY` rows, and enable the trigger again.
- **6b.** Create a `BEFORE UPDATE` row trigger on `LOTS` that runs `SELECT COUNT(*) INTO v_holds FROM lots WHERE status = 'HOLD'`. Update any lot and read the error. Then drop that trigger.

<details>
<summary>Hint 1: 6a</summary>

`ALTER TRIGGER lots_status_hist_trg DISABLE;` and later `ENABLE`. The status column is `STATUS` in `USER_TRIGGERS`.
</details>

<details>
<summary>Hint 2: 6b</summary>

The trigger needs `FOR EACH ROW` and a `DECLARE` section for `v_holds NUMBER;`. Any update will do, for example `UPDATE lots SET priority = priority WHERE lot_id = 'L26-003'`.
</details>

<details>
<summary>Hint 3: the message</summary>

The first line is `ORA-04091: table ... LOTS is mutating, trigger/function may not see it`.
</details>

**Checkpoint:** the count stays at 148 while the trigger is disabled. 6b fails with `ORA-04091`.

**Trap:** leaving the trigger disabled. A later status change then leaves no history. Check `USER_TRIGGERS` before you move on.

## Exercise 7: Clean up

Maya: "Put it all back the way it was."

Set `L26-003` and `L26-007` back to `ACTIVE` with a `NULL` hold reason, delete the history rows with `hist_id >= 1000`, commit, and drop your trigger. Check that `LOT_HISTORY` has 147 rows and you own no triggers.

<details>
<summary>Hint 1: order</summary>

Restore the lots first, then delete the history rows (the restoring update adds rows too), then `COMMIT`, then drop the trigger.
</details>

<details>
<summary>Hint 2: the statements</summary>

```sql
UPDATE lots SET status = 'ACTIVE', hold_reason = NULL WHERE lot_id IN (___, ___);
DELETE FROM lot_history WHERE hist_id >= ___;
COMMIT;
DROP TRIGGER ___;
```
</details>

**Checkpoint:** 147 history rows, 0 triggers, both lots `ACTIVE` with an empty hold reason.

**Trap:** `ROLLBACK` does not help for changes made before a `CREATE TRIGGER` or `DROP TRIGGER`, because DDL commits first. That is why this exercise repairs the data with statements.
