# Lab 4: Summarising with GROUP BY

**Time:** 40 minutes. **Reading first:** [Summarising: aggregate functions, GROUP BY and HAVING](../topics/05-summarising-with-group-by.md).

## The story

Maya has a review meeting at ten and no time for raw rows. "I do not want to scroll through 186 measurements," she says. "Give me numbers: how many, how much, how often, and per what." You will answer her in nine short questions, working from one number for the whole table up to numbers per bowl, and finally to bowls you throw away.

Remember the receipts and bowls from the reading. `WHERE` throws away receipts before they go into a bowl. `HAVING` throws away bowls after you have counted them.

## What you will do

- use `COUNT(*)`, `COUNT(column)` and `COUNT(DISTINCT column)` and know why they differ
- use `SUM`, `AVG`, `MIN`, `MAX` and `ROUND`
- group by one column, by two columns and by an expression
- filter with `WHERE` and with `HAVING`
- read and fix an `ORA-00979` error

## Scripts

| File | What it does |
| --- | --- |
| [`lab4_summarising.sql`](scripts/lab4_summarising.sql) | Your worksheet: each question is a comment with space below it for your query. Run as `FAB_LAB`. |

## Before you start

1. Open DBeaver and connect with the **`fab-lab`** connection (user `FAB_LAB`).
2. Open `lab4_summarising.sql` with **File > Open File**.
3. Check the active connection at the top of the editor says `fab-lab`.
4. Work in the file. Write your query under each question. Put your cursor inside the query and press `Ctrl + Enter` to run just that one.

Each exercise has three hints. Open Hint 1 first. It tells you where to look. Hint 2 gives a skeleton with blanks (`___`). Hint 3 is nearly the answer. The honest way to learn is to try, get stuck, open one hint, try again.

## Part A: one number for the whole table

With no `GROUP BY`, the whole table is one big bowl.

### Exercise 1: How many lots, and how many products

**Maya asks:** "How many lots do we have in total, and how many different products do those lots use?"

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

The table is `LOTS`. You need two counts in one `SELECT`. One of them needs the word `DISTINCT`.

</details>

<details>
<summary>Hint 2</summary>

`SELECT COUNT(___) AS lots, COUNT(DISTINCT ___) AS products_used FROM ___;`

</details>

<details>
<summary>Hint 3</summary>

`SELECT COUNT(*) AS lots, COUNT(DISTINCT product_id) AS products_used FROM lots;` Check it against the five products in `PRODUCTS`. Does the number surprise you?

</details>

### Exercise 2: Graded and ungraded wafers

**Maya asks:** "How many wafers are there, and how many of them already have a grade?"

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Table `WAFERS`, column `grade`. Remember that `NULL` means "no value yet".

</details>

<details>
<summary>Hint 2</summary>

`SELECT COUNT(___) AS all_wafers, COUNT(___) AS graded_wafers FROM wafers;` One of the blanks is a star and the other is a column.

</details>

<details>
<summary>Hint 3</summary>

`SELECT COUNT(*) AS all_wafers, COUNT(grade) AS graded_wafers FROM wafers;` The two numbers are different. Say out loud why.

</details>

### Exercise 3: Defects at ANNEAL

**Maya asks:** "Looking only at the ANNEAL step, what are the lowest and highest defect counts, the average (one decimal) and the total?"

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Table `MEASUREMENTS`, column `defect_count`. The step filter is a row filter, so it goes in `WHERE`.

</details>

<details>
<summary>Hint 2</summary>

`SELECT MIN(___), MAX(___), ROUND(AVG(___), 1), SUM(___) FROM ___ WHERE step = '___';` Give each result an alias with `AS`.

</details>

<details>
<summary>Hint 3</summary>

`SELECT MIN(defect_count) AS fewest, MAX(defect_count) AS most, ROUND(AVG(defect_count), 1) AS average, SUM(defect_count) AS total FROM measurements WHERE step = 'ANNEAL';`

</details>

## Part B: one line per bowl

Now you decide the bowls with `GROUP BY`. Ask: "per what?" The answer goes after `GROUP BY`.

### Exercise 4: Lots per status

**Maya asks:** "How many lots are in each status? Put the biggest group first."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Table `LOTS`. The "per what" is `status`. Sort by the count, largest first.

</details>

<details>
<summary>Hint 2</summary>

`SELECT ___, COUNT(*) AS lots FROM ___ GROUP BY ___ ORDER BY lots ___;`

</details>

<details>
<summary>Hint 3</summary>

`SELECT status, COUNT(*) AS lots FROM lots GROUP BY status ORDER BY lots DESC;`

</details>

### Exercise 5: Defects per tool

**Maya asks:** "What is the total defect count per tool? Show the tool with the most defects first."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Table `MEASUREMENTS`. The "per what" is `tool_id`. The thing to add up is `defect_count`.

</details>

<details>
<summary>Hint 2</summary>

`SELECT tool_id, SUM(___) AS total_defects FROM ___ GROUP BY ___ ORDER BY ___ DESC;`

</details>

<details>
<summary>Hint 3</summary>

`SELECT tool_id, SUM(defect_count) AS total_defects FROM measurements GROUP BY tool_id ORDER BY total_defects DESC;` How many tools are in your answer? There are nine tools in the fab.

</details>

### Exercise 6: Lots per product and status

**Maya asks:** "For each product_id, how many lots are in each status?"

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Table `LOTS`. You need two columns after `GROUP BY`: one bowl per combination.

</details>

<details>
<summary>Hint 2</summary>

`SELECT product_id, ___, COUNT(*) AS lots FROM lots GROUP BY ___, ___ ORDER BY product_id, status;`

</details>

<details>
<summary>Hint 3</summary>

`SELECT product_id, status, COUNT(*) AS lots FROM lots GROUP BY product_id, status ORDER BY product_id, status;` Product 5 is missing from the list. Why?

</details>

## Part C: throwing bowls away, and fixing the classic error

`WHERE` filters rows before the bowls. `HAVING` filters bowls after they are counted.

### Exercise 7: Lots with several bad wafers

**Maya asks:** "Which lots have at least 2 wafers that are not PRIME grade, and how many?"

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Table `WAFERS`. Two filters. "Not PRIME" is about a row, so it goes in `WHERE`. "At least 2" is about a bowl, so it goes in `HAVING`.

</details>

<details>
<summary>Hint 2</summary>

`SELECT lot_id, COUNT(*) AS not_prime FROM wafers WHERE grade ___ 'PRIME' GROUP BY ___ HAVING COUNT(*) ___ 2;`

</details>

<details>
<summary>Hint 3</summary>

`SELECT lot_id, COUNT(*) AS not_prime FROM wafers WHERE grade <> 'PRIME' GROUP BY lot_id HAVING COUNT(*) >= 2;` Does the two-wafer "no grade yet" group count as not PRIME? Run it and think about `NULL`.

</details>

### Exercise 8: Busy months

**Maya asks:** "For each month (like 2026-08), how many lots started, and what was the average priority to one decimal? Only show months with more than 7 lots."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Table `LOTS`, column `start_date`. Group by an expression: `TO_CHAR(start_date, 'YYYY-MM')`. The "more than 7" test is on the count, so it needs `HAVING`.

</details>

<details>
<summary>Hint 2</summary>

`SELECT TO_CHAR(start_date, 'YYYY-MM') AS yr_mon, COUNT(*) AS lots_started, ROUND(AVG(___), 1) AS avg_priority FROM lots GROUP BY ___ HAVING COUNT(*) ___ 7;`

</details>

<details>
<summary>Hint 3</summary>

`... GROUP BY TO_CHAR(start_date, 'YYYY-MM') HAVING COUNT(*) > 7;` Repeat the same `TO_CHAR` expression in `GROUP BY`. Then try `> 6` and see what changes.

</details>

### Exercise 9: Fix the broken query

**Maya asks:** "I tried to get the number of wafers per lot with the grade next to it, and Oracle shouted at me. Can you fix it so it gives one line per lot and grade?"

Here is Maya's attempt. Copy it into your file under the question and run it to see the error before you fix it:

```sql
SELECT lot_id, grade, COUNT(*) AS wafers
FROM   wafers
GROUP  BY lot_id
ORDER  BY lot_id;
```

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Read the error message. Which part of the `SELECT` does the database complain about? The marker `*` points at it.

</details>

<details>
<summary>Hint 2</summary>

Every plain column in `SELECT` must also be in `GROUP BY`. Which column is missing there?

</details>

<details>
<summary>Hint 3</summary>

`... GROUP BY lot_id, grade ORDER BY lot_id, grade;` Now a lot with two different grades appears on two lines.

</details>

## Checkpoints

Tick each box before you finish.

- [ ] I can say in one sentence why `COUNT(*)` and `COUNT(column)` can differ
- [ ] My group counts in exercise 4 add up to 16
- [ ] I know why `CMP01`, `IMP01` and product 5 never appear in a `GROUP BY` result
- [ ] I can explain the difference between `WHERE` and `HAVING` using receipts and bowls
- [ ] I can fix `ORA-00979` in two different ways

## Stretch

Maya: "Which tools have an average defect count above 20 across all their measurements? Show the average to one decimal and how many measurements it is based on, highest first." Use `HAVING` with `AVG`. Then explain to a neighbour why the answer contains only the two splitting tools, and what the numbers say about how defects change along the line.

## If something goes wrong

| You see | What it usually means | What to do |
| --- | --- | --- |
| `ORA-00979: not a GROUP BY expression` | A plain column in `SELECT` is missing from `GROUP BY` | Add it to `GROUP BY`, or remove it from `SELECT` |
| `ORA-00937: not a single-group group function` | You mixed an aggregate and a plain column with no `GROUP BY` at all | Add `GROUP BY` with the plain columns |
| `ORA-00934: group function is not allowed here` | An aggregate such as `COUNT(*)` is inside `WHERE` | Move that test to `HAVING` |
| A group is missing from the result | A bowl exists only if a row falls in it | That is normal. A join (lab 5) can show it with a zero |
