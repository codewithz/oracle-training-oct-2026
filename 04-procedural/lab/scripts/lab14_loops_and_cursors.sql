-- =====================================================================
-- Lab 14: Loops and cursors
-- Run as FAB_LAB (connection fab-lab). Nothing here changes data.
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
-- SQL*Plus users: run SET SERVEROUTPUT ON once before the first block.
-- =====================================================================

-- Exercise 1: Decisions
-- Maya: "For lot L26-003B, say how urgent it is (priority 1 = rush, 2 = normal,
-- anything else = low) and what we should do (HOLD: find out why it is on hold;
-- ACTIVE: none, it is in production; anything else: none, the lot is finished)."
-- Use CASE for the priority wording and IF / ELSIF / ELSE for the action.
-- Checkpoint: rush, and the hold action.



-- Exercise 2: A WHILE loop
-- Maya: "A film of 12 nm doubles in thickness at each pass. How many passes until it
-- is 1500 nm or more?" Print each pass. Use WHILE.
-- Checkpoint: the loop body runs 7 times and the film ends at 1536 nm.



-- Exercise 3: A cursor FOR loop
-- Maya: "List every lot with its status and its wafer count, and the total number
-- of wafers at the end." Include lots with no wafers (LEFT JOIN).
-- Checkpoint: 16 lines and a total of 66.



-- Exercise 4: An explicit cursor
-- Maya: "Number the lots that are on HOLD or SCRAPPED: 1., 2., ..."
-- Use OPEN, FETCH, EXIT WHEN c%NOTFOUND, c%ROWCOUNT and CLOSE.
-- Checkpoint: 3 lots; the last line says Rows fetched: 3.



-- Exercise 5: A cursor with parameters
-- Maya: "How many PRIME wafers and how many TEST wafers does L26-003 have?
-- And how many PRIME wafers does L26-012 have?" One cursor, parameters p_lot and
-- p_grade, used three times.
-- Checkpoint: 4, 1 and 2.



-- Exercise 6: A loop that decides
-- Maya: "For lot L26-005, look at the ANNEAL readings. Class each one as
-- LOW (below 90 percent of the product target), HIGH (above 110 percent) or OK, and
-- count each class."
-- Checkpoint: LOW 0, OK 2, HIGH 2.



-- Exercise 7: Do you need the loop?
-- Write exercise 6 again as one SELECT with CASE and GROUP BY.
-- Checkpoint: the same two classes with the same counts.



SELECT 'Lab 14 finished' AS message FROM dual;
