# Day 1: Oracle 19c and advanced SQL

Day 1 has two modules. Module 1 introduces Oracle Database 19c: what it is, how it is installed and configured, how the instance and the database work, and which tools you use to manage it. Module 2 reviews the SQL you already know and then adds analytic functions, hierarchical queries and advanced grouping.

Slides: 1 to 4 and 34 of the Day 1 deck.

By the end of the day you have a working 19c environment with the lab schema loaded, a picture of what happens inside the database when you run and commit SQL, and experience writing analytic, hierarchical and grouping queries.

## Agenda

The day has five short labs, each straight after the topic it practises, so about two and a half hours of it is hands-on.

| Time | Session | Reading |
| --- | --- | --- |
| 09:00 | Welcome, course map, environment check | [Install Oracle Database 19c on Windows](../before-you-start/install-oracle-19c-windows.md) |
| 09:30 | 1.1 Overview of Oracle Database 19c | [Oracle Database 19c overview](module-1/01-oracle-19c-overview.md), [Multitenant architecture](module-1/02-multitenant-architecture.md) |
| 09:55 | 1.2 Installation and configuration | [Installing Oracle 19c](module-1/03-installing-oracle-19c.md), [Oracle Net and the listener](module-1/04-oracle-net-and-the-listener.md), [Configuration and parameters](module-1/05-configuration-and-parameters.md) |
| 10:30 | Lab 1: Connect and configure (25 minutes) | [Lab 1](labs/lab-1-connect-and-configure.md) |
| 10:55 | Break | |
| 11:10 | 1.3 Oracle database architecture | [Instance and database](module-1/06-instance-and-database.md), [Memory: SGA and PGA](module-1/07-memory-sga-and-pga.md), [Background processes](module-1/08-background-processes.md), [Storage structures](module-1/09-storage-structures.md), [COMMIT, redo and undo](module-1/10-commit-redo-and-undo.md) |
| 11:55 | 1.4 Tools and the data dictionary | [Tools](module-1/11-tools.md), [The data dictionary](module-1/12-data-dictionary.md) |
| 12:05 | Lunch | |
| 13:05 | Lab 2: Inside your instance (35 minutes) | [Lab 2](labs/lab-2-inside-your-instance.md) |
| 13:40 | Meet the lab data, then 2.1 SQL review | [Meet the lab data](meet-the-lab-data.md), [SQL review](module-2/01-sql-review.md), [Transaction control](module-2/02-transaction-control.md) |
| 14:05 | Lab 3: SQL review (25 minutes) | [Lab 3](labs/lab-3-sql-review.md) |
| 14:30 | Break | |
| 14:45 | 2.2 Analytic functions | [Analytic functions](module-2/03-analytic-functions.md) |
| 15:15 | Lab 4: Analytic functions (30 minutes) | [Lab 4](labs/lab-4-analytic-functions.md) |
| 15:45 | 2.3 Hierarchical queries and 2.4 Advanced grouping | [Hierarchical queries](module-2/04-hierarchical-queries.md), [Advanced grouping](module-2/05-advanced-grouping.md) |
| 16:20 | Lab 5: Hierarchies and grouping (30 minutes) | [Lab 5](labs/lab-5-hierarchies-and-grouping.md) |
| 16:50 | Wrap-up and Day 2 preview | |

Your trainer may adjust the times.

## What you use all day

| Item | Value |
| --- | --- |
| Database | Your own Oracle 19c container database with one pluggable database (PDB) |
| Tools | SQL Developer for the labs, SQL*Plus for scripts, a Command Prompt for `lsnrctl` |
| Lab user | FAB_LAB, password `Lab_2026`, in the PDB. You create it in Lab 1 |
| Lab scripts | [`lab0_oracle_create_user.sql`](labs/scripts/lab0_oracle_create_user.sql), [`fab_lab_data.sql`](labs/scripts/fab_lab_data.sql), [`lab1_connect_configure.sql`](labs/scripts/lab1_connect_configure.sql), [`lab2_explore_instance.sql`](labs/scripts/lab2_explore_instance.sql), [`lab2_dictionary.sql`](labs/scripts/lab2_dictionary.sql), [`lab3_sql_review.sql`](labs/scripts/lab3_sql_review.sql), [`lab4_analytic_functions.sql`](labs/scripts/lab4_analytic_functions.sql), [`lab5_hierarchies_and_grouping.sql`](labs/scripts/lab5_hierarchies_and_grouping.sql) |

Check your setup at the start of the day: connect as SYSTEM and run `SELECT banner_full FROM v$version;`. If that fails, the troubleshooting section of the [install guide](../before-you-start/install-oracle-19c-windows.md) covers the usual causes.

## After Day 1

Day 2 starts PL/SQL: blocks, variables, data types and control structures, then procedures, functions, packages, triggers and autonomous transactions. It uses the same FAB_LAB schema, so keep it as it is at the end of Lab 5.

Optional homework: take one report from your own work that uses a loop or a self-join and rewrite it with an analytic function.
