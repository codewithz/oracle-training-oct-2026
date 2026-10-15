# Lab 14 solutions: Loops and cursors

Try each exercise yourself first. Your block may differ from these and still be right: compare the output, not the spelling. The runnable file is [`lab14_solutions.sql`](scripts/lab14_solutions.sql).

Each exercise has the same four parts: the problem in plain words, the block, how the block runs (taken apart in the order Oracle runs it: `DECLARE` first, then each statement between `BEGIN` and `END` from top to bottom, with a few real passes of each loop), and the output with what to notice.

All outputs and the in-between values in the breakdowns came from running the blocks, and copies of them with extra `PUT_LINE` lines, on the lab data (Oracle 21c XE; 19c gives the same results). The outputs are shown as SQL*Plus prints them. In DBeaver the printed lines appear in the Output panel, and the status messages look a little different.

To run a block in DBeaver, open the Output panel (`Ctrl + Shift + O`), select the whole block from `DECLARE` (or `BEGIN`) down to `END;`, and press `Ctrl + Enter`. Exercise 7 is a plain `SELECT`: put the cursor in it and press `Ctrl + Enter`.

Two ideas carry this whole lab:

- **A loop is one piece of code that runs again and again.** What changes between passes is the values of the variables. To follow a loop, write down the variables at the end of each pass.
- **A cursor walks through a query result one row at a time.** A cursor `FOR` loop opens, fetches and closes by itself. An explicit cursor makes you do each step, and tells you about it with `%FOUND`, `%NOTFOUND` and `%ROWCOUNT`.

## Exercise 1: Decisions

**Maya asks:** "For lot L26-003B, say how urgent it is and what we should do."

### The problem in plain words

One row of `LOTS`, the row of L26-003B, gives two values: the priority and the status. The priority becomes a word (1 is rush, 2 is normal, anything else is low). The status decides the action: HOLD means find out why, ACTIVE means none because it is in production, anything else means none because it is finished. The answer is two printed lines.

### The block

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-003B';
  v_prio    lots.priority%TYPE;
  v_status  lots.status%TYPE;
  v_text    VARCHAR2(30);
BEGIN
  SELECT priority, status INTO v_prio, v_status FROM lots WHERE lot_id = v_lot;
  v_text := CASE v_prio WHEN 1 THEN 'rush' WHEN 2 THEN 'normal' ELSE 'low' END;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' priority ' || v_prio || ' = ' || v_text);
  IF v_status = 'HOLD' THEN
    DBMS_OUTPUT.PUT_LINE('Action: find out why it is on hold');
  ELSIF v_status = 'ACTIVE' THEN
    DBMS_OUTPUT.PUT_LINE('Action: none, it is in production');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Action: none, the lot is finished');
  END IF;
END;
/
```

### How the block runs

**Step 1. DECLARE.** `v_lot` = `'L26-003B'`. `v_prio`, `v_status` and `v_text` are `NULL`.

**Step 2. SELECT INTO.** The row of L26-003B has priority 1 and status HOLD, so `v_prio` = 1 and `v_status` = `'HOLD'`.

**Step 3. The CASE expression.** `CASE v_prio` compares 1 with each `WHEN` in turn. `WHEN 1` matches, so the whole `CASE` gives `'rush'`, and that value goes into `v_text`. The other branches are not looked at.

**Step 4. First PUT_LINE.** Prints `L26-003B priority 1 = rush`.

**Step 5. The IF.** Oracle tests the conditions from the top and runs the first branch that is true. `v_status = 'HOLD'` is `'HOLD' = 'HOLD'`, true, so it prints the hold action. The `ELSIF` and `ELSE` branches are skipped.

### Output

```text
L26-003B priority 1 = rush
Action: find out why it is on hold

PL/SQL procedure successfully completed.
```

### What to notice

The `CASE` is an expression: it produces a value that goes into `v_text`. The `IF` is a statement: it runs different code. Change `v_lot` to `L26-003` and the action line changes.

## Exercise 2: A WHILE loop

**Maya asks:** "A film of 12 nm doubles in thickness at each pass. How many passes until it is 1500 nm or more?"

### The problem in plain words

No table is involved; this is pure arithmetic. The film starts at 12 nm and doubles each pass. One printed line per pass shows the thickness at the start of that pass, and a last line gives the final thickness and the number of passes.

### The block

```sql
DECLARE
  v_thk    NUMBER := 12;
  v_passes PLS_INTEGER := 0;
BEGIN
  WHILE v_thk < 1500 LOOP
    v_passes := v_passes + 1;
    DBMS_OUTPUT.PUT_LINE('pass ' || v_passes || ': ' || v_thk || ' nm');
    v_thk := v_thk * 2;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Stopped at ' || v_thk || ' nm after ' || v_passes || ' passes');
END;
/
```

### How the block runs

**Step 1. DECLARE.** `v_thk` = 12, `v_passes` = 0.

**Step 2. The WHILE loop.** Before every pass Oracle tests `v_thk < 1500`. If it is true, the three statements inside run once: add 1 to `v_passes`, print, double `v_thk`. Then the test comes again.

- Test: 12 < 1500, true. Pass 1: `v_passes` = 1, prints `pass 1: 12 nm`, `v_thk` = 24.
- Test: 24 < 1500, true. Pass 2: `v_passes` = 2, prints `pass 2: 24 nm`, `v_thk` = 48.
- Test: 48 < 1500, true. Pass 3: `v_passes` = 3, prints `pass 3: 48 nm`, `v_thk` = 96.
- Passes 4, 5 and 6 go the same way: `v_thk` becomes 192, 384, 768.
- Test: 768 < 1500, true. Pass 7: `v_passes` = 7, prints `pass 7: 768 nm`, `v_thk` = 1536.
- Test: 1536 < 1500, false. The loop ends. The test ran 8 times; the body ran 7 times.

**Step 3. Last PUT_LINE.** After `END LOOP`, `v_thk` = 1536 and `v_passes` = 7.

### Output

```text
pass 1: 12 nm
pass 2: 24 nm
pass 3: 48 nm
pass 4: 96 nm
pass 5: 192 nm
pass 6: 384 nm
pass 7: 768 nm
Stopped at 1536 nm after 7 passes

PL/SQL procedure successfully completed.
```

### What to notice

The printed value is the thickness at the start of each pass. The check happens before each pass, so the film of 1536 nm never gets a pass of its own. The answer is 7.

## Exercise 3: A cursor FOR loop

**Maya asks:** "List every lot with its status and its wafer count, and the total number of wafers at the end."

### The problem in plain words

`LOTS` joined to `WAFERS`, grouped by lot, gives one row per lot with the number of its wafers. A `LEFT JOIN` keeps a lot even if it has no wafers. Each row of that query becomes one printed line. A running total adds up the counts, and the last line prints it.

### The block

```sql
DECLARE
  v_total PLS_INTEGER := 0;
BEGIN
  FOR r IN (SELECT l.lot_id, l.status, COUNT(w.wafer_id) AS wafers
            FROM   lots l LEFT JOIN wafers w ON w.lot_id = l.lot_id
            GROUP  BY l.lot_id, l.status
            ORDER  BY l.lot_id) LOOP
    DBMS_OUTPUT.PUT_LINE(RPAD(r.lot_id, 11) || RPAD(r.status, 10) || r.wafers || ' wafers');
    v_total := v_total + r.wafers;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Total wafers: ' || v_total);
END;
/
```

### How the block runs

**Step 1. DECLARE.** `v_total` = 0. The loop variable `r` is not declared here; the `FOR` loop creates it.

**Step 2. The FOR loop opens the query.** Oracle runs the `SELECT` and gets 16 rows, one per lot, sorted by lot id. `r` is a record with three fields: `r.lot_id`, `r.status` and `r.wafers` (the alias of `COUNT(w.wafer_id)`).

**Step 3. One pass per row.** Each pass prints one line and adds the count to `v_total`. `RPAD` pads the text with spaces to a fixed width, so the columns line up.

- Pass 1: `r` = (L26-001, SHIPPED, 5). Prints the line, `v_total` = 0 + 5 = 5.
- Pass 2: `r` = (L26-002, SHIPPED, 5). `v_total` = 10.
- Pass 3: `r` = (L26-003, ACTIVE, 5). `v_total` = 15.
- Pass 4: `r` = (L26-003A, SHIPPED, 3). `v_total` = 18.
- Pass 5: `r` = (L26-003B, HOLD, 2). `v_total` = 20.
- ...
- Pass 16: `r` = (L26-012, ACTIVE, 4). `v_total` = 62 + 4 = 66.

After row 16 there is no next row, so the loop closes the query and ends.

**Step 4. Last PUT_LINE.** Prints `Total wafers: 66`.

### Output

```text
L26-001    SHIPPED   5 wafers
L26-002    SHIPPED   5 wafers
L26-003    ACTIVE    5 wafers
L26-003A   SHIPPED   3 wafers
L26-003B   HOLD      2 wafers
L26-003B1  ACTIVE    2 wafers
L26-004    SHIPPED   5 wafers
L26-005    HOLD      4 wafers
L26-006    SHIPPED   5 wafers
L26-007    ACTIVE    5 wafers
L26-007A   ACTIVE    2 wafers
L26-008    SCRAPPED  4 wafers
L26-009    ACTIVE    5 wafers
L26-010    ACTIVE    5 wafers
L26-011    ACTIVE    5 wafers
L26-012    ACTIVE    4 wafers
Total wafers: 66

PL/SQL procedure successfully completed.
```

### What to notice

The loop variable `r` was never declared. The total, 66, matches `SELECT COUNT(*) FROM wafers` from the basics. Here the total is a one-line `SUM` away in plain SQL, so this exercise shows the tool and not the best way to get a total.

## Exercise 4: An explicit cursor

**Maya asks:** "Number the lots that are on HOLD or SCRAPPED."

### The problem in plain words

From `LOTS`, only the lots whose status is HOLD or SCRAPPED, sorted by lot id. Each one is printed on its own line with a number in front (1., 2., ...), and a last line says how many rows were fetched. This time we open, fetch and close the cursor ourselves.

### The block

```sql
DECLARE
  CURSOR c_problem IS
    SELECT lot_id, status
    FROM   lots
    WHERE  status IN ('HOLD', 'SCRAPPED')
    ORDER  BY lot_id;
  v_lot     lots.lot_id%TYPE;
  v_status  lots.status%TYPE;
BEGIN
  OPEN c_problem;
  LOOP
    FETCH c_problem INTO v_lot, v_status;
    EXIT WHEN c_problem%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(c_problem%ROWCOUNT || '. ' || v_lot || ' (' || v_status || ')');
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Rows fetched: ' || c_problem%ROWCOUNT);
  CLOSE c_problem;
END;
/
```

### How the block runs

**Step 1. DECLARE.** `CURSOR c_problem IS ...` gives the query a name. Nothing runs yet. `v_lot` and `v_status` are `NULL`.

**Step 2. OPEN c_problem.** Now the query runs. Its result has three rows: L26-003B (HOLD), L26-005 (HOLD), L26-008 (SCRAPPED). No row has been fetched yet, so `c_problem%ROWCOUNT` is 0.

**Step 3. The LOOP.** A basic `LOOP` has no test of its own; the `EXIT WHEN` inside decides when it stops. Each pass fetches one row into the two variables, then checks `%NOTFOUND`:

- Pass 1: `FETCH` gives `v_lot` = `'L26-003B'`, `v_status` = `'HOLD'`. `%NOTFOUND` is false, `%ROWCOUNT` is 1. Prints `1. L26-003B (HOLD)`.
- Pass 2: `v_lot` = `'L26-005'`, `v_status` = `'HOLD'`. `%ROWCOUNT` is 2. Prints `2. L26-005 (HOLD)`.
- Pass 3: `v_lot` = `'L26-008'`, `v_status` = `'SCRAPPED'`. `%ROWCOUNT` is 3. Prints `3. L26-008 (SCRAPPED)`.
- Pass 4: `FETCH` finds no more rows. `%NOTFOUND` becomes true and `%ROWCOUNT` stays 3. The variables keep their old values, `'L26-008'` and `'SCRAPPED'`. `EXIT WHEN` is true, so the loop ends before the `PUT_LINE`.

**Step 4. After the loop.** The cursor is still open, so `%ROWCOUNT` can be read: 3.

**Step 5. CLOSE c_problem.** Frees the cursor.

### Output

```text
1. L26-003B (HOLD)
2. L26-005 (HOLD)
3. L26-008 (SCRAPPED)
Rows fetched: 3

PL/SQL procedure successfully completed.
```

### What to notice

The fourth `FETCH` finds nothing, sets `%NOTFOUND` and ends the loop, and `%ROWCOUNT` stays at 3. If you moved `EXIT WHEN` below the `PUT_LINE`, the last lot would print twice, because the variables keep their old values when a fetch finds no row.

## Exercise 5: A cursor with parameters

**Maya asks:** "How many PRIME wafers and how many TEST wafers does L26-003 have? And how many PRIME wafers does L26-012 have?"

### The problem in plain words

All three questions are the same query on `WAFERS` with different values: the wafers of one lot with one grade. One cursor with two parameters, `p_lot` and `p_grade`, serves all three. For L26-003 each matching wafer is printed and then counted; for L26-012 only the count is printed.

These are the wafers involved:

```text
WAFER_ID            SLOT_NO GRADE
---------------- ---------- ------
L26-003-01                1 PRIME
L26-003-02                2 PRIME
L26-003-03                3 PRIME
L26-003-04                4 PRIME
L26-003-05                5 TEST
L26-012-01                1 PRIME
L26-012-02                2 PRIME
L26-012-03                3
L26-012-04                4
```

### The block

```sql
DECLARE
  CURSOR c_wafers (p_lot VARCHAR2, p_grade VARCHAR2) IS
    SELECT wafer_id, slot_no
    FROM   wafers
    WHERE  lot_id = p_lot AND grade = p_grade
    ORDER  BY slot_no;
  v_n PLS_INTEGER;
BEGIN
  v_n := 0;
  FOR w IN c_wafers('L26-003', 'PRIME') LOOP
    v_n := v_n + 1;
    DBMS_OUTPUT.PUT_LINE('L26-003 PRIME: ' || w.wafer_id);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('count: ' || v_n);
  --
  v_n := 0;
  FOR w IN c_wafers('L26-003', 'TEST') LOOP
    v_n := v_n + 1;
    DBMS_OUTPUT.PUT_LINE('L26-003 TEST:  ' || w.wafer_id);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('count: ' || v_n);
  --
  v_n := 0;
  FOR w IN c_wafers('L26-012', 'PRIME') LOOP
    v_n := v_n + 1;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('L26-012 PRIME count: ' || v_n);
END;
/
```

The `--` lines only give some space. A blank line inside a block can make DBeaver cut the block in two, so the scripts use a comment line instead.

### How the block runs

**Step 1. DECLARE.** The cursor `c_wafers` is defined with two parameters. Inside its query, `p_lot` and `p_grade` stand for whatever values are passed in later. `v_n` is `NULL`.

**Step 2. First loop, `c_wafers('L26-003', 'PRIME')`.** `v_n := 0` first. Then the cursor opens with `p_lot` = `'L26-003'` and `p_grade` = `'PRIME'`, and the query returns four wafers in slot order.

- Pass 1: `w.wafer_id` = `'L26-003-01'`, `v_n` = 1.
- Pass 2: `w.wafer_id` = `'L26-003-02'`, `v_n` = 2.
- Pass 3: `'L26-003-03'`, `v_n` = 3.
- Pass 4: `'L26-003-04'`, `v_n` = 4.

The loop ends and closes the cursor. Prints `count: 4`.

**Step 3. Second loop, `c_wafers('L26-003', 'TEST')`.** `v_n` is set back to 0. The same cursor opens again with `p_grade` = `'TEST'` and returns one wafer. Pass 1: `w.wafer_id` = `'L26-003-05'`, `v_n` = 1. Prints `count: 1`.

**Step 4. Third loop, `c_wafers('L26-012', 'PRIME')`.** `v_n` back to 0. L26-012 has four wafers, but only slots 1 and 2 have a grade, and both are PRIME. Slots 3 and 4 have no grade (`NULL`), and `NULL = 'PRIME'` is not true, so they are not returned. Two passes, `v_n` = 2. This loop prints nothing inside; the line after it prints `L26-012 PRIME count: 2`.

### Output

```text
L26-003 PRIME: L26-003-01
L26-003 PRIME: L26-003-02
L26-003 PRIME: L26-003-03
L26-003 PRIME: L26-003-04
count: 4
L26-003 TEST:  L26-003-05
count: 1
L26-012 PRIME count: 2

PL/SQL procedure successfully completed.
```

### What to notice

One definition, three uses. Lot `L26-012` has four wafers but only two with a grade, and both graded wafers are PRIME, so the answer is 2.

## Exercise 6: A loop that decides

**Maya asks:** "For lot L26-005, class each ANNEAL reading as LOW, HIGH or OK, and count each class."

### The problem in plain words

The target comes from `PRODUCTS`, through the lot's `product_id` in `LOTS`. The readings come from `MEASUREMENTS` joined to `WAFERS`, only lot L26-005 and only step ANNEAL. Each reading is one printed line with its class: LOW below 90 percent of the target, HIGH above 110 percent, OK in between. A last line gives the three counts.

### The block

```sql
DECLARE
  v_target  products.target_thk_nm%TYPE;
  v_pct     NUMBER;
  v_low     PLS_INTEGER := 0;
  v_ok      PLS_INTEGER := 0;
  v_high    PLS_INTEGER := 0;
BEGIN
  SELECT p.target_thk_nm INTO v_target
  FROM   lots l JOIN products p ON p.product_id = l.product_id
  WHERE  l.lot_id = 'L26-005';
  --
  FOR r IN (SELECT w.wafer_id, m.thickness_nm
            FROM   measurements m JOIN wafers w ON w.wafer_id = m.wafer_id
            WHERE  w.lot_id = 'L26-005' AND m.step = 'ANNEAL'
            ORDER  BY w.wafer_id) LOOP
    v_pct := r.thickness_nm / v_target * 100;
    IF v_pct < 90 THEN
      v_low := v_low + 1;
      DBMS_OUTPUT.PUT_LINE(r.wafer_id || '  ' || r.thickness_nm || '  LOW');
    ELSIF v_pct > 110 THEN
      v_high := v_high + 1;
      DBMS_OUTPUT.PUT_LINE(r.wafer_id || '  ' || r.thickness_nm || '  HIGH');
    ELSE
      v_ok := v_ok + 1;
      DBMS_OUTPUT.PUT_LINE(r.wafer_id || '  ' || r.thickness_nm || '  OK');
    END IF;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('LOW ' || v_low || ', OK ' || v_ok || ', HIGH ' || v_high);
END;
/
```

### How the block runs

**Step 1. DECLARE.** `v_target` and `v_pct` are `NULL`. The three counters `v_low`, `v_ok` and `v_high` start at 0.

**Step 2. SELECT INTO.** Lot L26-005 makes PHO-300, so `v_target` = 220. That makes 90 percent 198 nm and 110 percent 242 nm.

**Step 3. The FOR loop.** The query returns the four ANNEAL readings of the lot. Each pass works out the percentage and then the `IF` picks one branch:

- Pass 1: L26-005-01, 243.9 nm. `v_pct` = 243.9 / 220 * 100 = 110.86. Not below 90; above 110, so HIGH. `v_high` = 1.
- Pass 2: L26-005-02, 250.29 nm. `v_pct` = 113.77. HIGH. `v_high` = 2.
- Pass 3: L26-005-03, 241.07 nm. `v_pct` = 109.58. Not below 90, not above 110, so the `ELSE`: OK. `v_ok` = 1.
- Pass 4: L26-005-04, 237.85 nm. `v_pct` = 108.11. OK. `v_ok` = 2.

`v_low` was never touched and is still 0.

**Step 4. Last PUT_LINE.** Prints the three counters.

### Output

```text
L26-005-01  243.9  HIGH
L26-005-02  250.29  HIGH
L26-005-03  241.07  OK
L26-005-04  237.85  OK
LOW 0, OK 2, HIGH 2

PL/SQL procedure successfully completed.
```

### What to notice

The target is 220 nm, so 110 percent is 242. Wafers 01 and 02 are above it, and 03 and 04 are below it. At the ANNEAL step the film has not thinned to its final value yet, so HIGH readings are normal here.

## Exercise 7: Do you need the loop?

**Maya asks:** "Same numbers, but I want them in a table."

### The problem in plain words

The same four readings and the same three classes as exercise 6, but as one `SELECT`. One result row per class that has readings, with the class name and the number of readings. The target is joined in, so each reading row carries its own target.

### The query

```sql
SELECT CASE
         WHEN m.thickness_nm < p.target_thk_nm * 0.9 THEN 'LOW'
         WHEN m.thickness_nm > p.target_thk_nm * 1.1 THEN 'HIGH'
         ELSE 'OK'
       END AS class,
       COUNT(*) AS readings
FROM   measurements m
       JOIN wafers w   ON w.wafer_id = m.wafer_id
       JOIN lots l     ON l.lot_id = w.lot_id
       JOIN products p ON p.product_id = l.product_id
WHERE  w.lot_id = 'L26-005' AND m.step = 'ANNEAL'
GROUP  BY CASE
            WHEN m.thickness_nm < p.target_thk_nm * 0.9 THEN 'LOW'
            WHEN m.thickness_nm > p.target_thk_nm * 1.1 THEN 'HIGH'
            ELSE 'OK'
          END
ORDER  BY class;
```

### How the query builds the answer

**Step 1. FROM and the joins.** Each reading is joined to its wafer, the wafer to its lot, the lot to its product. Now every reading row also has the product target.

**Step 2. WHERE.** Only lot L26-005 and step ANNEAL stay: 4 rows. Here they are with the `CASE` worked out for each:

```text
WAFER_ID         THICKNESS_NM TARGET_THK_NM         LO         HI CLS
---------------- ------------ ------------- ---------- ---------- ----
L26-005-01              243.9           220        198        242 HIGH
L26-005-02             250.29           220        198        242 HIGH
L26-005-03             241.07           220        198        242 OK
L26-005-04             237.85           220        198        242 OK
```

**Step 3. GROUP BY the CASE.** Rows with the same class go into one group: HIGH has 2 rows, OK has 2 rows. No row is LOW, so there is no LOW group.

**Step 4. SELECT.** One row per group: the class and `COUNT(*)`.

**Step 5. ORDER BY class.** Alphabetical: HIGH before OK.

### Output

```text
CLAS   READINGS
---- ----------
HIGH          2
OK            2
```

### What to notice

The same counts from a single statement, as a result set you can sort, join or export. The column heading shows `CLAS` only because SQL*Plus cuts the heading to the width of the longest value; your tool will show `CLASS`. The loop is worth writing when each row must trigger something SQL cannot do, such as a call to another program. For classing and counting, SQL is shorter and scales better.
