-- Lab 10: Report shapes
-- Run as FAB_LAB. Write your query under each question and run it with Ctrl+Enter.
-- Put a blank line between statements, and end each one with a semicolon.

-- Exercise 1: Subtotals per family and step
-- Maya: Defects per product family and step, with a subtotal for each family and a grand
-- total at the bottom. Family by family, steps in alphabetical order, the subtotal under
-- its family.




-- Exercise 2: Which blank is which?
-- Maya: Count the wafers by grade, with a total line. But the blank cells confuse people:
-- label the two wafers without a grade as 'NO GRADE YET' and the total line as 'ALL
-- WAFERS'. Put the total last.




-- Exercise 3: Totals per family, per step, and overall
-- Maya: I do not need the detail lines this time. Give me only three kinds of line: defects
-- per product family, defects per step, and one grand total. Add a column that says which
-- kind of line it is.




-- Exercise 4: A grid of lots by step
-- Maya: For the FD-SOI lots, give me one line per lot with the total defects at SPLIT,
-- ANNEAL and FINAL in three columns.




-- Exercise 5: Lists on one line
-- Maya: Part a: for each lot of product FD-SOI that has wafers, list its wafers on one
-- line. Part b: for each lot, the history of its statuses in time order on one line, like
-- ACTIVE > HOLD > ACTIVE. Show lots L26-003B and L26-008 only.




SELECT 'End of Lab 10' AS finished FROM dual;
