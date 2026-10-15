# Lab 17 solutions: Packages and triggers

Try each exercise yourself first. Your code may differ from this and still be right: compare the output. The runnable file is [`lab17_solutions.sql`](scripts/lab17_solutions.sql).

Each exercise has the same parts: the problem in plain words, the code, how the code runs (step by step, in the order Oracle runs it), the output, and what to notice.

All outputs and the in-between values in the step-by-step parts were produced by running the code, and pieces of it, on the lab data (Oracle 21c XE; 19c gives the same results). The outputs are shown the way SQL*Plus prints them. In DBeaver, query results appear in the results grid, `DBMS_OUTPUT` lines in the Output panel, and errors in a dialog or the results panel. Error line numbers and `hist_id` values can differ on your machine if your code is laid out differently or the sequence was used before.

How to run the code in DBeaver: open the Output panel first (**Ctrl + Shift + O**). Select each `CREATE OR REPLACE ...` or `BEGIN ... END;` whole, from its first line down to its `END;` line, and press **Ctrl + Enter**, one at a time. Plain `SELECT`, `UPDATE`, `ALTER` and `DROP` statements run with the cursor inside them. Switch to **Manual Commit** first.

Three ideas carry this lab:

- **A package has two parts.** The specification lists what callers may use: names, parameters, return types. The body holds the code. Callers only see the specification.
- **Package state lives in your session.** A variable declared at the top of a body is created the first time your session uses the package, and it keeps its value between calls until the session ends or the package is compiled again.
- **A trigger runs by itself.** Nobody calls it. Oracle runs it when the statement it is attached to changes a row.

## Exercise 1: The specification

**Maya asks:** "Put our four routines in a package called `FAB_REPORTS`. Start with the label on the lid."

### The problem in plain words

No table is read here. The specification is a list of four headings, the same four routines as in Lab 16 with the same parameters. After it is created, `USER_OBJECTS` shows one row for the package. Then a small block tries to call `fab_reports.wafer_yield`, and the call should fail because there is no code behind the headings yet.

### The code

```sql
CREATE OR REPLACE PACKAGE fab_reports AS
  FUNCTION  wafer_yield (p_lot_id VARCHAR2) RETURN NUMBER;
  FUNCTION  thickness_status (p_thickness NUMBER, p_target NUMBER) RETURN VARCHAR2 DETERMINISTIC;
  PROCEDURE print_lot_report (p_lot_id VARCHAR2);
  PROCEDURE hold_lot (p_lot_id VARCHAR2, p_reason VARCHAR2);
END fab_reports;
/
SELECT object_name, object_type, status FROM user_objects WHERE object_name = 'FAB_REPORTS' ORDER BY object_type;
```

Calling a member now:

```sql
BEGIN
  DBMS_OUTPUT.PUT_LINE(fab_reports.wafer_yield('L26-003'));
END;
/
```

### How the code runs

**Step 1. CREATE PACKAGE.** Oracle compiles the four headings and stores them as an object of type `PACKAGE` named `FAB_REPORTS`. Nothing runs. The `DETERMINISTIC` keyword is part of the heading of `thickness_status`, so the body will have to say it too.

**Step 2. USER_OBJECTS** shows the package as `VALID`. A specification on its own is complete and correct.

**Step 3. The block.** Oracle compiles the block: the call matches a heading in the specification, so compiling works. Then it runs the block, and at the call Oracle looks for the body to find the code. There is none, so the call fails with `ORA-04067`. The `ORA-06512: at line 2` line points to line 2 of the block, the `PUT_LINE` line with the call.

### Output

```text
Package created.

OBJECT_NAME      OBJECT_TYPE    STATUS
---------------- -------------- ---------
FAB_REPORTS      PACKAGE        VALID
```

```text
ORA-04067: not executed, package body "FAB_LAB.FAB_REPORTS" does not exist
ORA-06508: PL/SQL: could not find program unit being called: "FAB_LAB.FAB_REPORTS"
ORA-06512: at line 2
```

### What to notice

The specification compiled with no code behind it. It is a promise only: callers can be written and compiled against it, but nothing can run until the body exists.

## Exercise 2: The body

**Maya asks:** "Now put the tools in the box."

### The problem in plain words

The body holds the code of the four routines, copied from Lab 16. Each routine loses its own `CREATE OR REPLACE`, and the whole set is wrapped in one `CREATE OR REPLACE PACKAGE BODY ... END fab_reports;`. After it is created, `USER_OBJECTS` shows two rows for `FAB_REPORTS`. The yield query should return 80 for `L26-003`, and the report for `L26-005` should print the same six lines as in Lab 16.

### The code

```sql
CREATE OR REPLACE PACKAGE BODY fab_reports AS
  --
  FUNCTION wafer_yield (p_lot_id VARCHAR2) RETURN NUMBER IS
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
  --
  FUNCTION thickness_status (p_thickness NUMBER, p_target NUMBER)
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
  --
  PROCEDURE print_lot_report (p_lot_id VARCHAR2) IS
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
  --
  PROCEDURE hold_lot (p_lot_id VARCHAR2, p_reason VARCHAR2) IS
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
--
END fab_reports;
/
SELECT object_name, object_type, status FROM user_objects WHERE object_name = 'FAB_REPORTS' ORDER BY object_type;
SELECT fab_reports.wafer_yield('L26-003') AS yield FROM dual;
BEGIN fab_reports.print_lot_report('L26-005'); END;
/
```

### How the code runs

**Step 1. CREATE PACKAGE BODY.** Oracle compiles the four routines and checks each one against its heading in the specification: same name, same parameter names and types, same return type, and `DETERMINISTIC` on `thickness_status`. It stores the result as an object of type `PACKAGE BODY`. The `--` lines between the routines are spacers so DBeaver does not cut the statement at a blank line.

**Step 2. USER_OBJECTS** now lists two rows: `PACKAGE` and `PACKAGE BODY`, both `VALID`.

**Step 3. `fab_reports.wafer_yield('L26-003')`.** The first use of the package in this session loads it. The function runs exactly as in Lab 16: `v_graded` = 5, `v_prime` = 4, so it returns 80.

**Step 4. `fab_reports.print_lot_report('L26-005')`.** Same steps as in Lab 16: the header query gives `HOLD`, `PHO-300`, 220; the cursor loop runs four passes with `v_count` going from 1 to 4 and every FINAL reading between 198 and 242 (`OK`); the yield is 100. Inside the body, `thickness_status` and `wafer_yield` without a prefix mean the package's own copies.

### Output

```text
Package body created.

OBJECT_NAME      OBJECT_TYPE    STATUS
---------------- -------------- ---------
FAB_REPORTS      PACKAGE        VALID
FAB_REPORTS      PACKAGE BODY   VALID

     YIELD
----------
        80

Lot L26-005  product PHO-300  target 220 nm  status HOLD
- L26-005-01    PRIME    221.07 nm  OK
- L26-005-02    PRIME    219.76 nm  OK
- L26-005-03    PRIME    216.63 nm  OK
- L26-005-04    PRIME    215.62 nm  OK
Wafers: 4   Yield: 100 %
```

### What to notice

The package now shows two lines in `USER_OBJECTS`, one for the specification and one for the body. The Lab 16 functions and procedures still exist on their own; the package holds its own copies. If you copy the code from your own Lab 16 solution, your report format may differ slightly from this one.

## Exercise 3: A private helper and a counter

**Maya asks:** "How many reports have I printed today? And check that the lot exists in one place only."

### The problem in plain words

Three changes. A counter variable in the body counts the reports printed in this session, and a new public function `reports_printed` returns it. A private procedure `check_lot` reads a lot's status and raises `-20101` when the lot does not exist; `hold_lot` calls it instead of its own query. The test reads the counter (0), prints two reports, reads the counter again (2), and shows that `check_lot` cannot be called from outside.

### The code

The specification gets one new line, `FUNCTION reports_printed RETURN PLS_INTEGER;`:

```sql
CREATE OR REPLACE PACKAGE fab_reports AS
  FUNCTION  wafer_yield (p_lot_id VARCHAR2) RETURN NUMBER;
  FUNCTION  thickness_status (p_thickness NUMBER, p_target NUMBER) RETURN VARCHAR2 DETERMINISTIC;
  PROCEDURE print_lot_report (p_lot_id VARCHAR2);
  PROCEDURE hold_lot (p_lot_id VARCHAR2, p_reason VARCHAR2);
  FUNCTION  reports_printed RETURN PLS_INTEGER;
END fab_reports;
/
```

The new body in full:

```sql
CREATE OR REPLACE PACKAGE BODY fab_reports AS
  --
  g_printed PLS_INTEGER := 0;             -- package state: one copy per session
  --
  -- private: not in the specification, so nobody outside can call it
  PROCEDURE check_lot (p_lot_id VARCHAR2, p_status OUT VARCHAR2) IS
  BEGIN
    SELECT status INTO p_status FROM lots WHERE lot_id = p_lot_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20101, 'Lot ' || p_lot_id || ' does not exist');
  END check_lot;
  --
  FUNCTION wafer_yield (p_lot_id VARCHAR2) RETURN NUMBER IS
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
  --
  FUNCTION thickness_status (p_thickness NUMBER, p_target NUMBER)
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
  --
  PROCEDURE print_lot_report (p_lot_id VARCHAR2) IS
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
    g_printed := g_printed + 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Lot ' || p_lot_id || ' does not exist');
  END print_lot_report;
  --
  PROCEDURE hold_lot (p_lot_id VARCHAR2, p_reason VARCHAR2) IS
    v_status lots.status%TYPE;
  BEGIN
    check_lot(p_lot_id, v_status);
    IF v_status = 'HOLD' THEN
      RAISE_APPLICATION_ERROR(-20102, 'Lot ' || p_lot_id || ' is already on hold');
    END IF;
    UPDATE lots SET status = 'HOLD', hold_reason = p_reason WHERE lot_id = p_lot_id;
  END hold_lot;
  --
  FUNCTION reports_printed RETURN PLS_INTEGER IS
  BEGIN
    RETURN g_printed;
  END reports_printed;
--
END fab_reports;
/
```

Now use it:

```sql
SELECT fab_reports.reports_printed AS printed FROM dual;
BEGIN fab_reports.print_lot_report('L26-008'); END;
/
BEGIN fab_reports.print_lot_report('L26-012'); END;
/
SELECT fab_reports.reports_printed AS printed FROM dual;
```

And the private procedure from outside:

```sql
DECLARE
  v VARCHAR2(10);
BEGIN
  fab_reports.check_lot('L26-003', v);
END;
/
```

### How the code runs

**Step 1. CREATE PACKAGE and CREATE PACKAGE BODY.** Both are replaced. Compiling a package again throws away the copy your session had loaded, including any counter value it held. `check_lot` is declared near the top of the body, above `hold_lot`, so `hold_lot` can call it. It is not in the specification, so it is private: only code inside the body can call it.

**Step 2. The first `reports_printed`.** This is the first use of the new package in the session, so Oracle sets up the package state: it runs the body's declaration `g_printed PLS_INTEGER := 0`. The function returns 0.

**Step 3. `print_lot_report('L26-008')`.** The header query gives `SCRAPPED`, `PWR-200`, 1500, so the limits are 1350 and 1650. The four FINAL readings, 1551.89, 1580.16, 1570.47 and 1582.6, are all inside, so all `OK`. `v_count` ends at 4, and the yield is 0 (4 graded, 0 PRIME). After the last line, `g_printed := g_printed + 1` changes the counter from 0 to 1.

**Step 4. `print_lot_report('L26-012')`.** Four wafers, no FINAL reading, yield 100, as in Lab 16. The counter goes from 1 to 2. It kept its value between the two calls because it lives in the session, not in the procedure.

**Step 5. The second `reports_printed`** returns 2.

**Step 6. The block that calls `fab_reports.check_lot`.** The block is compiled first. The compiler looks for `CHECK_LOT` in the specification, does not find it, and stops with `PLS-00302` at line 4, column 15 of the block. The block never runs. The error comes from compiling, before anything runs.

**Step 7. What `hold_lot` does now (used in exercise 5).** It calls `check_lot(p_lot_id, v_status)`. `p_lot_id` goes in; `p_status` is an `OUT` parameter, so it starts empty inside `check_lot`, and the `SELECT ... INTO p_status` fills it. When `check_lot` ends, that value is copied back out into `hold_lot`'s `v_status`.

### Output

```text
   PRINTED
----------
         0

Lot L26-008  product PWR-200  target 1500 nm  status SCRAPPED
- L26-008-01    SCRAP   1551.89 nm  OK
- L26-008-02    SCRAP   1580.16 nm  OK
- L26-008-03    SCRAP   1570.47 nm  OK
- L26-008-04    SCRAP    1582.6 nm  OK
Wafers: 4   Yield: 0 %

Lot L26-012  product PHO-300  target 220 nm  status ACTIVE
- L26-012-01    PRIME       n/a nm  -
- L26-012-02    PRIME       n/a nm  -
- L26-012-03    -           n/a nm  -
- L26-012-04    -           n/a nm  -
Wafers: 4   Yield: 100 %

   PRINTED
----------
         2
```

```text
  fab_reports.check_lot('L26-003', v);
              *
ERROR at line 4:
ORA-06550: line 4, column 15:
PLS-00302: component 'CHECK_LOT' must be declared
```

### What to notice

The counter grew by one per report, and the private helper is unreachable from outside. `L26-012` shows a yield of 100% although two of its wafers have no grade. `wafer_yield` only counts graded wafers, as agreed in Lab 16. The counter exists for one session only: another connection, or a reconnect, starts again at 0. The error codes of `hold_lot` are the ones from Lab 16: `-20101` when the lot does not exist and `-20102` when it is already on hold.

## Exercise 4: Package members in a SELECT

**Maya asks:** "Show every lot with its yield, worst first. Then count the thickness verdicts for all measurements, step by step."

### The problem in plain words

4a reads `LOTS` and returns one row per lot (16 rows) with its yield from `fab_reports.wafer_yield`, the lowest yield first, and a lot with no yield at the very top. 4b reads `MEASUREMENTS` joined to `WAFERS`, `LOTS` and `PRODUCTS`, and returns one row per step and verdict with the number of readings. 4c tries to use the procedure `hold_lot` as if it were a function.

### The code

```sql
SELECT lot_id, status, fab_reports.wafer_yield(lot_id) AS yield_pct
FROM   lots
ORDER  BY yield_pct NULLS FIRST, lot_id;
```

```sql
SELECT m.step,
       fab_reports.thickness_status(m.thickness_nm, p.target_thk_nm) AS verdict,
       COUNT(*) AS readings
FROM   measurements m
JOIN   wafers   w ON w.wafer_id   = m.wafer_id
JOIN   lots     l ON l.lot_id     = w.lot_id
JOIN   products p ON p.product_id = l.product_id
GROUP  BY m.step, fab_reports.thickness_status(m.thickness_nm, p.target_thk_nm)
ORDER  BY m.step, verdict;
```

```sql
SELECT fab_reports.hold_lot('L26-003', 'x') FROM dual;
```

### How the code runs

**Step 1. 4a.** For each of the 16 lots, Oracle calls `fab_reports.wafer_yield(lot_id)` once for the select list. The yields are 0 (`L26-008`), 80 (nine lots) and 100 (six lots), as in Lab 16, exercise 2. `ORDER BY yield_pct NULLS FIRST, lot_id` sorts them; there is no `NULL` yield in this data, so `NULLS FIRST` changes nothing here.

**Step 2. 4b.** The 186 readings are joined to their target. For each reading Oracle calls `fab_reports.thickness_status(thickness, target)`, then groups by step and verdict and counts. The same call is repeated in `GROUP BY`, because a column alias is not allowed there. The counts match Lab 16, exercise 3.

**Step 3. 4c.** Oracle reads the `SELECT` and looks for a function `HOLD_LOT` in `FAB_REPORTS`. There is only a procedure with that name, and a procedure has no return value, so it cannot stand in a select list. The statement fails before it runs with `ORA-00904`. Nothing is changed.

### Output

```text
LOT_ID     STATUS     YIELD_PCT
---------- --------- ----------
L26-008    SCRAPPED           0
L26-001    SHIPPED           80
L26-002    SHIPPED           80
L26-003    ACTIVE            80
L26-004    SHIPPED           80
L26-006    SHIPPED           80
L26-007    ACTIVE            80
L26-009    ACTIVE            80
L26-010    ACTIVE            80
L26-011    ACTIVE            80
L26-003A   SHIPPED          100
L26-003B   HOLD             100
L26-003B1  ACTIVE           100
L26-005    HOLD             100
L26-007A   ACTIVE           100
L26-012    ACTIVE           100

16 rows selected.
```

```text
STEP     VERDICT    READINGS
-------- -------- ----------
ANNEAL   HIGH             34
ANNEAL   OK               28
FINAL    OK               62
SPLIT    HIGH             62
```

```text
ORA-00904: "FAB_REPORTS"."HOLD_LOT": invalid identifier
```

### What to notice

A package function works like a built-in one, one call per row. In this data every `SPLIT` reading is about 30 percent above target, so all are `HIGH`, and every `FINAL` reading is `OK`. A procedure has no return value, so it cannot be used as an expression. `NULLS FIRST` protects you if a lot appears with no graded wafers.

## Exercise 5: A trigger that writes LOT_HISTORY

**Maya asks:** "Whenever a lot's status changes, I want a history row, whoever makes the change."

### The problem in plain words

`LOT_HISTORY` has one row per status change of a lot: `hist_id`, `lot_id`, `old_status`, `new_status`, when, by whom, and a note. It starts with 147 rows. The trigger watches `LOTS`: each time an `UPDATE` changes the status of a row, it adds one history row. The test puts `L26-003` on hold through `fab_reports.hold_lot`, which knows nothing about history, and the count should go from 147 to 148. Then the two error cases of `hold_lot` and an update of only the hold reason should add nothing.

### The code

```sql
CREATE OR REPLACE TRIGGER lots_status_hist_trg
AFTER UPDATE OF status ON lots
FOR EACH ROW
WHEN (OLD.status <> NEW.status)
BEGIN
  INSERT INTO lot_history (hist_id, lot_id, old_status, new_status, changed_at, changed_by, note)
  VALUES (lot_history_seq.NEXTVAL, :NEW.lot_id, :OLD.status, :NEW.status, SYSDATE, USER, 'set by trigger');
END lots_status_hist_trg;
/
SELECT COUNT(*) AS history_rows FROM lot_history;
BEGIN fab_reports.hold_lot('L26-003', 'Particle check'); END;
/
SELECT hist_id, lot_id, old_status, new_status, note
FROM   lot_history
WHERE  hist_id >= 1000
ORDER  BY hist_id;
SELECT COUNT(*) AS history_rows FROM lot_history;
```

The guard cases:

```sql
BEGIN fab_reports.hold_lot('L26-003', 'again'); END;
/
BEGIN fab_reports.hold_lot('L26-999', 'x'); END;
/
UPDATE lots SET hold_reason = 'Particle check, second look' WHERE lot_id = 'L26-003';
SELECT COUNT(*) AS history_rows FROM lot_history;
```

### How the code runs

**Step 1. CREATE TRIGGER.** Oracle compiles the trigger and attaches it to `LOTS`. It is enabled at once. Nothing is inserted yet. Like every `CREATE`, it commits first.

**Step 2. The count** shows 147 rows.

**Step 3. `fab_reports.hold_lot('L26-003', 'Particle check')`.** `check_lot` returns `v_status` = `ACTIVE`, the `IF v_status = 'HOLD'` is false, and the `UPDATE` runs. It sets `status`, so `AFTER UPDATE OF status` applies, and `FOR EACH ROW` means the trigger runs once for the one changed row. For that row, `:OLD.status` = `ACTIVE` (before the update) and `:NEW.status` = `HOLD` (after). `:NEW.lot_id` = `L26-003`. The `WHEN (OLD.status <> NEW.status)` test is `'ACTIVE' <> 'HOLD'`, true, so the trigger body runs. The `INSERT` takes `lot_history_seq.NEXTVAL` = 1000 (the first value of a fresh sequence), `SYSDATE` (the date and time now), `USER` (your user name) and the note `set by trigger`.

**Step 4. The two queries** show the new row and a count of 148.

**Step 5. `hold_lot('L26-003', 'again')`.** `check_lot` now returns `HOLD`, so the `IF` is true and line 84 of the body raises `ORA-20102`. No `UPDATE`, so no trigger.

**Step 6. `hold_lot('L26-999', 'x')`.** Inside `check_lot`, the `SELECT ... INTO` finds no row and raises `NO_DATA_FOUND`. The handler raises `ORA-20101` on line 11 of the body. The error leaves `check_lot` and passes through `hold_lot` at line 82, the line that called `check_lot`. That is why there are two `ORA-06512` lines for the package.

**Step 7. `UPDATE lots SET hold_reason = ...`.** This `UPDATE` does not set `status`, so the `OF status` part means the trigger does not fire at all. The `WHEN` clause guards a different case: an `UPDATE` that sets `status` to the value it already has. The count stays at 148.

### Output

```text
Trigger created.

HISTORY_ROWS
------------
         147

PL/SQL procedure successfully completed.

   HIST_ID LOT_ID     OLD_STAT NEW_STAT NOTE
---------- ---------- -------- -------- ----------------
      1000 L26-003    ACTIVE   HOLD     set by trigger

HISTORY_ROWS
------------
         148
```

```text
ORA-20102: Lot L26-003 is already on hold
ORA-06512: at "FAB_LAB.FAB_REPORTS", line 84
ORA-06512: at line 1

ORA-20101: Lot L26-999 does not exist
ORA-06512: at "FAB_LAB.FAB_REPORTS", line 11
ORA-06512: at "FAB_LAB.FAB_REPORTS", line 82
ORA-06512: at line 1

1 row updated.

HISTORY_ROWS
------------
         148
```

### What to notice

`hold_lot` knows nothing about `LOT_HISTORY`. The trigger did the recording. The hold-reason update left the history alone because it did not touch the status. Your `hist_id` is 1000 only if nobody has used the sequence before. On a fresh install it is 1000.

## Exercise 6: Manage the trigger and meet ORA-04091

**Maya asks:** "Can we switch the recording off for a moment? And why can't a trigger on LOTS simply count the lots on hold?"

### The problem in plain words

`USER_TRIGGERS` has one row per trigger you own, with its type, the event it listens to and whether it is enabled. 6a disables the history trigger, puts `L26-007` on hold with a plain `UPDATE`, and counts `LOT_HISTORY`: the count should stay at 148. Then it enables the trigger again. 6b creates a second trigger on `LOTS` that reads `LOTS` itself, and shows the error that follows.

### The code

```sql
SELECT trigger_name, trigger_type, triggering_event, status FROM user_triggers;
ALTER TRIGGER lots_status_hist_trg DISABLE;
SELECT trigger_name, status FROM user_triggers;
UPDATE lots SET status = 'HOLD', hold_reason = 'test' WHERE lot_id = 'L26-007';
SELECT COUNT(*) AS history_rows FROM lot_history;
ALTER TRIGGER lots_status_hist_trg ENABLE;
SELECT trigger_name, status FROM user_triggers;
```

With the trigger disabled, `L26-007` went on hold and no history row appeared. Now the mutating-table error:

```sql
CREATE OR REPLACE TRIGGER lots_count_holds_trg
BEFORE UPDATE ON lots
FOR EACH ROW
DECLARE
  v_holds NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_holds FROM lots WHERE status = 'HOLD';
END;
/
UPDATE lots SET priority = priority WHERE lot_id = 'L26-003';
DROP TRIGGER lots_count_holds_trg;
```

### How the code runs

**Step 1. USER_TRIGGERS** shows one trigger: `AFTER EACH ROW`, on `UPDATE`, `ENABLED`.

**Step 2. ALTER TRIGGER ... DISABLE.** The trigger stays in the schema, but Oracle skips it. Like all DDL, it commits first, so the hold of `L26-003` from exercise 5 is now committed.

**Step 3. The UPDATE of `L26-007`.** The status changes from `ACTIVE` to `HOLD`, but the trigger is disabled, so no history row is written. The count stays at 148.

**Step 4. ALTER TRIGGER ... ENABLE.** The trigger works again from now on. It does not go back and record the change it missed.

**Step 5. CREATE TRIGGER lots_count_holds_trg.** It compiles without a problem: the `SELECT` on `LOTS` is valid code. The mistake only shows when it runs.

**Step 6. The UPDATE of `L26-003`.** Before Oracle changes the row, it runs the new `BEFORE UPDATE ... FOR EACH ROW` trigger for it. The trigger's `SELECT COUNT(*) ... FROM lots` on line 4 (counting from `DECLARE` as line 1) tries to read `LOTS` while an `UPDATE` on `LOTS` is in the middle of changing rows. Oracle does not allow a row trigger to read the table it is attached to (the "mutating" table) and raises `ORA-04091`. The error stops the trigger, and the whole `UPDATE` fails, so nothing is changed. `ORA-04088` names the trigger.

**Step 7. DROP TRIGGER** removes the broken trigger.

### Output

```text
TRIGGER_NAME           TRIGGER_TYPE     TRIGGERI STATUS
---------------------- ---------------- -------- ---------
LOTS_STATUS_HIST_TRG   AFTER EACH ROW   UPDATE   ENABLED

Trigger altered.

TRIGGER_NAME           STATUS
---------------------- ---------
LOTS_STATUS_HIST_TRG   DISABLED

1 row updated.

HISTORY_ROWS
------------
         148

Trigger altered.

TRIGGER_NAME           STATUS
---------------------- ---------
LOTS_STATUS_HIST_TRG   ENABLED
```

```text
Trigger created.

UPDATE lots SET priority = priority WHERE lot_id = 'L26-003'
       *
ERROR at line 1:
ORA-04091: table FAB_LAB.LOTS is mutating, trigger/function may not see it
ORA-06512: at "FAB_LAB.LOTS_COUNT_HOLDS_TRG", line 4
ORA-04088: error during execution of trigger 'FAB_LAB.LOTS_COUNT_HOLDS_TRG'

Trigger dropped.
```

### What to notice

The hole in the history is the price of disabling a trigger: the data is now out of step with the audit trail. This is why you re-enable it at once and check `USER_TRIGGERS`. The `ORA-04088` line names the trigger that raised the error.

## Exercise 7: Clean up

**Maya asks:** "Put it all back the way it was."

### The problem in plain words

`L26-003` and `L26-007` are on hold and should be `ACTIVE` with an empty hold reason. `LOT_HISTORY` should go back to its 147 rows, so every row with `hist_id` 1000 or more must go. The history trigger must be dropped. The checks show the two lots, 147 history rows and 0 triggers.

### The code

```sql
ROLLBACK;
UPDATE lots SET status = 'ACTIVE', hold_reason = NULL WHERE lot_id IN ('L26-003', 'L26-007');
DELETE FROM lot_history WHERE hist_id >= 1000;
COMMIT;
DROP TRIGGER lots_status_hist_trg;
SELECT lot_id, status, hold_reason FROM lots WHERE lot_id IN ('L26-003', 'L26-007');
SELECT COUNT(*) AS history_rows FROM lot_history;
SELECT COUNT(*) AS my_triggers FROM user_triggers;
```

### How the code runs

**Step 1. ROLLBACK.** There is nothing to undo. The last change, the hold of `L26-007`, was committed by the `ALTER TRIGGER ... ENABLE` that followed it, and the failed `UPDATE` in 6b changed nothing.

**Step 2. The UPDATE of the two lots.** The status changes from `HOLD` to `ACTIVE` for both rows, and the history trigger is enabled, so it fires once per row. In this run it wrote `hist_id` 1001 for `L26-003` (`:OLD.status` = `HOLD`, `:NEW.status` = `ACTIVE`) and 1002 for `L26-007` (the same change). `LOT_HISTORY` now has 150 rows.

**Step 3. The DELETE** removes the three rows 1000, 1001 and 1002.

**Step 4. COMMIT** makes the repair permanent.

**Step 5. DROP TRIGGER** removes the history trigger.

**Step 6. The checks** show both lots `ACTIVE` with an empty reason, 147 history rows and no triggers.

### Output

```text
Rollback complete.

2 rows updated.

3 rows deleted.

Commit complete.

Trigger dropped.

LOT_ID     STATUS    HOLD_REASON
---------- --------- ------------------------------------------------------------
L26-003    ACTIVE
L26-007    ACTIVE

HISTORY_ROWS
------------
         147

MY_TRIGGERS
-----------
          0
```

### What to notice

Three rows were deleted: the one from `hold_lot`, and two more that the restoring `UPDATE` created because the trigger was still enabled. The `ROLLBACK` at the top found nothing to undo, because DDL (`ALTER TRIGGER`, `CREATE TRIGGER`, `DROP TRIGGER`) had already committed the earlier changes. The sequence is not rolled back or restored. The next `hist_id` will be higher than 1002, which does no harm.
