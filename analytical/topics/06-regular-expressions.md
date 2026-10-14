# Regular expressions: finding patterns in free text

The `NOTE` column of `LOT_HISTORY` is where operators type whatever they like: `hold per FAB-OPS-113, thickness 58.1 nm`, `RELEASED. recheck IMP01 pass (INC-20666)`, `ok to continue   MET01` with too many spaces. `LIKE` can find a word in that text, but it cannot say "a tool id" or "a number followed by nm". Regular expressions can. They describe the shape of the text you want, and Oracle finds, cuts out or replaces anything that has that shape.

Open the animated page for this topic to see a pattern slide along a note: [06-regular-expressions.html](../tutorials/06-regular-expressions.html).

**By the end of this page you can:**

- read and write a small set of pattern pieces: `.`, `[ ]`, `^` and `$`, `*` `+` `?`, `{n}`, `( )`, `|`, `\d`, `\s`
- filter rows with `REGEXP_LIKE`, including a case-insensitive match
- cut out text with `REGEXP_SUBSTR`, choosing which match (occurrence) and which bracketed part (subexpression) you want
- find a position with `REGEXP_INSTR` and count matches with `REGEXP_COUNT`
- rewrite text with `REGEXP_REPLACE`
- say when `LIKE`, a regular expression or Oracle Text is the right tool

## The question this answers

Maya has 147 status-change rows, and the interesting facts are buried in the free-text `note` column: which tool was involved, which ticket was raised, which readings were quoted. The tool appears as `MET01` in one note and `SPL02` in another, the ticket as `INC-20666` or `FAB-OPS-113`, and the spacing is irregular. `LIKE` finds a fixed word with `%` around it, but it cannot say "three capital letters followed by two digits". A regular expression describes a shape instead of a word, and the `REGEXP` functions check for it, cut it out, count it or replace it.

## The analogy: a highlighter and a shape

You do not know any particular tool ID, but you know the shape: three capital letters, then two digits, like `MET01`. You take a highlighter and read a note from left to right. At each character you ask: does the shape fit starting here? The first place it fits is the match, and you highlight it.

| Note | Is there one? | The first one | How many | With them hidden |
|---|---|---|---|---|
| moved to MET01 after check | yes | MET01 | 1 | moved to XXX after check |
| customer away, back Tuesday | no | blank | 0 | customer away, back Tuesday |
| damaged, see CLM90 and MET07 | yes | CLM90 | 2 | damaged, see XXX and XXX |

- Is there one? A yes or no answer. That is `REGEXP_LIKE`, and it is what you put in `WHERE`.
- The first one: copy out what the highlighter found. That is `REGEXP_SUBSTR`.
- How many: count the highlighted bits. That is `REGEXP_COUNT`.
- With them hidden: cover each highlighted bit with something else. That is `REGEXP_REPLACE`.

**Where the picture breaks.**

- You would know that `ABC12` is not a real tool. The shape `[A-Z]{3}[0-9]{2}` accepts it as happily as `MET01`. Whether a match means something real is your check.
- A blank note is not "no". Oracle treats a NULL note as unknown, so `REGEXP_LIKE` on it is neither true nor false. 21 of the 147 notes are NULL, and they match neither the pattern nor its negation.
- Nothing is changed in the table. `REGEXP_REPLACE` returns new text and leaves the stored note as it was.

## What Oracle actually does

1. Take the text of the row. If it is NULL, the call returns NULL (unknown for `REGEXP_LIKE`) and nothing is searched.
2. Read the pattern as a list of pieces from left to right. A piece says what kind of character (a class such as `[A-Z]`, a literal, or `.` for any) and how many (`{3}`, `+`, `*`, `?`). Brackets group, `|` offers a choice, `^` and `$` anchor to the start and end.
3. Try to fit the whole list starting at the first character. Repeating pieces are greedy: they take as many characters as they can and give some back only if a later piece cannot otherwise fit.
4. If the list cannot fit here, slide one character right and try again. The first start position where it fits is the match, which is why the match is always the leftmost one. Without `^` or `$` it can be anywhere in the text.
5. Do what the function asks. `REGEXP_LIKE` returns true if any position fits and never returns the text. `REGEXP_SUBSTR(text, pattern, start, n, flags, group)` returns the n-th match, or only the part in bracket number `group`, or NULL. `REGEXP_INSTR` returns the position. `REGEXP_COUNT` counts non-overlapping matches. `REGEXP_REPLACE` replaces every match by default, and `\1` puts back the first bracketed group.
6. Letters are case sensitive unless you pass the flag `'i'`.

For the note `hold per FAB-OPS-121, thickness 87.7 nm` (hist_id 14), the pattern `[0-9]+` matches `121` at character 18, `87` at 33 and `7` at 36. `REGEXP_COUNT` gives 3 and `REGEXP_REPLACE(note, '[0-9]+', '#')` gives `hold per FAB-OPS-#, thickness #.# nm`. The reading 87.7 counts as two numbers because the dot is not a digit.

| In Oracle | With the highlighter |
|---|---|
| the pattern | the shape you describe |
| `REGEXP_LIKE` | is there one? yes or no |
| `REGEXP_SUBSTR` | copy out the first highlighted bit |
| `REGEXP_COUNT` | count the highlighted bits |
| `REGEXP_REPLACE` | cover the highlighted bits |
| greedy `+` | highlight the whole run of digits |
| NULL note | a blank note |

## The pieces you need

A pattern is ordinary text with a few characters that mean something special. This small set is enough for almost every real task.

| Piece | Meaning | Example | Matches |
| --- | --- | --- | --- |
| `.` | any one character | `58.1` | `58.1`, and also `58x1` |
| `\.` | a real dot | `58\.1` | only `58.1` |
| `[abc]` | one character from the list | `[MA]` | `M` or `A` |
| `[A-Z]` `[0-9]` | one character from a range | `[0-9]` | a digit |
| `[^0-9]` | one character not in the list | `[^0-9]` | anything but a digit |
| `^` | start of the text | `^hold` | text that begins with hold |
| `$` | end of the text | `nm$` | text that ends with nm |
| `*` | zero or more of the previous piece | `ab*` | `a`, `ab`, `abbb` |
| `+` | one or more | `[0-9]+` | `7`, `4198` |
| `?` | zero or one | `colou?r` | `color`, `colour` |
| `{n}` and `{n,m}` | exactly n, or n to m | `[0-9]{4}` | four digits |
| `( )` | a group, also a numbered part to pull out | `(INC)-([0-9]+)` | two parts |
| `\|` | or | `INC\|FAB-OPS` | either word |
| `\d` | a digit, same as `[0-9]` | `\d+` | `812` |
| `\s` | a space, tab or line break | `\s{2,}` | two or more of them |
| `[[:alnum:]]` | a letter or digit (named class) | `[[:alnum:]]+` | `fabops` |

The tool pattern in this topic is `[A-Z]{3}[0-9]{2}`: three capital letters, then two digits. In SQL, a pattern is a string in single quotes, like any other text. If the pattern needs a quote, you double it as usual.

A fifth piece is a flag, the last argument of most functions. `'i'` means ignore upper and lower case. `'c'` (the default) means respect it.

## REGEXP_LIKE: does the note fit the pattern?

`REGEXP_LIKE(column, pattern [, flags])` goes in a `WHERE` clause, like `LIKE`. It returns true or false, so it cannot be used in the `SELECT` list of a plain query.

The table has 147 history rows. Some have no note at all.

```sql
SELECT COUNT(*) AS all_notes, COUNT(note) AS with_text
FROM   lot_history;
```

```text
 ALL_NOTES  WITH_TEXT
---------- ----------
       147        126
```

Maya: "How many notes mention a hold?" The operators write HOLD, Hold and hold. `LIKE` is case sensitive, so it misses some.

```sql
SELECT COUNT(*) AS like_hold
FROM   lot_history
WHERE  note LIKE '%hold%';
```

```text
 LIKE_HOLD
----------
        49
```

```sql
SELECT COUNT(*) AS regexp_hold
FROM   lot_history
WHERE  REGEXP_LIKE(note, 'hold', 'i');
```

```text
REGEXP_HOLD
-----------
         57
```

The `'i'` flag found 8 more. `^` anchors the pattern to the start of the text. Maya: "Which notes start with the word hold?"

```sql
SELECT hist_id, note
FROM   lot_history
WHERE  REGEXP_LIKE(note, '^hold', 'i')
AND    hist_id <= 26
ORDER  BY hist_id;
```

```text
   HIST_ID NOTE
---------- ------------------------------------------------------------
         3 hold cleared, no action
         6 hold per FAB-OPS-113, thickness 58.1 nm
        14 hold per FAB-OPS-121, thickness 87.7 nm
        19 hold cleared, no action
        24 hold - thk OOS at FINAL, SPL01 read 38.4nm vs target
        26 HOLD: defect cnt high after SPL02 (INC-20829)
```

(I limited the output to the first rows. Without the `hist_id` filter, 35 rows match.)

Rows where `note` is `NULL` never match any pattern. `REGEXP_LIKE` on a NULL is neither true nor false, so those rows silently disappear from the result.

## REGEXP_SUBSTR: cut out the match

`REGEXP_SUBSTR(text, pattern [, start [, occurrence [, flags [, subexpression]]]])` returns the part of the text that fits the pattern, or NULL if nothing fits.

Maya: "Which tool is named in each note?"

```sql
SELECT hist_id,
       REGEXP_SUBSTR(note, '[A-Z]{3}[0-9]{2}') AS tool,
       note
FROM   lot_history
WHERE  hist_id <= 9
ORDER  BY hist_id;
```

```text
   HIST_ID TOOL   NOTE
---------- ------ ------------------------------------------------------------
         1        lot started
         2 MET03  Held by shift lead. particle count 61 on MET03
         3        hold cleared, no action
         4 ANL01  wafer bow suspected - L26-001 on hold pending ANL01 check
         5 SPL02  re-meas on SPL02 ok, 59.2nm within spec
         6        hold per FAB-OPS-113, thickness 58.1 nm
         7        released by eng - defect cnt 8 within limit
         8        Audit hold. contact j.tan@fabops.example (ext 4198)
         9 IMP01  RELEASED. recheck IMP01 pass (INC-20666)
```

Rows 1, 3, 6, 7 and 8 mention no tool, so they get NULL. Now the cut-out text can be grouped like any other column. Maya: "Which tools do the operators write about most?"

```sql
SELECT REGEXP_SUBSTR(note, '[A-Z]{3}[0-9]{2}') AS tool,
       COUNT(*) AS notes
FROM   lot_history
WHERE  REGEXP_LIKE(note, '[A-Z]{3}[0-9]{2}')
GROUP  BY REGEXP_SUBSTR(note, '[A-Z]{3}[0-9]{2}')
ORDER  BY notes DESC, tool;
```

```text
TOOL        NOTES
------ ----------
MET01          12
SPL02          12
ANL01          10
MET03           9
IMP01           7
SPL01           7
MET02           6
CMP01           4
ANL02           2
```

### Readings in nm

A reading is a number, perhaps with a decimal part, perhaps a space, then `nm`. As a pattern: `[0-9]+(\.[0-9]+)? ?nm`. Read it piece by piece: one or more digits, an optional group made of a dot and more digits, an optional space, then `nm`.

```sql
SELECT hist_id,
       REGEXP_SUBSTR(note, '[0-9]+(\.[0-9]+)? ?nm') AS reading
FROM   lot_history
WHERE  REGEXP_LIKE(note, '[0-9] ?nm')
AND    hist_id <= 50
ORDER  BY hist_id;
```

```text
   HIST_ID READING
---------- ----------
         5 59.2nm
         6 58.1 nm
        14 87.7 nm
        24 38.4nm
        33 67.6nm
        38 92.2nm
        49 55.7 nm
```

The result still has `nm` in it, so it is text. To get just the number, put brackets around the part you want and ask for that part with the last argument, the subexpression number. Bracket number 1 is the first `(`...`)` in the pattern, counted from the left.

```sql
SELECT hist_id,
       REGEXP_SUBSTR(note, '[0-9]+(\.[0-9]+)? ?nm') AS reading,
       REGEXP_SUBSTR(note, '([0-9]+(\.[0-9]+)?) ?nm', 1, 1, NULL, 1) AS nm
FROM   lot_history
WHERE  REGEXP_LIKE(note, '[0-9] ?nm')
AND    hist_id <= 50
ORDER  BY hist_id;
```

```text
   HIST_ID READING    NM
---------- ---------- --------
         5 59.2nm     59.2
         6 58.1 nm    58.1
        14 87.7 nm    87.7
        24 38.4nm     38.4
        33 67.6nm     67.6
        38 92.2nm     92.2
        49 55.7 nm    55.7
```

The arguments between the pattern and the subexpression are: where to start (1), which match (1), and the flag (NULL for none). Count them: `note, pattern, 1, 1, NULL, 1`.

The number is still text. `TO_NUMBER` makes it a number, and then you can average it. Maya: "What is the average of all the readings in the notes?"

```sql
SELECT COUNT(*) AS notes_with_reading,
       ROUND(AVG(TO_NUMBER(REGEXP_SUBSTR(note, '([0-9]+(\.[0-9]+)?) ?nm', 1, 1, NULL, 1),
                           '9999.99')), 1) AS avg_nm
FROM   lot_history
WHERE  REGEXP_LIKE(note, '[0-9] ?nm');
```

```text
NOTES_WITH_READING     AVG_NM
------------------ ----------
                26      100.2
```

Think about what this average means before you quote it to Maya. The readings come from notes written by different operators on different products, including the scrap notes. It shows that you can pull numbers out of text, not that 100.2 nm is a useful figure.

### Which match? The occurrence argument

A note can contain several matches. The fourth argument says which one you want. Take `[0-9]+`, which matches any run of digits, on three notes:

```sql
SELECT hist_id, note,
       REGEXP_SUBSTR(note, '[0-9]+', 1, 1) AS n1,
       REGEXP_SUBSTR(note, '[0-9]+', 1, 2) AS n2,
       REGEXP_SUBSTR(note, '[0-9]+', 1, 3) AS n3,
       REGEXP_COUNT(note, '[0-9]+')        AS how_many
FROM   lot_history
WHERE  hist_id IN (6, 8, 9)
ORDER  BY hist_id;
```

```text
   HIST_ID NOTE                                                     N1    N2    N3      HOW_MANY
---------- -------------------------------------------------------- ----- ----- ----- ----------
         6 hold per FAB-OPS-113, thickness 58.1 nm                  113   58    1              3
         8 Audit hold. contact j.tan@fabops.example (ext 4198)      4198                       1
         9 RELEASED. recheck IMP01 pass (INC-20666)                 01    20666                2
```

Look at row 6: `58.1` was split into 58 and 1, because the dot is not a digit. And in row 9 the first run of digits is the `01` inside `IMP01`. A pattern that is too loose picks the wrong thing. The fix is a more specific pattern, as in the previous section, not a higher occurrence number.

`REGEXP_COUNT(text, pattern)` returns how many times the pattern fits. It returns 0, not NULL, when there is no match.

### Ticket numbers

Tickets come in two styles: `INC-20417` and `FAB-OPS-117`. One pattern with `|` (or) handles both: `(INC|FAB-OPS)-[0-9]+`. The bracket gives you two things at once: it limits the "or" to the prefix, and it is subexpression 1 if you want the prefix alone.

```sql
SELECT hist_id,
       REGEXP_SUBSTR(note, '(INC|FAB-OPS)-[0-9]+')                 AS ticket,
       REGEXP_SUBSTR(note, '(INC|FAB-OPS)-[0-9]+', 1, 1, NULL, 1)   AS kind,
       REGEXP_SUBSTR(note, '(INC|FAB-OPS)-([0-9]+)', 1, 1, NULL, 2) AS ticket_no
FROM   lot_history
WHERE  REGEXP_LIKE(note, '(INC|FAB-OPS)-[0-9]+')
AND    hist_id <= 40
ORDER  BY hist_id;
```

```text
   HIST_ID TICKET       KIND     TICKET_NO
---------- ------------ -------- ---------
         6 FAB-OPS-113  FAB-OPS  113
         9 INC-20666    INC      20666
        14 FAB-OPS-121  FAB-OPS  121
        25 INC-20408    INC      20408
        26 INC-20829    INC      20829
        28 INC-20978    INC      20978
        35 INC-20933    INC      20933
        37 INC-20514    INC      20514
```

Maya: "How many tickets of each kind are in the notes?"

```sql
SELECT REGEXP_SUBSTR(note, '(INC|FAB-OPS)-[0-9]+', 1, 1, NULL, 1) AS kind,
       COUNT(*) AS tickets
FROM   lot_history
WHERE  REGEXP_LIKE(note, '(INC|FAB-OPS)-[0-9]+')
GROUP  BY REGEXP_SUBSTR(note, '(INC|FAB-OPS)-[0-9]+', 1, 1, NULL, 1);
```

```text
KIND       TICKETS
-------- ----------
FAB-OPS           8
INC              23
```

### The email and the extension

An address is some characters, an `@`, then more characters and dots. `[[:alnum:]._]+@[[:alnum:].]+` says: one or more letters, digits, dots or underscores; an at sign; one or more letters, digits or dots. Inside square brackets the dot is a plain dot, so no backslash is needed there.

```sql
SELECT hist_id,
       REGEXP_SUBSTR(note, '[[:alnum:]._]+@[[:alnum:].]+')  AS email,
       REGEXP_SUBSTR(note, 'ext ([0-9]+)', 1, 1, NULL, 1)    AS ext
FROM   lot_history
WHERE  REGEXP_LIKE(note, '@')
AND    hist_id <= 60
ORDER  BY hist_id;
```

```text
   HIST_ID EMAIL                    EXT
---------- ------------------------ ------
         8 j.tan@fabops.example     4198
        16 j.tan@fabops.example     4254
        51 j.tan@fabops.example     4534
```

This pattern is good enough for a report. It is not a full address validator, and nobody should use it to decide whether an address is legal.

## Notes that mention a tool but give no number

Maya: "Which notes name a tool but give no measurement, no ticket, nothing numeric? Someone should have written more."

The trouble is that tool ids and lot ids contain digits themselves (`MET01`, `L26-003`). Take those out first with `REGEXP_REPLACE`, which you will meet in the next section, and then test whether any digit is left.

```sql
SELECT hist_id, note
FROM   lot_history
WHERE  REGEXP_LIKE(note, '[A-Z]{3}[0-9]{2}')
AND    NOT REGEXP_LIKE(REGEXP_REPLACE(note, '[A-Z]{3}[0-9]{2}|L26-[0-9A-Z]+'), '[0-9]')
AND    hist_id <= 47
ORDER  BY hist_id;
```

```text
   HIST_ID NOTE
---------- ------------------------------------------------------------
         4 wafer bow suspected - L26-001 on hold pending ANL01 check
        11 ok to continue   MET01
        15 ok to continue   SPL02
        27 ok to continue   MET01
        32 wafer bow suspected - L26-003 on hold pending MET01 check
        41 wafer bow suspected - L26-003A on hold pending IMP01 check
        46 ok to continue   MET01
        47 wafer bow suspected - L26-003B on hold pending CMP01 check
```

Over the whole table, 18 notes fit. When `REGEXP_REPLACE` has only two arguments, the matches are replaced by nothing, which is a deletion.

## REGEXP_REPLACE: rewrite the text

`REGEXP_REPLACE(text, pattern [, replacement [, start [, occurrence [, flags]]]])` replaces every match (occurrence 0 is the default, meaning all) with the replacement text. `\1`, `\2` in the replacement put back the bracketed parts.

Some notes have double spaces or triple spaces. `\s{2,}` means two or more whitespace characters. First count them and find where they are with `REGEXP_INSTR` (the position of a match) and `REGEXP_COUNT`. Then clean:

```sql
SELECT hist_id,
       REGEXP_INSTR(note, '\s{2,}')  AS first_gap,
       REGEXP_COUNT(note, '\s{2,}')  AS gaps,
       REGEXP_REPLACE(note, '\s{2,}', ' ') AS cleaned
FROM   lot_history
WHERE  REGEXP_LIKE(note, '\s{2,}')
AND    hist_id <= 60
ORDER  BY hist_id;
```

```text
   HIST_ID  FIRST_GAP       GAPS CLEANED
---------- ---------- ---------- --------------------------------------------------
        11         15          1 ok to continue MET01
        15         15          1 ok to continue SPL02
        27         15          1 ok to continue MET01
        28          8          2 eng req hold re-meas on CMP01, see INC-20978
        37          8          2 eng req hold re-meas on SPL02, see INC-20514
        46         15          1 ok to continue MET01
        54         15          1 ok to continue ANL01
```

`REGEXP_INSTR` returns the position of the first character of the match (character 15 in `ok to continue   MET01`). Without a match it returns 0. Across the whole table, 16 notes have such a gap.

`REGEXP_REPLACE` does not change the table. It gives you a cleaned copy in the result. To change the table you would write an `UPDATE`, as you did in the changing-data lab, and commit it.

Other replacements, all from real notes:

```sql
SELECT hist_id,
       REGEXP_REPLACE(note, '[0-9]+(\.[0-9]+)? ?nm', '<reading>') AS no_reading
FROM   lot_history
WHERE  hist_id IN (5, 6, 24);
```

```text
   HIST_ID NO_READING
---------- ----------------------------------------------------------
         5 re-meas on SPL02 ok, <reading> within spec
         6 hold per FAB-OPS-113, thickness <reading>
        24 hold - thk OOS at FINAL, SPL01 read <reading> vs target
```

Hiding an address before a report goes out:

```sql
SELECT hist_id,
       REGEXP_REPLACE(note, '[[:alnum:]._]+@[[:alnum:].]+', '***') AS masked
FROM   lot_history
WHERE  hist_id = 8;
```

```text
   HIST_ID MASKED
---------- ----------------------------------------------------------
         8 Audit hold. contact *** (ext 4198)
```

And putting the bracketed parts back in another order:

```sql
SELECT REGEXP_REPLACE('MET02', '([A-Z]+)([0-9]+)', '\2-\1') AS swapped
FROM   dual;
```

```text
SWAPPED
--------
02-MET
```

## Which tool for which job

| You want to... | Use |
| --- | --- |
| find a fixed word or a prefix | `LIKE` (simple, and can use an index on a prefix) |
| find a shape: ids, numbers, "digits then nm", optional parts | `REGEXP_LIKE` and the other REGEXP functions |
| search long documents for words, phrases or word forms across millions of rows | Oracle Text, the full-text search feature (`CONTAINS`), which builds a special index first |

A regular expression has to read every note it is tested on, so on a small table like this one it is fine, and on a table with millions of long texts it is slow. Oracle Text exists for that second case. It is a separate option that needs to be installed and configured, so this course does not demonstrate it. If someone asks "can we search the shift reports for the word leak?", that is a question for Oracle Text, not for `REGEXP_LIKE`.

## Three common misreadings

**"REGEXP_LIKE gives me the part that matched."** It only answers yes or no and belongs in `WHERE` or a `CASE`. To get the text, use `REGEXP_SUBSTR` with the same pattern. Of the 147 notes, 69 contain a tool ID, 57 do not, and 21 are NULL and in neither group.

**"The pattern has to match the whole note, like LIKE without percent signs."** A pattern matches anywhere in the text unless you anchor it. `[A-Z]{3}[0-9]{2}` matches in 69 notes. `^[A-Z]{3}[0-9]{2}$` means "the whole note is exactly a tool ID" and matches none.

**"Searching for hold finds every hold note."** Letters are case sensitive. `REGEXP_LIKE(note, 'hold')` finds 49 notes. Some say `HOLD:` in capitals, and `REGEXP_LIKE(note, 'hold', 'i')` finds 57. A note that says `Held by shift lead` uses a different word and matches neither.

## Common mistakes

- Writing `.` when you mean a dot. `58.1` also matches `58x1`. Write `58\.1`, or put the dot inside square brackets.
- A pattern that is too loose. `[0-9]+` finds the `01` in `IMP01`. Describe the whole shape, like `[0-9]+(\.[0-9]+)? ?nm`.
- Forgetting the case flag. Without `'i'`, `hold` does not match `HOLD`.
- Counting brackets wrongly. Subexpressions are numbered by their opening bracket from the left. The outer bracket is 1 and the one inside it is 2.
- Treating the result as a number. `REGEXP_SUBSTR` returns text, so convert it with `TO_NUMBER` before you average.
- Expecting NULL notes to appear. A NULL never matches, not even `NOT REGEXP_LIKE`.
- Reaching for a regular expression when `LIKE` would do. Simple is easier to read and to maintain.

## Check your understanding

1. What does the pattern `^[0-9]{3}$` match?
2. What is the difference between `REGEXP_SUBSTR(note, 'INC-[0-9]+')` and `REGEXP_SUBSTR(note, '(INC)-([0-9]+)', 1, 1, NULL, 2)`?
3. Why does `REGEXP_SUBSTR('hold per FAB-OPS-113, thickness 58.1 nm', '[0-9]+', 1, 3)` return 1?
4. Write the query that returns the notes that contain the word released in any capitalisation.
5. When would you choose Oracle Text over `REGEXP_LIKE`?

<details>
<summary>Answers</summary>

1. A text that is exactly three digits and nothing else. `^` and `$` pin both ends.
2. The first returns the whole ticket, `INC-20666`. The second returns only the number part, `20666`, because it asks for subexpression 2.
3. The text holds the digit runs 113, 58 and 1. The decimal point splits `58.1` into two runs, and the third run is `1`.
4. `SELECT hist_id, note FROM lot_history WHERE REGEXP_LIKE(note, 'released', 'i');` (21 rows, against 12 without the flag.)
5. When you search for words in large amounts of text, such as thousands of long reports. It uses a special index, so it does not read every row.

</details>

## Further reading

- [Oracle Database SQL Language Reference 19c: REGEXP_SUBSTR](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/REGEXP_SUBSTR.html)
- [Oracle Database SQL Language Reference 19c: REGEXP_REPLACE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/REGEXP_REPLACE.html)
- [Oracle Database SQL Language Reference 19c: Condition REGEXP_LIKE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/REGEXP_LIKE-condition.html)
- [ORACLE-BASE: Regular expression support in Oracle](https://oracle-base.com/articles/misc/regular-expressions-support-in-oracle)

Practise it in [Lab 11](../labs/lab-11-trees-and-text.md).
