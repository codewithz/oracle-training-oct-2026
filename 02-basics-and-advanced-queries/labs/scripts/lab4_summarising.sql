-- Lab 4: Summarising with GROUP BY
-- Run as FAB_LAB. Write your query under each question and run it with Ctrl+Enter.
-- Put a blank line between statements, and end each one with a semicolon.

-- Exercise 1: How many lots, and how many products
-- Maya: How many lots do we have in total, and how many different products do those lots
-- use?




-- Exercise 2: Graded and ungraded wafers
-- Maya: How many wafers are there, and how many of them already have a grade?




-- Exercise 3: Defects at ANNEAL
-- Maya: Looking only at the ANNEAL step, what are the lowest and highest defect counts, the
-- average (one decimal) and the total?




-- Exercise 4: Lots per status
-- Maya: How many lots are in each status? Put the biggest group first.




-- Exercise 5: Defects per tool
-- Maya: What is the total defect count per tool? Show the tool with the most defects first.




-- Exercise 6: Lots per product and status
-- Maya: For each product_id, how many lots are in each status?




-- Exercise 7: Lots with several bad wafers
-- Maya: Which lots have at least 2 wafers that are not PRIME grade, and how many?




-- Exercise 8: Busy months
-- Maya: For each month (like 2026-08), how many lots started, and what was the average
-- priority to one decimal? Only show months with more than 7 lots.




-- Exercise 9: Fix the broken query
-- Maya: I tried to get the number of wafers per lot with the grade next to it, and Oracle
-- shouted at me. Can you fix it so it gives one line per lot and grade?




-- Stretch
-- Maya: "Which tools have an average defect count above 20 across all their measurements?
-- Show the average to one decimal and how many measurements it is based on, highest first."
-- Use `HAVING` with `AVG`. Then explain to a neighbour why the answer contains only the two
-- splitting tools, and what the numbers say about how defects change along the line.


