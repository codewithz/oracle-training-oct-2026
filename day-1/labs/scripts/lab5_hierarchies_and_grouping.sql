-- =====================================================================
-- Lab 5  Hierarchical queries and advanced grouping: EXERCISES
-- Connect as FAB_LAB (password Lab_2026) to your pluggable database.
-- The data comes from fab_lab_data.sql (loaded in Lab 1).
-- Write each query under its question and run it (Ctrl+Enter in SQL
-- Developer). Hints are below each question; try without them first.
-- Tables: PRODUCTS, TOOLS, LOTS, WAFERS, MEASUREMENTS (see the lab page).
-- =====================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI';


-- =====================================================================
-- PART C  Hierarchical queries: lot genealogy
-- =====================================================================

-- C1. The full genealogy tree (CONNECT BY, LEVEL, indentation)
--     Hint: START WITH parent_lot_id IS NULL CONNECT BY PRIOR lot_id = parent_lot_id; ORDER SIBLINGS BY




-- C2. Path, root and leaf flag for every lot that came from L26-003
--     Hint: SYS_CONNECT_BY_PATH, CONNECT_BY_ROOT, CONNECT_BY_ISLEAF




-- C3. Walk upwards: all ancestors of the rework lot L26-003B1
--     Hint: Reverse the direction: CONNECT BY lot_id = PRIOR parent_lot_id




-- C4. Wafers per family tree: total wafers under each root lot that has children
--     Hint: CONNECT_BY_ROOT in an inline view, then GROUP BY ... HAVING




-- =====================================================================
-- PART D  Advanced grouping and aggregation
-- =====================================================================

-- D1. Wafers started per product and month, with subtotals and grand total (ROLLUP)
--     Hint: GROUP BY ROLLUP (product, month)




-- D2. Label the subtotal rows with GROUPING() instead of showing NULL
--     Hint: GROUP BY CUBE, then GROUPING() and GROUPING_ID()




-- D3. Only the totals you ask for: per status and per lot type, no detail rows (GROUPING SETS)
--     Hint: GROUP BY GROUPING SETS ((status), (lot_type), ())




-- D4. Defects per step as columns for lots L26-001 to L26-009 (PIVOT); wafer grades by slot for L26-001, L26-008, L26-012 (LISTAGG)
--     Hint: PIVOT (SUM(...) FOR step IN (...)); LISTAGG(...) WITHIN GROUP (ORDER BY ...)
