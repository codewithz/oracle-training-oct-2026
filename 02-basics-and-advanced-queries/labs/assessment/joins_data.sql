-- =====================================================================
-- Joins assessment: people data for FAB_LAB (add-on).
-- Run as FAB_LAB (password Lab_2026), connected to your PDB.
-- DBeaver: open this file, then Execute Script (Alt+X).
--
-- Adds four tables about the people who run the fab:
--   DEPT        7 departments. HOME_BAY matches TOOLS.BAY.
--   EMPLOYEE   19 people. MANAGER_ID points at another employee.
--   SALARY     22 pay records (some people have two: a raise on 1 July).
--   ATTENDANCE 86 rows for the week of 14-19 September 2026.
--
-- The five original FAB_LAB tables are not touched.
-- Safe to re-run: the first block drops these four tables if they exist.
-- The last query is a check. Expect 7, 19, 22 and 86 rows.
-- =====================================================================

BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE  table_name IN ('ATTENDANCE','SALARY','EMPLOYEE','DEPT')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

CREATE TABLE dept (
  dept_id     NUMBER(3)     CONSTRAINT dept_pk PRIMARY KEY,
  dept_name   VARCHAR2(30)  NOT NULL CONSTRAINT dept_name_uk UNIQUE,
  home_bay    VARCHAR2(4),                 -- same values as TOOLS.BAY; NULL = no bay
  manager_id  NUMBER(4)                    -- FK to EMPLOYEE added below
);

CREATE TABLE employee (
  emp_id      NUMBER(4)     CONSTRAINT employee_pk PRIMARY KEY,
  first_name  VARCHAR2(20)  NOT NULL,
  last_name   VARCHAR2(20)  NOT NULL,
  job_title   VARCHAR2(24)  NOT NULL,
  dept_id     NUMBER(3)     CONSTRAINT employee_dept_fk REFERENCES dept,
  manager_id  NUMBER(4)     CONSTRAINT employee_mgr_fk REFERENCES employee,
  hire_date   DATE          NOT NULL
);

ALTER TABLE dept ADD CONSTRAINT dept_mgr_fk FOREIGN KEY (manager_id) REFERENCES employee;

CREATE TABLE salary (
  sal_id          NUMBER(4)    CONSTRAINT salary_pk PRIMARY KEY,
  emp_id          NUMBER(4)    NOT NULL CONSTRAINT salary_emp_fk REFERENCES employee,
  effective_from  DATE         NOT NULL,
  effective_to    DATE,                    -- NULL = this is the current pay
  base_pay        NUMBER(8,2)  NOT NULL,   -- monthly, SGD
  allowance       NUMBER(8,2)              -- monthly shift allowance; NULL = none
);

CREATE TABLE attendance (
  att_id        NUMBER(5)    CONSTRAINT attendance_pk PRIMARY KEY,
  emp_id        NUMBER(4)    NOT NULL CONSTRAINT attendance_emp_fk REFERENCES employee,
  work_date     DATE         NOT NULL,
  status        VARCHAR2(8)  NOT NULL CONSTRAINT attendance_status_ck CHECK (status IN ('PRESENT','ABSENT','LEAVE')),
  hours_worked  NUMBER(4,1),               -- NULL unless PRESENT
  CONSTRAINT attendance_emp_day_uk UNIQUE (emp_id, work_date)
);

CREATE INDEX employee_dept_ix ON employee (dept_id);
CREATE INDEX employee_mgr_ix  ON employee (manager_id);
CREATE INDEX salary_emp_ix    ON salary (emp_id);

-- Departments first, with no manager yet (the employees do not exist yet).
INSERT INTO dept VALUES (10,'Process Engineering','B1',NULL);
INSERT INTO dept VALUES (20,'Thermal Processing','B2',NULL);
INSERT INTO dept VALUES (30,'Metrology','B3',NULL);
INSERT INTO dept VALUES (40,'Polish and Implant','B4',NULL);
INSERT INTO dept VALUES (50,'Maintenance',NULL,NULL);
INSERT INTO dept VALUES (60,'Quality',NULL,NULL);
INSERT INTO dept VALUES (70,'Facilities',NULL,NULL);

-- Employees: the boss first, so every MANAGER_ID already exists when it is used.
INSERT INTO employee VALUES (100,'Ravi','Menon','Fab Manager',NULL,NULL,DATE '2015-03-02');
INSERT INTO employee VALUES (101,'Maya','Tan','Shift Manager',10,100,DATE '2018-06-11');
INSERT INTO employee VALUES (102,'Daniel','Lim','Process Engineer',10,101,DATE '2020-01-06');
INSERT INTO employee VALUES (103,'Priya','Nair','Process Engineer',10,101,DATE '2025-01-13');
INSERT INTO employee VALUES (104,'Ahmad','Rahman','Technician',10,102,DATE '2021-09-01');
INSERT INTO employee VALUES (105,'Grace','Wong','Thermal Lead',20,100,DATE '2017-04-03');
INSERT INTO employee VALUES (106,'Kevin','Ong','Technician',20,105,DATE '2022-02-14');
INSERT INTO employee VALUES (107,'Siti','Aminah','Technician',20,105,DATE '2023-07-03');
INSERT INTO employee VALUES (108,'Hui Min','Chua','Metrology Lead',30,100,DATE '2016-10-17');
INSERT INTO employee VALUES (109,'Arjun','Pillai','Metrology Engineer',30,108,DATE '2025-04-01');
INSERT INTO employee VALUES (110,'Mei Ling','Goh','Technician',30,108,DATE '2022-11-07');
INSERT INTO employee VALUES (111,'Farah','Ismail','Polish Lead',40,100,DATE '2019-05-20');
INSERT INTO employee VALUES (112,'Jason','Teo','Technician',40,111,DATE '2024-03-04');
INSERT INTO employee VALUES (113,'Wei Jie','Koh','Maintenance Lead',50,100,DATE '2016-08-08');
INSERT INTO employee VALUES (114,'Ramesh','Iyer','Maintenance Tech',50,113,DATE '2021-01-18');
INSERT INTO employee VALUES (115,'Nurul','Huda','Quality Engineer',60,101,DATE '2023-02-06');
INSERT INTO employee VALUES (116,'Bryan','Seah','Technician',10,102,DATE '2026-09-21');
INSERT INTO employee VALUES (117,'Li Na','Zhou','Intern',NULL,101,DATE '2026-08-03');
INSERT INTO employee VALUES (118,'Marcus','Yeo','Technician',30,108,DATE '2024-10-14');

-- Now each department gets its manager. Facilities has none.
UPDATE dept SET manager_id = 101 WHERE dept_id = 10;
UPDATE dept SET manager_id = 105 WHERE dept_id = 20;
UPDATE dept SET manager_id = 108 WHERE dept_id = 30;
UPDATE dept SET manager_id = 111 WHERE dept_id = 40;
UPDATE dept SET manager_id = 113 WHERE dept_id = 50;
UPDATE dept SET manager_id = 115 WHERE dept_id = 60;

-- Pay. Four people got a raise on 1 July 2026, so they have an old row and a current row.
-- Bryan Seah (116) starts next week and has no pay record yet.
INSERT INTO salary VALUES (1,100,DATE '2024-01-01',DATE '2026-06-30',14000,800);
INSERT INTO salary VALUES (2,100,DATE '2026-07-01',NULL,15000,800);
INSERT INTO salary VALUES (3,101,DATE '2024-01-01',DATE '2026-06-30',8200,400);
INSERT INTO salary VALUES (4,101,DATE '2026-07-01',NULL,9000,400);
INSERT INTO salary VALUES (5,102,DATE '2024-01-01',NULL,6500,NULL);
INSERT INTO salary VALUES (6,103,DATE '2025-01-13',DATE '2026-06-30',6000,NULL);
INSERT INTO salary VALUES (7,103,DATE '2026-07-01',NULL,6400,NULL);
INSERT INTO salary VALUES (8,104,DATE '2024-01-01',NULL,3600,300);
INSERT INTO salary VALUES (9,105,DATE '2024-01-01',NULL,7800,400);
INSERT INTO salary VALUES (10,106,DATE '2024-01-01',NULL,3500,300);
INSERT INTO salary VALUES (11,107,DATE '2024-01-01',NULL,3400,300);
INSERT INTO salary VALUES (12,108,DATE '2024-01-01',NULL,7600,400);
INSERT INTO salary VALUES (13,109,DATE '2025-04-01',DATE '2026-06-30',5600,NULL);
INSERT INTO salary VALUES (14,109,DATE '2026-07-01',NULL,6100,NULL);
INSERT INTO salary VALUES (15,110,DATE '2024-01-01',NULL,3300,300);
INSERT INTO salary VALUES (16,111,DATE '2024-01-01',NULL,7400,400);
INSERT INTO salary VALUES (17,112,DATE '2024-03-04',NULL,3500,NULL);
INSERT INTO salary VALUES (18,113,DATE '2024-01-01',NULL,7000,400);
INSERT INTO salary VALUES (19,114,DATE '2024-01-01',NULL,3800,300);
INSERT INTO salary VALUES (20,115,DATE '2024-01-01',NULL,5900,NULL);
INSERT INTO salary VALUES (21,117,DATE '2026-08-03',NULL,1200,NULL);
INSERT INTO salary VALUES (22,118,DATE '2024-10-14',NULL,3400,300);

-- Attendance, Monday 14 to Saturday 19 September 2026.
-- One row per person per day they were expected. Marcus Yeo (118) and Bryan Seah (116)
-- have no rows. The intern (117) only works Monday, Wednesday and Friday.
INSERT INTO attendance VALUES (1,100,DATE '2026-09-14','PRESENT',9);
INSERT INTO attendance VALUES (2,100,DATE '2026-09-15','PRESENT',9);
INSERT INTO attendance VALUES (3,100,DATE '2026-09-16','PRESENT',9);
INSERT INTO attendance VALUES (4,100,DATE '2026-09-17','PRESENT',9);
INSERT INTO attendance VALUES (5,100,DATE '2026-09-18','PRESENT',9);
INSERT INTO attendance VALUES (6,101,DATE '2026-09-14','PRESENT',10);
INSERT INTO attendance VALUES (7,101,DATE '2026-09-15','PRESENT',10);
INSERT INTO attendance VALUES (8,101,DATE '2026-09-16','PRESENT',10);
INSERT INTO attendance VALUES (9,101,DATE '2026-09-17','PRESENT',10);
INSERT INTO attendance VALUES (10,101,DATE '2026-09-18','PRESENT',10);
INSERT INTO attendance VALUES (11,102,DATE '2026-09-14','PRESENT',9);
INSERT INTO attendance VALUES (12,102,DATE '2026-09-15','PRESENT',9);
INSERT INTO attendance VALUES (13,102,DATE '2026-09-16','PRESENT',9);
INSERT INTO attendance VALUES (14,102,DATE '2026-09-17','PRESENT',9);
INSERT INTO attendance VALUES (15,102,DATE '2026-09-18','PRESENT',9);
INSERT INTO attendance VALUES (16,103,DATE '2026-09-14','PRESENT',8.5);
INSERT INTO attendance VALUES (17,103,DATE '2026-09-15','PRESENT',8.5);
INSERT INTO attendance VALUES (18,103,DATE '2026-09-16','PRESENT',8.5);
INSERT INTO attendance VALUES (19,103,DATE '2026-09-17','PRESENT',8.5);
INSERT INTO attendance VALUES (20,103,DATE '2026-09-18','PRESENT',8.5);
INSERT INTO attendance VALUES (21,104,DATE '2026-09-14','PRESENT',8);
INSERT INTO attendance VALUES (22,104,DATE '2026-09-15','PRESENT',8);
INSERT INTO attendance VALUES (23,104,DATE '2026-09-16','ABSENT',NULL);
INSERT INTO attendance VALUES (24,104,DATE '2026-09-17','PRESENT',8);
INSERT INTO attendance VALUES (25,104,DATE '2026-09-18','PRESENT',8);
INSERT INTO attendance VALUES (26,105,DATE '2026-09-14','PRESENT',9);
INSERT INTO attendance VALUES (27,105,DATE '2026-09-15','PRESENT',9);
INSERT INTO attendance VALUES (28,105,DATE '2026-09-16','PRESENT',9);
INSERT INTO attendance VALUES (29,105,DATE '2026-09-17','PRESENT',9);
INSERT INTO attendance VALUES (30,105,DATE '2026-09-18','PRESENT',9);
INSERT INTO attendance VALUES (31,106,DATE '2026-09-14','PRESENT',10);
INSERT INTO attendance VALUES (32,106,DATE '2026-09-15','PRESENT',10);
INSERT INTO attendance VALUES (33,106,DATE '2026-09-16','PRESENT',10);
INSERT INTO attendance VALUES (34,106,DATE '2026-09-17','PRESENT',10);
INSERT INTO attendance VALUES (35,106,DATE '2026-09-18','PRESENT',10);
INSERT INTO attendance VALUES (36,107,DATE '2026-09-14','PRESENT',8);
INSERT INTO attendance VALUES (37,107,DATE '2026-09-15','PRESENT',8);
INSERT INTO attendance VALUES (38,107,DATE '2026-09-16','PRESENT',8);
INSERT INTO attendance VALUES (39,107,DATE '2026-09-17','LEAVE',NULL);
INSERT INTO attendance VALUES (40,107,DATE '2026-09-18','LEAVE',NULL);
INSERT INTO attendance VALUES (41,108,DATE '2026-09-14','PRESENT',9);
INSERT INTO attendance VALUES (42,108,DATE '2026-09-15','PRESENT',9);
INSERT INTO attendance VALUES (43,108,DATE '2026-09-16','PRESENT',9);
INSERT INTO attendance VALUES (44,108,DATE '2026-09-17','PRESENT',9);
INSERT INTO attendance VALUES (45,108,DATE '2026-09-18','PRESENT',9);
INSERT INTO attendance VALUES (46,109,DATE '2026-09-14','PRESENT',8.5);
INSERT INTO attendance VALUES (47,109,DATE '2026-09-15','PRESENT',8.5);
INSERT INTO attendance VALUES (48,109,DATE '2026-09-16','PRESENT',8.5);
INSERT INTO attendance VALUES (49,109,DATE '2026-09-17','PRESENT',8.5);
INSERT INTO attendance VALUES (50,109,DATE '2026-09-18','PRESENT',8.5);
INSERT INTO attendance VALUES (51,110,DATE '2026-09-14','PRESENT',8);
INSERT INTO attendance VALUES (52,110,DATE '2026-09-15','ABSENT',NULL);
INSERT INTO attendance VALUES (53,110,DATE '2026-09-16','PRESENT',8);
INSERT INTO attendance VALUES (54,110,DATE '2026-09-17','PRESENT',8);
INSERT INTO attendance VALUES (55,110,DATE '2026-09-18','PRESENT',8);
INSERT INTO attendance VALUES (56,111,DATE '2026-09-14','PRESENT',9);
INSERT INTO attendance VALUES (57,111,DATE '2026-09-15','PRESENT',9);
INSERT INTO attendance VALUES (58,111,DATE '2026-09-16','PRESENT',9);
INSERT INTO attendance VALUES (59,111,DATE '2026-09-17','PRESENT',9);
INSERT INTO attendance VALUES (60,111,DATE '2026-09-18','PRESENT',9);
INSERT INTO attendance VALUES (61,112,DATE '2026-09-14','LEAVE',NULL);
INSERT INTO attendance VALUES (62,112,DATE '2026-09-15','LEAVE',NULL);
INSERT INTO attendance VALUES (63,112,DATE '2026-09-16','LEAVE',NULL);
INSERT INTO attendance VALUES (64,112,DATE '2026-09-17','LEAVE',NULL);
INSERT INTO attendance VALUES (65,112,DATE '2026-09-18','LEAVE',NULL);
INSERT INTO attendance VALUES (66,113,DATE '2026-09-14','PRESENT',9);
INSERT INTO attendance VALUES (67,113,DATE '2026-09-15','PRESENT',9);
INSERT INTO attendance VALUES (68,113,DATE '2026-09-16','PRESENT',9);
INSERT INTO attendance VALUES (69,113,DATE '2026-09-17','PRESENT',9);
INSERT INTO attendance VALUES (70,113,DATE '2026-09-18','PRESENT',9);
INSERT INTO attendance VALUES (71,114,DATE '2026-09-14','ABSENT',NULL);
INSERT INTO attendance VALUES (72,114,DATE '2026-09-15','PRESENT',12);
INSERT INTO attendance VALUES (73,114,DATE '2026-09-16','PRESENT',12);
INSERT INTO attendance VALUES (74,114,DATE '2026-09-17','PRESENT',12);
INSERT INTO attendance VALUES (75,114,DATE '2026-09-18','ABSENT',NULL);
INSERT INTO attendance VALUES (76,115,DATE '2026-09-14','PRESENT',8);
INSERT INTO attendance VALUES (77,115,DATE '2026-09-15','PRESENT',8);
INSERT INTO attendance VALUES (78,115,DATE '2026-09-16','PRESENT',8);
INSERT INTO attendance VALUES (79,115,DATE '2026-09-17','PRESENT',8);
INSERT INTO attendance VALUES (80,115,DATE '2026-09-18','LEAVE',NULL);
INSERT INTO attendance VALUES (81,117,DATE '2026-09-14','PRESENT',4);
INSERT INTO attendance VALUES (82,117,DATE '2026-09-16','PRESENT',4);
INSERT INTO attendance VALUES (83,117,DATE '2026-09-18','PRESENT',4);
INSERT INTO attendance VALUES (84,106,DATE '2026-09-19','PRESENT',6);
INSERT INTO attendance VALUES (85,114,DATE '2026-09-19','PRESENT',6);
INSERT INTO attendance VALUES (86,102,DATE '2026-09-19','PRESENT',4);

COMMIT;

-- Check: expect 7, 19, 22 and 86.
SELECT 'DEPT' AS table_name, COUNT(*) AS row_count FROM dept
UNION ALL SELECT 'EMPLOYEE',   COUNT(*) FROM employee
UNION ALL SELECT 'SALARY',     COUNT(*) FROM salary
UNION ALL SELECT 'ATTENDANCE', COUNT(*) FROM attendance;
