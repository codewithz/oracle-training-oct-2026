-- =====================================================================
-- Lab 18: Tuning a little.  Run as FAB_LAB.
-- MEASUREMENTS_BIG has 200,000 rows and only its primary key indexed.
-- This lab creates three indexes, one function and one helper table,
-- and Exercise 7 removes them. Do not skip Exercise 7.
-- Timings and costs differ on every machine. Compare the shape.
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
ALTER SESSION SET STATISTICS_LEVEL = ALL;

-- HELPER for "what really happened". Put a marker comment such as
-- /* mine1 */ after SELECT in the statement you want to inspect, run it,
-- then run this with the same marker. Use a NEW marker for every new
-- statement.
--
-- SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
--          (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /* mine1 */%'
--           ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY), NULL, 'ALLSTATS LAST'));

-- ---------------------------------------------------------------------
-- Exercise 1: statistics and a first plan
-- Maya: "Why is looking up one reading by its number instant, but
-- looking up a wafer's readings slow?"
-- 1a. How many rows and blocks does Oracle think MEASUREMENTS_BIG has,
--     and how many different values do MEAS_ID, WAFER_ID and TOOL_ID have?
-- 1b. EXPLAIN PLAN for  SELECT * FROM measurements_big WHERE meas_id = 100000
--     and for           SELECT * FROM measurements_big WHERE wafer_id = 'L26-005-02'
-- Checkpoint: 200000 rows; the first plan is INDEX UNIQUE SCAN (cost 3; 2 on some databases),
-- the second TABLE ACCESS FULL (cost 378, estimated rows 3030).
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 2: create an index and watch the buffers
-- Maya: "Can you make the wafer lookup quick?"
-- Run  SELECT /* l18a */ AVG(thickness_nm) FROM measurements_big
--      WHERE wafer_id = 'L26-005-02';  and look at its real plan.
-- Create an index on wafer_id, run the same query with a new marker
-- (l18b) and compare the Buffers column.
-- Checkpoint: about 1360 buffers before, about 33 after; the plan has
-- INDEX RANGE SCAN. Both return 3030 rows (A-Rows).
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 3: when an index does not help
-- Maya: "Same trick for the tool, please."
-- Create an index on tool_id. Look at the real plan of
--   SELECT AVG(thickness_nm) FROM measurements_big WHERE tool_id = 'MET02'
-- Then force the index with /*+ INDEX(m meas_big_tool_ix) */ (give the
-- table the alias m) and compare buffers. Compare E-Rows with A-Rows.
-- Checkpoint: Oracle chooses TABLE ACCESS FULL (1359 buffers); the forced
-- index costs about 1381. E-Rows 28571, A-Rows 9524.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 4: the function-on-the-column trap
-- Maya: "How many readings were taken on 15 September 2026?"
-- Create an index on meas_time. Count the readings with
-- TRUNC(meas_time) = DATE '2026-09-15', then with a range
-- (>= the day, < the next day). Compare the plans and the buffers.
-- Checkpoint: both return 2985. TRUNC: INDEX FAST FULL SCAN, 541 buffers.
-- Range: INDEX RANGE SCAN, 11 buffers.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 5: bind variables
-- Maya: "Does it matter if we paste the wafer id into the query?"
-- 5a. Run SELECT /* l18g */ COUNT(*) ... WHERE wafer_id = '<literal>'
--     for L26-001-01, -02 and -03. Look in V$SQL for the marker.
-- 5b. Run the same query with a bind variable :w and marker l18h, for the
--     same three wafers. Use one block with three
--       EXECUTE IMMEDIATE 'SELECT /* l18h */ ... WHERE wafer_id = :w'
--         INTO v_n USING 'L26-001-01';
--     (then -02 and -03). EXECUTE IMMEDIATE sends the text exactly as you
--     wrote it, and USING fills in :w. Look in V$SQL for l18h.
-- 5c. In a PL/SQL block, loop over the wafers of lot L26-001 and count
--     readings with a static SELECT ... INTO using the loop variable.
--     Find that statement in V$SQL (PL/SQL names the bind :B1).
-- Checkpoint: 5a three rows, 1 execution each; 5b one row, 3 executions;
-- 5c a statement with :B1.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 6: the cost of calling PL/SQL, and loops against sets
-- Maya: "I need every reading flagged DIRTY (30 or more defects) or CLEAN."
-- 6a. Create FUNCTION is_dirty (p_defects NUMBER) RETURN NUMBER (1 when
--     30 or more, else 0). In one block, time SUM(CASE ...) and
--     SUM(is_dirty(defect_count)) over MEASUREMENTS_BIG, five runs each,
--     with DBMS_UTILITY.GET_TIME (hundredths of a second).
-- 6b. Create MY_VERDICT (meas_id NUMBER(8) NOT NULL, verdict VARCHAR2(5)
--     NOT NULL). For meas_id <= 50000 fill it three ways and time each:
--     row-by-row loop with one INSERT per row; BULK COLLECT LIMIT 1000
--     with FORALL; one INSERT ... SELECT. Truncate the table before each.
-- Checkpoint: both give 61333 dirty readings in 6a, and the function
-- version is at least 5 times slower. In 6b the table ends with 34667
-- CLEAN and 15333 DIRTY, and row by row is the slowest by far.
-- ---------------------------------------------------------------------



-- ---------------------------------------------------------------------
-- Exercise 7: clean up
-- Drop MY_VERDICT, the three indexes and the function. Set
-- STATISTICS_LEVEL back to TYPICAL.
-- Checkpoint: the only index left on MEASUREMENTS_BIG is MEAS_BIG_PK.
-- ---------------------------------------------------------------------



-- End of Lab 18
