-- Lab 9: Running totals, LAG and LEAD
-- Run as FAB_LAB. Write your query under each question and run it with Ctrl+Enter.
-- Put a blank line between statements, and end each one with a semicolon.

-- Exercise 1: Change since the previous reading
-- Maya: For lot L26-006, show every reading of every wafer with the thickness, the previous
-- thickness of the same wafer, and the change. The first reading of a wafer has nothing to
-- compare with, and that is fine.




-- Exercise 2: Defects collected so far
-- Maya: For lot L26-009, list every reading in time order with the defects found by that
-- reading and the total number of defects found in the lot so far.




-- Exercise 3: The running total that stays at 204
-- Maya: A colleague wrote the query below for the SPLIT readings of lot L26-001. Maya says
-- the running total shows 204 on every line, which cannot be right. Find out why and fix it
-- so the total grows reading by reading.

SELECT m.wafer_id,
       m.defect_count,
       SUM(m.defect_count) OVER (ORDER BY TRUNC(m.meas_time)) AS running_total
FROM   measurements m
JOIN   wafers w ON w.wafer_id = m.wafer_id
WHERE  w.lot_id = 'L26-001'
AND    m.step = 'SPLIT'
ORDER  BY m.meas_id;

-- Your fixed version:




-- Exercise 4: Moving average of FINAL thickness
-- Maya: For the RF-300 product, take the FINAL readings in time order. Next to each reading
-- show the average of that reading and the two before it.




-- Exercise 5: How long was each hold of one lot?
-- Maya: For lot L26-001, list each time it went on hold, when that was, and how many hours
-- until it was released. Then give me the total hours on hold.




-- Exercise 6: Longest hold, and holds still open
-- Maya: Part a: Which single hold was the longest of all, which lot, when did it start, how
-- many hours? Part b: which lots are on hold right now, since when, and how many hours so
-- far (count up to 2026-10-10 12:00, the time the data was cut)?




-- Exercise 7: Lots that bounced back and forth
-- Maya: Which lots went on hold five times or more? For each, show the number of holds and
-- the average length of the holds that have ended, in hours (one decimal), longest average
-- first.




SELECT 'End of Lab 9' AS finished FROM dual;
