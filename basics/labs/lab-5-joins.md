# Lab 5: Joins

**Time:** 45 minutes. **Reading first:** [Joins: bringing a second shelf to the counter](../topics/06-joins.md).

## The story

Maya has a different kind of question today. "The numbers on one table are never the whole story," she says. "I need the product name next to the lot, the target next to the reading, and I need to know what is missing." Everything she wants lives on two, three or four shelves, and you will bring them to the counter with joins.

At the end there is a real case for you: Maya wants to know which lots had a FINAL reading far from the product target, and which tool took that reading. You will build it one layer at a time with hints at four levels.

## What you will do

- join two, three and four tables by following the map
- use table aliases and prefix every column
- use `LEFT JOIN` and the anti-join pattern to find what is missing
- avoid the `COUNT(*)` trap on outer joins
- join a table to itself
- solve a small case study from question to query

## Scripts

| File | What it does |
| --- | --- |
| [`lab5_joins.sql`](scripts/lab5_joins.sql) | Your worksheet: each question is a comment with space below it for your query. Run as `FAB_LAB`. |

## Before you start

1. Open DBeaver and connect with the **`fab-lab`** connection (user `FAB_LAB`).
2. Open `lab5_joins.sql` with **File > Open File**. Check that the active connection says `fab-lab`.
3. Keep the map from [Meet the fab](../topics/02-meet-the-fab.md) open in another tab. Every join follows one line on that map:

| To connect | Use this join condition |
| --- | --- |
| lots and their product | `l.product_id = p.product_id` |
| wafers and their lot | `w.lot_id = l.lot_id` |
| measurements and their wafer | `m.wafer_id = w.wafer_id` |
| measurements and the tool used | `m.tool_id = t.tool_id` |
| a lot and its parent lot | `child.parent_lot_id = parent.lot_id` |

4. Give every table an alias and put the alias in front of every column. It prevents `ORA-00918` and keeps the query readable.

Each exercise has hints. Open Hint 1 first. It tells you where to look. Hint 2 gives a skeleton with blanks (`___`). Hint 3 is nearly the answer.

## Part A: bringing a second shelf

Use `JOIN ... ON` to bring `PRODUCTS` next to `LOTS`, and then more tables.

### Exercise 1: Active lots with their product

**Maya asks:** "List the active lots with their product code and family, in lot order."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Two tables: `LOTS` (has the status and `product_id`) and `PRODUCTS` (has the code and family). They share `product_id`.

</details>

<details>
<summary>Hint 2</summary>

`SELECT l.lot_id, p.___, p.___ FROM lots l JOIN products p ON p.___ = l.___ WHERE l.status = '___' ORDER BY l.lot_id;`

</details>

<details>
<summary>Hint 3</summary>

`SELECT l.lot_id, p.product_code, p.family FROM lots l JOIN products p ON p.product_id = l.product_id WHERE l.status = 'ACTIVE' ORDER BY l.lot_id;` You should see 8 rows.

</details>

### Exercise 2: Scrap wafers and their product

**Maya asks:** "Which wafers have grade SCRAP? For each, show the wafer, its lot and the product code."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

The wafer knows its lot, the lot knows its product. Walk along the map: `WAFERS`, then `LOTS`, then `PRODUCTS`. That is two joins.

</details>

<details>
<summary>Hint 2</summary>

`SELECT w.wafer_id, l.lot_id, p.product_code FROM wafers w JOIN lots l ON l.lot_id = w.___ JOIN products p ON p.product_id = l.___ WHERE w.grade = '___' ORDER BY w.wafer_id;`

</details>

<details>
<summary>Hint 3</summary>

`... WHERE w.grade = 'SCRAP' ORDER BY w.wafer_id;` Four rows. Which lot do they all come from?

</details>

### Exercise 3: Which tool measured which wafer

**Maya asks:** "For the wafers of lot L26-003B, show every measurement with the step, the tool, the tool type and the bay. Order by wafer and time."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

You need `MEASUREMENTS` (the readings), `WAFERS` (to know the lot) and `TOOLS` (type and bay). Two joins.

</details>

<details>
<summary>Hint 2</summary>

`SELECT m.wafer_id, m.step, m.tool_id, t.tool_type, t.bay FROM measurements m JOIN wafers w ON w.wafer_id = m.___ JOIN tools t ON t.tool_id = m.___ WHERE w.lot_id = '___' ORDER BY m.wafer_id, m.meas_time;`

</details>

<details>
<summary>Hint 3</summary>

`... WHERE w.lot_id = 'L26-003B' ORDER BY m.wafer_id, m.meas_time;` The lot has 2 wafers and 3 steps each, so expect 6 rows.

</details>

### Exercise 4: Reading against target

**Maya asks:** "For lot L26-006, show each FINAL reading next to the product target, and how far apart they are (thickness minus target, two decimals)."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Four tables: `MEASUREMENTS`, `WAFERS`, `LOTS`, `PRODUCTS`. Follow the map from the reading to the target: three joins.

</details>

<details>
<summary>Hint 2</summary>

`SELECT m.wafer_id, m.thickness_nm, p.target_thk_nm, ROUND(m.thickness_nm - p.___, 2) AS diff_nm FROM measurements m JOIN wafers w ON ... JOIN lots l ON ... JOIN products p ON ... WHERE m.step = 'FINAL' AND l.lot_id = '___' ORDER BY m.wafer_id;`

</details>

<details>
<summary>Hint 3</summary>

`FROM measurements m JOIN wafers w ON w.wafer_id = m.wafer_id JOIN lots l ON l.lot_id = w.lot_id JOIN products p ON p.product_id = l.product_id` and then the `WHERE` from hint 2. Five rows. A negative difference means thinner than target.

</details>

## Part B: finding what is missing

An inner join keeps only pairs. A `LEFT JOIN` keeps every row of the left table, and the anti-join (`WHERE right_key IS NULL`) lists the ones with no partner.

### Exercise 5: Products with no lots, tools never used

**Maya asks:** "Which products have no lots at all? And which tools have never taken a measurement? Two queries."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Both are anti-joins. Start from the table that must keep all its rows (`PRODUCTS`, then `TOOLS`), `LEFT JOIN` the other, and keep the rows where the other side is `NULL`.

</details>

<details>
<summary>Hint 2</summary>

`SELECT p.product_code FROM products p LEFT JOIN lots l ON l.___ = p.___ WHERE l.___ IS NULL;` and the same shape with `tools t` and `measurements m`.

</details>

<details>
<summary>Hint 3</summary>

For the right-hand test, use the primary key of the right-hand table: `l.lot_id IS NULL` and `m.meas_id IS NULL`. Two rows come back for the tools.

</details>

### Exercise 6: Lots with wafers but no readings

**Maya asks:** "Which lots have wafers, but none of those wafers has been measured yet? Show the lot and how many wafers are waiting."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Chain two joins: `LOTS` to `WAFERS` (an inner join, you only want lots that have wafers), then `WAFERS` to `MEASUREMENTS` (a left join, you want wafers without readings). Then group.

</details>

<details>
<summary>Hint 2</summary>

`SELECT l.lot_id, COUNT(*) AS wafers_waiting FROM lots l JOIN wafers w ON ... LEFT JOIN measurements m ON m.wafer_id = w.wafer_id WHERE m.___ IS NULL GROUP BY l.lot_id;`

</details>

<details>
<summary>Hint 3</summary>

`WHERE m.meas_id IS NULL GROUP BY l.lot_id ORDER BY l.lot_id;` One lot, with 4 wafers.

</details>

### Exercise 7: Lots per product, with zeros

**Maya asks:** "How many lots does each product have? I want to see products with none, showing 0."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

Start from `PRODUCTS`, `LEFT JOIN` `LOTS`, and group by the product. Be careful which `COUNT` you use.

</details>

<details>
<summary>Hint 2</summary>

`SELECT p.product_code, COUNT(l.___) AS lots FROM products p LEFT JOIN lots l ON l.product_id = p.product_id GROUP BY p.product_code ORDER BY p.product_code;`

</details>

<details>
<summary>Hint 3</summary>

Try `COUNT(*)` as well as `COUNT(l.lot_id)` in the same query, side by side. One of them gives product SIC-150 a count of 1. Which, and why?

</details>

### Exercise 8: Children of a lot on hold

**Maya asks:** "Which split or reworked lots came from a parent lot that is on HOLD? Show the child, its type, the parent and the parent's hold reason."

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

`LOTS` appears twice: once as the child, once as the parent. Give them different aliases. The condition links the child's `parent_lot_id` to the parent's `lot_id`.

</details>

<details>
<summary>Hint 2</summary>

`SELECT child.lot_id, child.lot_type, parent.lot_id AS parent_lot, parent.hold_reason FROM lots child JOIN lots parent ON child.___ = parent.___ WHERE parent.status = '___';`

</details>

<details>
<summary>Hint 3</summary>

`... ON child.parent_lot_id = parent.lot_id WHERE parent.status = 'HOLD';` Only one row. Look at the hold reason.

</details>

## Part C: capstone case study

This is one question, built up in four levels. Try level 1 on your own, then open the next hint only when you are stuck. Finish with the final query and a short sentence you could say to Maya.

### Exercise 9: Capstone: readings far from target

**Maya asks:** "Which lots had a FINAL reading more than 0.3 nm away from their product target, and on which tool?"

Work through the four-step method from the reading before you type anything: what am I looking for, which tables hold it, which rows do I want, which columns in what order. "More than 0.3 nm away" means too thick **or** too thin, so you need the absolute difference, `ABS(x)`.

Try it first. Open a hint only when you are stuck, one at a time.

<details>
<summary>Hint 1</summary>

**Level 1, plan it.** You are looking for FINAL readings, so start from `MEASUREMENTS`. The reading has the tool (`tool_id`) and the wafer. The lot is on `WAFERS`. The target is on `PRODUCTS`, reached through `LOTS`. So four tables: measurements, wafers, lots, products. You do not need the `TOOLS` table, because `m.tool_id` already names the tool. This is the query you wrote in exercise 4, for every lot.

</details>

<details>
<summary>Hint 2</summary>

**Level 2, the skeleton.** `SELECT l.lot_id, m.tool_id, m.thickness_nm, p.target_thk_nm, ROUND(m.thickness_nm - p.target_thk_nm, 2) AS diff_nm FROM measurements m JOIN wafers w ON ___ JOIN lots l ON ___ JOIN products p ON ___ WHERE m.step = 'FINAL' ORDER BY l.lot_id;` Run this first, with `FETCH FIRST 10 ROWS ONLY`, and check that diff_nm looks sensible. 62 FINAL readings should come back without the limit.

</details>

<details>
<summary>Hint 3</summary>

**Level 3, the filter.** Add the condition on the size of the difference. It belongs in `WHERE` (it is about a row, not a group): `AND ABS(m.thickness_nm - p.target_thk_nm) > 0.3`. You cannot use the alias `diff_nm` in `WHERE`, because `SELECT` runs after `WHERE`. Repeat the expression. Count the rows you get.

</details>

<details>
<summary>Hint 4</summary>

**Level 4, nearly the answer.** To give Maya a short answer, summarise per lot and tool: `SELECT l.lot_id, m.tool_id, COUNT(*) AS bad_readings, MAX(ABS(m.thickness_nm - p.target_thk_nm)) AS worst_nm FROM ... WHERE m.step = 'FINAL' AND ABS(...) > 0.3 GROUP BY l.lot_id, m.tool_id ORDER BY l.lot_id, m.tool_id;` Fill in the joins from level 2.

</details>

## Checkpoints

Tick each box before you finish.

- [ ] Every join I wrote has an `ON` and I checked the row count looked sensible
- [ ] I can say when a `LEFT JOIN` is needed instead of a plain `JOIN`
- [ ] I found the product with no lots and the two tools never used with an anti-join
- [ ] I used `COUNT(l.lot_id)` and not `COUNT(*)` in exercise 7
- [ ] I solved the capstone and can explain each layer of it

## Stretch

Maya: "For the capstone, per tool, how many FINAL readings were more than 0.3 nm from the target, out of how many FINAL readings the tool took?" Hint: the second number needs every FINAL reading, so put a `CASE` expression inside `COUNT`, or join twice. A simple way is `SUM(CASE WHEN ABS(m.thickness_nm - p.target_thk_nm) > 0.3 THEN 1 ELSE 0 END)`. Which tool has the highest share?

## If something goes wrong

| You see | What it usually means | What to do |
| --- | --- | --- |
| `ORA-00918: column ambiguously defined` | A column name exists in both tables and you did not prefix it | Write `alias.column` |
| `ORA-00905: missing keyword` | You wrote `JOIN` without `ON` | Add `ON a.key = b.key` |
| Far more rows than expected | A missing or wrong `ON` made a cross join | Check the join condition against the map |
| A row you expected is missing | An inner join dropped it because it had no partner | Use `LEFT JOIN` from the table that must keep all its rows |
