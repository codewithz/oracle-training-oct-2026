-- =====================================================================
-- Lab 13: First PL/SQL blocks
-- Run as FAB_LAB (connection fab-lab). Nothing here changes data.
-- Write your block under each question. Each answer is an anonymous
-- block: end it with END; and then a line that holds only a slash (/).
-- Do not leave blank lines inside a block.
--
-- How to run this in DBeaver:
--   1. Open the Output panel first (Ctrl+Shift+O, or SQL Editor menu >
--      Show Server Output). The PUT_LINE text appears there.
--   2. A plain SELECT: put the cursor in it and press Ctrl+Enter.
--   3. A PL/SQL block: select the whole block, from its first line
--      (DECLARE or BEGIN) down to its END;, and press Ctrl+Enter.
--      Run one block at a time.
--   4. Do not run the whole file with Alt+X.
--      The broken block in exercise 5 fails until you fix it.
-- SQL*Plus users: run SET SERVEROUTPUT ON once before the first block.
-- =====================================================================

-- Exercise 1: How many lots?
-- Maya: "How many lots does the fab have? Print one sentence."
-- Use a variable, SELECT COUNT(*) INTO ..., and DBMS_OUTPUT.PUT_LINE.
-- Checkpoint: the sentence contains 16.



-- Exercise 2: Product and target of one lot
-- Maya: "Which product is lot L26-009, and what is its target thickness?"
-- Declare v_lot with a starting value. Declare the other variables with %TYPE.
-- Checkpoint: PHO-300 and 220.



-- Exercise 3: A whole row
-- Maya: "Tell me the status, start date and hold reason of lot L26-003B."
-- Use a variable declared with lots%ROWTYPE and SELECT * INTO.
-- Checkpoint: status HOLD, start date 14-AUG-2026.



-- Exercise 4: Average thickness against target
-- Maya: "For lot L26-009, how close is the average FINAL thickness to the
-- product target, as a percentage?"
-- Two SELECT ... INTO statements, one calculation, three printed lines.
-- Checkpoint: average 219.78 nm, 99.9 percent.



-- Exercise 5: Fix the broken block
-- This block has four mistakes. Fix them one at a time and run it after each fix.
-- Checkpoint: L26-005 is HOLD and has 4 wafers
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-005';
  v_status  VARCHAR2(3);
  v_wafers  NUMBER
BEGIN
  SELECT status FROM lots WHERE lot_id = v_lot;
  SELECT COUNT(*) INTO v_wafers FROM wafers WHERE lot_id = v_lot;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' is ' || v_status || ' and has ' || v_wafers || ' wafers')
END;
/


-- Exercise 6: One block, three lots
-- Reuse a block that counts the wafers of v_lot. Run it for L26-003, L26-003B
-- and L26-999. Then change it to read the STATUS of L26-999 and read the error.
-- Checkpoint: 5, 2 and 0 wafers; then ORA-01403.



SELECT 'Lab 13 finished' AS message FROM dual;
