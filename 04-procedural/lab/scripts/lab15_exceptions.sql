-- =====================================================================
-- Lab 15: Exceptions
-- Run as FAB_LAB (connection fab-lab).
-- Every INSERT in this lab is designed to FAIL, so your data does not change.
-- A check at the end of exercise 4 shows the row counts.
-- Write your block under each question. End every block with END; and
-- then a line that holds only a slash (/). No blank lines inside a block.
--
-- How to run this in DBeaver:
--   1. Open the Output panel first (Ctrl+Shift+O, or SQL Editor menu >
--      Show Server Output). The PUT_LINE text appears there.
--   2. A plain SELECT: put the cursor in it and press Ctrl+Enter.
--   3. A PL/SQL block: select the whole block, from its first line
--      (DECLARE or BEGIN) down to its END;, and press Ctrl+Enter.
--      Run one block at a time.
--   4. Do not run the whole file with Alt+X.
--      Some blocks in this lab stop with an error on purpose.
-- SQL*Plus users: run SET SERVEROUTPUT ON once before the first block.
-- =====================================================================

-- Exercise 1: NO_DATA_FOUND
-- Maya: "What is the status of lot L26-999?" There is no such lot.
-- Write a block that reads the status with SELECT INTO and, when there is no row,
-- prints: No lot called L26-999. Then run it for L26-005.
-- Checkpoint: the message for L26-999, and "L26-005 is HOLD".



-- Exercise 2: TOO_MANY_ROWS
-- Maya: "Which wafer is in lot L26-003?" There are five.
-- SELECT wafer_id INTO a single variable and catch TOO_MANY_ROWS. In the handler,
-- list the wafers with a cursor loop instead.
-- Checkpoint: five wafer ids, L26-003-01 to L26-003-05.



-- Exercise 3: ZERO_DIVIDE and VALUE_ERROR
-- Maya: "What percentage of lot L26-999 is PRIME?"  (Divide PRIME by all wafers.)
-- Catch ZERO_DIVIDE and print n/a. Run it for L26-003 as well.
-- Then convert the text '812.5 nm' to a number and catch VALUE_ERROR.
-- Checkpoint: n/a for L26-999, 80 % for L26-003, and a message for the text.



-- Exercise 4: Constraint errors
-- (a) Try to insert a lot with the id L26-001 (it exists). Catch DUP_VAL_ON_INDEX.
-- (b) Try to insert a wafer for lot L26-999 (it does not exist). The error is ORA-02291,
--     which has no predefined name. Give it one with PRAGMA EXCEPTION_INIT.
-- Both inserts fail, so nothing is saved. Check with the query below.
-- Checkpoint: both messages, then 16 lots and 66 wafers.

SELECT (SELECT COUNT(*) FROM lots) AS lots, (SELECT COUNT(*) FROM wafers) AS wafers FROM dual;



-- Exercise 5: Your own exceptions
-- Maya: "Only ACTIVE lots can be put on hold. Check lot L26-004."
-- (a) Declare your own exception, RAISE it when the status is not ACTIVE,
--     and print a message in a handler.
-- (b) Do the same with RAISE_APPLICATION_ERROR(-20001, ...) and no handler.
-- (c) Add a WHEN OTHERS handler that prints SQLCODE and SQLERRM.
-- Checkpoint: (a) a message, (b) ORA-20001, (c) SQLCODE -20001.



-- Exercise 6: One bad lot must not stop the loop
-- Maya: "Print the status of L26-001, L26-999 and L26-005. If one lot is missing,
-- say so and carry on."
-- Put a small block with its own EXCEPTION section inside the loop.
-- Then find out why this block says nothing:
--   DECLARE v_status lots.status%TYPE;
--   BEGIN
--     SELECT status INTO v_status FROM lots WHERE lot_id = 'L26-5';
--     DBMS_OUTPUT.PUT_LINE('status is ' || v_status);
--   EXCEPTION WHEN OTHERS THEN NULL;
--   END;
--   /
-- and rewrite its handler so the problem is visible.
-- Checkpoint: three lines (the middle one says skipped); the second block reports L26-5.



SELECT 'Lab 15 finished' AS message FROM dual;
