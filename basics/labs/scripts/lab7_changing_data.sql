-- =====================================================================
-- Lab 7: Creating tables and changing data
-- Run as FAB_LAB (connection fab-lab).
-- FIRST: switch DBeaver to Manual Commit mode (toolbar transaction button).
-- Every table you create here starts with MY_. The original FAB_LAB tables
-- (PRODUCTS, TOOLS, LOTS, WAFERS, MEASUREMENTS) are only read, never changed.
-- Run statements one at a time with Ctrl+Enter unless a step says otherwise.
-- =====================================================================

-- Exercise 1
-- Create MY_LOTS_COPY as a copy of LOTS (structure and rows), then count the rows.
-- Expected: 16.



-- Exercise 2a
-- Insert a new lot into MY_LOTS_COPY, naming the columns:
--   lot_id L26-099, product 1, type PROD, start date 2026-10-12,
--   status ACTIVE, priority 2.



-- Exercise 2b
-- SELECT the new lot to check it is there.



-- Exercise 2c
-- Maya: "Put L26-099 on hold because of a particle check."
-- UPDATE status and hold_reason, with a WHERE. Then SELECT it again.



-- Exercise 2d
-- Make everything so far permanent.



-- Exercise 3a
-- THE MISTAKE (on purpose): set priority = 1 on the whole table, no WHERE.
-- Then count the lots per priority.



-- Exercise 3b
-- Undo it. Then count lots per priority again and check L26-099 is still
-- there and on HOLD.



-- Exercise 4
-- 4a. DELETE the SHIPPED lots. Count the rows.
-- 4b. Set a SAVEPOINT called after_shipped.
-- 4c. DELETE the SCRAPPED lots. Count the rows.
-- 4d. Go back to the savepoint. Count the rows.
-- 4e. Roll back everything. Count the rows.



-- Exercise 5
-- 5a. Create MY_SHIPPED_LOTS with the same columns as LOTS but NO rows.
--     (Trick: a WHERE that is never true.)
-- 5b. Fill it with INSERT ... SELECT from LOTS where status is SHIPPED. Count. COMMIT.
-- 5c. DELETE all rows, ROLLBACK, count.
-- 5d. TRUNCATE the table, ROLLBACK, count.
-- 5e. DROP the table.



-- Exercise 6
-- Run this setup (Alt+X) to create two strict tables with named constraints.
CREATE TABLE my_products (
  product_id    NUMBER(4)     CONSTRAINT my_products_pk PRIMARY KEY,
  product_code  VARCHAR2(12)  NOT NULL CONSTRAINT my_products_code_uk UNIQUE
);

CREATE TABLE my_strict_lots (
  lot_id      VARCHAR2(12)  CONSTRAINT my_strict_lots_pk PRIMARY KEY,
  product_id  NUMBER(4)     NOT NULL CONSTRAINT my_strict_lots_fk REFERENCES my_products (product_id),
  status      VARCHAR2(8)   DEFAULT 'ACTIVE'
                            CONSTRAINT my_strict_lots_status_ck CHECK (status IN ('ACTIVE','HOLD','SHIPPED','SCRAPPED'))
);

-- 6a. Insert products (1, FD-300) and (2, RF-300), and lot S-001 for product 1. COMMIT.



-- 6b. Break each rule on purpose, one statement at a time. Note each ORA- number.
--     1. a second lot called S-001
--     2. a third product with code FD-300
--     3. a lot with status BROKEN
--     4. a lot for product 99
--     5. a lot with product_id NULL
--     6. delete product 1



-- Exercise 7
-- Insert lot S-005 for product 2, then create a table MY_TMP (x NUMBER),
-- then ROLLBACK, then list the lots. Is S-005 there?



-- Exercise 8
-- The two-tab experiment is done by hand in DBeaver. See the lab page.
-- Tab A: UPDATE my_lots_copy SET priority = 5 WHERE lot_id = 'L26-001';   (no commit)
-- Tab B: SELECT lot_id, priority FROM my_lots_copy WHERE lot_id = 'L26-001';



-- Exercise 9
-- Clean up: drop MY_TMP, MY_STRICT_LOTS, MY_PRODUCTS and MY_LOTS_COPY (children first).
-- Then list any table whose name starts with MY_ . You should get no rows.

