# Lab 6: Subqueries and set operators

**Time:** 40 minutes. **Reading first:** [Subqueries and set operators](../topics/07-subqueries-and-set-operators.md).

## The story

Maya is preparing the weekly review. Her questions are getting harder to say in one breath. "Which readings are above average?" needs the average first. "Which lots were never measured?" means looking for something that is missing. Each one needs a small question inside the big one.

One of the questions will look easy, give you an empty result, and say nothing about why. Finding out why is the most useful five minutes of this lab.

## What you will do

- compare against a value worked out by a subquery
- filter with `IN`, `NOT EXISTS` and a correlated subquery
- find and fix the `NOT IN` and `NULL` trap
- name a sticky note with `WITH`
- combine lists with `UNION`, `UNION ALL`, `INTERSECT` and `MINUS`

Everything in this lab is a `SELECT`. Nothing is changed, so you cannot break the data.

## Scripts

| File | What it does |
| --- | --- |
| [`lab6_subqueries_and_sets.sql`](scripts/lab6_subqueries_and_sets.sql) | Every question as a comment with space for your query. Run as `FAB_LAB`. |

Open it in DBeaver on the `fab-lab` connection. Write each query under its question, select it, and press `Ctrl + Enter`. Solutions are in [lab-6-solutions.md](../solutions/lab-6-solutions.md). Try first, use the hints second, and read the solution last.

## Part 1: One value from a subquery

### Exercise 1: Above the average

Maya: "What is the average number of defects per measurement? Then show me the ten worst measurements that are above that average, worst first."

Do it in two steps: (a) the average on its own, rounded to 2 decimals, then (b) the list, with the average coming from a subquery. Show `meas_id`, `wafer_id`, `step`, `defect_count`. Break ties on `meas_id`.

<details>
<summary>Hint 1: which table and which clause?</summary>

Everything is in `MEASUREMENTS`. The subquery goes inside `WHERE`, on the right side of `>`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT ___, ___, ___, ___
FROM   measurements
WHERE  defect_count > (SELECT ___(defect_count) FROM measurements)
ORDER  BY ___ DESC, ___
FETCH FIRST ___ ROWS ONLY;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The function for an average is `AVG`. `FETCH FIRST 10 ROWS ONLY` goes last. Your list should start with meas_id 118.
</details>

## Part 2: A list from a subquery

### Exercise 2: Lots for the thicker products

Maya: "Which lots belong to products with a target thickness above 100 nm?" Show `lot_id`, `product_id`, `status`, ordered by `lot_id`.

<details>
<summary>Hint 1: which table and which clause?</summary>

The thickness is in `PRODUCTS`. The lots are in `LOTS`. Use `product_id IN (...)` in `WHERE` and let the inner query choose the products.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT lot_id, product_id, status
FROM   lots
WHERE  product_id IN (SELECT ___ FROM ___ WHERE ___ > 100)
ORDER  BY lot_id;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The inner query selects `product_id` from `products` where `target_thk_nm > 100`. You should get five lots.
</details>

## Part 3: The NOT IN trap (a discovery exercise)

### Exercise 3: Lots that are nobody's parent

Maya: "Which lots are not the parent of any other lot?"

Work through it in four steps. Do not look at the hints until you have tried each step.

**3a.** Write it with `NOT IN` and the inner query `SELECT parent_lot_id FROM lots`. Run it. Write down how many rows you get. Is that believable? You know that most lots have no children.

**3b.** Find out why. Run one query that returns two numbers from `LOTS`: how many rows there are, and how many of them have a `parent_lot_id`. (`COUNT(*)` counts rows. `COUNT(column)` skips `NULL`s.)

**3c.** Fix it by keeping `NOT IN` but removing the `NULL`s from the inner query.

**3d.** Fix it a second way with `NOT EXISTS`. Give the outer table the alias `l` and the inner table the alias `child`.

Both fixes must return the same 13 lots.

<details>
<summary>Hint 1: how to think about it</summary>

`NOT IN` against a list that contains `NULL` can never be true, because "not equal to unknown" is unknown. Count the `NULL`s, and the empty result stops being a mystery.
</details>

<details>
<summary>Hint 2: skeletons</summary>

```sql
-- 3b
SELECT COUNT(*) AS rows_in_list, COUNT(___) AS non_null_values FROM lots;

-- 3c
SELECT lot_id FROM lots
WHERE  lot_id NOT IN (SELECT parent_lot_id FROM lots WHERE parent_lot_id ___);

-- 3d
SELECT l.lot_id FROM lots l
WHERE  NOT EXISTS (SELECT 1 FROM lots child WHERE child.___ = l.___);
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

For 3c the missing words are `IS NOT NULL`. For 3d, the link is `child.parent_lot_id = l.lot_id`. Add `ORDER BY` as you like.
</details>

## Part 4: Looking for what is missing

### Exercise 4: Never measured, never used

(a) Maya: "Which lots have never been measured?" (b) "Which products have no lots?"

Use `NOT EXISTS` for both. For (a), a lot reaches its measurements through its wafers, so the inner query needs a join.

<details>
<summary>Hint 1: which table and which clause?</summary>

(a) Outer table `LOTS`. Inner tables `WAFERS` joined to `MEASUREMENTS`. (b) Outer table `PRODUCTS`, inner table `LOTS`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
-- (a)
SELECT l.lot_id, l.status
FROM   lots l
WHERE  NOT EXISTS (SELECT 1
                   FROM   wafers w
                   JOIN   ___ m ON m.wafer_id = w.wafer_id
                   WHERE  w.lot_id = ___.lot_id);

-- (b)
SELECT p.product_code
FROM   products p
WHERE  NOT EXISTS (SELECT 1 FROM lots l WHERE l.___ = p.___);
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

In (a) the missing names are `measurements` and `l`. In (b) the link is on `product_id`. One lot and one product come back.
</details>

### Exercise 5: Tools that never measured anything

Maya: "Which tools never took a measurement?" Use `MINUS`: all `tool_id`s from `TOOLS`, minus the `tool_id`s found in `MEASUREMENTS`. Sort the result.

<details>
<summary>Hint 1: which table and which clause?</summary>

Two `SELECT`s, one from `TOOLS`, one from `MEASUREMENTS`, joined by the word `MINUS`. `ORDER BY` goes once, at the very end.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT tool_id FROM ___
MINUS
SELECT tool_id FROM ___
ORDER  BY tool_id;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Both queries select the single column `tool_id`. You should get two tools, a polisher and an implanter.
</details>

## Part 5: Checking each row against its own group

### Exercise 6: Above my own tool's average

Maya: "Show me the eight measurements whose `defect_count` is above the average of the same tool. Worst first, ties by `meas_id`." Show `meas_id`, `tool_id`, `defect_count`.

This is a correlated subquery: the inner query needs to know the tool of the outer row.

<details>
<summary>Hint 1: which table and which clause?</summary>

Only `MEASUREMENTS`, used twice, once in the outer query (alias `m`) and once inside (alias `m2`). The link is on `tool_id`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT m.meas_id, m.tool_id, m.defect_count
FROM   measurements m
WHERE  m.defect_count > (SELECT AVG(m2.defect_count)
                         FROM   measurements m2
                         WHERE  m2.___ = m.___)
ORDER  BY ___ DESC, ___
FETCH FIRST 8 ROWS ONLY;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The link is `m2.tool_id = m.tool_id`. Your first row is `meas_id` 118 on `SPL01` with 60 defects.
</details>

## Part 6: A named sticky note

### Exercise 7: Lots bigger than the average lot

Maya: "Which lots have more wafers than the average lot?" Show `lot_id` and `wafer_count`.

Use `WITH` to name a list called `wafers_per_lot` (one row per lot with its count of wafers), then select from it where the count is above the average of that same list.

<details>
<summary>Hint 1: which table and which clause?</summary>

Count wafers per lot with `GROUP BY` on `WAFERS`. Put that in the `WITH` part. The main query reads the named list twice: once for rows, once inside a scalar subquery for the average.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
WITH wafers_per_lot AS (
  SELECT lot_id, COUNT(*) AS wafer_count
  FROM   ___
  GROUP  BY ___
)
SELECT lot_id, wafer_count
FROM   wafers_per_lot
WHERE  wafer_count > (SELECT ___(wafer_count) FROM wafers_per_lot)
ORDER  BY lot_id;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`FROM wafers GROUP BY lot_id`, and `AVG`. Nine lots have 5 wafers, which is above the average.
</details>

## Part 7: Combining lists

### Exercise 8: UNION, UNION ALL and INTERSECT

Maya wants three lists built from the same two sources: List A is lots that have a wafer graded `SCRAP` (from `WAFERS`). List B is lots on `HOLD` (from `LOTS`).

- **8a.** One list, each lot once: `UNION`.
- **8b.** The same, stapled together with `UNION ALL`. Which lot appears more than once, and how often? Why does that lot have so many rows? (Hint: how many `SCRAP` wafers does it have?)
- **8c.** Change List B to "lots with status `SCRAPPED`" and ask for the lots on both lists: `INTERSECT`.

<details>
<summary>Hint 1: which table and which clause?</summary>

List A is `SELECT lot_id FROM wafers WHERE grade = 'SCRAP'`. List B is `SELECT lot_id FROM lots WHERE status = ...`. The set operator goes between them, and `ORDER BY lot_id` at the very end.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT lot_id FROM wafers WHERE grade = 'SCRAP'
___
SELECT lot_id FROM lots WHERE status = 'HOLD'
ORDER  BY lot_id;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

8a uses `UNION`, 8b uses `UNION ALL`, 8c uses `INTERSECT` and changes `'HOLD'` to `'SCRAPPED'`. For 8c you do not need `ORDER BY`, since there is one row.
</details>

## Checkpoints

Tick each box before you finish.

- [ ] I wrote a subquery inside `WHERE` and did not type a calculated value by hand
- [ ] My exercise 3a gave an empty result, and I can explain why in one sentence
- [ ] Exercises 3c and 3d return the same 13 lots
- [ ] I found the lot that was never measured and the product that has no lots
- [ ] I can say which clause links the inner query to the outer row in a correlated subquery
- [ ] I can explain the difference between `UNION` and `UNION ALL`

## Stretch

Answer exercise 4b (products with no lots) a third way, without any subquery: `LEFT JOIN` products to lots and keep the rows where the lot side is empty. Which of the three forms (`NOT IN`, `NOT EXISTS`, `LEFT JOIN ... IS NULL`) do you find easiest to read? Which one would you trust on a column that might hold `NULL`?
