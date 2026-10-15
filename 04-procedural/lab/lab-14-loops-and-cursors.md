# Lab 14: Loops and cursors

**Time:** 40 minutes. **Reading first:** [Decisions, loops and cursors](../topics/02-control-and-cursors.md).

> **Your data is only read in this lab.** Every block selects and prints. Nothing is changed, so there is nothing to restore.

## The story

Maya wants a printed walk through the lots. "Go through them one at a time, tell me which need attention, and count how many readings are off target." You will use the checkout-belt tools from the topic: decisions, loops, and the cursor that walks through a query result. The last exercise asks whether you needed the loop at all.

## What you will do

- choose with `CASE` and `IF`/`ELSIF`
- repeat with `WHILE`
- walk a query result with a cursor `FOR` loop and with `OPEN`/`FETCH`/`CLOSE`
- reuse one cursor with parameters
- count classes inside a loop, then count them with one `SELECT`

## Before you start

1. Connect to `fab-lab` in DBeaver and open [`lab14_loops_and_cursors.sql`](scripts/lab14_loops_and_cursors.sql) with **File > Open File**.
2. Open the Output panel before you run anything: **Ctrl + Shift + O** (or SQL Editor menu, **Show Server Output**). The text from `PUT_LINE` appears there.
3. Run one block at a time: select the whole block, from its first line (`DECLARE` or `BEGIN`) down to its `END;`, and press **Ctrl + Enter**. A plain `SELECT` can be run with the cursor inside it.
4. Write each block with `END;` followed by a line that holds only `/`, and leave no blank lines inside a block. Do not run the whole script with **Alt + X**.

If you use SQL*Plus instead of DBeaver, run `SET SERVEROUTPUT ON` once before the first block.

Solutions: [lab-14-solutions.md](../solutions/lab-14-solutions.md).

## Exercise 1: Decisions

Maya: "For lot L26-003B, say how urgent it is (priority 1 is rush, 2 is normal, anything else is low) and what we should do. On HOLD: find out why it is on hold. ACTIVE: none, it is in production. Anything else: none, the lot is finished."

<details>
<summary>Hint 1: which tools?</summary>

`CASE` as an expression gives the priority wording. `IF ... ELSIF ... ELSE ... END IF;` chooses the action.
</details>

<details>
<summary>Hint 2: getting the values</summary>

`SELECT priority, status INTO v_prio, v_status FROM lots WHERE lot_id = v_lot;`
</details>

<details>
<summary>Hint 3: skeleton</summary>

```sql
v_text := CASE v_prio WHEN 1 THEN '___' WHEN 2 THEN '___' ELSE '___' END;
IF v_status = 'HOLD' THEN ... ELSIF v_status = 'ACTIVE' THEN ... ELSE ... END IF;
```
</details>

**Checkpoint:** `L26-003B priority 1 = rush` and the hold action.

**Common trap:** writing `ELSEIF` or `ELSE IF`. The word is `ELSIF`, and `ELSE IF` would need a second `END IF`.

## Exercise 2: A WHILE loop

Maya: "A film starts at 12 nm and doubles at each pass. How many passes until it is 1500 nm or more?"

Print one line per pass, and a last line with the final thickness and the number of passes.

<details>
<summary>Hint 1: the condition</summary>

`WHILE v_thk < 1500 LOOP ... END LOOP;` runs while the film is still too thin.
</details>

<details>
<summary>Hint 2: what goes inside</summary>

Add 1 to a counter, print, then double the thickness: `v_thk := v_thk * 2;`
</details>

<details>
<summary>Hint 3: the last line</summary>

Print after `END LOOP;`, because then `v_thk` holds the first value that reached 1500.
</details>

**Checkpoint:** the loop body runs 7 times, and the film ends at 1536 nm.

**Common trap:** forgetting the line that doubles `v_thk`. The condition never changes and the loop runs forever. Use the stop button in DBeaver if it happens.

## Exercise 3: A cursor FOR loop

Maya: "List every lot with its status and its wafer count, and the total number of wafers at the end."

Loop over a query that counts wafers per lot. Keep a running total in a variable.

<details>
<summary>Hint 1: the query</summary>

Count wafers per lot with a `GROUP BY`. Use a `LEFT JOIN` from `LOTS` to `WAFERS` so a lot with no wafers would still appear.
</details>

<details>
<summary>Hint 2: the loop</summary>

`FOR r IN (SELECT ... ) LOOP ... END LOOP;` The loop variable `r` has one field per column, so give `COUNT(...)` an alias and use `r.wafers`.
</details>

<details>
<summary>Hint 3: the total</summary>

Declare `v_total PLS_INTEGER := 0;` and add `r.wafers` to it in each pass. Print after the loop.
</details>

**Checkpoint:** 16 lines, then `Total wafers: 66`.

**Common trap:** a missing alias. Without `AS wafers`, the field has an unusable name and Oracle raises `PLS-00302`.

## Exercise 4: An explicit cursor

Maya: "Number the lots that are on HOLD or SCRAPPED: 1., 2., and so on."

Declare a named cursor, then `OPEN`, `FETCH ... INTO` in a basic `LOOP`, `EXIT WHEN c%NOTFOUND`, and `CLOSE`. Print `%ROWCOUNT` as the number, and again after the loop.

<details>
<summary>Hint 1: the pattern</summary>

```sql
OPEN c;
LOOP
  FETCH c INTO ...;
  EXIT WHEN c%NOTFOUND;
  ...
END LOOP;
CLOSE c;
```
</details>

<details>
<summary>Hint 2: the variables</summary>

Declare `v_lot lots.lot_id%TYPE` and `v_status lots.status%TYPE`, in the same order as the cursor's columns.
</details>

<details>
<summary>Hint 3: where %ROWCOUNT works</summary>

`c%ROWCOUNT` counts the rows fetched so far. It is still readable after the loop, but before `CLOSE`.
</details>

**Checkpoint:** three lots, and the last line says `Rows fetched: 3`.

**Common trap:** putting `EXIT WHEN` after the `PUT_LINE`. The last `FETCH` finds nothing, and the loop prints the previous row a second time. Test `%NOTFOUND` straight after the fetch.

## Exercise 5: A cursor with parameters

Maya: "How many PRIME wafers and how many TEST wafers does L26-003 have? And how many PRIME wafers does L26-012 have?"

Declare one cursor with parameters `p_lot` and `p_grade`. Open it three times with different values, counting the rows each time.

<details>
<summary>Hint 1: the syntax</summary>

```sql
CURSOR c_wafers (p_lot VARCHAR2, p_grade VARCHAR2) IS
  SELECT wafer_id, slot_no FROM wafers WHERE lot_id = p_lot AND grade = p_grade;
```
</details>

<details>
<summary>Hint 2: calling it</summary>

`FOR w IN c_wafers('L26-003', 'PRIME') LOOP ... END LOOP;`
</details>

<details>
<summary>Hint 3: counting</summary>

Reset a counter to 0 before each loop and add 1 inside it. Print the counter after `END LOOP;`.
</details>

**Checkpoint:** 4, 1 and 2.

**Common trap:** naming the parameter `lot_id` or `grade`. Inside the query `lot_id = lot_id` compares the column with itself and matches every row. A `p_` prefix avoids that.

## Exercise 6: A loop that decides

Maya: "For lot L26-005, look at the ANNEAL readings. Class each one as LOW (below 90 percent of the product target), HIGH (above 110 percent) or OK, and count each class."

Get the product target with `SELECT ... INTO`. Loop over the lot's ANNEAL readings. Inside the loop, compute the percentage and use `IF` to add to one of three counters. Print one line per reading and a summary line.

<details>
<summary>Hint 1: two pieces</summary>

First the target of the lot's product (a join, as in Lab 13). Then a cursor loop over `MEASUREMENTS` joined to `WAFERS`, filtered on lot and step.
</details>

<details>
<summary>Hint 2: the decision</summary>

`v_pct := r.thickness_nm / v_target * 100;` then `IF v_pct < 90 THEN ... ELSIF v_pct > 110 THEN ... ELSE ... END IF;`
</details>

<details>
<summary>Hint 3: the counters</summary>

Three variables `v_low`, `v_ok`, `v_high`, all starting at 0. Each branch adds 1 to its own.
</details>

**Checkpoint:** `LOW 0, OK 2, HIGH 2`.

**Common trap:** testing `v_pct = 90` or `v_pct = 110` and missing the values between. Use `<` and `>`, and let the `ELSE` take the middle.

## Exercise 7: Do you need the loop?

Maya: "Same numbers, but I want them in a table, not in the output panel."

Write exercise 6 again as one `SELECT` with a `CASE` expression and `GROUP BY`.

<details>
<summary>Hint 1: the shape</summary>

`SELECT CASE ... END AS class, COUNT(*) FROM ... GROUP BY CASE ... END`
</details>

<details>
<summary>Hint 2: the joins</summary>

You need `MEASUREMENTS`, `WAFERS`, `LOTS` and `PRODUCTS`, so the target is available in the same row as the reading.
</details>

<details>
<summary>Hint 3: the CASE</summary>

`WHEN m.thickness_nm < p.target_thk_nm * 0.9 THEN 'LOW' WHEN m.thickness_nm > p.target_thk_nm * 1.1 THEN 'HIGH' ELSE 'OK'`
</details>

**Checkpoint:** `HIGH 2` and `OK 2`. A class with no readings does not appear, so there is no `LOW` row.

**Common trap:** repeating the `CASE` in `GROUP BY` with a typo, which gives `ORA-00979`. Copy it exactly.

## Finish

Nothing to clean up. You only read data.

## What you learned

- `CASE` and `IF`/`ELSIF` choose between paths. A `CASE` statement needs an `ELSE`.
- A cursor `FOR` loop is the shortest way to walk a result.
- An explicit cursor gives control of each step: `%NOTFOUND` ends the loop and `%ROWCOUNT` counts rows.
- Parameters let one cursor serve many lots.
- If a loop only counts or sums, a `SELECT` does the same job in one statement.
