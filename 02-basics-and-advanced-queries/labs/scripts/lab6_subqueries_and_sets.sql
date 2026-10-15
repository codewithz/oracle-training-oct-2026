-- =====================================================================
-- Lab 6: Subqueries and set operators
-- Run as FAB_LAB (connection fab-lab). Every exercise is a SELECT.
-- Write your query under each question, select it, and press Ctrl+Enter.
-- =====================================================================

-- Exercise 1a
-- Maya: "What is the average number of defects per measurement?"
-- (Round it to 2 decimals.)



-- Exercise 1b
-- Maya: "Show me the ten worst measurements that are above that average.
--        Highest defect_count first, then meas_id."
-- Use a subquery. Do not type the average into the query.
-- Show: meas_id, wafer_id, step, defect_count



-- Exercise 2
-- Maya: "Which lots belong to products with a target thickness above 100 nm?"
-- Use IN with a subquery. Show: lot_id, product_id, status



-- Exercise 3a (discovery)
-- Maya: "Which lots are not the parent of any other lot?"
-- Use lot_id NOT IN (SELECT parent_lot_id FROM lots). What do you get?



-- Exercise 3b
-- Why? Count the rows in lots and count how many have a parent_lot_id.
-- COUNT(*) counts rows. COUNT(column) skips NULLs.



-- Exercise 3c
-- Fix 1: keep NOT IN, but remove the NULLs from the list.



-- Exercise 3d
-- Fix 2: use NOT EXISTS (lot l, with an inner lot "child").



-- Exercise 4a
-- Maya: "Which lots have never been measured?"
-- Use NOT EXISTS. Wafers connect a lot to its measurements.



-- Exercise 4b
-- Maya: "Which products have no lots?" Use NOT EXISTS.



-- Exercise 5
-- Maya: "Which tools never took a measurement?"
-- Use MINUS: all tool_ids from tools, minus those in measurements.



-- Exercise 6
-- Maya: "Show me the eight measurements whose defect_count is above the
--        average of the SAME tool." Highest defect_count first, then meas_id.
-- This is a correlated subquery. Show: meas_id, tool_id, defect_count



-- Exercise 7
-- Maya: "Which lots have more wafers than the average lot?"
-- Use WITH to name a "wafers per lot" list, then compare it with its own average.
-- Show: lot_id, wafer_count



-- Exercise 8a
-- Maya: "Give me one list of lots that have a SCRAP wafer or are on HOLD."
-- UNION. Each lot should appear once.



-- Exercise 8b
-- Same two lists, but with UNION ALL. Which lot appears more than once, and why?



-- Exercise 8c
-- Maya: "Which lots have a SCRAP wafer AND have status SCRAPPED?"
-- INTERSECT.



-- Stretch
-- Answer 4b again without a subquery: LEFT JOIN products to lots and keep
-- the rows where there is no lot.

