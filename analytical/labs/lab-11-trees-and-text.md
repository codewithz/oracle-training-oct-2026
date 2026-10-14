# Lab 11: Trees and text

**Time:** 40 minutes. **Reading first:** [Trees: hierarchical queries](../topics/05-trees.md) and [Regular expressions](../topics/06-regular-expressions.md).

> **Your tables are safe.** Everything here is a `SELECT` on `LOTS` and `LOT_HISTORY`. Only exercise 7 creates a table of your own, `MY_NOTES_CLEAN`, and it removes it at the end. `LOT_HISTORY` exists because you ran the add-on script in Lab 8.

## The story

Maya has two things on her desk. The first is a quality complaint about a reworked lot, and she needs to know where it came from. The second is the weekly report, which is full of free-text notes from the operators. "I do not want to read them one by one," she says. "Can you find out what is in them?"

## What you will do

- list the lot genealogy as an indented tree, with paths, roots and leaves
- walk up from a lot to its ancestors
- see the difference between a filter in `WHERE` and one in `CONNECT BY`
- pull tool ids, readings, tickets and an email out of the notes
- clean the notes and mask the address in a copy

## Scripts

| File | What it does |
| --- | --- |
| [`lab11_trees_and_text.sql`](scripts/lab11_trees_and_text.sql) | Every exercise as a comment with space for your statement. Run as `FAB_LAB`. |

Solutions: [lab-11-solutions.md](../solutions/lab-11-solutions.md). The solutions need no special setup. In DBeaver, run one statement at a time with `Ctrl + Enter`. If the indent in the tree looks flat in the grid, switch the results panel to **Text** view.

## Part 1: Trees

### Exercise 1: The family tree of lots

Maya: "Show me every lot as a family tree. Indent the children, show the generation number, the type and the status. Children go under their parent, sorted by lot id."

**Checkpoint:** 16 rows. `L26-003B1` is on level 3.

<details>
<summary>Hint 1: which clauses?</summary>

You need `START WITH` to say where the walk begins, and `CONNECT BY PRIOR` to say how to go down one step. The roots are the lots that have no parent.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT LEVEL AS lvl,
       LPAD(' ', 2 * (LEVEL - 1)) || lot_id AS lot_tree,
       lot_type, status
FROM   lots
START  WITH ___
CONNECT BY PRIOR ___ = ___
ORDER  SIBLINGS BY ___;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The roots are the rows where `parent_lot_id IS NULL`. A child is a row whose `parent_lot_id` equals the `lot_id` of the row before it.
</details>

**Common trap.** Leave out `START WITH` and run `SELECT COUNT(*) FROM lots CONNECT BY PRIOR lot_id = parent_lot_id;`. You get 21 instead of 16. Every row became a root, so the lots with a parent are listed again under their ancestors.

### Exercise 2: Path, root and leaf

Maya: "For every lot that has a parent, show the path from the original lot down to it, written like `L26-003/L26-003B`. Add the original lot and say whether this lot has children of its own."

**Checkpoint:** 4 rows. `L26-003B` is the only one with children.

<details>
<summary>Hint 1: which tools?</summary>

`SYS_CONNECT_BY_PATH`, `CONNECT_BY_ROOT` and `CONNECT_BY_ISLEAF`. To leave out the roots, filter on `LEVEL`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT lot_id,
       LTRIM(SYS_CONNECT_BY_PATH(lot_id, '/'), '/') AS path,
       CONNECT_BY_ROOT ___ AS root_lot,
       CONNECT_BY_ISLEAF AS is_leaf
FROM   lots
WHERE  LEVEL > ___
START  WITH ___
CONNECT BY PRIOR ___ = ___;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`LEVEL > 1` removes the roots after the walk. The path always starts with its separator, so the `LTRIM` is there to remove the leading `/`.
</details>

### Exercise 3: Where did this lot come from?

Maya: "A customer complained about a wafer from `L26-003B1`. Which lots is it descended from? Show the steps up, the lot, the type and the status."

**Checkpoint:** 3 rows, ending with `L26-003`.

<details>
<summary>Hint 1: direction</summary>

You start at the child and move towards the parents. Which side of the `=` does `PRIOR` go on when you walk up?
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT LEVEL AS steps_up, lot_id, lot_type, status
FROM   lots
START  WITH lot_id = '___'
CONNECT BY lot_id = PRIOR ___;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

"The next row is the one whose `lot_id` is the `parent_lot_id` of the row I am on."
</details>

**Common trap.** Write `CONNECT BY PRIOR lot_id = parent_lot_id` instead. You walk down, and `L26-003B1` has no children, so you get one row back.

### Exercise 4: One filter, two places

Maya: "Show me the L26-003 family without the lots on hold."

- **4a.** Put the hold test in `WHERE`. Start at `L26-003`, indent the tree, sort siblings by lot id.
- **4b.** Maya changes her mind: "I meant: follow the family, but stop at any lot that is on hold and do not look below it." Put the hold test in `CONNECT BY` instead.

Before you run them, predict how many rows each gives.

**Checkpoint:** 4a returns 3 rows, 4b returns 2 rows. Which lot is in the first answer and not in the second?

<details>
<summary>Hint 1: the difference</summary>

`WHERE` is applied to the finished tree, row by row. `CONNECT BY` is applied while the walk is going on, so a lot that fails the test is never stepped on, and nothing below it is reached.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
-- 4a
SELECT LEVEL AS lvl, LPAD(' ', 2 * (LEVEL - 1)) || lot_id AS lot_tree, status
FROM   lots
WHERE  ___
START  WITH lot_id = 'L26-003'
CONNECT BY PRIOR lot_id = parent_lot_id
ORDER  SIBLINGS BY lot_id;

-- 4b: same without the WHERE, and add AND ___ to the CONNECT BY line
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The test is `status <> 'HOLD'`. In 4b it follows `parent_lot_id` after an `AND`. The extra lot in 4a is the one that hangs below the lot on hold.
</details>

## Part 2: Text

### Exercise 5: What do the operators write about?

- **5a.** Maya: "Which tool is named most often in the notes?" Count the notes per tool.
- **5b.** Maya: "How many notes name a tool but give no measurement, ticket or other number at all?"

**Checkpoint:** 5a gives 9 tools, with `MET01` and `SPL02` tied at 12. 5b gives 18.

<details>
<summary>Hint 1: the pattern</summary>

A tool id is three capital letters and two digits: `MET02`, `SPL01`. For 5a cut it out with `REGEXP_SUBSTR` and group on the result. For 5b the tool ids and lot ids (`L26-003`) contain digits themselves. Remove them before you look for digits.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
-- 5a
SELECT REGEXP_SUBSTR(note, '___') AS tool, COUNT(*) AS notes
FROM   lot_history
WHERE  REGEXP_LIKE(note, '___')
GROUP  BY REGEXP_SUBSTR(note, '___')
ORDER  BY notes DESC, tool;

-- 5b
SELECT COUNT(*)
FROM   lot_history
WHERE  REGEXP_LIKE(note, '___')
AND    NOT REGEXP_LIKE(REGEXP_REPLACE(note, '___|L26-[0-9A-Z]+'), '[0-9]');
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The pattern is `[A-Z]{3}[0-9]{2}` in all four blanks. With two arguments, `REGEXP_REPLACE` deletes whatever the pattern matches. Notes that are `NULL` never match, so they do not appear.
</details>

### Exercise 6: Numbers and tickets hiding in the notes

- **6a.** Maya: "Pull the readings in nm out of the notes as real numbers. How many are there, and what are the lowest, highest and average?"
- **6b.** "Which three notes have the highest readings? Show the history row, the lot, the number and the new status."
- **6c.** "How many tickets of each kind, `INC` and `FAB-OPS`, are in the notes?"

**Checkpoint:** 26 readings, average 100.2. The highest is 1104, on lot `L26-008`. Tickets: `FAB-OPS` 8, `INC` 23.

<details>
<summary>Hint 1: what to build</summary>

A reading is a number, maybe with a decimal part, maybe a space, then `nm`: `12.4nm`, `812.5 nm`. Put brackets round the number so that you can ask for just that part with the subexpression argument, and wrap it in `TO_NUMBER`. For 6b, sort in an inline view and take the first three rows in the outer query. For 6c, the ticket prefix is a group with an `|` in it.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
-- the number as a number
TO_NUMBER(REGEXP_SUBSTR(note, '(___(\.[0-9]+)?) ?nm', 1, 1, NULL, ___), '9999.99')

-- the ticket prefix
REGEXP_SUBSTR(note, '(INC|___)-[0-9]+', 1, 1, NULL, ___)
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The digits part is `[0-9]+`. Subexpression 1 is the outer bracket in the reading pattern, and subexpression 1 is also the `(INC|FAB-OPS)` bracket in the ticket pattern. To keep only notes that have a reading, use `WHERE REGEXP_LIKE(note, '[0-9] ?nm')`.
</details>

**Common trap.** A loose pattern such as `[0-9]+` finds the first run of digits, not the reading. In note 6 (`hold per FAB-OPS-113, thickness 58.1 nm`) it returns 113.

### Exercise 7: A cleaned copy for the weekly report

Maya: "Make a copy of the notes for the weekly report: single spaces only, and hide the email address."

- **7a.** Count the notes that have a gap of two or more spaces.
- **7b.** Create `MY_NOTES_CLEAN` with `hist_id`, `lot_id` and the cleaned `note`. Check how many rows it has, and how many still have a gap or an `@`.
- **7c.** Drop the table and check that you have no `MY_` tables left.

**Checkpoint:** 16 messy notes before. 147 rows in the copy, 0 gaps and 0 emails after. 0 tables left at the end.

<details>
<summary>Hint 1: two replacements</summary>

Use `REGEXP_REPLACE` twice, one inside the other: first collapse the gaps, then mask the address. `\s{2,}` means two or more white-space characters.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
CREATE TABLE my_notes_clean AS
SELECT hist_id, lot_id,
       REGEXP_REPLACE(
         REGEXP_REPLACE(note, '___', ' '),
         '[[:alnum:]._]+@[[:alnum:].]+', '___') AS note
FROM   lot_history;
```

To count what is left, use `SUM(CASE WHEN REGEXP_LIKE(note, '...') THEN 1 ELSE 0 END)`.
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Gap pattern `\s{2,}`, masked address `***`. The check for leftovers uses the patterns `\s{2,}` and `@`. Clean up with `DROP TABLE my_notes_clean PURGE;` and list tables with `LIKE 'MY\_%' ESCAPE '\'`.
</details>

## Checkpoints

- [ ] Exercise 1 listed 16 lots and L26-003B1 is on level 3
- [ ] I can say why leaving out `START WITH` gives 21 rows
- [ ] Exercise 3 returned 3 rows, and I can say which way `PRIOR` points
- [ ] 4a gave 3 rows and 4b gave 2, and I can explain the extra row
- [ ] Tools: 9 found, 18 notes with a tool and no number
- [ ] Readings: 26 notes, average 100.2. Tickets: 8 and 23
- [ ] The cleaned copy had 147 rows and no gaps or emails, and I dropped it
- [ ] `LOTS` and `LOT_HISTORY` are unchanged

## Stretch

Write exercise 1 again as a recursive `WITH` with a column list, and `SEARCH DEPTH FIRST BY lot_id SET walk_order`. Order the result by `walk_order`. Then add a `CYCLE` clause and say what it would do if the data had a loop.
