# Lab 16 solutions: Functions and procedures

Try each exercise yourself first. Your code may differ from these and still be right: compare the output, not the spelling. The runnable file is [`lab16_solutions.sql`](scripts/lab16_solutions.sql).

Each exercise has the same parts: the problem in plain words, the code, how the code runs (step by step, in the order Oracle runs it), the output, and what to notice.

All outputs and the in-between values in the step-by-step parts were produced by running the code, and pieces of it, on the lab data (Oracle 21c XE; 19c gives the same results). The outputs are shown the way SQL*Plus prints them. In DBeaver, query results appear in the results grid and `DBMS_OUTPUT` lines in the Output panel.

> **For Lab 17.** The four definitions below are the exact objects the next lab builds on: `wafer_yield`, `thickness_status`, `print_lot_report` and `hold_lot`. Keep them in your schema, and do not rename them or change their parameters.

How to run the code in DBeaver: open the Output panel first (**Ctrl + Shift + O**). Select each `CREATE OR REPLACE ...` or `BEGIN ... END;` whole, from its first line down to its `END;` line, and press **Ctrl + Enter**, one at a time. A plain `SELECT` runs with the cursor inside it. Exercise 5 changes data, so switch to **Manual Commit** first.

Two ideas carry this lab:

- **Creating is not running.** `CREATE OR REPLACE FUNCTION` or `PROCEDURE` only compiles the code and stores it in your schema. Nothing is read from the tables and nothing is printed. The code runs later, each time somebody calls it.
- **A function returns one value, a procedure does a job.** You call a function inside an expression, for example in a `SELECT`. You call a procedure as a statement of its own, here in a `BEGIN ... END;` block.

## Exercise 1: The function wafer_yield

**Maya asks:** "What percentage of a lot's graded wafers are PRIME? One decimal. If the lot has no graded wafer, give me nothing."

### The problem in plain words

The table is `WAFERS`: one row per wafer, with the lot it belongs to and its `grade` (PRIME, TEST, SCRAP, or empty when the wafer has not been graded yet). The function gets a lot id and returns one number: the PRIME wafers as a percentage of the graded wafers of that lot, rounded to one decimal. A lot with no graded wafer, or a lot that does not exist, returns `NULL`. The test query calls the function four times and shows one row with four numbers.

### The code

```sql
CREATE OR REPLACE FUNCTION wafer_yield(p_lot_id VARCHAR2) RETURN NUMBER IS
  v_graded NUMBER;
  v_prime  NUMBER;
BEGIN
  SELECT COUNT(grade),
         COUNT(CASE WHEN grade = 'PRIME' THEN 1 END)
  INTO   v_graded, v_prime
  FROM   wafers
  WHERE  lot_id = p_lot_id;
  --
  IF v_graded = 0 THEN
    RETURN NULL;
  END IF;
  RETURN ROUND(v_prime / v_graded * 100, 1);
END wafer_yield;
/
```

Test:

```sql
SELECT wafer_yield('L26-003') AS l003, wafer_yield('L26-012') AS l012,
       wafer_yield('L26-008') AS l008, wafer_yield('L26-999') AS l999
FROM   dual;
```

### How the code runs

**Step 1. CREATE.** Oracle checks the syntax, checks that `WAFERS` and its columns `grade` and `lot_id` exist, and stores the compiled function in your schema under the name `WAFER_YIELD`. It prints `Function created.` No row is read yet. The `--` line in the middle is only a spacer for DBeaver; Oracle ignores it.

**Step 2. The test query calls the function four times**, once per column, for the single row of `DUAL`. Each call starts fresh: `p_lot_id` gets the lot id, and `v_graded` and `v_prime` start as `NULL`.

**Step 3. The call for `'L26-003'`.** The `SELECT ... INTO` looks at the 5 wafers of the lot: 4 PRIME and 1 TEST. `COUNT(grade)` counts the wafers that have a grade, so `v_graded` = 5. The `CASE` gives 1 for a PRIME wafer and `NULL` otherwise, and `COUNT` counts only the 1s, so `v_prime` = 4. The `IF v_graded = 0` is false (5 is not 0). `RETURN ROUND(4 / 5 * 100, 1)` returns 80.

**Step 4. The call for `'L26-012'`.** The lot has 4 wafers, 2 PRIME and 2 with no grade. `v_graded` = 2 (the two empty grades are not counted), `v_prime` = 2. The `IF` is false. The function returns `ROUND(2 / 2 * 100, 1)` = 100.

**Step 5. The call for `'L26-008'`.** 4 wafers, all SCRAP. `v_graded` = 4, `v_prime` = 0. The function returns `ROUND(0 / 4 * 100, 1)` = 0.

**Step 6. The call for `'L26-999'`.** No wafer has this lot id. A `SELECT` with only `COUNT`s and no `GROUP BY` always returns one row, so there is no `NO_DATA_FOUND`: `v_graded` = 0 and `v_prime` = 0. Now `IF v_graded = 0` is true, and `RETURN NULL` ends the function at once. The division is never reached, so there is no "divisor is equal to zero" error.

### Output

```text
Function created.
```

```text
      L003       L012       L008       L999
---------- ---------- ---------- ----------
        80        100          0
```

### What to notice

`COUNT(grade)` ignores the `NULL` grades, which is why `L26-012` gives 100 and not 50. The last column is empty because the function returned `NULL`. A `RETURN` ends the function at once, which is why the `NULL` case needs no `ELSE`.

## Exercise 2: Use the function in a query

**Maya asks:** "Show me the lots with a yield below 90 percent, lowest first."

### The problem in plain words

The table is `LOTS`, one row per lot (16 lots). For each lot, the function from exercise 1 works out the yield. Maya wants one row per lot whose yield is below 90, with the lot id, its status and the yield, the lowest yield first. Lots with the same yield are sorted by lot id.

### The code

```sql
SELECT lot_id, status, wafer_yield(lot_id) AS yield_pct
FROM   lots
WHERE  wafer_yield(lot_id) < 90
ORDER  BY yield_pct, lot_id;
```

### How the code runs

**Step 1. FROM.** Oracle reads the 16 rows of `LOTS`.

**Step 2. WHERE.** For each lot, Oracle calls `wafer_yield(lot_id)`, and the function runs exactly as in exercise 1, with its own `SELECT` on `WAFERS`. The yields are: 0 for `L26-008`; 80 for the nine lots `L26-001`, `-002`, `-003`, `-004`, `-006`, `-007`, `-009`, `-010` and `-011` (4 PRIME out of 5 graded each); and 100 for the six lots `L26-003A`, `L26-003B`, `L26-003B1`, `L26-005`, `L26-007A` and `L26-012`. The test `< 90` keeps 10 lots and drops the six at 100.

**Step 3. SELECT.** For the 10 rows that are left, Oracle calls the function again for the `yield_pct` column. So some lots get the function called twice, once for the filter and once for the output.

**Step 4. ORDER BY.** `yield_pct` is the alias from the select list, and Oracle allows it in `ORDER BY`. `L26-008` (0) comes first, then the nine lots at 80, sorted by `lot_id`.

### Output

```text
LOT_ID       STATUS    YIELD_PCT
------------ -------- ----------
L26-008      SCRAPPED          0
L26-001      SHIPPED          80
L26-002      SHIPPED          80
L26-003      ACTIVE           80
L26-004      SHIPPED          80
L26-006      SHIPPED          80
L26-007      ACTIVE           80
L26-009      ACTIVE           80
L26-010      ACTIVE           80
L26-011      ACTIVE           80

10 rows selected.
```

### What to notice

The function sits in `WHERE` and in the select list, like a built-in function. Each call runs its own small query on `WAFERS`. On 16 lots that costs nothing; on a million rows it would, and Lab 18 measures that cost.

## Exercise 3: The function thickness_status

**Maya asks:** "Give me a word for a reading: LOW below 90 percent of the target, HIGH above 110 percent, otherwise OK."

### The problem in plain words

The function gets two numbers, a thickness and a target, and returns one word: `LOW`, `HIGH` or `OK`, or `NULL` when one of the inputs is missing. It reads no table. The first test query shows one row with four words. The report then uses the function on `MEASUREMENTS` (one row per reading, with `step` and `thickness_nm`), joined through `WAFERS` and `LOTS` to `PRODUCTS` for the target (`target_thk_nm`). It returns one row per step and word, with the number of readings.

### The code

```sql
CREATE OR REPLACE FUNCTION thickness_status(p_thickness NUMBER, p_target NUMBER)
  RETURN VARCHAR2 DETERMINISTIC IS
BEGIN
  IF p_thickness IS NULL OR p_target IS NULL THEN
    RETURN NULL;
  ELSIF p_thickness < p_target * 0.9 THEN
    RETURN 'LOW';
  ELSIF p_thickness > p_target * 1.1 THEN
    RETURN 'HIGH';
  ELSE
    RETURN 'OK';
  END IF;
END thickness_status;
/
```

Test and report:

```sql
SELECT thickness_status(100, 100) AS a, thickness_status(89.9, 100) AS b,
       thickness_status(110.1, 100) AS c, thickness_status(NULL, 100) AS d
FROM   dual;

SELECT m.step, thickness_status(m.thickness_nm, p.target_thk_nm) AS status, COUNT(*) AS readings
FROM   measurements m
       JOIN wafers w   ON w.wafer_id = m.wafer_id
       JOIN lots l     ON l.lot_id = w.lot_id
       JOIN products p ON p.product_id = l.product_id
GROUP  BY m.step, thickness_status(m.thickness_nm, p.target_thk_nm)
ORDER  BY m.step, status;
```

### How the code runs

**Step 1. CREATE.** Oracle compiles and stores the function. `DETERMINISTIC` is a promise that the same two inputs always give the same answer, which is true because the function reads nothing but its parameters.

**Step 2. The four test calls.** Each call runs the `IF` from the top and stops at the first branch that is true.

- `(100, 100)`: neither input is `NULL`. The limits are 100 × 0.9 = 90 and 100 × 1.1 = 110. 100 < 90 is false, 100 > 110 is false, so the `ELSE` returns `OK`.
- `(89.9, 100)`: 89.9 < 90 is true, so it returns `LOW`.
- `(110.1, 100)`: 110.1 < 90 is false, 110.1 > 110 is true, so it returns `HIGH`.
- `(NULL, 100)`: the first test, `p_thickness IS NULL`, is true, so it returns `NULL` (the empty column `D`).

**Step 3. The report: FROM and joins.** The 186 readings are joined to their wafer, lot and product, so every reading row now carries its product's target. For example, the readings of lot `L26-005` (product PHO-300) have a target of 220, so the limits are 198 and 242.

**Step 4. GROUP BY.** For every reading Oracle calls the function with the reading's thickness and its target, and groups by the step and the word. A few real readings of wafer `L26-005-01`: SPLIT 290.74 is above 242, so `HIGH`; ANNEAL 243.9 is above 242, so `HIGH`; FINAL 221.07 is between 198 and 242, so `OK`. Across all lots, the SPLIT readings are 125 to 135 percent of their target, the ANNEAL readings 108 to 114 percent, and the FINAL readings 98 to 106 percent.

**Step 5. SELECT and ORDER BY.** One row per group with `COUNT(*)`, sorted by step and word. The `status` alias names the function column.

### Output

```text
Function created.
```

```text
A      B      C      D
------ ------ ------ ------
OK     LOW    HIGH


STEP     STATUS     READINGS
-------- -------- ----------
ANNEAL   HIGH             34
ANNEAL   OK               28
FINAL    OK               62
SPLIT    HIGH             62
```

### What to notice

The result tells a process story: SPLIT readings are thicker than the target, ANNEAL readings come closer, and all 62 FINAL readings are within 10 percent. ANNEAL splits because its readings sit around the 110 percent line. A reading of exactly 90 or 110 percent is `OK`, because the tests use `<` and `>`: `thickness_status(198, 220)` and `thickness_status(242, 220)` both return `OK`.

## Exercise 4: The procedure print_lot_report

**Maya asks:** "Print a short report for a lot: a header with the product and target, one line per wafer with its grade, its FINAL thickness and the status word, and a last line with the wafer count and the yield."

### The problem in plain words

The procedure gets a lot id and prints lines with `DBMS_OUTPUT`; it returns nothing. It needs `LOTS` and `PRODUCTS` for the header (status, product code, target), `WAFERS` for the wafer lines, and `MEASUREMENTS` for each wafer's FINAL reading. A wafer with no FINAL reading still gets a line, with `n/a`. The printout is one header line, one line per wafer, and one closing line. For a lot that does not exist, it prints one sentence instead.

### The code

```sql
CREATE OR REPLACE PROCEDURE print_lot_report(p_lot_id VARCHAR2) IS
  v_status  lots.status%TYPE;
  v_code    products.product_code%TYPE;
  v_target  products.target_thk_nm%TYPE;
  v_count   PLS_INTEGER := 0;
  CURSOR c_wafers IS
    SELECT w.wafer_id, w.grade, m.thickness_nm
    FROM   wafers w
           LEFT JOIN measurements m
                  ON m.wafer_id = w.wafer_id AND m.step = 'FINAL'
    WHERE  w.lot_id = p_lot_id
    ORDER  BY w.slot_no;
BEGIN
  SELECT l.status, p.product_code, p.target_thk_nm
  INTO   v_status, v_code, v_target
  FROM   lots l JOIN products p ON p.product_id = l.product_id
  WHERE  l.lot_id = p_lot_id;
  --
  DBMS_OUTPUT.PUT_LINE('Lot ' || p_lot_id || '  product ' || v_code
                       || '  target ' || v_target || ' nm  status ' || v_status);
  FOR w IN c_wafers LOOP
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE('- ' || RPAD(w.wafer_id, 14)
                         || RPAD(NVL(w.grade, '-'), 7)
                         || LPAD(NVL(TO_CHAR(w.thickness_nm), 'n/a'), 8) || ' nm  '
                         || NVL(thickness_status(w.thickness_nm, v_target), '-'));
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Wafers: ' || v_count || '   Yield: '
                       || NVL(TO_CHAR(wafer_yield(p_lot_id)), 'n/a') || ' %');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Lot ' || p_lot_id || ' does not exist');
END print_lot_report;
/
```

Test:

```sql
BEGIN print_lot_report('L26-005'); END;
/
BEGIN print_lot_report('L26-012'); END;
/
BEGIN print_lot_report('L26-999'); END;
/
```

### How the code runs

**Step 1. CREATE.** Oracle compiles and stores the procedure. It checks that the two functions it calls, `thickness_status` and `wafer_yield`, exist. Nothing is printed except `Procedure created.`

**Step 2. The call for `'L26-005'`.** The block `BEGIN print_lot_report('L26-005'); END;` passes `'L26-005'` into `p_lot_id`. The declarations run first: `v_status`, `v_code` and `v_target` start as `NULL`, `v_count` starts at 0. The cursor `c_wafers` is only declared here; it is not opened yet.

**Step 3. The header query.** The `SELECT ... INTO` finds the lot and its product: `v_status` = `HOLD`, `v_code` = `PHO-300`, `v_target` = 220. The first `PUT_LINE` prints the header.

**Step 4. The cursor loop.** `FOR w IN c_wafers` opens the cursor with `p_lot_id` = `'L26-005'` and fetches one row per pass, in slot order. The `LEFT JOIN` with `m.step = 'FINAL'` in the `ON` brings each wafer's FINAL reading.

- Pass 1: `w.wafer_id` = `L26-005-01`, `w.grade` = `PRIME`, `w.thickness_nm` = 221.07. `v_count` becomes 1. `thickness_status(221.07, 220)`: 221.07 is between 198 and 242, so `OK`. The line `- L26-005-01    PRIME    221.07 nm  OK` is printed. `RPAD` and `LPAD` pad each part to a fixed width so the columns line up.
- Pass 2: `L26-005-02`, `PRIME`, 219.76, `OK`. `v_count` = 2.
- Pass 3: `L26-005-03`, `PRIME`, 216.63, `OK`. `v_count` = 3.
- Pass 4: `L26-005-04`, `PRIME`, 215.62, `OK`. `v_count` = 4.

The cursor has no fifth row, so the loop ends and closes the cursor by itself.

**Step 5. The closing line.** `wafer_yield('L26-005')` runs: 4 graded, 4 PRIME, so 100. The line `Wafers: 4   Yield: 100 %` is printed. The `EXCEPTION` section is skipped because nothing went wrong.

**Step 6. The call for `'L26-012'`.** The header query gives `ACTIVE`, `PHO-300`, 220. The cursor returns four wafers, and none of them has a FINAL reading, so `w.thickness_nm` is `NULL` on every pass. `TO_CHAR(NULL)` is `NULL`, and `NVL` turns it into `n/a`. `thickness_status(NULL, 220)` returns `NULL`, and `NVL` turns that into `-`. Wafers 3 and 4 have no grade either, so `NVL(w.grade, '-')` prints `-`. `v_count` ends at 4, and `wafer_yield('L26-012')` returns 100 (2 PRIME out of 2 graded).

**Step 7. The call for `'L26-999'`.** The header query finds no row and raises `NO_DATA_FOUND`. Oracle jumps straight to the `EXCEPTION` section: the header is never printed and the loop never runs. The handler prints `Lot L26-999 does not exist`. Because the error was handled inside the procedure, the call itself ends normally.

### Output

```text
Procedure created.
```

```text
Lot L26-005  product PHO-300  target 220 nm  status HOLD
- L26-005-01    PRIME    221.07 nm  OK
- L26-005-02    PRIME    219.76 nm  OK
- L26-005-03    PRIME    216.63 nm  OK
- L26-005-04    PRIME    215.62 nm  OK
Wafers: 4   Yield: 100 %

PL/SQL procedure successfully completed.

Lot L26-012  product PHO-300  target 220 nm  status ACTIVE
- L26-012-01    PRIME       n/a nm  -
- L26-012-02    PRIME       n/a nm  -
- L26-012-03    -           n/a nm  -
- L26-012-04    -           n/a nm  -
Wafers: 4   Yield: 100 %

PL/SQL procedure successfully completed.

Lot L26-999 does not exist

PL/SQL procedure successfully completed.
```

### What to notice

The `LEFT JOIN` keeps the four wafers of `L26-012`, which has no measurements. That only works because the condition `m.step = 'FINAL'` is in the `ON` clause; in a `WHERE` it would remove those wafers. The header query raises `NO_DATA_FOUND` for an unknown lot, and the handler turns it into a sentence. The procedure uses both functions from the earlier exercises, so a fix in one of them reaches the report at once.

## Exercise 5: The procedure hold_lot

**Maya asks:** "Put a lot on hold and write down why."

### The problem in plain words

The procedure changes one row of `LOTS`: it sets `status` to `HOLD` and `hold_reason` to the text it is given. Before it changes anything it checks two rules. A lot that does not exist gives error -20101, and a lot that is already on hold gives error -20102. It does not commit, so the caller decides whether to keep or undo the change. The test changes `L26-010`, tries the two error cases, and undoes everything with `ROLLBACK`.

### The code

```sql
CREATE OR REPLACE PROCEDURE hold_lot(p_lot_id VARCHAR2, p_reason VARCHAR2) IS
  v_status lots.status%TYPE;
BEGIN
  BEGIN
    SELECT status INTO v_status FROM lots WHERE lot_id = p_lot_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20101, 'Lot ' || p_lot_id || ' does not exist');
  END;
  --
  IF v_status = 'HOLD' THEN
    RAISE_APPLICATION_ERROR(-20102, 'Lot ' || p_lot_id || ' is already on hold');
  END IF;
  --
  UPDATE lots
  SET    status = 'HOLD',
         hold_reason = p_reason
  WHERE  lot_id = p_lot_id;
END hold_lot;
/
```

Test, then undo (manual commit mode on):

```sql
SELECT lot_id, status, hold_reason FROM lots WHERE lot_id = 'L26-010';
BEGIN hold_lot('L26-010', 'Particle check'); END;
/
SELECT lot_id, status, hold_reason FROM lots WHERE lot_id = 'L26-010';
BEGIN hold_lot(p_reason => 'Again', p_lot_id => 'L26-010'); END;
/
BEGIN hold_lot('L26-999', 'Nothing'); END;
/
ROLLBACK;
SELECT lot_id, status, hold_reason FROM lots WHERE lot_id = 'L26-010';
SELECT COUNT(*) AS lots_on_hold FROM lots WHERE status = 'HOLD';
```

### How the code runs

**Step 1. CREATE.** Oracle compiles and stores the procedure. The line numbers inside it matter later: line 8 is the `RAISE_APPLICATION_ERROR(-20101, ...)` and line 12 is the `RAISE_APPLICATION_ERROR(-20102, ...)`. The `--` spacer lines count as lines too.

**Step 2. The first SELECT.** `L26-010` is `ACTIVE` with an empty reason.

**Step 3. `hold_lot('L26-010', 'Particle check')`.** `p_lot_id` = `'L26-010'`, `p_reason` = `'Particle check'`, `v_status` starts as `NULL`. The inner block's `SELECT ... INTO` finds the lot: `v_status` = `ACTIVE`. Its `EXCEPTION` section is skipped. `IF v_status = 'HOLD'` is false (`ACTIVE` is not `HOLD`). The `UPDATE` changes 1 row. The procedure ends without a commit, so the change is only visible in your session.

**Step 4. The second SELECT** shows `HOLD` and `Particle check`.

**Step 5. `hold_lot(p_reason => 'Again', p_lot_id => 'L26-010')`.** Named notation: each value is matched to its parameter by name, so the order does not matter. `p_lot_id` = `'L26-010'`, `p_reason` = `'Again'`. The inner `SELECT` now finds `v_status` = `HOLD`, because your own uncommitted update is visible to you. The `IF` is true, and line 12 raises `ORA-20102`. The procedure stops; the `UPDATE` is never reached. The error goes back to the calling block, which has no handler, so the block fails and the error is shown. Your earlier update from step 3 stays in place, because a failed call only undoes its own work.

**Step 6. `hold_lot('L26-999', 'Nothing')`.** The inner `SELECT` finds no row and raises `NO_DATA_FOUND`. The inner block's handler catches it and raises `ORA-20101` on line 8 instead. That new error leaves the procedure: the `IF` and the `UPDATE` never run.

**Step 7. ROLLBACK.** It undoes the one change that was made, the update from step 3. The last two queries show `L26-010` as `ACTIVE` again, with an empty reason, and 2 lots on hold (`L26-003B` and `L26-005`), the same as before the lab.

### Output

```text
Procedure created.
```

```text
LOT_ID       STATUS   HOLD_REASON
------------ -------- --------------------
L26-010      ACTIVE


PL/SQL procedure successfully completed.


LOT_ID       STATUS   HOLD_REASON
------------ -------- --------------------
L26-010      HOLD     Particle check

BEGIN hold_lot(p_reason => 'Again', p_lot_id => 'L26-010'); END;
*
ERROR at line 1:
ORA-20102: Lot L26-010 is already on hold
ORA-06512: at "FAB_LAB.HOLD_LOT", line 12
ORA-06512: at line 1


BEGIN hold_lot('L26-999', 'Nothing'); END;
*
ERROR at line 1:
ORA-20101: Lot L26-999 does not exist
ORA-06512: at "FAB_LAB.HOLD_LOT", line 8
ORA-06512: at line 1



Rollback complete.


LOT_ID       STATUS   HOLD_REASON
------------ -------- --------------------
L26-010      ACTIVE


LOTS_ON_HOLD
------------
           2
```

In DBeaver the error appears in a dialog or in the results panel instead of the `ERROR at line 1` text.

### What to notice

The procedure changes data but does not commit, so `ROLLBACK` restores the lot. The second call used named notation, so the order of the arguments did not matter. The two errors carry the numbers you chose and a message the caller can read. The `ORA-06512` lines tell you where the error was raised: line 12 and line 8 of `HOLD_LOT`.

## Exercise 6: What is stored, and a function that does not compile

**Maya asks:** "Where do these routines live, and what happens when one has a mistake?"

### The problem in plain words

Three dictionary views describe your stored code. `USER_OBJECTS` has one row per object, with its type and whether it is `VALID`. `USER_SOURCE` has one row per line of source code. `USER_ERRORS` has one row per compile error. The first query lists your functions and procedures (one row each); the second counts the source lines of the four lab objects. Then a function with a missing semicolon is created, its error is read, it is fixed, called and dropped.

### The code

```sql
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_type IN ('FUNCTION','PROCEDURE')
ORDER  BY object_name;

SELECT name, type, COUNT(*) AS lines_of_code
FROM   user_source
WHERE  name IN ('WAFER_YIELD','THICKNESS_STATUS','PRINT_LOT_REPORT','HOLD_LOT')
GROUP  BY name, type
ORDER  BY name;
```

Now the broken function:

```sql
CREATE OR REPLACE FUNCTION double_it(p_x NUMBER) RETURN NUMBER IS
BEGIN
  RETURN p_x * 2
END;
/
SELECT line, position, text FROM user_errors WHERE name = 'DOUBLE_IT';
SELECT object_name, status FROM user_objects WHERE object_name = 'DOUBLE_IT';
```

Fix the missing semicolon and run `CREATE OR REPLACE` again:

```sql
CREATE OR REPLACE FUNCTION double_it(p_x NUMBER) RETURN NUMBER IS
BEGIN
  RETURN p_x * 2;
END;
/
SELECT double_it(21) AS answer FROM dual;
SELECT object_name, status FROM user_objects WHERE object_name = 'DOUBLE_IT';
DROP FUNCTION double_it;
```

### How the code runs

**Step 1. USER_OBJECTS.** Oracle stored the names in capitals when you created the objects, so the four lab objects appear as `HOLD_LOT`, `PRINT_LOT_REPORT`, `THICKNESS_STATUS` and `WAFER_YIELD`, all `VALID`.

**Step 2. USER_SOURCE.** Each stored line is one row, from the `FUNCTION` or `PROCEDURE` line down to the `END` line. The `CREATE OR REPLACE` words and the `/` are not stored. `COUNT(*)` per object gives 15 lines for `WAFER_YIELD`, 13 for `THICKNESS_STATUS`, 33 for `PRINT_LOT_REPORT` and 19 for `HOLD_LOT`. The `--` spacer lines are counted too.

**Step 3. The broken CREATE.** Line 3, `RETURN p_x * 2`, has no semicolon. The parser reads on and only notices the problem when it reaches `END` on line 4, where it expected a `;` or more of the expression. Oracle still stores the function, but marked `INVALID`, and writes the message to `USER_ERRORS`. SQL*Plus says `Warning: Function created with compilation errors.`; DBeaver shows a similar warning.

**Step 4. USER_ERRORS and USER_OBJECTS** show the one error (line 4, position 1, `PLS-00103`) and the status `INVALID`.

**Step 5. The fixed CREATE.** `CREATE OR REPLACE` replaces the stored function. This time it compiles, the old error disappears from `USER_ERRORS`, and the status becomes `VALID`. `double_it(21)` runs `RETURN 21 * 2` and returns 42. `DROP FUNCTION` removes it.

### Output

```text
OBJECT_NAME          OBJECT_TYPE  STATUS
-------------------- ------------ --------
HOLD_LOT             PROCEDURE    VALID
PRINT_LOT_REPORT     PROCEDURE    VALID
THICKNESS_STATUS     FUNCTION     VALID
WAFER_YIELD          FUNCTION     VALID


NAME                 TYPE         LINES_OF_CODE
-------------------- ------------ -------------
HOLD_LOT             PROCEDURE               19
PRINT_LOT_REPORT     PROCEDURE               33
THICKNESS_STATUS     FUNCTION                13
WAFER_YIELD          FUNCTION                15
```

The broken function:

```text
Warning: Function created with compilation errors.


      LINE   POSITION TEXT
---------- ---------- ----------------------------------------------------------------------
         4          1 PLS-00103: Encountered the symbol "END" when expecting one of the foll
                      owing:

                         * & = - + ; < / > at in is mod remainder not rem
                         <an exponent (**)> <> or != or ~= >= <= <> and or like like2
                         like4 likec between || member submultiset
                      The symbol ";" was substituted for "END" to continue.



OBJECT_NAME          STATUS
-------------------- --------
DOUBLE_IT            INVALID
```

After the fix:

```text
Function created.


    ANSWER
----------
        42


OBJECT_NAME          STATUS
-------------------- --------
DOUBLE_IT            VALID

Function dropped.
```

### What to notice

An object with a compile error still exists, marked `INVALID`, and `USER_ERRORS` says why. The error line is the `END`, one line after the missing semicolon. `CREATE OR REPLACE` mends the object in place. Your line counts may differ from these if you formatted the code differently.
