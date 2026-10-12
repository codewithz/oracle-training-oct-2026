-- Lab 5: Joins
-- Run as FAB_LAB. Write your query under each question and run it with Ctrl+Enter.
-- Put a blank line between statements, and end each one with a semicolon.

-- Exercise 1: Active lots with their product
-- Maya: List the active lots with their product code and family, in lot order.




-- Exercise 2: Scrap wafers and their product
-- Maya: Which wafers have grade SCRAP? For each, show the wafer, its lot and the product
-- code.




-- Exercise 3: Which tool measured which wafer
-- Maya: For the wafers of lot L26-003B, show every measurement with the step, the tool, the
-- tool type and the bay. Order by wafer and time.




-- Exercise 4: Reading against target
-- Maya: For lot L26-006, show each FINAL reading next to the product target, and how far
-- apart they are (thickness minus target, two decimals).




-- Exercise 5: Products with no lots, tools never used
-- Maya: Which products have no lots at all? And which tools have never taken a measurement?
-- Two queries.




-- Exercise 6: Lots with wafers but no readings
-- Maya: Which lots have wafers, but none of those wafers has been measured yet? Show the lot
-- and how many wafers are waiting.




-- Exercise 7: Lots per product, with zeros
-- Maya: How many lots does each product have? I want to see products with none, showing 0.




-- Exercise 8: Children of a lot on hold
-- Maya: Which split or reworked lots came from a parent lot that is on HOLD? Show the child,
-- its type, the parent and the parent's hold reason.




-- Exercise 9: Capstone: readings far from target
-- Maya: Which lots had a FINAL reading more than 0.3 nm away from their product target, and
-- on which tool?




-- Stretch
-- Maya: "For the capstone, per tool, how many FINAL readings were more than 0.3 nm from the
-- target, out of how many FINAL readings the tool took?" Hint: the second number needs every
-- FINAL reading, so put a `CASE` expression inside `COUNT`, or join twice. A simple way is
-- `SUM(CASE WHEN ABS(m.thickness_nm - p.target_thk_nm) > 0.3 THEN 1 ELSE 0 END)`. Which tool
-- has the highest share?


