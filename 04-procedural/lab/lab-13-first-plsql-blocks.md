# Lab 13: First PL/SQL blocks

**Time:** 35 minutes. **Reading first:** [PL/SQL blocks](../topics/01-plsql-blocks.md).

> **Your data is only read in this lab.** The blocks you write select from `LOTS`, `PRODUCTS`, `WAFERS` and `MEASUREMENTS` and print results. Nothing is changed.

## The story

Maya has been asking for the same little answers all week: how many lots, which product, how close to target. "Can you make the database tell me in a sentence?" she asks. You will write your first blocks, and each one will print a sentence she can read.

## What you will do

- print text with `DBMS_OUTPUT.PUT_LINE`
- declare variables and fill them with `SELECT ... INTO`
- use `%TYPE` and `%ROWTYPE` so you do not have to guess column types
- read four typical error messages and fix a block that does not compile
- see what happens when `SELECT ... INTO` finds no row

## Before you start

1. Connect to `fab-lab` in DBeaver and open [`lab13_first_plsql_blocks.sql`](scripts/lab13_first_plsql_blocks.sql) with **File > Open File**.
2. Open the Output panel before you run anything: **Ctrl + Shift + O** (or SQL Editor menu, **Show Server Output**). The text from `PUT_LINE` appears there.
3. Run one block at a time: select the whole block, from its first line (`DECLARE` or `BEGIN`) down to its `END;`, and press **Ctrl + Enter**. A plain `SELECT` can be run with the cursor inside it.
4. Write each block with `END;` followed by a line that holds only `/`, and leave no blank lines inside a block. Do not run the whole script with **Alt + X**.

If you use SQL*Plus instead of DBeaver, run `SET SERVEROUTPUT ON` once before the first block.

Solutions: [lab-13-solutions.md](../solutions/lab-13-solutions.md).

## Exercise 1: How many lots?

Maya: "How many lots does the fab have? One sentence, please."

Write a block with a variable `v_lots`, fill it from `COUNT(*)`, and print `The fab has ... lots`.

<details>
<summary>Hint 1: the three parts</summary>

`DECLARE` the variable, `BEGIN` with a `SELECT ... INTO` and a `PUT_LINE`, then `END;` and a `/` on its own line.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
DECLARE
  v_lots NUMBER;
BEGIN
  SELECT COUNT(*) INTO ___ FROM ___;
  DBMS_OUTPUT.PUT_LINE('The fab has ' || ___ || ' lots');
END;
/
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The table is `lots` and the variable after `INTO` is `v_lots`.
</details>

**Checkpoint:** the sentence says 16.

**Common trap:** the block runs, you see "PL/SQL procedure successfully completed" and no sentence. The Output panel was not open when the block ran. Open it with **Ctrl + Shift + O** and run the block again. (In SQL*Plus the same symptom means `SET SERVEROUTPUT ON` has not been run.)

## Exercise 2: Product and target of one lot

Maya: "Which product is lot L26-009, and what is its target thickness?"

Declare `v_lot` with the starting value `'L26-009'`. Declare the other variables with `%TYPE` taken from the `PRODUCTS` columns. One `SELECT ... INTO` with a join gives both values.

<details>
<summary>Hint 1: which tables?</summary>

`LOTS` knows the `product_id`. `PRODUCTS` knows the code and the target. Join them on `product_id`.
</details>

<details>
<summary>Hint 2: the declarations</summary>

`v_code products.product_code%TYPE;` and `v_target products.target_thk_nm%TYPE;`
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

```sql
SELECT p.product_code, p.target_thk_nm
INTO   v_code, v_target
FROM   lots l JOIN products p ON p.product_id = l.product_id
WHERE  l.lot_id = v_lot;
```
</details>

**Checkpoint:** `PHO-300` and `220`.

**Common trap:** the order after `INTO` must match the order in the `SELECT`. Swap them and you put the target into the code variable, which fails with `ORA-06502`.

## Exercise 3: A whole row

Maya: "Tell me the status, start date and hold reason of lot L26-003B."

Declare `r lots%ROWTYPE`, fill it with `SELECT * INTO r`, and print fields with `r.status`, `r.start_date` and `r.hold_reason`. Format the date with `TO_CHAR`.

<details>
<summary>Hint 1: the record</summary>

A `%ROWTYPE` variable is a record with one field per column. You read a field with a dot.
</details>

<details>
<summary>Hint 2: printing the date</summary>

`TO_CHAR(r.start_date, 'DD-MON-YYYY')`
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

```sql
SELECT * INTO r FROM lots WHERE lot_id = 'L26-003B';
DBMS_OUTPUT.PUT_LINE('Lot ' || r.lot_id || ' is ' || r.status || ' since its start on ' || ___);
```
</details>

**Checkpoint:** status `HOLD`, start date `14-AUG-2026`.

**Common trap:** `SELECT lot_id, status INTO r ...` with only two columns. The columns must match the record, so use `SELECT *` or declare matching variables.

## Exercise 4: Average thickness against target

Maya: "For lot L26-009, how close is the average FINAL thickness to the product target, as a percentage?"

You need two numbers: the average FINAL thickness of the lot's wafers, and the target of its product. Use two `SELECT ... INTO` statements, then calculate `average / target * 100` and print three lines: the average (2 decimals), the target and the percentage (1 decimal).

<details>
<summary>Hint 1: the average</summary>

Join `MEASUREMENTS` to `WAFERS` to reach the lot, and filter on `step = 'FINAL'`.
</details>

<details>
<summary>Hint 2: the target</summary>

You wrote this query in exercise 2.
</details>

<details>
<summary>Hint 3: rounding</summary>

`ROUND(v_avg, 2)` and `ROUND(v_pct, 1)`. Round when you print, so the variable keeps full precision.
</details>

**Checkpoint:** average `219.78` nm, `99.9` percent.

**Common trap:** a variable that was declared but never filled is `NULL`, and `NULL / 220 * 100` is `NULL`. The sentence then prints with an empty space. If a result is blank, print each variable to find which one is empty.

## Exercise 5: Fix the broken block

The script contains a block with four mistakes. Run it, read the error, fix one thing, and run it again. Do not fix everything at once, because Oracle reports the syntax errors first and the runtime errors only after the block compiles.

The block should print `L26-005 is HOLD and has 4 wafers`.

<details>
<summary>Hint 1: how to read the error</summary>

`PLS-00103: Encountered the symbol "BEGIN" when expecting one of the following` usually means that the line before the one named is missing something. Look at the line above.
</details>

<details>
<summary>Hint 2: what to look for</summary>

Two statements end without a semicolon. One `SELECT` has no `INTO`. One variable is too small for its value.
</details>

<details>
<summary>Hint 3: the order</summary>

The first error names `BEGIN` (line 5 of the block): the `DECLARE` section needs a semicolon after `NUMBER`. After that fix the error names `END`: the `PUT_LINE` needs its semicolon. Then comes `PLS-00428` (add `INTO v_status`), and last comes `ORA-06502: character string buffer too small`, for `VARCHAR2(3)`. Use `lots.status%TYPE` and it can never be too small.
</details>

**Checkpoint:** `L26-005 is HOLD and has 4 wafers`.

**Common trap:** the position in an error message is where the parser noticed the problem, which can be a line after the real mistake.

## Exercise 6: One block, three lots

Maya: "Do the same count for L26-003, L26-003B and L26-999."

Write a block that counts the wafers of the lot in `v_lot`, and prints `<lot> has <n> wafers`. Run it three times, changing only the value of `v_lot`.

Then change the block so it reads the **status** of `L26-999` with `SELECT status INTO ...` and read the error.

<details>
<summary>Hint 1: what changes between runs</summary>

Only the starting value in `DECLARE`: `v_lot lots.lot_id%TYPE := 'L26-003';`
</details>

<details>
<summary>Hint 2: why the unknown lot works for the count</summary>

`COUNT(*)` always returns one row, even over nothing. The answer is 0.
</details>

<details>
<summary>Hint 3: why the status fails</summary>

`SELECT status INTO` needs exactly one row. There is no lot `L26-999`, so Oracle has no row to give and raises `ORA-01403: no data found`. Lab 15 teaches you to catch it.
</details>

**Checkpoint:** 5, 2 and 0 wafers, then `ORA-01403: no data found`.

**Common trap:** an aggregate query hides the "no row" problem. A plain column query shows it. Expect both behaviours in your own code.

## Finish

Nothing needs cleaning up in this lab, because you only read data.

## What you learned

- A block has a `DECLARE` part, a `BEGIN` part and an optional `EXCEPTION` part.
- `DBMS_OUTPUT.PUT_LINE` prints text once the output is switched on.
- `SELECT ... INTO` fills variables, and needs exactly one row.
- `%TYPE` and `%ROWTYPE` copy types from the table.
- Compile errors come first, runtime errors after.
