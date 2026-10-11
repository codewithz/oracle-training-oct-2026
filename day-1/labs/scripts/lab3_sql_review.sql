-- =====================================================================
-- Lab 3  SQL review: joins, subqueries, set operators, transactions: EXERCISES
-- Connect as FAB_LAB (password Lab_2026) to your pluggable database.
-- The data comes from fab_lab_data.sql (loaded in Lab 1).
-- Write each query under its question and run it (Ctrl+Enter in SQL
-- Developer). Hints are below each question; try without them first.
-- Tables: PRODUCTS, TOOLS, LOTS, WAFERS, MEASUREMENTS (see the lab page).
-- =====================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI';


-- =====================================================================
-- PART A  SQL review: joins, subqueries, set operators, DML
-- =====================================================================

-- A1. Lots with their product code and family (inner join)
--     Hint: JOIN products ON product_id




-- A2. Every product with its number of lots, including products with none (outer join)
--     Hint: LEFT JOIN, and COUNT a column from the right-hand table, not COUNT(*)




-- A3. Wafers in lot L26-003 whose FINAL thickness is above the lot's average FINAL thickness (correlated subquery)
--     Hint: Correlated subquery: the inner query refers to the outer wafer's lot




-- A4. Tools that have never recorded a measurement (MINUS)
--     Hint: MINUS




-- A5. Lots that have wafers but no measurements yet (NOT EXISTS)
--     Hint: EXISTS and NOT EXISTS




-- A6. Lots on HOLD without a hold reason: why does '' not show up with = ''?
--     Hint: Compare = '' with IS NULL. What does Oracle store for an empty string?




-- A7. DML in a transaction: put a lot on hold, check, then undo it
--     Hint: UPDATE, SAVEPOINT, DELETE, ROLLBACK TO SAVEPOINT, ROLLBACK
