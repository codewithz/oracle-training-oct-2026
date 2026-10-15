# Lab 12: What your SELECT sees

**Time:** 30 minutes. **Reading first:** [What your SELECT sees](../topics/07-what-your-select-sees.md). It builds on [Lab 7](../../basics/labs/lab-7-changing-data.md), where you used two tabs for the first time.

> **Your original tables are safe.** You only change your own copy, `MY_LOTS_COPY`. `LOTS` is read and never changed. The last exercise drops the copy.

## The story

Maya runs a morning report while the night shift is still correcting lots. "Which numbers do I get," she asks, "the ones from when I pressed the button, or the ones that are changing right now?" Then, half joking: "And if somebody deletes something by mistake, can you get it back without calling the DBA?"

You will find out with two editors side by side.

## What you will do

- watch one tab change data while the other tab reads
- keep a report consistent with a read-only transaction
- read an older state of a row and of a table (flashback query)
- put deleted rows back from the past
- lock a row with `FOR UPDATE` and see what `NOWAIT`, `WAIT` and `SKIP LOCKED` do
- clean up

## Before you start: two tabs in manual commit mode

This is the setup from Lab 7, exercise 8. If you did not do that one, read this carefully.

1. Open a SQL editor on the `fab-lab` connection. This is **tab A**.
2. Open a second SQL editor on the same connection. This is **tab B**. Right-click an editor tab to rename them if you like.
3. Make sure the DBeaver option **Open separate connection for each editor** is ticked (it is the same option as in Lab 7). Without it the two tabs share one session, and nothing in this lab works as described.
4. In each tab, click the transaction mode button in the toolbar (it shows **Auto**) and choose **Manual Commit**. You should see **Commit** and **Rollback** buttons and a counter of pending statements.
5. Arrange the two editors so that you can see both at once, for example by dragging one tab to the side.

Switch both back to Auto-Commit at the end.

## Scripts

| File | What it does |
| --- | --- |
| [`lab12_what_your_select_sees.sql`](scripts/lab12_what_your_select_sees.sql) | Every exercise as comments with room for your statements. Run as `FAB_LAB`. |

Solutions: [lab-12-solutions.md](../solutions/lab-12-solutions.md). Run statements one at a time with `Ctrl + Enter`.

## Part 1: Reading while others write

### Exercise 1: Sandbox and two sessions

Maya: "Make a copy of the lot list for yourself, and prove that your two tabs are really two sessions."

- Tab A: create `MY_LOTS_COPY` as a copy of `LOTS` and count its rows.
- Run `SELECT SYS_CONTEXT('USERENV', 'SID') AS my_session FROM dual;` in tab A and in tab B.

**Checkpoint:** 16 rows. The two session numbers differ.

<details>
<summary>Hint 1: which statement?</summary>

`CREATE TABLE ... AS SELECT`, as in Lab 7.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
CREATE TABLE ___ AS SELECT * FROM ___;
SELECT COUNT(*) FROM ___;
```
</details>

<details>
<summary>Hint 3: if the numbers are the same</summary>

Both tabs use one connection. Tick **Open separate connection for each editor**, close the tabs and open them again.
</details>

### Exercise 2: Your pencil is invisible to others

Maya: "If the night shift changes a lot while I am looking, do I wait, and what do I see?"

- **Tab B:** set `priority = 9` for lot `L26-001`. Do not commit.
- **Tab A:** select `lot_id` and `priority` for that lot. What do you see? Did the query wait?
- **Tab B:** click **Commit**.
- **Tab A:** run the same select again.

Predict both answers before you run them.

**Checkpoint:** tab A shows 3 straight away, then 9 after tab B has committed.

<details>
<summary>Hint 1: what to look for</summary>

Is tab B's change in pencil or in ink when tab A reads? Does a plain `SELECT` ever wait for a writer?
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
-- tab B
UPDATE my_lots_copy SET priority = ___ WHERE lot_id = '___';
-- tab A
SELECT lot_id, priority FROM my_lots_copy WHERE lot_id = '___';
```
</details>

<details>
<summary>Hint 3: if tab A shows 9 at once</summary>

Tab B is probably in Auto-Commit mode, and committed by itself. Check its transaction button.
</details>

### Exercise 3: One photograph for the whole report

Maya: "My report runs several queries. If a change is committed between two of them, the totals do not match. Can I stop that?"

- **Tab A:** run `SET TRANSACTION READ ONLY;`. Then count the lots and add up their priority.
- **Tab B:** add 1 to the priority of every lot whose status is `ACTIVE`. Commit.
- **Tab A:** run the same count and sum again. Then click **Commit**, and run it once more.

**Checkpoint:** 16 lots. The sum is 38 the first two times and 46 after tab A's commit.

<details>
<summary>Hint 1: what does READ ONLY do?</summary>

It makes every query in the transaction read from the same moment, until you commit or roll back.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
-- tab A
SET TRANSACTION READ ONLY;
SELECT COUNT(*) AS lots, SUM(priority) AS total_priority FROM my_lots_copy;
-- tab B
UPDATE my_lots_copy SET priority = priority + 1 WHERE status = '___';
COMMIT;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Run the same select in tab A three times: before tab B's commit, after it, and after tab A's own commit.
</details>

**Common trap.** `SET TRANSACTION READ ONLY` must be the first statement of a transaction. If tab A has pending changes, you get `ORA-01453`. Click **Rollback** or **Commit** in tab A first. If your sum is not 38, make sure exercise 2 was finished: `L26-001` must be at priority 9.

## Part 2: The old photo album

### Exercise 4: What was it a minute ago?

Maya: "Lot L26-002 is at priority 2. Somebody changes it twice. Show me what it was in between, and show me the whole history of the row."

Use one tab.

- **4a.** Set `priority = 7` for `L26-002` and commit. Wait about ten seconds.
- **4b.** Note the time with `SELECT TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') FROM dual;` and write it down. Wait about ten seconds more.
- **4c.** Set `priority = 8` for `L26-002` and commit.
- **4d.** Show the priority now, and the priority at the time you wrote down.
- **4e.** List every version of the row.

**Checkpoint:** now 8, then 7. The versions list shows 2, 7 and 8, with `U` (update) on the later two.

<details>
<summary>Hint 1: which clauses?</summary>

`AS OF TIMESTAMP` goes right after the table name. For the list of versions, use `VERSIONS BETWEEN TIMESTAMP MINVALUE AND MAXVALUE` and the pseudocolumns `VERSIONS_STARTTIME`, `VERSIONS_ENDTIME` and `VERSIONS_OPERATION`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT priority
FROM   my_lots_copy AS OF TIMESTAMP TO_TIMESTAMP('___', 'YYYY-MM-DD HH24:MI:SS')
WHERE  lot_id = 'L26-002';

SELECT versions_starttime, versions_endtime, versions_operation AS op, priority
FROM   my_lots_copy VERSIONS BETWEEN TIMESTAMP MINVALUE AND ___
WHERE  lot_id = 'L26-002'
ORDER  BY versions_starttime NULLS FIRST;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Type the time you wrote down in the first blank, for example `2026-10-13 10:42:15`.
</details>

**Common trap.** Skipping the waits. Oracle matches a timestamp to a change number in steps of about three seconds, so a time very close to a commit can return the older value. Another one: a time from before `MY_LOTS_COPY` was created gives `ORA-01466: unable to read data - table definition has changed`.

### Exercise 5: Put back what was deleted

Maya: "Somebody deleted the shipped lots by mistake. Put them back."

- **5a.** Note the time, as in 4b, and wait about ten seconds.
- **5b.** In `MY_LOTS_COPY`, delete the lots with status `SHIPPED`, commit, and count the rows.
- **5c.** Insert them again from the time you noted, commit, and count the rows. Then count the lots per status.

**Checkpoint:** 11 rows after the delete, 16 after the insert. Status counts: `ACTIVE` 8, `HOLD` 2, `SCRAPPED` 1, `SHIPPED` 5.

<details>
<summary>Hint 1: which statement?</summary>

`INSERT INTO ... SELECT ...`, where the `SELECT` reads the table `AS OF TIMESTAMP`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
INSERT INTO my_lots_copy
SELECT * FROM my_lots_copy AS OF TIMESTAMP TO_TIMESTAMP('___', 'YYYY-MM-DD HH24:MI:SS')
WHERE  status = '___';
COMMIT;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Use the time from 5a. Flashback only reads, and the rows are not back until the `INSERT` is committed. Do not use `TRUNCATE` for the delete, because it makes the older state unreadable.
</details>

## Part 3: The SELECT that locks

### Exercise 6: FOR UPDATE and its options

Maya: "Two planners both want to take lot L26-001 to the next stage. How do I stop them taking the same lot?"

- **Tab B:** `SELECT lot_id FROM my_lots_copy WHERE lot_id = 'L26-001' FOR UPDATE;`. Do not commit.
- **Tab A:** try (a) a plain `SELECT` of that lot, (b) the same with `FOR UPDATE NOWAIT`, (c) with `FOR UPDATE WAIT 5`, and (d) a `FOR UPDATE SKIP LOCKED` over `L26-001`, `L26-002` and `L26-003`, ordered by lot id. Note what happens in each case and how long it takes.
- **Tab B:** click **Rollback**.
- **Tab A:** run (b) again, then click **Rollback**.

**Checkpoint:** (a) works at once. (b) fails at once with ORA-00054. (c) waits 5 seconds and fails with ORA-30006. (d) returns 2 rows, `L26-002` and `L26-003`. After tab B's rollback, (b) returns the lot.

<details>
<summary>Hint 1: which keywords?</summary>

`FOR UPDATE` goes at the very end of the `SELECT`. After it come `NOWAIT`, `WAIT n` or `SKIP LOCKED`.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
SELECT lot_id FROM my_lots_copy WHERE lot_id = 'L26-001' FOR UPDATE ___;
SELECT lot_id FROM my_lots_copy WHERE lot_id = 'L26-001' FOR UPDATE WAIT ___;
SELECT lot_id FROM my_lots_copy
WHERE  lot_id IN ('L26-001', 'L26-002', 'L26-003')
ORDER  BY lot_id
FOR UPDATE ___ ___;
```
</details>

<details>
<summary>Hint 3: if tab A seems frozen</summary>

That is the plain `FOR UPDATE` with no option: it waits for as long as it takes. Click **Rollback** in tab B, or cancel the statement in tab A. You asked for options, so use one.
</details>

**Common trap.** Reading the `SKIP LOCKED` result as the full answer. It silently leaves out the locked lot.

## Part 4: Clean up

### Exercise 7: Leave no trace

Maya: "Make sure nobody's lock is left hanging."

Click **Rollback** in both tabs. Drop `MY_LOTS_COPY`. List the tables whose name starts with `MY_`: you should get none. Check that `LOTS` still has 16 rows. Switch both tabs back to **Auto-Commit**.

**Checkpoint:** 0 `MY_` tables, 16 lots.

<details>
<summary>Hint 1: which statements?</summary>

`DROP TABLE ... PURGE;` and the `USER_TABLES` query from Lab 7.
</details>

<details>
<summary>Hint 2: skeleton</summary>

```sql
DROP TABLE ___ PURGE;
SELECT COUNT(*) FROM user_tables WHERE table_name LIKE 'MY\_%' ESCAPE '\';
SELECT COUNT(*) FROM lots;
```
</details>

<details>
<summary>Hint 3: nearly the answer</summary>

If your list is not empty, tables from an earlier lab may be left. Drop those that you made.
</details>

## Checkpoints

- [ ] In exercise 2, tab A saw 3 without waiting, and 9 after tab B's commit
- [ ] In exercise 3, the sum stayed 38 inside the read-only transaction, and became 46 after my commit
- [ ] In exercise 4, flashback showed 7 and the versions list showed 2, 7 and 8
- [ ] In exercise 5, the table went from 16 to 11 and back to 16
- [ ] I got ORA-00054 and ORA-30006 on purpose and can say which option causes which
- [ ] No `MY_` tables are left and `LOTS` has 16 rows
- [ ] Both tabs are back in Auto-Commit mode

## Stretch

Before you drop the table in exercise 7, run `SELECT priority FROM my_lots_copy AS OF TIMESTAMP SYSTIMESTAMP - INTERVAL '1' HOUR` (the table is only minutes old). Read the error, and say why Oracle cannot answer.
