# Lab 13 solutions: First PL/SQL blocks

Try each exercise yourself first. Your block may differ from these and still be right: compare the output, not the spelling. The runnable file is [`lab13_solutions.sql`](scripts/lab13_solutions.sql).

Each exercise has the same four parts: the problem in plain words, the block, how the block runs (taken apart in the order Oracle runs it: `DECLARE` first, then each statement between `BEGIN` and `END` from top to bottom), and the output with what to notice.

All outputs and the in-between values in the breakdowns came from running the blocks, and copies of them with extra `PUT_LINE` lines, on the lab data (Oracle 21c XE; 19c gives the same results). The outputs are shown as SQL*Plus prints them. In DBeaver the printed lines appear in the Output panel, and the status messages look a little different.

To run a block in DBeaver, open the Output panel (`Ctrl + Shift + O`), select the whole block from `DECLARE` down to `END;`, and press `Ctrl + Enter`.

Two ideas carry this whole lab:

- **A block runs top to bottom.** First `DECLARE` creates the variables. A variable with no starting value is `NULL`. Then the statements between `BEGIN` and `END` run one after the other.
- **`SELECT ... INTO` needs exactly one row.** It copies the columns of that row into the variables after `INTO`, in the same order. No row gives `ORA-01403`; more than one row gives `ORA-01422`.

## Exercise 1: How many lots?

**Maya asks:** "How many lots does the fab have? One sentence, please."

### The problem in plain words

The table is `LOTS`, one row per lot. Maya wants one printed line, a sentence with the number of lots in it. The number comes from `COUNT(*)` over `LOTS`, which always returns exactly one row with one value.

### The block

```sql
DECLARE
  v_lots NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_lots FROM lots;
  DBMS_OUTPUT.PUT_LINE('The fab has ' || v_lots || ' lots');
END;
/
```

### How the block runs

**Step 1. DECLARE.** Oracle creates one variable, `v_lots`, of type `NUMBER`. It has no starting value, so it is `NULL`.

**Step 2. SELECT COUNT(*) INTO v_lots.** The query counts the rows of `LOTS` and gets 16. `INTO` copies that one value into `v_lots`, so `v_lots` is now 16.

**Step 3. PUT_LINE.** `||` glues three pieces together: `'The fab has '`, the value of `v_lots` (Oracle turns 16 into the text `16` by itself), and `' lots'`. The line goes into the output buffer.

**Step 4. END.** The block is finished. SQL*Plus prints the buffer, then "PL/SQL procedure successfully completed."

### Output

```text
The fab has 16 lots

PL/SQL procedure successfully completed.
```

### What to notice

The query is the one you already know. `INTO` moves its single result into the variable, and `||` joins the number to the text.

## Exercise 2: Product and target of one lot

**Maya asks:** "Which product is lot L26-009, and what is its target thickness?"

### The problem in plain words

`LOTS` knows which product a lot makes (`product_id`). `PRODUCTS` knows the product code and the target thickness. A join on `product_id` gives one row for one lot. Maya wants one printed line with the lot, the product code and the target.

### The block

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-009';
  v_code    products.product_code%TYPE;
  v_target  products.target_thk_nm%TYPE;
BEGIN
  SELECT p.product_code, p.target_thk_nm
  INTO   v_code, v_target
  FROM   lots l JOIN products p ON p.product_id = l.product_id
  WHERE  l.lot_id = v_lot;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' makes ' || v_code || ', target ' || v_target || ' nm');
END;
/
```

### How the block runs

**Step 1. DECLARE.** Three variables:

- `v_lot` gets the type of `LOTS.LOT_ID` and the starting value `'L26-009'`.
- `v_code` gets the type of `PRODUCTS.PRODUCT_CODE`. No starting value, so `NULL`.
- `v_target` gets the type of `PRODUCTS.TARGET_THK_NM`. Also `NULL`.

**Step 2. SELECT ... INTO.** The `WHERE` uses `v_lot`, so Oracle looks for lot L26-009. That lot has `product_id` 4, and product 4 is PHO-300 with target 220. The query returns one row: `PHO-300`, `220`. `INTO` copies the first column into the first variable and the second into the second: `v_code` = `'PHO-300'`, `v_target` = 220.

**Step 3. PUT_LINE.** The line is built from `v_lot`, `v_code` and `v_target`.

### Output

```text
L26-009 makes PHO-300, target 220 nm

PL/SQL procedure successfully completed.
```

### What to notice

Putting the lot id in a variable means only one line changes when Maya asks about another lot. The `%TYPE` declarations follow the table columns.

## Exercise 3: A whole row

**Maya asks:** "Tell me the status, start date and hold reason of lot L26-003B."

### The problem in plain words

All three facts are columns of one row of `LOTS`, the row of lot L26-003B. Instead of three variables, we take the whole row into one record variable and print the fields we want on two lines.

### The block

```sql
DECLARE
  r lots%ROWTYPE;
BEGIN
  SELECT * INTO r FROM lots WHERE lot_id = 'L26-003B';
  DBMS_OUTPUT.PUT_LINE('Lot ' || r.lot_id || ' is ' || r.status
                       || ' since its start on ' || TO_CHAR(r.start_date, 'DD-MON-YYYY'));
  DBMS_OUTPUT.PUT_LINE('Reason: ' || r.hold_reason);
END;
/
```

### How the block runs

**Step 1. DECLARE.** `r lots%ROWTYPE` creates a record with one field for each of the eight columns of `LOTS`: `r.lot_id`, `r.product_id`, `r.lot_type`, `r.parent_lot_id`, `r.start_date`, `r.status`, `r.priority`, `r.hold_reason`. All eight fields start as `NULL`.

**Step 2. SELECT * INTO r.** The query finds the one row of L26-003B and copies every column into the field of the same position:

```text
r.lot_id        L26-003B
r.product_id    1
r.lot_type      SPLIT
r.parent_lot_id L26-003
r.start_date    14-AUG-2026
r.status        HOLD
r.priority      1
r.hold_reason   Thickness out of spec at FINAL
```

**Step 3. First PUT_LINE.** Reads `r.lot_id` and `r.status`, and turns `r.start_date` into text with `TO_CHAR(..., 'DD-MON-YYYY')`. The statement is split over two lines; that is fine, because it ends only at the `;`.

**Step 4. Second PUT_LINE.** Prints `r.hold_reason`.

### Output

```text
Lot L26-003B is HOLD since its start on 14-AUG-2026
Reason: Thickness out of spec at FINAL

PL/SQL procedure successfully completed.
```

### What to notice

One record variable replaced eight scalar ones. The wording "since its start" is a little odd, because a hold begins later than the lot start; `LOTS` keeps only the start date. `LOT_HISTORY` has the time of the hold.

## Exercise 4: Average thickness against target

**Maya asks:** "For lot L26-009, how close is the average FINAL thickness to the product target, as a percentage?"

### The problem in plain words

Two numbers are needed. The first is the average of the FINAL readings of the lot's wafers: `MEASUREMENTS` has the readings, `WAFERS` tells which lot a wafer belongs to. The second is the target of the lot's product, from `LOTS` joined to `PRODUCTS` as in exercise 2. Then one division, and three printed lines: the average, the target and the percentage.

### The block

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-009';
  v_avg     NUMBER;
  v_target  products.target_thk_nm%TYPE;
  v_pct     NUMBER;
BEGIN
  SELECT AVG(m.thickness_nm)
  INTO   v_avg
  FROM   measurements m JOIN wafers w ON w.wafer_id = m.wafer_id
  WHERE  w.lot_id = v_lot AND m.step = 'FINAL';
  --
  SELECT p.target_thk_nm
  INTO   v_target
  FROM   lots l JOIN products p ON p.product_id = l.product_id
  WHERE  l.lot_id = v_lot;
  --
  v_pct := v_avg / v_target * 100;
  DBMS_OUTPUT.PUT_LINE('Average FINAL: ' || ROUND(v_avg, 2) || ' nm');
  DBMS_OUTPUT.PUT_LINE('Target:        ' || v_target || ' nm');
  DBMS_OUTPUT.PUT_LINE('Percent:       ' || ROUND(v_pct, 1) || ' %');
END;
/
```

The two `--` lines only give some space. A blank line inside a block can make DBeaver cut the block in two, so the scripts use a comment line instead.

### How the block runs

**Step 1. DECLARE.** `v_lot` = `'L26-009'`. `v_avg`, `v_target` and `v_pct` are all `NULL`.

**Step 2. First SELECT INTO.** The join keeps the five FINAL readings of lot L26-009:

```text
WAFER_ID         STEP     THICKNESS_NM
---------------- -------- ------------
L26-009-01       FINAL          222.79
L26-009-02       FINAL          220.11
L26-009-03       FINAL          217.67
L26-009-04       FINAL           216.6
L26-009-05       FINAL          221.72
```

`AVG` turns them into one value, 219.778, and `INTO` puts it in `v_avg`.

**Step 3. Second SELECT INTO.** Lot L26-009 makes PHO-300, so `v_target` = 220.

**Step 4. The calculation.** `v_pct := 219.778 / 220 * 100`, which is 99.899090909... `v_pct` keeps all the decimals.

**Step 5. The three PUT_LINE lines.** Rounding happens only here: `ROUND(v_avg, 2)` prints 219.78 and `ROUND(v_pct, 1)` prints 99.9. The variables themselves are not changed.

### Output

```text
Average FINAL: 219.78 nm
Target:        220 nm
Percent:       99.9 %

PL/SQL procedure successfully completed.
```

### What to notice

Two small queries and one line of arithmetic. In SQL you could do the same in one query with a join, and that is often the better answer. The block pays off when the next step needs a decision, which is the subject of the next lab.

## Exercise 5: Fix the broken block

**Maya asks:** "The block in the script should tell me that L26-005 is HOLD and has 4 wafers. It does not run. Can you fix it?"

### The problem in plain words

This is a debugging exercise. The block reads the status of lot L26-005 from `LOTS` and counts its wafers in `WAFERS`, then prints one line. It has four mistakes. Fixing them one at a time shows how Oracle reports each kind: syntax errors first, while it reads the block, and runtime errors only after the block compiles.

The broken block, as it is in the lab script:

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-005';
  v_status  VARCHAR2(3);
  v_wafers  NUMBER
BEGIN
  SELECT status FROM lots WHERE lot_id = v_lot;
  SELECT COUNT(*) INTO v_wafers FROM wafers WHERE lot_id = v_lot;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' is ' || v_status || ' and has ' || v_wafers || ' wafers')
END;
/
```

### The four errors, one at a time

**Error 1. A missing semicolon after `v_wafers NUMBER`.**

```text
BEGIN
*
ERROR at line 5:
ORA-06550: line 5, column 1:
PLS-00103: Encountered the symbol "BEGIN" when expecting one of the following:
:= . ( @ % ; not null range default character
The symbol ";" was substituted for "BEGIN" to continue.
ORA-06550: line 9, column 1:
PLS-00103: Encountered the symbol "END" when expecting one of the following:
:= . ( % ;
The symbol ";" was substituted for "END" to continue.
```

What Oracle saw: on line 4 it read `v_wafers NUMBER` and then expected the end of that declaration, a `;`, or something more about it, such as `:=` for a starting value. Instead the next word was `BEGIN` on line 5. It cannot tell you "line 4 has no semicolon"; it can only say where it got stuck and what it was waiting for. That is why the error points at the line after the real mistake. Oracle guessed a `;` and read on, and found a second problem at line 9: the `END` message. The fix: add `;` after `NUMBER`.

**Error 2. A missing semicolon after the last `PUT_LINE`.** With the first fix in, only the `END` error is left:

```text
END;
*
ERROR at line 9:
ORA-06550: line 9, column 1:
PLS-00103: Encountered the symbol "END" when expecting one of the following:
:= . ( % ;
The symbol ";" was substituted for "END" to continue.
```

What Oracle saw: the `PUT_LINE(...)` call on line 8 was not closed by a `;`, and the next word was `END`. Every statement inside `BEGIN ... END` needs its own semicolon. The fix: add `;` at the end of line 8.

**Error 3. A `SELECT` without `INTO`.**

```text
  SELECT status FROM lots WHERE lot_id = v_lot;
  *
ERROR at line 6:
ORA-06550: line 6, column 3:
PLS-00428: an INTO clause is expected in this SELECT statement
```

What Oracle saw: a `SELECT` inside a block that does not say where its result should go. In a block there is no result grid to show rows in, so every `SELECT` must put its values into variables. The fix: `SELECT status INTO v_status FROM lots ...`.

**Error 4. `VARCHAR2(3)` is too small for `HOLD`.** Now the block compiles and runs, and fails while running:

```text
DECLARE
*
ERROR at line 1:
ORA-06502: PL/SQL: numeric or value error: character string buffer too small
ORA-06512: at line 6
```

What Oracle saw: line 6 tried to copy the status `HOLD` (4 characters) into `v_status`, which holds at most 3. Oracle does not cut the text short; it stops with `ORA-06502`. `ORA-06512: at line 6` says which line of the block was running. The fix: declare `v_status lots.status%TYPE`, so the variable is always as wide as the column.

### The block

The corrected block:

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-005';
  v_status  lots.status%TYPE;
  v_wafers  NUMBER;
BEGIN
  SELECT status INTO v_status FROM lots WHERE lot_id = v_lot;
  SELECT COUNT(*) INTO v_wafers FROM wafers WHERE lot_id = v_lot;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' is ' || v_status || ' and has ' || v_wafers || ' wafers');
END;
/
```

### How the block runs

**Step 1. DECLARE.** `v_lot` = `'L26-005'`. `v_status` (as wide as `LOTS.STATUS`) and `v_wafers` are `NULL`.

**Step 2. First SELECT INTO.** Lot L26-005 has status HOLD, so `v_status` = `'HOLD'`.

**Step 3. Second SELECT INTO.** `COUNT(*)` over the wafers of L26-005 gives 4, so `v_wafers` = 4.

**Step 4. PUT_LINE.** Prints the sentence from the three variables.

### Output

```text
L26-005 is HOLD and has 4 wafers

PL/SQL procedure successfully completed.
```

### What to notice

The compiler reports syntax errors first and can only say what it expected next. A runtime error such as `ORA-06502` appears only after the block compiles. `lots.status%TYPE` removes the last class of mistake for good.

## Exercise 6: One block, three lots

**Maya asks:** "Do the same count for L26-003, L26-003B and L26-999."

### The problem in plain words

The same block runs three times; only the starting value of `v_lot` changes. Each run counts the rows of `WAFERS` for one lot and prints one line. L26-999 does not exist, which is the interesting case. Then a second block asks for the status of L26-999 and shows what `SELECT ... INTO` does when there is no row at all.

### The block

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-003';
  v_wafers  NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_wafers FROM wafers WHERE lot_id = v_lot;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' has ' || v_wafers || ' wafers');
END;
/
```

The script has this block three times, with `'L26-003'`, `'L26-003B'` and `'L26-999'` as the starting value.

### How the block runs

**Step 1. DECLARE.** `v_lot` gets the lot of this run. `v_wafers` is `NULL`.

**Step 2. SELECT COUNT(*) INTO v_wafers.** For L26-003 the count is 5, for L26-003B it is 2. For L26-999 no wafer matches, but `COUNT(*)` still returns one row, with the value 0. So `INTO` has its one row and `v_wafers` = 0.

**Step 3. PUT_LINE.** Prints one line per run.

### Output

```text
L26-003 has 5 wafers
L26-003B has 2 wafers
L26-999 has 0 wafers
```

### Then the status of the lot that does not exist

```sql
DECLARE
  v_lot     lots.lot_id%TYPE := 'L26-999';
  v_status  lots.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM lots WHERE lot_id = v_lot;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' is ' || v_status);
END;
/
```

**Step 1. DECLARE.** `v_lot` = `'L26-999'`, `v_status` = `NULL`.

**Step 2. SELECT status INTO v_status.** This is a plain column query, with no `COUNT`. There is no row for L26-999, so the query returns no row at all, and `INTO` has nothing to copy. Oracle raises `ORA-01403: no data found` (its PL/SQL name is `NO_DATA_FOUND`).

**Step 3. The rest is skipped.** The block has no `EXCEPTION` section, so the error stops the block on line 5. The `PUT_LINE` never runs, and the error goes back to the tool.

```text
DECLARE
*
ERROR at line 1:
ORA-01403: no data found
ORA-06512: at line 5
```

### What to notice

`COUNT(*)` always returns exactly one row, so an unknown lot gives 0 and no error. A query that selects a column returns no row for an unknown lot, so `SELECT ... INTO` raises `NO_DATA_FOUND`. `ORA-06512: at line 5` points at the `SELECT`. You will catch this error in Lab 15.
