# Lab 16: Functions and procedures

**Time:** 45 minutes. **Reading first:** [Functions and procedures](../topics/04-functions-and-procedures.md).

> **You keep four objects from this lab.** You create `wafer_yield`, `thickness_status`, `print_lot_report` and `hold_lot`, and Lab 17 builds a package on them. Use exactly these names and parameters. One of them, `hold_lot`, changes `LOTS`, so you test it with manual commit and end with `ROLLBACK`.

## The story

Maya keeps asking the same three things: the PRIME percentage of a lot, whether a reading is in range, and a one-page summary of a lot. "Stop writing a new query each time," she says. "Give me buttons." You will turn her questions into stored functions and procedures, call them from a `SELECT`, and finish with one action: putting a lot on hold, with proper errors.

## What you will do

- write two functions and call them inside queries
- write a procedure that prints a report using a cursor loop
- write a procedure that changes data, raises your own errors, and undo its work
- look at what is stored, and read a compile error

## Before you start

1. In DBeaver, switch the `fab-lab` connection to **Manual Commit** (the transaction button in the toolbar, as in Lab 7). Switch back to Auto when you finish.
2. Open [`lab16_functions_and_procedures.sql`](scripts/lab16_functions_and_procedures.sql) and open the Output panel (**Ctrl + Shift + O**, or **SQL Editor > Show Server Output**) before you run anything. `DBMS_OUTPUT` lines appear there.
3. Run each `CREATE OR REPLACE` statement on its own: select the whole statement, from `CREATE` down to its `END ...;` line, and press **Ctrl + Enter**. Do the same with each `BEGIN ... END;` call. One at a time. A plain `SELECT` runs with the cursor inside it and **Ctrl + Enter**.
4. Do not leave blank lines inside a function or procedure. DBeaver can cut the statement in two at a blank line. If you want space, use a line holding only `--`.
5. If a `CREATE` reports a compile error, read it with `SELECT line, position, text FROM user_errors WHERE name = 'WAFER_YIELD' ORDER BY sequence;` (with your object's name in capitals). Exercise 6 practises this.

Solutions, with the four finished definitions: [lab-16-solutions.md](../solutions/lab-16-solutions.md).

## Exercise 1: The function wafer_yield

Maya: "What percentage of a lot's graded wafers are PRIME? One decimal. If the lot has no graded wafer, give me nothing."

Create `FUNCTION wafer_yield(p_lot_id VARCHAR2) RETURN NUMBER`. Count the graded wafers and the PRIME wafers of the lot. Return `NULL` when no wafer is graded, otherwise the PRIME share, rounded to one decimal. Then test it:

```sql
SELECT wafer_yield('L26-003') AS l003, wafer_yield('L26-012') AS l012,
       wafer_yield('L26-008') AS l008, wafer_yield('L26-999') AS l999
FROM   dual;
```

<details>
<summary>Hint 1: two counts</summary>

`COUNT(grade)` counts the wafers that have a grade. `COUNT(CASE WHEN grade = 'PRIME' THEN 1 END)` counts the PRIME ones. One `SELECT ... INTO` can fill both variables.
</details>

<details>
<summary>Hint 2: the NULL rule</summary>

If the graded count is 0, `RETURN NULL;` before you divide.
</details>

<details>
<summary>Hint 3: skeleton</summary>

```sql
CREATE OR REPLACE FUNCTION wafer_yield(p_lot_id VARCHAR2) RETURN NUMBER IS
  v_graded NUMBER;
  v_prime  NUMBER;
BEGIN
  SELECT COUNT(grade), COUNT(CASE WHEN ___ THEN 1 END)
  INTO   v_graded, v_prime
  FROM   wafers WHERE lot_id = p_lot_id;
  IF ___ THEN RETURN NULL; END IF;
  RETURN ROUND(___ / ___ * 100, 1);
END wafer_yield;
/
```
</details>

**Checkpoint:** `80`, `100`, `0` and an empty value.

**Common trap:** writing `p_lot_id VARCHAR2(12)`. Parameters take a type without a length, and the length version is a syntax error. Another one: counting with `COUNT(*)` instead of `COUNT(grade)`. Lot `L26-012` has four wafers but only two graded ones, and `COUNT(*)` would give 50 instead of 100.

## Exercise 2: Use the function in a query

Maya: "Show me the lots with a yield below 90 percent, lowest first."

<details>
<summary>Hint 1: where the function goes</summary>

A function works anywhere an expression works: in the `SELECT` list, in `WHERE`, in `ORDER BY`.
</details>

<details>
<summary>Hint 2: ordering</summary>

`ORDER BY yield_pct, lot_id` puts the lowest yield first and breaks ties by lot.
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

```sql
SELECT lot_id, status, wafer_yield(lot_id) AS yield_pct
FROM   lots
WHERE  wafer_yield(lot_id) < ___
ORDER  BY yield_pct, lot_id;
```
</details>

**Checkpoint:** 10 lots. `L26-008` first with 0, then nine lots with 80.

**Common trap:** a lot with `NULL` yield is never returned by `< 90`, because a comparison with `NULL` is unknown. In this data no lot has a `NULL` yield, but a lot with no graded wafers would silently disappear from this list.

## Exercise 3: The function thickness_status

Maya: "Give me a word for a reading: LOW below 90 percent of the target, HIGH above 110 percent, otherwise OK."

Create `FUNCTION thickness_status(p_thickness NUMBER, p_target NUMBER) RETURN VARCHAR2`. Mark it `DETERMINISTIC`. Return `NULL` if either input is `NULL`. Test it with three calls (`100, 100`), (`89.9, 100`) and (`110.1, 100`), then count readings per step and status:

<details>
<summary>Hint 1: the shape</summary>

You wrote this rule as an `IF`/`ELSIF` in Lab 14. Put it inside a function and replace each `PUT_LINE` with a `RETURN`.
</details>

<details>
<summary>Hint 2: the declaration</summary>

```sql
CREATE OR REPLACE FUNCTION thickness_status(p_thickness NUMBER, p_target NUMBER)
  RETURN VARCHAR2 DETERMINISTIC IS
```
</details>

<details>
<summary>Hint 3: the report query</summary>

Join `MEASUREMENTS` to `WAFERS` to `LOTS` to `PRODUCTS`, and call `thickness_status(m.thickness_nm, p.target_thk_nm)`. Group by the step and by the same function call, and count.
</details>

**Checkpoint:** `OK`, `LOW`, `HIGH`. In the report, `FINAL` has 62 readings, all `OK`, and `SPLIT` has 62, all `HIGH`. `ANNEAL` splits into 34 `HIGH` and 28 `OK`.

**Common trap:** the boundaries. A reading of exactly 90 or 110 percent is `OK`, because the tests use `<` and `>`.

## Exercise 4: The procedure print_lot_report

Maya: "Print a short report for a lot: a header with the product and target, one line per wafer with its grade, its FINAL thickness and the status word, and a last line with the wafer count and the yield."

Create `PROCEDURE print_lot_report(p_lot_id VARCHAR2)`. Use a cursor loop over the lot's wafers with a `LEFT JOIN` to their `FINAL` measurement, and use both of your functions. If the lot does not exist, print `Lot ... does not exist`.

Start the wafer lines with `- `. Some tools, SQL*Plus among them, drop spaces at the start of an output line, and the dash keeps the lines readable everywhere.

<details>
<summary>Hint 1: the header</summary>

`SELECT l.status, p.product_code, p.target_thk_nm INTO ...` joined on `product_id`. If the lot does not exist, this raises `NO_DATA_FOUND`, which your `EXCEPTION` section can turn into the message.
</details>

<details>
<summary>Hint 2: the wafer lines</summary>

`LEFT JOIN measurements m ON m.wafer_id = w.wafer_id AND m.step = 'FINAL'` keeps wafers that have no FINAL reading. The condition on `step` belongs in the `ON`, not in a `WHERE`.
</details>

<details>
<summary>Hint 3: the last line</summary>

Count the wafers in a variable inside the loop. Call `wafer_yield(p_lot_id)` after the loop. `NVL(TO_CHAR(...), 'n/a')` handles a `NULL`.
</details>

**Checkpoint:** `BEGIN print_lot_report('L26-005'); END;` prints a header, four wafer lines all `OK`, and `Wafers: 4   Yield: 100 %`. For `L26-999` it prints `Lot L26-999 does not exist`.

**Common trap:** putting `m.step = 'FINAL'` in the `WHERE` clause. That turns the left join back into an inner join, and wafers with no reading disappear, so `L26-012` would print no wafer lines at all.

## Exercise 5: The procedure hold_lot

Maya: "Put a lot on hold and write down why."

Create `PROCEDURE hold_lot(p_lot_id VARCHAR2, p_reason VARCHAR2)`. It sets `LOTS.status` to `'HOLD'` and `LOTS.hold_reason` to the reason. It raises `RAISE_APPLICATION_ERROR(-20101, ...)` when the lot does not exist and `RAISE_APPLICATION_ERROR(-20102, ...)` when the lot is already on hold. It does not commit.

Test it with manual commit on, and undo the change:

```sql
BEGIN hold_lot('L26-010', 'Particle check'); END;
/
SELECT lot_id, status, hold_reason FROM lots WHERE lot_id = 'L26-010';
BEGIN hold_lot('L26-010', 'Again'); END;
/
BEGIN hold_lot('L26-999', 'Nothing'); END;
/
ROLLBACK;
SELECT lot_id, status, hold_reason FROM lots WHERE lot_id = 'L26-010';
```

Also call it once with named notation: `hold_lot(p_reason => 'Again', p_lot_id => 'L26-010')`.

<details>
<summary>Hint 1: the checks come first</summary>

Read the lot's status before you update. No row means "does not exist". A status of `HOLD` means "already on hold".
</details>

<details>
<summary>Hint 2: an inner block for the missing lot</summary>

`SELECT ... INTO` raises `NO_DATA_FOUND`. A small inner `BEGIN ... EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(...) END;` turns it into your error.
</details>

<details>
<summary>Hint 3: the update</summary>

```sql
UPDATE lots SET status = 'HOLD', hold_reason = p_reason WHERE lot_id = p_lot_id;
```
Always keep the `WHERE`.
</details>

**Checkpoint:** after the first call the lot is `HOLD` with `Particle check`. The second call fails with `ORA-20102`, the third with `ORA-20101`. After `ROLLBACK` the lot is `ACTIVE` again with an empty reason. Two lots are on hold in total (`L26-003B` and `L26-005`).

**Common trap:** forgetting the `ROLLBACK`, which leaves `L26-010` on hold for every exercise that follows, and for Lab 17. Check the final query. Another trap: the reason column holds at most 60 characters, so a longer text fails with `ORA-12899`.

## Exercise 6: What is stored, and a function that does not compile

- **(a)** List your functions and procedures with their status.
- **(b)** Count the lines of source of each object.
- **(c)** Create `FUNCTION double_it(p_x NUMBER) RETURN NUMBER` with `RETURN p_x * 2` missing its semicolon. Read the error in `USER_ERRORS`, fix the function, call it, and drop it.

<details>
<summary>Hint 1: the views</summary>

`USER_OBJECTS` has `object_name`, `object_type` and `status`. `USER_SOURCE` has `name`, `type`, `line` and `text`.
</details>

<details>
<summary>Hint 2: counting</summary>

`SELECT name, type, COUNT(*) FROM user_source GROUP BY name, type`
</details>

<details>
<summary>Hint 3: the error</summary>

`SELECT line, position, text FROM user_errors WHERE name = 'DOUBLE_IT';` The error is reported at the `END` line, one line after the real mistake.
</details>

**Checkpoint:** the four lab objects, all `VALID`. `DOUBLE_IT` is `INVALID` after the first attempt and `VALID` after the fix, and `double_it(21)` is 42. Your line counts may differ from the solutions if you formatted the code differently.

**Common trap:** looking at the line number in the error as if it were exact. The parser notices the problem when it reaches `END`.

## Finish

1. Check that `L26-010` is `ACTIVE` and that two lots are on hold:

   ```sql
   SELECT lot_id, status FROM lots WHERE status = 'HOLD' OR lot_id = 'L26-010' ORDER BY lot_id;
   ```

   Expected: `L26-003B` HOLD, `L26-005` HOLD, `L26-010` ACTIVE.

2. Keep `wafer_yield`, `thickness_status`, `print_lot_report` and `hold_lot`. Lab 17 uses them.
3. Switch DBeaver back to **Auto** commit mode.

## What you learned

- A function returns one value and can be used inside a `SELECT`. A procedure does a job.
- Parameters have a type and no length. They can be `IN`, `OUT` or `IN OUT`, with defaults and named notation.
- `RAISE_APPLICATION_ERROR` turns a business rule into a clear error for the caller.
- `USER_OBJECTS`, `USER_SOURCE` and `USER_ERRORS` show what is stored and why it failed.
