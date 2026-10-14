-- =====================================================================
-- Lab 12: What your SELECT sees
-- Run as FAB_LAB (connection fab-lab).
-- You need TWO SQL editors on the fab-lab connection, both in Manual Commit mode,
-- both with their own connection (tick "Open separate connection for each editor").
-- Call them tab A and tab B. The exercises say which tab runs what.
-- Run statements one at a time with Ctrl+Enter.
-- The only table you change is your own MY_LOTS_COPY. LOTS is only read.
-- The last exercise drops MY_LOTS_COPY.
-- =====================================================================

-- Exercise 1 (tab A)
-- Make MY_LOTS_COPY as a copy of LOTS and count the rows. Checkpoint: 16.
-- Then run this in tab A and in tab B. The two numbers must differ:
--   SELECT SYS_CONTEXT('USERENV', 'SID') AS my_session FROM dual;



-- Exercise 2
-- Tab B: set priority = 9 for lot L26-001. Do not commit.
-- Tab A: select lot_id and priority for L26-001. What do you see? Did the query wait?
-- Tab B: commit.
-- Tab A: run the same select again.



-- Exercise 3
-- Tab A: start a read-only transaction, then count the lots and add up their priority.
-- Tab B: add 1 to the priority of every lot with status ACTIVE. Commit.
-- Tab A: run the same count and sum again. Then commit, and run it once more.
-- Checkpoint: 16 lots. The sum is 38 twice, then 46.



-- Exercise 4 (one tab)
-- Maya: "Lot L26-002 is at priority 2. Someone changes it twice. Show me what it was in between."
-- 4a. Set priority = 7 for L26-002. Commit. Wait about ten seconds.
-- 4b. Note the time:  SELECT TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') FROM dual;
--     Write it down. Wait about ten seconds more.
-- 4c. Set priority = 8 for L26-002. Commit.
-- 4d. Show the priority now, and the priority at the time you noted.
-- 4e. List every version of the row.



-- Exercise 5 (one tab)
-- Maya: "Somebody deleted the shipped lots by mistake. Put them back."
-- 5a. Note the time (as in 4b). Wait about ten seconds.
-- 5b. Delete the lots with status SHIPPED from MY_LOTS_COPY. Commit. Count the rows. Checkpoint: 11.
-- 5c. Put the lots back from the earlier time. Commit. Count the rows. Checkpoint: 16.



-- Exercise 6
-- Tab B: lock L26-001 with SELECT ... FOR UPDATE. Do not commit.
-- Tab A: (a) plain SELECT of L26-001   (b) FOR UPDATE NOWAIT   (c) FOR UPDATE WAIT 5
--        (d) FOR UPDATE SKIP LOCKED over L26-001, L26-002, L26-003
-- Tab B: rollback.  Tab A: run (b) again.



-- Exercise 7
-- Roll back both tabs. Drop MY_LOTS_COPY. Check that no MY_ tables are left
-- and that LOTS still has 16 rows. Switch both tabs back to Auto-Commit.



SELECT 'Lab 12 finished' AS done FROM dual;
