-- =====================================================================
-- Lab 11: Trees and text
-- Run as FAB_LAB (connection fab-lab). Run statements one at a time with Ctrl+Enter.
-- Only exercise 7 creates a table, MY_NOTES_CLEAN, and it drops it at the end.
-- LOTS and LOT_HISTORY are only read. LOT_HISTORY comes from the Lab 8 add-on script.
-- =====================================================================

-- Exercise 1
-- Maya: "Show me every lot as a family tree, indented, with the generation number,
-- type and status. Children sit under their parent, sorted by lot id."
-- Checkpoint: 16 rows. L26-003B1 is on level 3.



-- Exercise 2
-- Maya: "For every lot that has a parent, show the path from the original lot
-- down to it (written like L26-003/L26-003B), the original lot, and whether the lot
-- has children of its own (1 = no children)."
-- Checkpoint: 4 rows.



-- Exercise 3
-- Maya: "A customer complained about a wafer from L26-003B1. Which lots is it
-- descended from? Show the steps up, lot, type and status."
-- Checkpoint: 3 rows. The last one is L26-003.



-- Exercise 4a
-- Maya: "The L26-003 family, without the lots on hold." Put the hold test in WHERE.
-- Checkpoint: 3 rows.



-- Exercise 4b
-- Maya: "Actually I meant: follow the family, but stop at any lot on hold,
-- and do not look below it." Put the hold test in CONNECT BY.
-- Checkpoint: 2 rows.



-- Exercise 5a
-- Maya: "Which tool is named most often in the history notes?"
-- Checkpoint: 9 tools. MET01 and SPL02 are tied at the top with 12.



-- Exercise 5b
-- Maya: "How many notes name a tool but give no measurement, ticket or other number?"
-- Tool ids and lot ids contain digits themselves, so take them out first.
-- Checkpoint: 18.



-- Exercise 6a
-- Maya: "Pull the nm readings out of the notes as real numbers. How many are there,
-- and what are the lowest, highest and average?"
-- Checkpoint: 26 readings, average 100.2.



-- Exercise 6b
-- Maya: "Which three notes have the highest readings? Show the history row, the lot,
-- the number and the new status."
-- Checkpoint: the highest is 1104, from lot L26-008.



-- Exercise 6c
-- Maya: "How many tickets of each kind (INC and FAB-OPS) appear in the notes?"
-- Checkpoint: FAB-OPS 8, INC 23.



-- Exercise 7a
-- Count the notes that have a gap of two or more spaces. Checkpoint: 16.



-- Exercise 7b
-- Maya: "Make me a cleaned copy of the notes for the weekly report: single spaces,
-- and the email address hidden as ***." Create MY_NOTES_CLEAN with hist_id, lot_id and the cleaned
-- note, then check that 147 rows were copied and no gaps or emails are left.



-- Exercise 7c
-- Clean up: drop MY_NOTES_CLEAN, then check that no MY_ tables are left.



-- Stretch
-- Write exercise 1 again as a recursive WITH with SEARCH DEPTH FIRST.



SELECT 'Lab 11 finished' AS done FROM dual;
