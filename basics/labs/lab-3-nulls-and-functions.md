# Lab 3: NULL and single-row functions

**Time:** 45 minutes. **Reading first:** [NULL and single-row functions](../topics/04-nulls-and-functions.md).

## The story

Maya is pleased with your first answers and now brings the awkward questions. "The board has blanks on it," she says. "Some say nothing, some say zero, and I never know which. And the dates look like a bar code. Can you tidy it up?"

The blanks are the `NULL` values from the reading, and the tidying is done with functions. Take your time with the first two exercises. The `NULL` rules are the part of SQL that surprises people most, and a surprise now in the lab is cheaper than one later in a report.

## What you will do

- find rows with a missing value, and watch `= ''` fail
- replace missing values with `NVL` and `COALESCE`
- label rows with `CASE`, including TOO THIN, ON TARGET and TOO THICK
- format dates with `TO_CHAR` and move them with `ADD_MONTHS`
- build text with `||` and compare text without caring about case

## Scripts

| File | What it does |
| --- | --- |
| [`lab3_nulls_and_functions.sql`](scripts/lab3_nulls_and_functions.sql) | The questions as comments, with space for your answers. Open it as `fab-lab`. |
| [`lab-3-solutions.md`](../solutions/lab-3-solutions.md) | Answers with real output. Look only after you have tried. |

## How to work

Same as last lab: type under each question, run one statement at a time with `Ctrl + Enter`, and open hints one at a time. Before you run a query, guess the number of rows. Several of today's exercises are designed so the first answer you think of is wrong.

## Exercise 1: Lots on hold with no reason

**Maya asks:** "Which lots are on hold and nobody wrote down why?" Show the lot, the status and the reason.

Try two versions. Part **a**: use `hold_reason = ''` (an empty string) and look at the result. Part **b**: write it the correct way.

<details>
<summary>Hint 1: which table and which clause</summary>

`LOTS`. One condition on `status`, one on `hold_reason`. Remember the box nobody opened.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

a) `WHERE status = 'HOLD' AND hold_reason = ''`. b) `WHERE status = 'HOLD' AND hold_reason ___ ___`. The blank is a two-word test for "has no value".

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

b) `WHERE status = 'HOLD' AND hold_reason IS NULL`. Part a returns nothing, and no error either.

</details>

## Exercise 2: Wafers with no grade

**Maya asks:** "Which wafers have no grade yet?" Show the wafer and its lot.

Then a second question: "How many wafers are not PRIME, counting the ungraded ones too?" Count them.

<details>
<summary>Hint 1: which table and which clause</summary>

`WAFERS`, column `grade`. The first is a plain `IS NULL`. The second needs the `NULL` test added to a `<>` test.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

First: `WHERE grade ___ ___`. Second: `SELECT COUNT(*) FROM wafers WHERE grade <> 'PRIME' ___ grade ___ ___`. `COUNT(*)` counts rows.

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`WHERE grade <> 'PRIME' OR grade IS NULL`. Try it without the `OR` part too, and note how the count changes.

</details>

## Exercise 3: Label the ungraded

**Maya asks:** "For the wafers of lots L26-011 and L26-012, show each wafer and its grade, but where nobody has graded it, write UNGRADED." Sort by wafer id.

<details>
<summary>Hint 1: which table and which clause</summary>

`WAFERS`. Replace a `NULL` with a word using the function that means "if this is empty, use that". Two lots: `IN`.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`SELECT wafer_id, NVL(___, '___') AS label FROM wafers WHERE lot_id IN (___, ___) ORDER BY ___;`

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`SELECT wafer_id, NVL(grade, 'UNGRADED') AS label FROM wafers WHERE lot_id IN ('L26-011', 'L26-012') ORDER BY wafer_id;`

</details>

## Exercise 4: The board with reasons

**Maya asks:** "Give me the lots on hold with the reason. If nobody wrote a reason, write NO REASON RECORDED." Use `COALESCE` this time.

<details>
<summary>Hint 1: which table and which clause</summary>

`LOTS`, filtered on status. `COALESCE` takes a list of values and returns the first one that is not `NULL`.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`SELECT lot_id, COALESCE(___, '___') AS reason FROM lots WHERE ___ = 'HOLD';`

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`COALESCE(hold_reason, 'NO REASON RECORDED')`

</details>

## Exercise 5: Words for lot types, and for priority

**Maya asks:** Two small boards.

- **a)** "Show each lot with a plain description of its type: PROD is 'normal production', SPLIT is 'split from a parent', REWORK is 'reworked from a parent'." Use a simple `CASE`.
- **b)** "For lots that are not shipped, show the priority as words: 1 is URGENT, 2 is SOON, anything else is WHEN READY." Use a searched `CASE`.

<details>
<summary>Hint 1: which table and which clause</summary>

`LOTS`. `CASE` is a series of "if" cards. Part **a** compares one column to several values. Part **b** can use full tests.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

a) `CASE lot_type WHEN '___' THEN '___' WHEN ... ELSE '___' END`. b) `CASE WHEN priority = ___ THEN '___' WHEN ... ELSE '___' END`.

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

End each `CASE` with `END AS some_name`. Always give an `ELSE`, or unmatched rows turn into `NULL`.

</details>

## Exercise 6: Too thin, on target, too thick

**Maya asks:** "For the FD-300 wafers, tell me whether each FINAL reading is TOO THIN, ON TARGET or TOO THICK. The target is 12 nm. Anything within 0.1 nm of it is on target." FD-300 wafers are in lots `L26-001`, `L26-003` (and its children), `L26-007` (and its child) and `L26-011`. Show the wafer, the thickness and the verdict.

<details>
<summary>Hint 1: which table and which clause</summary>

`MEASUREMENTS`, step FINAL. The wafer ids start with the lot id, so `LIKE` can select a lot and its children. You need a bracket because you will join several `LIKE`s with `OR`, and `AND step = 'FINAL'` must apply to all of them.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`WHERE step = 'FINAL' AND (wafer_id LIKE '___%' OR wafer_id LIKE '___%' OR ...)`. The label is `CASE WHEN thickness_nm < 12 - 0.1 THEN '___' WHEN thickness_nm > ___ THEN '___' ELSE '___' END`.

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The four patterns are `L26-001%`, `L26-003%`, `L26-007%` and `L26-011%`. Thin below 11.9, thick above 12.1. Sort by wafer id.

</details>

## Exercise 7: Dates in a readable shape

**Maya asks:** "For the lots of the L26-007 family, show the start as day/month/year with the time, and a review date one month after the start, written as year-month-day." Show lot, start and review date.

<details>
<summary>Hint 1: which table and which clause</summary>

`LOTS`. `TO_CHAR(date, 'mask')` turns a date into text. `ADD_MONTHS(date, n)` moves a date by months. The family is selected with `LIKE`.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`SELECT lot_id, TO_CHAR(start_date, '___') AS started, TO_CHAR(ADD_MONTHS(start_date, ___), '___') AS review FROM lots WHERE lot_id LIKE '___%' ORDER BY lot_id;`

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

The masks are `'DD/MM/YYYY HH24:MI'` and `'YYYY-MM-DD'`.

</details>

## Exercise 8: Building a label

**Maya asks:** Two small jobs.

- **a)** "I want a one-line label for every lot that is not a normal production lot, like `L26-003B (SPLIT, HOLD)`." Join the lot id, the type and the status with `||`.
- **b)** "I typed l26-007a in lower case. Find that lot." Make the match ignore case.

<details>
<summary>Hint 1: which table and which clause</summary>

`LOTS`. Part **a**: `lot_type <> 'PROD'` selects the splits and reworks, and `||` glues text together. Part **b**: put a function on both sides of the `=`.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

a) `SELECT lot_id || ' (' || ___ || ', ' || ___ || ')' AS label FROM lots WHERE ___ <> 'PROD' ORDER BY ___;` b) `WHERE UPPER(___) = UPPER('l26-007a')`.

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

Remember the quotes around the text bits: `' ('`, `', '` and `')'`.

</details>

## Stretch: how far from the target?

**Maya asks:** "For the FINAL readings of the L26-003B lot, how far is each from the 12 nm target? Just the size of the miss, rounded to one decimal, biggest miss first." Show the wafer, the thickness and the miss in nm.

<details>
<summary>Hint 1: which table and which clause</summary>

`MEASUREMENTS`. A subtraction, then `ABS` to drop the minus sign, then `ROUND` to one decimal.

</details>

<details>
<summary>Hint 2: the skeleton</summary>

`ABS(ROUND(___ - 12, ___)) AS miss_nm` and `ORDER BY ___ DESC`.

</details>

<details>
<summary>Hint 3: nearly the answer</summary>

`wafer_id LIKE 'L26-003B-%'` selects only the lot L26-003B, not its child L26-003B1.

</details>

## Checkpoints

- [ ] I can explain why `hold_reason = ''` finds nothing in Oracle
- [ ] I used `IS NULL` and `IS NOT NULL` and got the lot `L26-005`
- [ ] My ungraded count was 2, and I know why `<>` alone gave me 13 and not 15
- [ ] Every `CASE` I wrote has an `ELSE`
- [ ] My dates are written with a mask, not left to the default display

## Further reading

- [Oracle Database 19c SQL Language Reference: Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Functions.html)
