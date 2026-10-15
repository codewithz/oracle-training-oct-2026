-- =====================================================================
-- Lab 17: Packages and triggers.  Run as FAB_LAB.
-- You need the four Lab 16 objects (wafer_yield, thickness_status,
-- print_lot_report, hold_lot). If you skipped Lab 16, run
-- lab17_catchup.sql first.
-- Switch DBeaver to Manual Commit mode first (as in Lab 7).
-- How to run it in DBeaver:
--   1. Open the Output panel first (Ctrl+Shift+O, or SQL Editor menu >
--      Show Server Output). DBMS_OUTPUT lines appear there.
--   2. A plain SELECT, INSERT, UPDATE, ALTER or DROP: put the cursor in
--      the statement and press Ctrl+Enter.
--   3. A PL/SQL block (DECLARE or BEGIN) or a CREATE FUNCTION / PROCEDURE /
--      PACKAGE / TRIGGER: select the whole statement, from its first line
--      down to its END; line, and press Ctrl+Enter. One at a time.
--   4. Do not run the whole file with Alt+X.
-- The line holding only a slash (/) ends a PL/SQL block or a CREATE.
-- Do not leave blank lines inside your own blocks: DBeaver can cut the
-- block in two there. Use a line holding only "--" if you want space.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Exercise 1: the specification
-- Maya: "Put our four reporting routines in one package called
-- FAB_REPORTS. Start with the label on the lid."
-- Create only the SPECIFICATION with the four routines. Then call
-- fab_reports.wafer_yield('L26-003') and read the error.
-- Checkpoint: package VALID, no body, error ORA-04067.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 2: the body
-- Maya: "Now put the tools in the box."
-- Create the BODY by copying the code of your Lab 16 routines.
-- Then run: SELECT fab_reports.wafer_yield('L26-003') FROM dual;
--           BEGIN fab_reports.print_lot_report('L26-005'); END;
--           /
-- Checkpoint: yield 80, report for L26-005 with 4 wafers.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 3: a private helper and a counter
-- Maya: "How many reports did I print today? And check the lot exists
-- in one place only."
-- Add a PRIVATE procedure check_lot (raises ORA-20101 when the lot does
-- not exist), use it in hold_lot, and add a package
-- variable counting printed reports, with a public function
-- reports_printed.
-- Checkpoint: after printing L26-008 and L26-012, reports_printed = 2.
-- Calling fab_reports.check_lot from outside fails with PLS-00302.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 4: package members in a SELECT
-- Maya: "Show every lot with its yield, worst first. Then count the
-- thickness verdict for every measurement, by step."
-- 4a. lot_id, status, yield_pct, lowest yield first (NULLs first).
-- 4b. step, verdict, readings (count) using fab_reports.thickness_status
--     with the product target (join measurements, wafers, lots, products).
-- 4c. Try SELECT fab_reports.hold_lot('L26-003','x') FROM dual; and read
--     the error.
-- Checkpoint: 4a first row L26-008 with 0; 4b has 4 rows, FINAL/OK = 62.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 5: a trigger that writes LOT_HISTORY
-- Maya: "Whenever a lot's status changes, I want a history row, whoever
-- makes the change."
-- Create trigger lots_status_hist_trg (AFTER UPDATE OF status, row level,
-- only when the status really changed) that inserts into lot_history
-- using lot_history_seq.NEXTVAL. Then run
--   BEGIN fab_reports.hold_lot('L26-003', 'Particle check'); END;
--   /
-- and look at the new row. Then try hold_lot again on the same lot.
-- Checkpoint: LOT_HISTORY goes from 147 to 148 rows; the new row has
-- old_status ACTIVE and new_status HOLD.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 6: manage the trigger, meet ORA-04091
-- 6a. Query user_triggers. Disable your trigger, put L26-007 on HOLD with
--     a plain UPDATE, count LOT_HISTORY rows, enable the trigger again.
-- 6b. Create a BEFORE UPDATE row trigger on LOTS that runs
--     SELECT COUNT(*) FROM lots WHERE status = 'HOLD'. Update any lot.
--     Read the error. Drop that trigger.
-- Checkpoint: count stays 148 while disabled; the error is ORA-04091.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 7: clean up
-- Restore L26-003 and L26-007 to ACTIVE with hold_reason NULL, delete the
-- history rows with hist_id >= 1000, commit, drop your trigger.
-- Checkpoint: LOT_HISTORY has 147 rows again, no triggers left.
-- ---------------------------------------------------------------------



-- End of Lab 17
