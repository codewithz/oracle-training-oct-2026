# Lab 2: Your first queries

**Time:** 40 minutes. **Reading first:** [Your first queries: from Maya's question to SQL](../topics/03-your-first-queries.md).

## The story

Your first morning went well and the database is loaded. This morning Maya, the shift manager, walks over with a coffee and a list of questions she has been wanting answered for months. "Nothing fancy," she says. "Just tell me what is in there."

Each question below is a sentence from Maya. For each one, use the four-step method from the reading: what am I looking for, which table holds it, which rows do I want, which columns in what order. Then write the query.

## What you will do

- turn eight plain-English questions into queries
- use `WHERE` with `=`, `IN`, `BETWEEN`, `LIKE` and dates
- fall into the `LIKE` trap on purpose, and learn to spot it
- mix `AND` with `OR` and fix it with brackets
- sort, remove duplicates and limit the rows

## Scripts

| File | What it does |
| --- | --- |
| [`lab2_first_queries.sql`](scripts/lab2_first_queries.sql) | The questions as comments, with space to type your answers. Open it in DBeaver as `fab-lab`. |
| [`lab-2-solutions.md`](../solutions/lab-2-solutions.md) | Answers with real output. Look only after you have tried. |

## How to work

Open `lab2_first_queries.sql`. Type each answer under its question. Put the cursor inside a statement and press `Ctrl + Enter` to run only that one. Leave a blank line between statements. Every exercise has three hints. Open one at a time: the first only points at the table, the third is nearly the answer.

Before you run a query, say out loud what you expect: how many rows, which columns. Then compare. That habit is worth more than any hint.

## Exercise 1: Which tools are in bay B1?

**Maya asks:** "Which tools are in bay B1? Show me the tool id and the type, sorted by tool id."

<details>
<summary>Hint 1: which table and which clause</summary>

The tools live in the `TOOLS` table. You are keeping some rows (bay B1), so you need a `WHERE`. Sorting is `ORDER BY`.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`SELECT ___, ___ FROM ___ WHERE ___ = '___' ORDER BY ___;`

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`SELECT tool_id, tool_type FROM tools WHERE bay = 'B_' ORDER BY tool_id;` Fill the last blank. Text goes in single quotes.

</details>

## Exercise 2: What kinds of tool do we have?

**Maya asks:** "What different types of tool do we have? Each type once, in alphabetical order."

<details>
<summary>Hint 1: which table and which clause</summary>

Still the `TOOLS` table. You want a column, but each value only once.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`SELECT ___ ___ FROM ___ ORDER BY ___;` The first blank is a keyword from topic 03.

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`SELECT DISTINCT tool_type FROM tools ORDER BY tool_type;`

</details>

## Exercise 3: Two products at once

**Maya asks:** "Show me the lots of the RF-300 and PWR-200 products. Those are product ids 2 and 3. I want the lot, the product id and the status, in lot order."

<details>
<summary>Hint 1: which table and which clause</summary>

The `LOTS` table has `product_id`. You want rows where it is one of two values.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`SELECT ___, ___, ___ FROM ___ WHERE ___ IN (___, ___) ORDER BY ___;`

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`... WHERE product_id IN (2, 3) ORDER BY lot_id;`

</details>

## Exercise 4: The worst readings

**Maya asks:** "Which FINAL measurements had between 15 and 20 defects? Show the measurement id, the wafer and the defect count, with the worst first. If two are equal, sort them by wafer."

<details>
<summary>Hint 1: which table and which clause</summary>

The `MEASUREMENTS` table. Two conditions joined by `AND`: the step is FINAL, and the defect count is in a range.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`SELECT ___, ___, ___ FROM ___ WHERE ___ = '___' AND ___ BETWEEN ___ AND ___ ORDER BY ___ DESC, ___;`

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`... WHERE step = 'FINAL' AND defect_count BETWEEN 15 AND 20 ORDER BY defect_count DESC, wafer_id;`

</details>

## Exercise 5: The LIKE trap

**Maya asks:** Three small questions in a row.

- **a)** "Show me lot L26-003 and everything that came out of it." Show the lot, its type and its parent.
- **b)** "Sorry, I only wanted the lot L26-003 itself." Write the query again.
- **c)** "Now all the original lots numbered 001 to 009, nothing with a letter after the number." Show the lot and its type.

<details>
<summary>Hint 1: which table and which clause</summary>

All three use `LOTS` and the `lot_id` column. Part **a** needs a pattern, part **b** needs an exact match, part **c** needs a pattern with a one-character wildcard.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

a) `WHERE lot_id LIKE '___%'`. b) `WHERE lot_id = '___'`. c) `WHERE lot_id LIKE 'L26-00_'` has the wildcard where you need it. Which wildcard means exactly one character, `%` or `_`?

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

a) `LIKE 'L26-003%'`, b) `= 'L26-003'`, c) `LIKE 'L26-00_'`. Run a) and count the rows before you read on.

</details>

## Exercise 6: AND and OR with brackets

**Maya asks:** "Show me the lots that are ACTIVE or on HOLD, and that are urgent. Urgent means priority 1." Show the lot, status and priority.

Write it two ways. First **without** brackets, and count the rows. Then add brackets so it says what Maya means, and count again.

<details>
<summary>Hint 1: which table and which clause</summary>

`LOTS` again. Three conditions: status ACTIVE, status HOLD, priority 1. The `AND` binds tighter than `OR`.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`WHERE ___ = 'ACTIVE' OR ___ = 'HOLD' AND ___ = 1` is the first try. For the second, put brackets around the two status tests: `WHERE (___ OR ___) AND ___`.

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Second version: `WHERE (status = 'ACTIVE' OR status = 'HOLD') AND priority = 1`. It should return 4 rows. The first version returns more.

</details>

## Exercise 7: Lots started in August

**Maya asks:** "Which lots started in August 2026? Show the lot and the start date, oldest first."

<details>
<summary>Hint 1: which table and which clause</summary>

`LOTS`, column `start_date`. A date literal is `DATE 'YYYY-MM-DD'`. Remember that a date carries a time of day.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`WHERE start_date >= DATE '___' AND start_date < DATE '___'` where the second date is the first day of the *next* month.

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`WHERE start_date >= DATE '2026-08-01' AND start_date < DATE '2026-09-01' ORDER BY start_date;`

</details>

## Exercise 8: The latest measurements

**Maya asks:** "What are the five most recent measurements? Show the measurement id, the wafer, the tool and the time, newest first."

<details>
<summary>Hint 1: which table and which clause</summary>

`MEASUREMENTS`, column `meas_time`. You need an order first, and then a limit on the number of rows.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`SELECT ___ FROM ___ ORDER BY ___ DESC FETCH FIRST ___ ROWS ONLY;`

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`... ORDER BY meas_time DESC FETCH FIRST 5 ROWS ONLY;`

</details>

## Stretch: a tidy board

**Maya asks:** "Give me a board of the three most urgent lots that are not yet shipped. Most urgent first, and among equals the newest start first. Name the columns Lot, Status and Urgency."

<details>
<summary>Hint 1: which table and which clause</summary>

`LOTS`. Sorting by two columns, a `WHERE` with `<>`, aliases with `AS` and double quotes, and a row limit.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`SELECT lot_id AS "Lot", ... FROM lots WHERE status <> '___' ORDER BY ___, ___ DESC FETCH FIRST 3 ROWS ONLY;`

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Sort by `priority` (smallest number is the most urgent) and then `start_date DESC`.

</details>

## Checkpoints

- [ ] I answered all eight questions and compared my row counts with the solutions
- [ ] I can say why `LIKE 'L26-003%'` returned four lots
- [ ] I can say what the brackets changed in exercise 6
- [ ] I wrote every text value in single quotes and every date as `DATE 'YYYY-MM-DD'`
- [ ] I used `ORDER BY` whenever the order mattered

If a box is empty, read the matching section of the topic page again before the next lab.
