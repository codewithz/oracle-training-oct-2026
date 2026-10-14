-- Joins assessment: solutions
-- Run as FAB_LAB after assess_joins_data.sql.
-- Your query can look different and still be right. Compare the rows, not the spelling.

-- Q1: Who works where
SELECT e.emp_id, e.first_name, e.last_name, d.dept_name
FROM   employee e
JOIN   dept d ON d.dept_id = e.dept_id
ORDER  BY d.dept_name, e.last_name;
-- 17 rows. Ravi Menon and Li Na Zhou are missing: their DEPT_ID is NULL, and NULL never equals anything.

-- Q2: Nobody left behind
SELECT e.emp_id, e.first_name, e.last_name,
       NVL(d.dept_name, '(no department)') AS dept_name
FROM   employee e
LEFT   JOIN dept d ON d.dept_id = e.dept_id
ORDER  BY e.emp_id;
-- 19 rows. The LEFT side (EMPLOYEE) keeps every row; the two unmatched ones get NULL for every DEPT column.

-- Q3: Who runs each department
SELECT d.dept_name,
       CASE WHEN m.emp_id IS NULL THEN 'Vacant'
            ELSE m.first_name || ' ' || m.last_name END AS manager
FROM   dept d
LEFT   JOIN employee m ON m.emp_id = d.manager_id
ORDER  BY d.dept_id;
-- 7 rows, Facilities is Vacant. Same two tables as Q1, joined through a different column.
-- Watch out: NVL(m.first_name || ' ' || m.last_name, 'Vacant') does NOT work in Oracle.
-- || treats NULL as an empty string, so the result is ' ' (one space), never NULL.

-- Q4: Reporting line
SELECT e.first_name || ' ' || e.last_name AS employee,
       e.job_title,
       CASE WHEN m.emp_id IS NULL THEN '(top of the tree)'
            ELSE m.first_name || ' ' || m.last_name END AS reports_to
FROM   employee e
LEFT   JOIN employee m ON m.emp_id = e.manager_id
ORDER  BY e.emp_id;
-- 19 rows. With a plain JOIN you get 18: Ravi Menon has no manager.

-- Q5: Managed from another department
SELECT e.first_name || ' ' || e.last_name AS employee,
       e.dept_id                         AS emp_dept,
       m.first_name || ' ' || m.last_name AS manager,
       m.dept_id                         AS mgr_dept
FROM   employee e
JOIN   employee m ON m.emp_id = e.manager_id
WHERE  NVL(e.dept_id, -1) <> NVL(m.dept_id, -1)
ORDER  BY e.emp_id;
-- 7 rows. Writing WHERE e.dept_id <> m.dept_id gives only 1 row (Nurul Huda):
-- every comparison with a NULL department is UNKNOWN, so those rows are thrown away.

-- Q6: Current monthly pay
SELECT e.emp_id, e.first_name, e.last_name,
       s.base_pay,
       NVL(s.allowance, 0)                AS allowance,
       s.base_pay + NVL(s.allowance, 0)   AS monthly_total
FROM   employee e
LEFT   JOIN salary s ON  s.emp_id = e.emp_id
                     AND s.effective_to IS NULL
ORDER  BY monthly_total DESC NULLS LAST, e.emp_id;
-- 19 rows, Bryan Seah last with no pay.
-- Leave the effective_to test out and you get 23 rows: the four people with a raise appear twice.
-- Here, moving the test to WHERE happens to give the same 19 rows, because Bryan's
-- unmatched S columns are all NULL and pass "IS NULL". Any other test on S in WHERE,
-- such as WHERE s.base_pay > 0, would silently drop him. Tests on the outer table go in ON.

-- Q7: Then and now
SELECT e.first_name || ' ' || e.last_name AS employee,
       s_then.base_pay                     AS pay_1_mar,
       s_now.base_pay                      AS pay_now,
       s_now.base_pay - s_then.base_pay    AS rise
FROM   employee e
JOIN   salary s_then ON  s_then.emp_id = e.emp_id
                     AND DATE '2026-03-01' BETWEEN s_then.effective_from
                                               AND NVL(s_then.effective_to, DATE '9999-12-31')
JOIN   salary s_now  ON  s_now.emp_id = e.emp_id
                     AND s_now.effective_to IS NULL
ORDER  BY rise DESC, e.emp_id;
-- 17 rows. Four rises: Ravi Menon 1000, Maya Tan 800, Arjun Pillai 500, Priya Nair 400.
-- Bryan Seah (no pay at all) and Li Na Zhou (joined in August) are not in the result.

-- Q8: Headcount and hours by department
SELECT d.dept_name,
       COUNT(DISTINCT e.emp_id)        AS headcount,
       NVL(SUM(a.hours_worked), 0)     AS hours_this_week
FROM   dept d
LEFT   JOIN employee   e ON e.dept_id = d.dept_id
LEFT   JOIN attendance a ON a.emp_id  = e.emp_id
GROUP  BY d.dept_id, d.dept_name
ORDER  BY d.dept_id;
-- 7 rows, Facilities 0 and 0.
-- COUNT(*) instead of COUNT(DISTINCT e.emp_id) counts attendance rows, not people
-- (Process Engineering would show 22 instead of 5), and Facilities would show 1, not 0.

-- Q9: Not seen all week
SELECT e.emp_id, e.first_name, e.last_name,
       NVL(d.dept_name, '(no department)') AS dept_name
FROM   employee e
LEFT   JOIN dept d       ON d.dept_id = e.dept_id
LEFT   JOIN attendance a ON  a.emp_id = e.emp_id
                         AND a.status = 'PRESENT'
WHERE  a.att_id IS NULL
ORDER  BY e.emp_id;
-- 3 rows: Jason Teo (on leave all week), Bryan Seah and Marcus Yeo (no rows at all).
-- Put a.status = 'PRESENT' in WHERE instead of ON and you get 0 rows.
-- Same answer with NOT EXISTS:
-- SELECT e.emp_id, e.first_name, e.last_name FROM employee e
-- WHERE NOT EXISTS (SELECT 1 FROM attendance a
--                   WHERE a.emp_id = e.emp_id AND a.status = 'PRESENT');

-- Q10: Capstone: tools with no technician on the floor
SELECT t.tool_id, t.tool_type, t.bay,
       CASE WHEN e.emp_id IS NULL THEN '-- nobody --'
            ELSE e.first_name || ' ' || e.last_name END AS technician
FROM   tools t
JOIN   dept d ON d.home_bay = t.bay
LEFT   JOIN (employee e
             JOIN attendance a ON  a.emp_id    = e.emp_id
                               AND a.work_date = DATE '2026-09-16'
                               AND a.status    = 'PRESENT')
         ON  e.dept_id   = d.dept_id
         AND e.job_title = 'Technician'
ORDER  BY t.tool_id, technician;
-- 11 rows: 5 tools show "-- nobody --" (CMP01, IMP01, MET03, SPL01, SPL02).
-- The bracket keeps "employee joined to attendance" as one unit, so the outer join
-- keeps the tool when that unit finds nobody. An inline view does the same:
--   LEFT JOIN (SELECT e.dept_id, e.first_name, e.last_name
--              FROM   employee e JOIN attendance a ON a.emp_id = e.emp_id
--              WHERE  a.work_date = DATE '2026-09-16' AND a.status = 'PRESENT'
--              AND    e.job_title = 'Technician') e ON e.dept_id = d.dept_id
-- Only the "nobody" rows, which is the short answer Maya wants: add WHERE e.emp_id IS NULL.
-- Writing it as tools JOIN dept LEFT JOIN employee JOIN attendance (no bracket) returns
-- only 6 rows: the last inner JOIN throws away every tool the outer join had saved.

-- Bonus: Monthly payroll by department (not marked)
SELECT NVL(d.dept_name, '(no department)')      AS dept_name,
       COUNT(e.emp_id)                          AS people,
       COUNT(s.sal_id)                          AS paid,
       NVL(SUM(s.base_pay + NVL(s.allowance, 0)), 0) AS monthly_payroll
FROM   employee e
LEFT   JOIN dept d   ON d.dept_id = e.dept_id
LEFT   JOIN salary s ON s.emp_id = e.emp_id AND s.effective_to IS NULL
GROUP  BY d.dept_name
ORDER  BY monthly_payroll DESC;
