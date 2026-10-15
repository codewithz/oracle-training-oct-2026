# Lab 15: Exceptions

**Time:** 35 minutes. **Reading first:** [Exceptions](../topics/03-exceptions.md).

> **Your data does not change in this lab.** The only `INSERT` statements are written to fail, and exercise 4 ends with a check that the row counts are still 16 lots and 66 wafers. If you ever see `1 row inserted` there, run `ROLLBACK;` and tell the trainer.

## The story

Maya is tired of raw Oracle errors on her screen. "If I ask for a lot that does not exist, I want a sentence, not an `ORA-01403`." You will catch the common errors, say something useful for each, and make sure that a bad lot in a list does not stop the rest.

## What you will do

- catch `NO_DATA_FOUND`, `TOO_MANY_ROWS`, `ZERO_DIVIDE` and `VALUE_ERROR`
- catch constraint errors, naming one with `PRAGMA EXCEPTION_INIT`
- declare and raise your own exception, and use `RAISE_APPLICATION_ERROR`
- keep a loop alive with a nested block
- see how `WHEN OTHERS THEN NULL` hides a typo

## Before you start

1. Connect to `fab-lab` in DBeaver and open [`lab15_exceptions.sql`](scripts/lab15_exceptions.sql) with **File > Open File**.
2. Open the Output panel before you run anything: **Ctrl + Shift + O** (or SQL Editor menu, **Show Server Output**). The text from `PUT_LINE` appears there.
3. Run one block at a time: select the whole block, from its first line (`DECLARE` or `BEGIN`) down to its `END;`, and press **Ctrl + Enter**. A plain `SELECT` can be run with the cursor inside it.
4. Write each block with `END;` followed by a line that holds only `/`, and leave no blank lines inside a block. Do not run the whole script with **Alt + X**.

If you use SQL*Plus instead of DBeaver, run `SET SERVEROUTPUT ON` once before the first block.

Solutions: [lab-15-solutions.md](../solutions/lab-15-solutions.md).

## Exercise 1: NO_DATA_FOUND

Maya: "What is the status of lot L26-999?" There is no such lot.

Write a block that reads the status with `SELECT ... INTO` and prints it. When there is no row, print `No lot called L26-999`. Then run the same block for `L26-005`.

<details>
<summary>Hint 1: where the handler goes</summary>

In the `EXCEPTION` section, between the last statement and `END;`.
</details>

<details>
<summary>Hint 2: the name</summary>

`WHEN NO_DATA_FOUND THEN ...`
</details>

<details>
<summary>Hint 3: skeleton</summary>

```sql
DECLARE
  v_lot    lots.lot_id%TYPE := 'L26-999';
  v_status lots.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM lots WHERE lot_id = v_lot;
  DBMS_OUTPUT.PUT_LINE(v_lot || ' is ' || v_status);
EXCEPTION
  WHEN ___ THEN
    DBMS_OUTPUT.PUT_LINE('No lot called ' || v_lot);
END;
/
```
</details>

**Checkpoint:** `No lot called L26-999`, then `L26-005 is HOLD`.

**Common trap:** the `PUT_LINE` that prints the status comes before the handler, so when the lot is missing it is skipped. That is the expected behaviour. Control jumps to the handler as soon as the error occurs.

## Exercise 2: TOO_MANY_ROWS

Maya: "Which wafer is in lot L26-003?" There are five of them.

Read `wafer_id` into one variable with `SELECT ... INTO` and catch `TOO_MANY_ROWS`. In the handler, print a message and list the wafers with a cursor loop instead.

<details>
<summary>Hint 1: why the error</summary>

`SELECT INTO` needs exactly one row. L26-003 has five wafers.
</details>

<details>
<summary>Hint 2: loops in handlers</summary>

A handler is ordinary PL/SQL. You can put a `FOR r IN (SELECT ...) LOOP` in it.
</details>

<details>
<summary>Hint 3: order</summary>

`ORDER BY slot_no` puts the wafers in slot order.
</details>

**Checkpoint:** five lines, `L26-003-01` to `L26-003-05`.

**Common trap:** catching `NO_DATA_FOUND` and expecting it to cover this case. Each exception has its own name. If you want both, write two `WHEN` clauses.

## Exercise 3: ZERO_DIVIDE and VALUE_ERROR

Maya: "What percentage of lot L26-999 is PRIME?"

Count all the wafers and the PRIME wafers of the lot, then divide. Catch `ZERO_DIVIDE` and print `n/a (no wafers)`. Run the block again for `L26-003`. After that, convert the text `'812.5 nm'` to a number with `TO_NUMBER` and catch `VALUE_ERROR`.

<details>
<summary>Hint 1: the counts</summary>

`COUNT(*)` counts all wafers and `COUNT(CASE WHEN grade = 'PRIME' THEN 1 END)` counts the PRIME ones. Both come back in one row, even for a lot that does not exist.
</details>

<details>
<summary>Hint 2: where the division happens</summary>

In PL/SQL, not in the query. The query only counts, so it never fails. The error is raised when you divide.
</details>

<details>
<summary>Hint 3: the text conversion</summary>

`v_reading := TO_NUMBER('812.5 nm');` is a PL/SQL statement, so the exception is `VALUE_ERROR`.
</details>

**Checkpoint:** `n/a (no wafers)` for L26-999, `80 %` for L26-003, then your message for the text.

**Common trap:** putting the division inside the `SELECT`. `SELECT COUNT(...)/COUNT(*)` raises the same `ORA-01476` from inside SQL, and the handler still catches it, but the statement fails as a whole. Doing the division in PL/SQL keeps your two counts available for printing.

## Exercise 4: Constraint errors

Both inserts below are meant to fail. If one succeeds, run `ROLLBACK;`.

- **(a)** Insert a lot with the id `L26-001` (columns: `lot_id`, `product_id`, `lot_type`, `start_date`, `status`, `priority`; use product 1, type `PROD`, today's date, `ACTIVE`, priority 2). Catch `DUP_VAL_ON_INDEX` and print that the lot already exists.
- **(b)** Insert a wafer `L26-999-01` for lot `L26-999`, slot 1, grade `PRIME`. This breaks a foreign key (`ORA-02291`), which has no predefined name. Declare an exception, attach the number with `PRAGMA EXCEPTION_INIT`, and catch it.

Finish with the check query in the script.

<details>
<summary>Hint 1: which exception for (a)?</summary>

A primary key violation is `DUP_VAL_ON_INDEX`.
</details>

<details>
<summary>Hint 2: the pragma</summary>

```sql
e_no_parent EXCEPTION;
PRAGMA EXCEPTION_INIT(e_no_parent, -2291);
```
Both lines go in `DECLARE`.
</details>

<details>
<summary>Hint 3: the sign</summary>

The number is `-2291`, with a minus. Without it the pragma refers to a different, non-existing error and your handler never fires.
</details>

**Checkpoint:** two messages, then `16` lots and `66` wafers.

**Common trap:** an insert that does succeed because you chose a new lot id. The point of this exercise is the failure, so use `L26-001` exactly.

## Exercise 5: Your own exceptions

Maya: "Only ACTIVE lots can be put on hold. Check lot L26-004."

- **(a)** Declare `e_not_active EXCEPTION;`, read the lot's status, `RAISE e_not_active` when it is not `ACTIVE`, and print a message in a handler.
- **(b)** Do the same with `RAISE_APPLICATION_ERROR(-20001, ...)` and no handler. Read the error that arrives.
- **(c)** Add `WHEN OTHERS` that prints `SQLCODE` and `SQLERRM`.

<details>
<summary>Hint 1: two ways to signal</summary>

`RAISE name;` for an exception you declared. `RAISE_APPLICATION_ERROR(number, text)` for an error with a message the caller can read.
</details>

<details>
<summary>Hint 2: the range</summary>

The number must be between -20000 and -20999.
</details>

<details>
<summary>Hint 3: handler order</summary>

In (c), `WHEN OTHERS` must be the last `WHEN`.
</details>

**Checkpoint:** (a) `L26-004 is SHIPPED, only ACTIVE lots can be put on hold`, (b) `ORA-20001` with the same text, (c) `SQLCODE -20001`.

**Common trap:** using a number such as `-1000`. Oracle answers `ORA-21000: error number argument to raise_application_error of -1000 is out of range`.

## Exercise 6: One bad lot must not stop the loop

Maya: "Print the status of L26-001, L26-999 and L26-005. If one lot is missing, say so and carry on."

Loop over the three lot ids (the script gives a `UNION ALL` list you can use). Put a small block with its own `EXCEPTION` section inside the loop body.

Then look at the second block in the script comments. It runs, says "success" and prints nothing. Find out why, and rewrite its handler so the problem is visible.

<details>
<summary>Hint 1: the shape</summary>

```sql
FOR r IN (...) LOOP
  DECLARE ... BEGIN
    ...
  EXCEPTION
    WHEN NO_DATA_FOUND THEN ...
  END;
END LOOP;
```
</details>

<details>
<summary>Hint 2: what happens without the inner block</summary>

An unhandled error in the loop body leaves the loop, and the lots after the bad one are never read.
</details>

<details>
<summary>Hint 3: the silent block</summary>

The lot id is `'L26-5'`, which does not exist. `NO_DATA_FOUND` is raised and `WHEN OTHERS THEN NULL` swallows it. Catch `NO_DATA_FOUND` for the expected case, and in `WHEN OTHERS` print `SQLCODE` and `SQLERRM`, then `RAISE;`.
</details>

**Checkpoint:** three lines: `L26-001 is SHIPPED`, `L26-999 not found, skipped`, `L26-005 is HOLD`. The corrected second block prints `No lot called L26-5`.

**Common trap:** `WHEN OTHERS THEN NULL` is the most dangerous line in PL/SQL. It turns every bug into silence.

## Finish

Confirm the counts one more time:

```sql
SELECT (SELECT COUNT(*) FROM lots) AS lots, (SELECT COUNT(*) FROM wafers) AS wafers FROM dual;
```

It should still say 16 and 66.

## What you learned

- A handler catches an error by name, and control continues after the block that handled it.
- `SELECT INTO` raises `NO_DATA_FOUND` or `TOO_MANY_ROWS`.
- `PRAGMA EXCEPTION_INIT` gives a name to an Oracle error number.
- `RAISE_APPLICATION_ERROR` sends your own text and a code to the caller.
- A nested block keeps a loop going, and a bare `WHEN OTHERS` hides bugs.
