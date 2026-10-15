-- Lab 8: Window functions and ranking
-- Run as FAB_LAB. Write your query under each question and run it with Ctrl+Enter.
-- Put a blank line between statements, and end each one with a semicolon.

-- Part 0: before the exercises, open day34_addon.sql and run it with Alt+X.
-- Then check the counts here. Expect 147, 200000 and 0.
SELECT 'LOT_HISTORY' AS table_name, COUNT(*) AS row_count FROM lot_history
UNION ALL SELECT 'MEASUREMENTS_BIG', COUNT(*) FROM measurements_big
UNION ALL SELECT 'ERROR_LOG', COUNT(*) FROM error_log;


-- Exercise 1: Lot average next to each reading
-- Maya: Lot L26-005 is on hold. Show each of its FINAL readings with the average FINAL
-- thickness of the lot next to it, and how far each wafer is from that average (two
-- decimals).




-- Exercise 2: Compare with the product average
-- Maya: Show every FINAL reading with its product code, the average FINAL thickness of that
-- product, and the difference. I only want the three readings that are furthest from their
-- product average, in either direction.




-- Exercise 3: Share of defects per product family
-- Maya: What percentage of all defects (all steps) comes from each product family? One line
-- per family, biggest share first, one decimal. The shares should add up to 100.




-- Exercise 4: Above-average readings, counted per product
-- Maya: How many FINAL readings are thicker than the average FINAL thickness of their own
-- product? Give me the count for each product.




-- Exercise 5: Worst wafer in each lot
-- Maya: For every lot that has readings, which wafer collected the most defects over all
-- its readings (SPLIT, ANNEAL and FINAL together)? One wafer per lot. If two wafers tie,
-- show the one with the lower wafer ID.




-- Exercise 6: Ties and quarters
-- Maya: Part a: Give me the three SPLIT readings with the most defects. Run it as FETCH
-- FIRST 3 ROWS ONLY and again with WITH TIES, and tell me the difference. Part b: split the
-- lots into four groups by total defects, worst first, and list the lots in the worst
-- group.




SELECT 'End of Lab 8' AS finished FROM dual;
