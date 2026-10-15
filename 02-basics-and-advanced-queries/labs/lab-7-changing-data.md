# Lab 7: Creating tables and changing data

**Time:** 45 minutes. **Reading first:** [Creating tables and changing data](../topics/08-changing-data.md).

> **Your original tables are safe.** In this lab you only create and change your own tables, all named `MY_...`. The five FAB_LAB tables (`PRODUCTS`, `TOOLS`, `LOTS`, `WAFERS`, `MEASUREMENTS`) are only read, never changed, so later labs and days still work. The last exercise removes everything you made.

## The story

Maya wants to try some corrections on a copy of the lot list before anyone touches the real one. "Make yourself a sandbox," she says. "Put lots in, take lots out, make mistakes. Just make sure you can undo them."

You will practise the pencil-and-ink habit: change, check, then commit or roll back.

## What you will do

- copy `LOTS` into your own table `MY_LOTS_COPY`
- insert, update and delete rows, and use `ROLLBACK`, `SAVEPOINT` and `COMMIT`
- see what happens when you forget a `WHERE`
- compare `DELETE`, `TRUNCATE` and `DROP`
- break each constraint on purpose and read the error
- watch two sessions disagree about uncommitted data
- clean up

## Before you start: manual commit mode

DBeaver normally commits after every statement (**Auto-Commit**). In that mode `ROLLBACK` has nothing to undo, and this lab would not work as written.

1. Open a SQL editor on the `fab-lab` connection.
2. In the main toolbar, find the **transaction mode** button (it shows **Auto**). Click it and choose **Manual Commit**.
3. You should now see **Commit** and **Rollback** buttons and a counter of pending statements.

Switch back to Auto when you finish the lab.

## Scripts

| File | What it does |
| --- | --- |
| [`lab7_changing_data.sql`](scripts/lab7_changing_data.sql) | Every exercise as a comment with space for your statement. Includes the setup for exercise 6. Run as `FAB_LAB`. |

Solutions: [lab-7-solutions.md](../solutions/lab-7-solutions.md). Run statements one at a time with `Ctrl + Enter`, except the two `CREATE TABLE` statements in exercise 6, which you can run together with `Alt + X`.

## Part 1: Your sandbox

### Exercise 1: Make a copy of LOTS

Maya: "Make a copy of the lot list for yourself, with all its rows. Then check that the copy has 16 rows."

<details>
<summary>Hint 1: which statement?</summary>

`CREATE TABLE ... AS SELECT` creates a table from a query. The new table has the columns and the rows of the query.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
CREATE TABLE ___ AS SELECT * FROM ___;
SELECT COUNT(*) FROM ___;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The new table is `my_lots_copy` and the source is `lots`.
</details>

### Exercise 2: Insert, update, commit

Maya: "A new lot, L26-099, has arrived: product 1, type PROD, started 2026-10-12, status ACTIVE, priority 2. Then a particle check puts it on hold."

- **2a.** Insert the lot, naming the columns.
- **2b.** Select it to check.
- **2c.** Update its `status` to `HOLD` and its `hold_reason` to `Particle check`, for that lot only. Select it again.
- **2d.** Make everything permanent.

<details>
<summary>Hint 1: which statements?</summary>

`INSERT INTO ... (columns) VALUES (...)`, then `UPDATE ... SET ... WHERE ...`, then `COMMIT`. The copy kept the `NOT NULL` rules of `LOTS`, so every column except `parent_lot_id` and `hold_reason` needs a value.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
INSERT INTO my_lots_copy (lot_id, product_id, lot_type, start_date, status, priority)
VALUES ('___', ___, '___', DATE '___', '___', ___);

UPDATE my_lots_copy
SET    status = '___', hold_reason = '___'
WHERE  lot_id = '___';
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Dates are written `DATE '2026-10-12'`. Text values need single quotes, numbers do not. Do not forget the `WHERE` on the update.
</details>

## Part 2: Mistakes you can undo

### Exercise 3: The forgotten WHERE

Maya: "Show me what happens if someone forgets the WHERE. Do it here, not on the real table."

- **3a.** Set `priority = 1` on the whole of `MY_LOTS_COPY` with no `WHERE`. Count the lots per priority.
- **3b.** Undo it. Count the lots per priority again. Check that `L26-099` is still there, on `HOLD`.

Before you start, predict: will `L26-099` survive the rollback? Why?

<details>
<summary>Hint 1: which statement?</summary>

`UPDATE ... SET ...` with nothing after it changes every row. `ROLLBACK` throws away everything since your last `COMMIT`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
UPDATE my_lots_copy SET priority = ___;
SELECT priority, COUNT(*) FROM my_lots_copy GROUP BY ___ ORDER BY ___;
___;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

After the update, one priority value covers all rows. After `ROLLBACK`, you get the old mix. `L26-099` survives because you committed in exercise 2d.
</details>

### Exercise 4: DELETE and a SAVEPOINT

Maya: "Delete the shipped lots from the sandbox. Then delete the scrapped ones too. Then change your mind about the second delete only."

- **4a.** Delete the `SHIPPED` lots. Count the rows.
- **4b.** Set a savepoint called `after_shipped`.
- **4c.** Delete the `SCRAPPED` lots. Count.
- **4d.** Roll back to the savepoint. Count.
- **4e.** Roll back everything. Count.

Write your five counts in the margin. They should tell a story.

<details>
<summary>Hint 1: which statements?</summary>

`DELETE FROM ... WHERE ...`, `SAVEPOINT name`, `ROLLBACK TO name`, `ROLLBACK`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
DELETE FROM my_lots_copy WHERE status = '___';
SAVEPOINT ___;
DELETE FROM my_lots_copy WHERE status = '___';
ROLLBACK TO ___;
ROLLBACK;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Count after each step with `SELECT COUNT(*) FROM my_lots_copy;`. You start at 17 rows.
</details>

## Part 3: DELETE, TRUNCATE and DROP

### Exercise 5: Three ways to get rid of things

Maya: "Make a small table of shipped lots, then show me the difference between DELETE, TRUNCATE and DROP."

- **5a.** Create `MY_SHIPPED_LOTS` with the same columns as `LOTS` but no rows.
- **5b.** Fill it with `INSERT ... SELECT` from `LOTS` where `status = 'SHIPPED'`. Count the rows and `COMMIT`.
- **5c.** `DELETE` all its rows, `ROLLBACK`, count.
- **5d.** `TRUNCATE` the table, `ROLLBACK`, count.
- **5e.** `DROP` the table.

<details>
<summary>Hint 1: which statements?</summary>

For an empty copy, use a `WHERE` that is never true, such as `WHERE 1 = 0`. For `INSERT ... SELECT`, there is no `VALUES`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
CREATE TABLE my_shipped_lots AS SELECT * FROM lots WHERE ___;
INSERT INTO my_shipped_lots SELECT * FROM lots WHERE status = '___';
TRUNCATE TABLE ___;
DROP TABLE ___ PURGE;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Five rows after the insert. After 5c you have 5 again, after 5d you have 0. Which of the two rollbacks actually did something?
</details>

## Part 4: Break every rule on purpose

### Exercise 6: The bouncers

Maya: "Real tables have rules. Prove to me that they work."

Run the two `CREATE TABLE` statements from the script (they are written out for you, with named constraints). Then:

- **6a.** Insert products `(1, 'FD-300')` and `(2, 'RF-300')` and the lot `S-001` for product 1. `COMMIT`.
- **6b.** Break each rule, one statement at a time, and write down the `ORA-` number you get:
  1. a second lot with `lot_id` `S-001`
  2. a third product with code `FD-300`
  3. a lot with status `BROKEN`
  4. a lot for product `99`
  5. a lot with `product_id` set to `NULL`
  6. delete product `1`, which still has a lot

For each one, say which bouncer stopped it: primary key, unique, check, foreign key or not null.

<details>
<summary>Hint 1: which statements?</summary>

All six are plain `INSERT` or `DELETE` statements. The message names the constraint in brackets, for example `(FAB_LAB.MY_STRICT_LOTS_PK)`. The constraint names were chosen to tell you the rule.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
INSERT INTO my_strict_lots (lot_id, product_id) VALUES ('___', ___);
INSERT INTO my_strict_lots (lot_id, product_id, status) VALUES ('S-002', 1, '___');
DELETE FROM my_products WHERE product_id = ___;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Six attempts, five different bouncers. The delete in step 6 is stopped by the same foreign key as step 4, but from the parent's side.
</details>

### Exercise 7: DDL commits

Maya: "Does ROLLBACK always work?"

Insert lot `S-005` for product 2 into `MY_STRICT_LOTS`. Do **not** commit. Then run `CREATE TABLE my_tmp (x NUMBER);`. Then `ROLLBACK`. Then list the lots. Is `S-005` still there? Why?

<details>
<summary>Hint 1: think about</summary>

`CREATE TABLE` is DDL. What did the page say DDL does to a transaction that is in progress?
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
INSERT INTO my_strict_lots (lot_id, product_id) VALUES ('___', ___);
CREATE TABLE my_tmp (x NUMBER);
ROLLBACK;
SELECT lot_id FROM my_strict_lots ORDER BY lot_id;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

You should see two lots in the list.
</details>

## Part 5: Two sessions

### Exercise 8: Who sees my pencil?

You need two SQL editors on the `fab-lab` connection, both in Manual Commit mode, and both as separate sessions (the DBeaver option **Open separate connection for each editor** must be ticked). Call them tab A and tab B.

1. **Tab A:** `UPDATE my_lots_copy SET priority = 5 WHERE lot_id = 'L26-001';` Do not commit.
2. **Tab A:** select `lot_id, priority` for `L26-001`. What do you see?
3. **Tab B:** run the same `SELECT`. What do you see? Is it the same as in tab A?
4. **Tab B:** try `UPDATE my_lots_copy SET priority = 4 WHERE lot_id = 'L26-001';`. What happens?
5. **Tab A:** `COMMIT`. Look at tab B again.
6. **Tab B:** `ROLLBACK`. The table is your own copy and is dropped in exercise 9, so you do not need to restore anything.

Write one sentence for each of your answers in steps 2, 3 and 4.

<details>
<summary>Hint 1: what to look for</summary>

Step 3: is tab A's change in pencil or in ink? Step 4: who owns the row at the moment?
</details>

<details>
<summary>Hint 2: if tab B does not seem to wait</summary>

You are probably in the same session or in Auto-Commit mode. Check the transaction button in both tabs.
</details>

<details>
<summary>Hint 3: if you get stuck</summary>

If tab B appears frozen, that is the expected behaviour. Switch to tab A and commit or roll back, and tab B continues.
</details>

## Part 6: Clean up

### Exercise 9: Leave no trace

Drop `MY_TMP`, `MY_STRICT_LOTS`, `MY_PRODUCTS` and `MY_LOTS_COPY`, children before parents. Then list your tables whose name starts with `MY_`. You should get no rows. Finally check that your five original tables are still there with their original counts (5, 9, 16, 66, 186).

<details>
<summary>Hint 1: which statements?</summary>

`DROP TABLE name PURGE;` for each. `MY_STRICT_LOTS` has a foreign key to `MY_PRODUCTS`, so it goes first.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
DROP TABLE ___ PURGE;
SELECT table_name FROM user_tables WHERE table_name LIKE 'MY\_%' ESCAPE '\';
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Four `DROP`s. For the check, `SELECT COUNT(*) FROM lots;` should say 16.
</details>

## Checkpoints

- [ ] `MY_LOTS_COPY` had 16 rows, then 17 after my insert
- [ ] After exercise 3b, `L26-099` was still there, and I can say why
- [ ] I can explain which of the two rollbacks in exercise 5 undid something
- [ ] I got `ORA-00001`, `ORA-02290`, `ORA-02291`, `ORA-01400` and `ORA-02292` on purpose
- [ ] In exercise 7 the row survived the `ROLLBACK`, and I can say why
- [ ] In exercise 8, tab B saw the old value until tab A committed
- [ ] No `MY_` tables are left, and `LOTS` still has 16 rows
- [ ] I switched DBeaver back to Auto-Commit

## Stretch

Create a view `MY_HOLD_LOTS_V` over `MY_LOTS_COPY` that shows `lot_id`, `status` and `hold_reason` for lots on hold. Put a different lot on hold with an `UPDATE` and check that the view changes without being re-created. Remember to run `DROP VIEW my_hold_lots_v;` in exercise 9.
