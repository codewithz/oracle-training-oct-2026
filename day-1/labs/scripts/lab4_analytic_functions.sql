-- =====================================================================
-- Lab 4  Analytic functions: EXERCISES
-- Connect as FAB_LAB (password Lab_2026) to your pluggable database.
-- The data comes from fab_lab_data.sql (loaded in Lab 1).
-- Write each query under its question and run it (Ctrl+Enter in SQL
-- Developer). Hints are below each question; try without them first.
-- Tables: PRODUCTS, TOOLS, LOTS, WAFERS, MEASUREMENTS (see the lab page).
-- =====================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI';


-- =====================================================================
-- PART B  Analytic functions
-- =====================================================================

-- B1. Rank the wafers of lot L26-003 by FINAL thickness: ROW_NUMBER, RANK, DENSE_RANK
--     Hint: ROW_NUMBER(), RANK(), DENSE_RANK() OVER (ORDER BY ...)




-- B2. The thickest FINAL wafer in each product (top-1 per group)
--     Hint: ROW_NUMBER() OVER (PARTITION BY product ...) in an inline view, then WHERE rn = 1




-- B3. For lots L26-003A and L26-003B: deviation of each FINAL reading from the product target and from the lot average
--     Hint: AVG(...) OVER (PARTITION BY lot_id)




-- B4. Thickness change from one step to the next for wafer L26-001-01 (LAG)
--     Hint: LAG(thickness_nm) OVER (PARTITION BY wafer_id ORDER BY meas_time)




-- B5. Running total of wafers started, by lot start date (window SUM)
--     Hint: SUM(COUNT(...)) OVER (ORDER BY ...): an analytic over an aggregate




-- B6. Moving average of defects over the last 3 readings on tool MET01 (first 8 readings)
--     Hint: AVG(...) OVER (... ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)




-- B7. Share of each product's FINAL defects (RATIO_TO_REPORT) and quartile of each lot (NTILE)
--     Hint: RATIO_TO_REPORT(...) OVER () and NTILE(4) OVER (ORDER BY ...)
