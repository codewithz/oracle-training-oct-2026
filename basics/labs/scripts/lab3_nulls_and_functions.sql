-- Lab 3: NULL and single-row functions
-- Run as FAB_LAB. Put the cursor in a statement and press Ctrl + Enter.
-- Type your answer under each question.

-- ============================================================
-- Exercise 1: Lots on hold with no reason
-- "Which lots are on hold and nobody wrote down why?" Show the lot, the status and the reason.
-- Try two versions. Part a: use hold_reason = '' (an empty string) and look at the result. Part b: write it the correct way.




-- ============================================================
-- Exercise 2: Wafers with no grade
-- "Which wafers have no grade yet?" Show the wafer and its lot.
-- Then a second question: "How many wafers are not PRIME, counting the ungraded ones too?" Count them.




-- ============================================================
-- Exercise 3: Label the ungraded
-- "For the wafers of lots L26-011 and L26-012, show each wafer and its grade, but where nobody has graded it, write UNGRADED." Sort by wafer id.




-- ============================================================
-- Exercise 4: The board with reasons
-- "Give me the lots on hold with the reason. If nobody wrote a reason, write NO REASON RECORDED." Use COALESCE this time.




-- ============================================================
-- Exercise 5: Words for lot types, and for priority
-- Two small boards.
-- - a) "Show each lot with a plain description of its type: PROD is 'normal production', SPLIT is 'split from a parent', REWORK is 'reworked from a parent'." Use a simple CASE.
-- - b) "For lots that are not shipped, show the priority as words: 1 is URGENT, 2 is SOON, anything else is WHEN READY." Use a searched CASE.




-- ============================================================
-- Exercise 6: Too thin, on target, too thick
-- "For the FD-300 wafers, tell me whether each FINAL reading is TOO THIN, ON TARGET or TOO THICK. The target is 12 nm. Anything within 0.1 nm of it is on target." FD-300 wafers are in lots L26-001, L26-003 (and its children), L26-007 (and its child) and L26-011. Show the wafer, the thickness and the verdict.




-- ============================================================
-- Exercise 7: Dates in a readable shape
-- "For the lots of the L26-007 family, show the start as day/month/year with the time, and a review date one month after the start, written as year-month-day." Show lot, start and review date.




-- ============================================================
-- Exercise 8: Building a label
-- Two small jobs.
-- - a) "I want a one-line label for every lot that is not a normal production lot, like L26-003B (SPLIT, HOLD)." Join the lot id, the type and the status with ||.
-- - b) "I typed l26-007a in lower case. Find that lot." Make the match ignore case.




-- ============================================================
-- Stretch: Stretch: how far from the target?
-- "For the FINAL readings of the L26-003B lot, how far is each from the 12 nm target? Just the size of the miss, rounded to one decimal, biggest miss first." Show the wafer, the thickness and the miss in nm.



