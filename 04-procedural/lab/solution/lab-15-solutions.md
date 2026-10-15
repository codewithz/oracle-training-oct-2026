# Lab 15 solutions: Exceptions

Try each exercise yourself first. Your block may differ from these and still be right: compare the output, not the spelling. The runnable file is [`lab15_solutions.sql`](scripts/lab15_solutions.sql).

Each exercise has the same four parts: the problem in plain words, the block, how the block runs (taken apart in the order Oracle runs it: `DECLARE` first, then each statement between `BEGIN` and `EXCEPTION` from top to bottom, and the `EXCEPTION` section only when an error is raised), and the output with what to notice.

All outputs and the in-between values in the breakdowns came from running the blocks, and copies of them with extra `PUT_LINE` lines, on the lab data (Oracle 21c XE; 19c gives the same results). The outputs are shown as SQL*Plus prints them. In DBeaver the printed lines appear in the Output panel, and errors and status messages look a little different. Error messages name the constraint with your schema in front, for example `FAB_LAB.LOTS_PK`.

To run a block in DBeaver, open the Output panel (`Ctrl + Shift + O`), select the whole block from `DECLARE` (or `BEGIN`) down to `END;`, and press `Ctrl + Enter`.

Two ideas carry this whole lab:

- **An error makes Oracle jump.** As soon as a statement raises an error, the rest of the `BEGIN` part is skipped and Oracle goes to the `EXCEPTION` section of the same block. It runs the first `WHEN` that names the error. After the handler, the block ends normally.
- **No matching handler, no rescue.** If no `WHEN` matches, or there is no `EXCEPTION` section, the error leaves the block and the tool shows it as `ORA-...`.

## Exercise 1: NO_DATA_FOUND

**Maya asks:** "What is the status of lot L26-999?"

### The problem in plain words

One row of `LOTS` should give the status of one lot. For a lot that exists, the answer is one line, `<lot> is <status>`. L26-999 does not exist, so there is no row, and Maya wants a sentence instead of an error. The same block runs twice: once for L26-999 and once for L26-005.

### The block

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-999';
  v_status  lots.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM lots WHERE lot_id = v_lot;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' is ' || v_status);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('No lot called ' || v_lot);
END;
/
```

The script has this block twice, the second time with `'L26-005'` as the starting value.

### How the block runs

For L26-999:

**Step 1. DECLARE.** `v_lot` = `'L26-999'`, `v_status` = `NULL`.

**Step 2. SELECT INTO.** No row has lot id L26-999, so the query returns no row. Oracle raises `NO_DATA_FOUND` (ORA-01403). `v_status` stays `NULL`.

**Step 3. Jump to EXCEPTION.** The `PUT_LINE` on the next line is skipped. In the `EXCEPTION` section, `WHEN NO_DATA_FOUND` matches, so its `PUT_LINE` runs and prints `No lot called L26-999`.

**Step 4. END.** The error has been handled, so the block ends normally: "successfully completed".

For L26-005:

**Step 1. DECLARE.** `v_lot` = `'L26-005'`, `v_status` = `NULL`.

**Step 2. SELECT INTO.** One row, status HOLD. `v_status` = `'HOLD'`.

**Step 3. PUT_LINE.** Prints `L26-005 is HOLD`. No error was raised, so the `EXCEPTION` section is never reached.

### Output

```text
No lot called L26-999

PL/SQL procedure successfully completed.
```

With `v_lot` set to `'L26-005'`:

```text
L26-005 is HOLD

PL/SQL procedure successfully completed.
```

### What to notice

The block ends with "successfully completed" in both cases. Once the handler has run, the error is dealt with.

## Exercise 2: TOO_MANY_ROWS

**Maya asks:** "Which wafer is in lot L26-003?"

### The problem in plain words

`WAFERS` has one row per wafer. Lot L26-003 has five of them, so "which wafer" has five answers, and `SELECT ... INTO` one variable cannot hold five. The block catches that error and lists the five wafer ids instead, one per line, in slot order.

### The block

```sql
DECLARE
  v_wafer wafers.wafer_id%TYPE;
BEGIN
  SELECT wafer_id INTO v_wafer FROM wafers WHERE lot_id = 'L26-003';
  DBMS_OUTPUT.PUT_LINE('Wafer: ' || v_wafer);
EXCEPTION
  WHEN TOO_MANY_ROWS THEN
    DBMS_OUTPUT.PUT_LINE('More than one wafer in L26-003, listing them instead:');
    FOR w IN (SELECT wafer_id FROM wafers WHERE lot_id = 'L26-003' ORDER BY slot_no) LOOP
      DBMS_OUTPUT.PUT_LINE(w.wafer_id);
    END LOOP;
END;
/
```

### How the block runs

**Step 1. DECLARE.** `v_wafer` = `NULL`.

**Step 2. SELECT INTO.** The query finds five rows. `SELECT ... INTO` allows exactly one, so Oracle raises `TOO_MANY_ROWS` (ORA-01422: exact fetch returns more than requested number of rows).

**Step 3. Jump to EXCEPTION.** `PUT_LINE('Wafer: ' ...)` is skipped. `WHEN TOO_MANY_ROWS` matches. The handler prints its first line, then runs an ordinary cursor `FOR` loop:

- Pass 1: `w.wafer_id` = `'L26-003-01'`, printed.
- Pass 2: `'L26-003-02'`, printed.
- Passes 3 to 5: `'L26-003-03'`, `'L26-003-04'`, `'L26-003-05'`.

**Step 4. END.** Handled, so the block ends normally.

### Output

```text
More than one wafer in L26-003, listing them instead:
L26-003-01
L26-003-02
L26-003-03
L26-003-04
L26-003-05

PL/SQL procedure successfully completed.
```

### What to notice

The better fix is to start with the right tool. A question that can return many rows belongs in a cursor loop, and `SELECT INTO` is for questions with one row.

## Exercise 3: ZERO_DIVIDE and VALUE_ERROR

**Maya asks:** "What percentage of lot L26-999 is PRIME?"

### The problem in plain words

From `WAFERS`, two counts for one lot: all wafers and PRIME wafers. The share is PRIME divided by all, times 100, printed as one line. For a lot with no wafers the division has nothing to divide by, and Maya wants `n/a` instead of an error. The same block runs for L26-999 and L26-003. A third block tries to turn the text `'812.5 nm'` into a number.

### The block

```sql
DECLARE
  v_lot    wafers.lot_id%TYPE := 'L26-999';
  v_total  NUMBER;
  v_prime  NUMBER;
BEGIN
  SELECT COUNT(*), COUNT(CASE WHEN grade = 'PRIME' THEN 1 END)
  INTO   v_total, v_prime
  FROM   wafers WHERE lot_id = v_lot;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' PRIME share: ' || ROUND(v_prime / v_total * 100, 1) || ' %');
EXCEPTION
  WHEN ZERO_DIVIDE THEN
    DBMS_OUTPUT.PUT_LINE(v_lot || ' PRIME share: n/a (no wafers)');
END;
/
```

The script has this block twice, the second time with `'L26-003'` as the starting value.

### How the block runs

For L26-999:

**Step 1. DECLARE.** `v_lot` = `'L26-999'`, `v_total` and `v_prime` are `NULL`.

**Step 2. SELECT INTO.** Both counts are aggregates, so the query returns one row even though no wafer matches: `v_total` = 0, `v_prime` = 0. No error so far.

**Step 3. PUT_LINE.** To build the text, Oracle works out `v_prime / v_total`, which is 0 / 0. That raises `ZERO_DIVIDE` (ORA-01476: divisor is equal to zero). Nothing is printed by this line.

**Step 4. Jump to EXCEPTION.** `WHEN ZERO_DIVIDE` matches and prints the n/a line.

For L26-003:

**Step 2. SELECT INTO.** `v_total` = 5, `v_prime` = 4.

**Step 3. PUT_LINE.** 4 / 5 * 100 = 80, `ROUND(80, 1)` is 80. Prints `L26-003 PRIME share: 80 %`. No error, so the `EXCEPTION` section is not reached.

### Output

```text
L26-999 PRIME share: n/a (no wafers)

PL/SQL procedure successfully completed.
```

With `v_lot` set to `'L26-003'`:

```text
L26-003 PRIME share: 80 %

PL/SQL procedure successfully completed.
```

### Then the text conversion

```sql
DECLARE
  v_reading NUMBER;
BEGIN
  v_reading := TO_NUMBER('812.5 nm');
  DBMS_OUTPUT.PUT_LINE('Reading: ' || v_reading);
EXCEPTION
  WHEN VALUE_ERROR THEN
    DBMS_OUTPUT.PUT_LINE('Not a number: 812.5 nm');
END;
/
```

**Step 1. DECLARE.** `v_reading` = `NULL`.

**Step 2. The assignment.** `TO_NUMBER('812.5 nm')` cannot read ` nm` as part of a number. Because this is a PL/SQL assignment, Oracle raises `VALUE_ERROR` (ORA-06502: character to number conversion error). `v_reading` stays `NULL`.

**Step 3. Jump to EXCEPTION.** The `PUT_LINE('Reading: ' ...)` is skipped. `WHEN VALUE_ERROR` matches and prints its line.

```text
Not a number: 812.5 nm

PL/SQL procedure successfully completed.
```

### What to notice

`COUNT(*)` returned 0 and no error, and the error came only at the division. The `LOT_HISTORY.NOTE` column holds readings written like `812.5 nm`, which is why free text needs cleaning before conversion (Day 3 shows regular expressions for it).

## Exercise 4: Constraint errors

**Maya asks:** "What happens if someone tries to add a lot that already exists, or a wafer for a lot that does not exist?"

### The problem in plain words

Two inserts that the table rules forbid. (a) `LOTS` already has a row L26-001, and its primary key does not allow a second one. (b) `WAFERS` has a foreign key to `LOTS`, and lot L26-999 does not exist. Each block prints one sentence instead of the raw error. Both inserts fail, so a count of `LOTS` and `WAFERS` afterwards must still say 16 and 66.

### The block

```sql
BEGIN
  INSERT INTO lots (lot_id, product_id, lot_type, start_date, status, priority)
  VALUES ('L26-001', 1, 'PROD', DATE '2026-10-12', 'ACTIVE', 2);
  DBMS_OUTPUT.PUT_LINE('Inserted');
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('Lot L26-001 already exists, nothing inserted');
END;
/
DECLARE
  e_no_parent EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_no_parent, -2291);
BEGIN
  INSERT INTO wafers (wafer_id, lot_id, slot_no, grade)
  VALUES ('L26-999-01', 'L26-999', 1, 'PRIME');
  DBMS_OUTPUT.PUT_LINE('Inserted');
EXCEPTION
  WHEN e_no_parent THEN
    DBMS_OUTPUT.PUT_LINE('Lot L26-999 does not exist, wafer not inserted');
END;
/
SELECT (SELECT COUNT(*) FROM lots) AS lots, (SELECT COUNT(*) FROM wafers) AS wafers FROM dual;
```

These are two blocks and one query. Run them one at a time.

### How the block runs

**Block (a), step 1. No DECLARE.** The block needs no variables, so it starts with `BEGIN`.

**Block (a), step 2. INSERT.** The new row has lot id L26-001, which is already in `LOTS`. The primary key `LOTS_PK` refuses it with `ORA-00001: unique constraint (FAB_LAB.LOTS_PK) violated`. In PL/SQL this error has the name `DUP_VAL_ON_INDEX`. No row is added.

**Block (a), step 3. Jump to EXCEPTION.** `PUT_LINE('Inserted')` is skipped. `WHEN DUP_VAL_ON_INDEX` matches and prints its sentence.

**Block (b), step 1. DECLARE.** `e_no_parent EXCEPTION` creates a new exception name. `PRAGMA EXCEPTION_INIT(e_no_parent, -2291)` ties that name to error number -2291, so from now on ORA-02291 inside this block counts as `e_no_parent`.

**Block (b), step 2. INSERT.** The wafer points to lot L26-999. The foreign key `WAFERS_LOT_FK` finds no such lot and refuses the row with `ORA-02291: integrity constraint (FAB_LAB.WAFERS_LOT_FK) violated - parent key not found`. SQLCODE is -2291. No row is added.

**Block (b), step 3. Jump to EXCEPTION.** `WHEN e_no_parent` matches, because of the pragma, and prints its sentence. Without the pragma there would be no name to catch, and the block would stop with the raw ORA-02291.

**The check query.** Counts both tables: still 16 lots and 66 wafers.

### Output

```text
Lot L26-001 already exists, nothing inserted

PL/SQL procedure successfully completed.

Lot L26-999 does not exist, wafer not inserted

PL/SQL procedure successfully completed.


      LOTS     WAFERS
---------- ----------
        16         66
```

### What to notice

A failed insert leaves nothing behind, so the counts are unchanged. The pragma gave the foreign key error a readable name.

## Exercise 5: Your own exceptions

**Maya asks:** "Only ACTIVE lots can be put on hold. Check lot L26-004."

### The problem in plain words

One row of `LOTS` gives the status of L26-004. If it is ACTIVE, the lot can be put on hold and the block says so. If not, that is a business rule being broken, and Oracle knows nothing about this rule, so we raise the error ourselves. Three versions: (a) with our own exception name and a handler, (b) with `RAISE_APPLICATION_ERROR` and no handler, (c) like (b) with a `WHEN OTHERS` handler that prints the error code and text.

### The block

**(a)** A declared exception:

```sql
DECLARE
  e_not_active EXCEPTION;
  v_lot     lots.lot_id%TYPE := 'L26-004';
  v_status  lots.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM lots WHERE lot_id = v_lot;
  IF v_status <> 'ACTIVE' THEN
    RAISE e_not_active;
  END IF;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' can be put on hold');
EXCEPTION
  WHEN e_not_active THEN
    DBMS_OUTPUT.PUT_LINE(v_lot || ' is ' || v_status || ', only ACTIVE lots can be put on hold');
END;
/
```

**(b)** `RAISE_APPLICATION_ERROR` with no handler:

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-004';
  v_status  lots.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM lots WHERE lot_id = v_lot;
  IF v_status <> 'ACTIVE' THEN
    RAISE_APPLICATION_ERROR(-20001, v_lot || ' is ' || v_status || ', only ACTIVE lots can be put on hold');
  END IF;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' can be put on hold');
END;
/
```

**(c)** The same block with a `WHEN OTHERS` handler:

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-004';
  v_status  lots.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM lots WHERE lot_id = v_lot;
  IF v_status <> 'ACTIVE' THEN
    RAISE_APPLICATION_ERROR(-20001, v_lot || ' is ' || v_status || ', only ACTIVE lots can be put on hold');
  END IF;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' can be put on hold');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SQLCODE ' || SQLCODE);
    DBMS_OUTPUT.PUT_LINE('SQLERRM ' || SQLERRM);
END;
/
```

### How the block runs

**(a), step 1. DECLARE.** `e_not_active` is a new exception name, with no error number behind it. `v_lot` = `'L26-004'`, `v_status` = `NULL`.

**(a), step 2. SELECT INTO.** Lot L26-004 is SHIPPED, so `v_status` = `'SHIPPED'`.

**(a), step 3. The IF.** `'SHIPPED' <> 'ACTIVE'` is true, so `RAISE e_not_active` runs. Oracle jumps straight to the `EXCEPTION` section; the `PUT_LINE` that says "can be put on hold" is skipped.

**(a), step 4. EXCEPTION.** `WHEN e_not_active` matches. `v_status` still holds `'SHIPPED'`, so the message can use it. The block ends normally.

**(b), steps 1 and 2.** The same, without the exception name: `v_status` = `'SHIPPED'`.

**(b), step 3. The IF.** True again, so `RAISE_APPLICATION_ERROR(-20001, ...)` runs. It raises an error with number -20001 and our text: `L26-004 is SHIPPED, only ACTIVE lots can be put on hold`.

**(b), step 4. No EXCEPTION section.** Nothing catches the error, so the block stops and the error goes back to the tool. `ORA-06512: at line 7` is the line of `RAISE_APPLICATION_ERROR`.

**(c), steps 1 to 3.** As in (b): the error -20001 is raised on line 7.

**(c), step 4. EXCEPTION.** `WHEN OTHERS` catches any error. Inside the handler `SQLCODE` is the error number, -20001, and `SQLERRM` is the full message with the `ORA-20001:` prefix. Both are printed, and the block ends normally.

### Output

**(a)**

```text
L26-004 is SHIPPED, only ACTIVE lots can be put on hold

PL/SQL procedure successfully completed.
```

**(b)**

```text
DECLARE
*
ERROR at line 1:
ORA-20001: L26-004 is SHIPPED, only ACTIVE lots can be put on hold
ORA-06512: at line 7
```

**(c)**

```text
SQLCODE -20001
SQLERRM ORA-20001: L26-004 is SHIPPED, only ACTIVE lots can be put on hold

PL/SQL procedure successfully completed.
```

### What to notice

In (a) the exception works inside one block only. In (b) the error leaves the block with your own text and a number, which is what a caller of a stored procedure sees (Lab 16's `hold_lot` does this).

## Exercise 6: One bad lot must not stop the loop

**Maya asks:** "Print the status of L26-001, L26-999 and L26-005. If one lot is missing, say so and carry on."

### The problem in plain words

Three lot ids, one printed line for each. For a lot that exists, the line gives its status from `LOTS`. L26-999 does not exist; its line says it was skipped, and the loop goes on to L26-005. The second part looks at a block that hides its error, and rewrites it so the error shows.

### The block

```sql
BEGIN
  FOR r IN (SELECT 'L26-001' AS lot_id FROM dual
            UNION ALL SELECT 'L26-999' FROM dual
            UNION ALL SELECT 'L26-005' FROM dual) LOOP
    DECLARE
      v_status lots.status%TYPE;
    BEGIN
      SELECT status INTO v_status FROM lots WHERE lot_id = r.lot_id;
      DBMS_OUTPUT.PUT_LINE(r.lot_id || ' is ' || v_status);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(r.lot_id || ' not found, skipped');
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(r.lot_id || ' unexpected error ' || SQLCODE || ': ' || SQLERRM);
    END;
  END LOOP;
END;
/
```

### How the block runs

**Step 1. The outer block.** It has no `DECLARE`. The `FOR` loop runs the `UNION ALL` query, which returns three rows: L26-001, L26-999, L26-005.

**Step 2. One pass per row.** Each pass runs the inner block, from its `DECLARE` to its `END;`. The inner block is new each time, so `v_status` starts as `NULL` on every pass.

- Pass 1: `r.lot_id` = `'L26-001'`. `SELECT INTO` finds the row, `v_status` = `'SHIPPED'`. Prints `L26-001 is SHIPPED`. No error.
- Pass 2: `r.lot_id` = `'L26-999'`. `SELECT INTO` finds no row and raises `NO_DATA_FOUND`. The inner `PUT_LINE` is skipped, and Oracle jumps to the inner `EXCEPTION` section. `WHEN NO_DATA_FOUND` matches and prints `L26-999 not found, skipped`. The inner block ends normally, so the loop is not disturbed.
- Pass 3: `r.lot_id` = `'L26-005'`. `v_status` = `'HOLD'`. Prints `L26-005 is HOLD`.

**Step 3. WHEN OTHERS.** It is there for any other error, but none happens in these three passes, so it never runs.

### Output

```text
L26-001 is SHIPPED
L26-999 not found, skipped
L26-005 is HOLD

PL/SQL procedure successfully completed.
```

### The silent block

```sql
DECLARE
  v_status lots.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM lots WHERE lot_id = 'L26-5';
  DBMS_OUTPUT.PUT_LINE('status is ' || v_status);
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/
```

**Step 1. DECLARE.** `v_status` = `NULL`.

**Step 2. SELECT INTO.** The lot id `L26-5` is a typo and does not exist. `NO_DATA_FOUND` is raised (SQLCODE 100, `ORA-01403: no data found`).

**Step 3. EXCEPTION.** `WHEN OTHERS` matches every error, and `NULL;` means "do nothing". The error is gone and nothing is printed.

The block prints only "PL/SQL procedure successfully completed." Nothing says that the lookup failed.

### The visible version

```sql
DECLARE
  v_status lots.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM lots WHERE lot_id = 'L26-5';
  DBMS_OUTPUT.PUT_LINE('status is ' || v_status);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('No lot called L26-5');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Unexpected: ' || SQLCODE || ' ' || SQLERRM);
    RAISE;
END;
/
```

**Steps 1 and 2.** The same: `NO_DATA_FOUND` is raised by the `SELECT`.

**Step 3. EXCEPTION.** Oracle checks the `WHEN` clauses from the top. `WHEN NO_DATA_FOUND` matches first and prints `No lot called L26-5`. `WHEN OTHERS` is not reached. Any other error would go to `WHEN OTHERS`, which prints the code and text and then `RAISE;` sends the same error on to the caller.

```text
No lot called L26-5

PL/SQL procedure successfully completed.
```

### What to notice

The inner block deals with a bad lot and the loop moves to the next one. In the second version, the expected problem gets a clear message. An unexpected one prints its code and is raised again, so it cannot pass unseen.
