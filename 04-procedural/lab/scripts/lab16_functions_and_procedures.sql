-- =====================================================================
-- Lab 16: Functions and procedures
-- Run as FAB_LAB (connection fab-lab).
-- You create four stored objects here and KEEP them. Lab 17 builds a
-- package on them, so use exactly these names:
--   FUNCTION  wafer_yield(p_lot_id VARCHAR2) RETURN NUMBER
--   FUNCTION  thickness_status(p_thickness NUMBER, p_target NUMBER) RETURN VARCHAR2
--   PROCEDURE print_lot_report(p_lot_id VARCHAR2)
--   PROCEDURE hold_lot(p_lot_id VARCHAR2, p_reason VARCHAR2)
-- hold_lot changes LOTS. Switch DBeaver to Manual Commit mode first, and finish
-- with ROLLBACK (exercise 5). Switch back to Auto at the end of the lab.
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

-- Exercise 1: FUNCTION wafer_yield
-- Maya: "What percentage of a lot's graded wafers are PRIME? One decimal.
-- If the lot has no graded wafer, give me NULL."
-- Parameter p_lot_id VARCHAR2 (no length). Return NUMBER.
-- Test: SELECT wafer_yield('L26-003'), wafer_yield('L26-012'), wafer_yield('L26-008'),
--              wafer_yield('L26-999') FROM dual;
-- Checkpoint: 80, 100, 0 and an empty value.



-- Exercise 2: Use the function in a query
-- Maya: "Show me the lots with a yield below 90 percent, lowest first."
-- Checkpoint: 10 lots; L26-008 first with 0, then nine lots at 80.



-- Exercise 3: FUNCTION thickness_status
-- Maya: "Give me a word for a reading: LOW below 90 percent of the target,
-- HIGH above 110 percent, otherwise OK."
-- Parameters p_thickness NUMBER, p_target NUMBER. Return VARCHAR2. Mark it DETERMINISTIC.
-- If either input is NULL, return NULL.
-- Then count the readings per step and status, joining MEASUREMENTS, WAFERS, LOTS and PRODUCTS.
-- Checkpoint: thickness_status(100,100) = OK, (89.9,100) = LOW, (110.1,100) = HIGH;
--             FINAL has 62 readings, all OK; SPLIT has 62, all HIGH.



-- Exercise 4: PROCEDURE print_lot_report
-- Maya: "Print a short report for a lot: a header with the product and target,
-- one line per wafer with its grade, its FINAL thickness and the status word,
-- and a last line with the wafer count and the yield."
-- Use a cursor loop and the two functions. If the lot does not exist, print
-- "Lot ... does not exist".
-- Lines that start with spaces lose them in SQL*Plus, so start wafer lines with "- ".
-- Test: BEGIN print_lot_report('L26-005'); END;
-- Checkpoint: 4 wafer lines, all OK, "Wafers: 4   Yield: 100 %".



-- Exercise 5: PROCEDURE hold_lot
-- Maya: "Put a lot on hold and write down why."
-- Set LOTS.status to 'HOLD' and LOTS.hold_reason to p_reason. Raise a user-defined
-- error (RAISE_APPLICATION_ERROR) when the lot does not exist (-20101) or is already
-- on hold (-20102). Do not COMMIT inside the procedure.
-- Test, then undo:
--   BEGIN hold_lot('L26-010', 'Particle check'); END;
--   BEGIN hold_lot('L26-010', 'Again'); END;
--   BEGIN hold_lot('L26-999', 'Nothing'); END;
--   ROLLBACK;
-- Checkpoint: status HOLD after the first call, ORA-20102, ORA-20101, then ACTIVE again.



-- Exercise 6: What is stored, and a function that does not compile
-- (a) List your functions and procedures with their status (USER_OBJECTS).
-- (b) Count the lines of source of each (USER_SOURCE).
-- (c) Create a function double_it(p_x NUMBER) that is missing a semicolon, read the error in
--     USER_ERRORS, fix it, and drop it again.
-- Checkpoint: four objects, all VALID. DOUBLE_IT is INVALID, then VALID after the fix.



SELECT 'Lab 16 finished' AS message FROM dual;
