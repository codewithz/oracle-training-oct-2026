-- Lab 2: Your first queries
-- Run as FAB_LAB. Put the cursor in a statement and press Ctrl + Enter.
-- Type your answer under each question.

-- ============================================================
-- Exercise 1: Which tools are in bay B1?
-- "Which tools are in bay B1? Show me the tool id and the type, sorted by tool id."




-- ============================================================
-- Exercise 2: What kinds of tool do we have?
-- "What different types of tool do we have? Each type once, in alphabetical order."




-- ============================================================
-- Exercise 3: Two products at once
-- "Show me the lots of the RF-300 and PWR-200 products. Those are product ids 2 and 3. I want the lot, the product id and the status, in lot order."




-- ============================================================
-- Exercise 4: The worst readings
-- "Which FINAL measurements had between 15 and 20 defects? Show the measurement id, the wafer and the defect count, with the worst first. If two are equal, sort them by wafer."




-- ============================================================
-- Exercise 5: The LIKE trap
-- Three small questions in a row.
-- - a) "Show me lot L26-003 and everything that came out of it." Show the lot, its type and its parent.
-- - b) "Sorry, I only wanted the lot L26-003 itself." Write the query again.
-- - c) "Now all the original lots numbered 001 to 009, nothing with a letter after the number." Show the lot and its type.




-- ============================================================
-- Exercise 6: AND and OR with brackets
-- "Show me the lots that are ACTIVE or on HOLD, and that are urgent. Urgent means priority 1." Show the lot, status and priority.
-- Write it two ways. First without brackets, and count the rows. Then add brackets so it says what Maya means, and count again.




-- ============================================================
-- Exercise 7: Lots started in August
-- "Which lots started in August 2026? Show the lot and the start date, oldest first."




-- ============================================================
-- Exercise 8: The latest measurements
-- "What are the five most recent measurements? Show the measurement id, the wafer, the tool and the time, newest first."




-- ============================================================
-- Stretch: Stretch: a tidy board
-- "Give me a board of the three most urgent lots that are not yet shipped. Most urgent first, and among equals the newest start first. Name the columns Lot, Status and Urgency."



