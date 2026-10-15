-- Joins assessment: 10 questions, 100 marks
-- Run as FAB_LAB, after assess_joins_data.sql.
-- Write your query under each question and run it with Ctrl+Enter.
-- Put a blank line between statements, and end each one with a semicolon.
-- The number in [brackets] is the row count a correct answer returns. Use it to check yourself.

-- Q1 (5 marks): Who works where   [17 rows]
-- Maya: List every employee with their department name. Order by department name, then
-- last name.




-- Q2 (5 marks): Nobody left behind   [19 rows]
-- Maya: Same list, but I want all 19 people. Anyone without a department shows
-- '(no department)'. Order by employee id.




-- Q3 (10 marks): Who runs each department   [7 rows]
-- Maya: Show every department and the full name of its manager. If a department has no
-- manager, show 'Vacant'.




-- Q4 (10 marks): Reporting line   [19 rows]
-- Maya: For every employee, show their full name, job title and the full name of the person
-- they report to. The person at the top shows '(top of the tree)'.




-- Q5 (10 marks): Managed from another department   [7 rows]
-- Maya: Who reports to a manager in a different department? Treat "no department" as a
-- department of its own, so someone with no department is always different from someone who
-- has one. Show both people and both department ids.




-- Q6 (10 marks): Current monthly pay   [19 rows]
-- Maya: For everyone, show current base pay, allowance (0 if none) and the monthly total.
-- People with no pay record still appear. Highest total first, no-pay people last.




-- Q7 (10 marks): Then and now   [17 rows]
-- Maya: For everyone who was being paid on 1 March 2026, show their base pay on that day,
-- their base pay now, and the difference. Biggest rise first.




-- Q8 (10 marks): Headcount and hours by department   [7 rows]
-- Maya: For each department, how many people it has and how many hours they worked in
-- total during the week of 14 September. Departments with nobody show 0 and 0.




-- Q9 (10 marks): Not seen all week   [3 rows]
-- Maya: Who was not PRESENT on a single day this week? That includes people with no
-- attendance rows at all. Show id, name and department ('(no department)' if none).




-- Q10 (20 marks): Capstone: tools with nobody on the floor   [11 rows]
-- Maya: Each department with a HOME_BAY looks after the tools in that bay. For Wednesday
-- 16 September, list every one of those tools with each Technician from the owning
-- department who was PRESENT that day. A tool with no such technician must still appear,
-- once, showing '-- nobody --'. Order by tool id.




-- Bonus (not marked): Monthly payroll by department
-- Maya: For each department (and one '(no department)' line), how many people, how many of
-- them have a current pay record, and the total current monthly pay (base + allowance).


