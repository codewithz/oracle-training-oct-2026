-- =====================================================================
-- Day 4, topic 07 demo: collections, bulk processing, dynamic SQL and
-- autonomous transactions.  Run as FAB_LAB.  For the trainer, and for
-- anyone who wants to run it again at their own pace.
--
-- How to run it in DBeaver:
--   1. Open the Output panel first: Ctrl+Shift+O, or SQL Editor menu >
--      Show Server Output. The PUT_LINE text appears there.
--   2. Run the script one statement at a time, from the top.
--      - A plain SELECT, CREATE TABLE, DROP or DELETE: put the cursor in
--        the statement and press Ctrl+Enter.
--      - A PL/SQL block (DECLARE ... END; or BEGIN ... END;) or a
--        CREATE PROCEDURE: select the whole block, from its first line
--        down to END;, and press Ctrl+Enter. Run blocks one at a time.
--   3. Do not use Alt+X (Execute Script) on this file.
-- The lines with a single / after each END; are for SQL*Plus.
-- The rollbacks that matter happen inside PL/SQL blocks, so the demo
-- works the same whether DBeaver's auto-commit is on or off.
-- Everything this script creates is removed in section 9. It changes no
-- lot data.
-- =====================================================================

-- === 1. Records and %ROWTYPE (a row in a variable) ===
DECLARE
  -- a record you define yourself
  TYPE t_lot_line IS RECORD (
    lot_id  lots.lot_id%TYPE,
    status  lots.status%TYPE,
    shout   VARCHAR2(100)
  );
  v_line t_lot_line;
  -- a record shaped like a whole table row
  v_lot  lots%ROWTYPE;
BEGIN
  SELECT * INTO v_lot FROM lots WHERE lot_id = 'L26-003B';
  v_line.lot_id := v_lot.lot_id;
  v_line.status := v_lot.status;
  v_line.shout  := 'priority ' || v_lot.priority || ', ' || v_lot.hold_reason;
  DBMS_OUTPUT.PUT_LINE(v_line.lot_id || ' ' || v_line.status || ' - ' || v_line.shout);
END;
/

-- === 2. Associative array (a lookup table in memory, indexed by text) ===
DECLARE
  TYPE t_target IS TABLE OF products.target_thk_nm%TYPE INDEX BY VARCHAR2(20);
  v_target t_target;
  v_key    VARCHAR2(20);
BEGIN
  FOR p IN (SELECT product_code, target_thk_nm FROM products ORDER BY product_code) LOOP
    v_target(p.product_code) := p.target_thk_nm;
  END LOOP;
  v_key := v_target.FIRST;
  WHILE v_key IS NOT NULL LOOP
    DBMS_OUTPUT.PUT_LINE(RPAD(v_key, 12) || v_target(v_key));
    v_key := v_target.NEXT(v_key);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('count = ' || v_target.COUNT);
END;
/

-- === 3. Nested table (a list that you EXTEND) ===
DECLARE
  TYPE t_ids IS TABLE OF lots.lot_id%TYPE;
  v_ids t_ids := t_ids();
BEGIN
  FOR l IN (SELECT lot_id FROM lots WHERE status = 'HOLD' ORDER BY lot_id) LOOP
    v_ids.EXTEND;
    v_ids(v_ids.LAST) := l.lot_id;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('lots on hold: ' || v_ids.COUNT);
  FOR i IN 1 .. v_ids.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE('  ' || i || ' ' || v_ids(i));
  END LOOP;
END;
/

-- === 4. VARRAY (a list with a fixed top size) ===
DECLARE
  TYPE t_steps IS VARRAY(3) OF VARCHAR2(8);
  v_steps t_steps := t_steps('SPLIT', 'ANNEAL', 'FINAL');
BEGIN
  DBMS_OUTPUT.PUT_LINE('limit ' || v_steps.LIMIT || ', in use ' || v_steps.COUNT);
  FOR i IN 1 .. v_steps.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(i || ' ' || v_steps(i));
  END LOOP;
  BEGIN
    v_steps.EXTEND;      -- a fourth element does not fit
  EXCEPTION
    WHEN SUBSCRIPT_BEYOND_COUNT OR SUBSCRIPT_OUTSIDE_LIMIT THEN
      DBMS_OUTPUT.PUT_LINE('cannot add a 4th step: ' || SQLERRM);
  END;
END;
/

-- === 5. BULK COLLECT with LIMIT, FORALL, and SAVE EXCEPTIONS ===
CREATE TABLE my_demo_targets (
  wafer_id VARCHAR2(16) PRIMARY KEY,
  grade    VARCHAR2(6)  NOT NULL
);
DECLARE
  TYPE t_wafer_tab IS TABLE OF wafers.wafer_id%TYPE;
  TYPE t_grade_tab IS TABLE OF wafers.grade%TYPE;
  v_ids    t_wafer_tab;
  v_grades t_grade_tab;
  CURSOR c IS SELECT wafer_id, grade FROM wafers ORDER BY wafer_id;
  v_batches PLS_INTEGER := 0;
  v_rows    PLS_INTEGER := 0;
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_ids, v_grades LIMIT 20;      -- 20 rows per trip
    EXIT WHEN v_ids.COUNT = 0;
    v_batches := v_batches + 1;
    FORALL i IN 1 .. v_ids.COUNT
      INSERT INTO my_demo_targets (wafer_id, grade) VALUES (v_ids(i), NVL(v_grades(i), 'NONE'));
    v_rows := v_rows + SQL%ROWCOUNT;
  END LOOP;
  CLOSE c;
  DBMS_OUTPUT.PUT_LINE('batches ' || v_batches || ', rows inserted ' || v_rows);
END;
/
SELECT COUNT(*) AS rows_in_table FROM my_demo_targets;

-- SAVE EXCEPTIONS: keep going when some rows fail, then look at the failures.
-- Inserting the same 66 wafers again breaks the primary key for every row,
-- so we insert only three, two of which already exist.
DECLARE
  TYPE t_wafer_tab IS TABLE OF wafers.wafer_id%TYPE;
  v_ids t_wafer_tab := t_wafer_tab('L26-001-01', 'NEW-WAFER-01', 'L26-001-02');
  e_bulk EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bulk, -24381);
BEGIN
  FORALL i IN 1 .. v_ids.COUNT SAVE EXCEPTIONS
    INSERT INTO my_demo_targets (wafer_id, grade) VALUES (v_ids(i), 'TEST');
EXCEPTION
  WHEN e_bulk THEN
    DBMS_OUTPUT.PUT_LINE('failed rows: ' || SQL%BULK_EXCEPTIONS.COUNT);
    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
      DBMS_OUTPUT.PUT_LINE('  item ' || SQL%BULK_EXCEPTIONS(j).ERROR_INDEX
                           || ' (' || v_ids(SQL%BULK_EXCEPTIONS(j).ERROR_INDEX) || ')'
                           || ' error ' || SQL%BULK_EXCEPTIONS(j).ERROR_CODE);
    END LOOP;
END;
/
SELECT COUNT(*) AS rows_in_table FROM my_demo_targets;
ROLLBACK;

-- === 6. EXECUTE IMMEDIATE with a bind variable (USING) ===
DECLARE
  v_status VARCHAR2(8) := 'HOLD';
  v_n      NUMBER;
BEGIN
  EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM lots WHERE status = :s' INTO v_n USING v_status;
  DBMS_OUTPUT.PUT_LINE('lots with status ' || v_status || ': ' || v_n);
  v_status := 'ACTIVE';
  EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM lots WHERE status = :s' INTO v_n USING v_status;
  DBMS_OUTPUT.PUT_LINE('lots with status ' || v_status || ': ' || v_n);
END;
/

-- === 6b. A SELECT built at run time, opened through a cursor variable ===
-- A small stored procedure builds and runs the query. It is dropped in section 9.
CREATE OR REPLACE PROCEDURE demo7_show_lots (p_filter VARCHAR2, p_order VARCHAR2) IS
  v_sql     VARCHAR2(400);
  v_cur     SYS_REFCURSOR;
  v_lot     lots.lot_id%TYPE;
  v_status  lots.status%TYPE;
BEGIN
  -- the column to sort by is part of the text; the value to filter by is a bind
  v_sql := 'SELECT lot_id, status FROM lots WHERE (:f IS NULL OR status = :f) ORDER BY ' || p_order;
  DBMS_OUTPUT.PUT_LINE('-- ' || v_sql);
  OPEN v_cur FOR v_sql USING p_filter, p_filter;
  LOOP
    FETCH v_cur INTO v_lot, v_status;
    EXIT WHEN v_cur%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('   ' || v_lot || ' ' || v_status);
  END LOOP;
  CLOSE v_cur;
END demo7_show_lots;
/
BEGIN
  demo7_show_lots('HOLD', 'lot_id');
  demo7_show_lots('HOLD', 'lot_id DESC');
END;
/

-- === 7. Autonomous transaction: a log line that survives a rollback ===
CREATE OR REPLACE PROCEDURE log_error (p_module VARCHAR2, p_code NUMBER, p_msg VARCHAR2) IS
  PRAGMA AUTONOMOUS_TRANSACTION;          -- this procedure has its own transaction
BEGIN
  INSERT INTO error_log (log_id, module, err_code, err_msg)
  VALUES (error_log_seq.NEXTVAL, p_module, p_code, SUBSTR(p_msg, 1, 400));
  COMMIT;                                  -- commits only the log line
END log_error;
/
-- Change a lot, log something, then roll the change back, all in one block.
DECLARE
  v_prio lots.priority%TYPE;
BEGIN
  UPDATE lots SET priority = 9 WHERE lot_id = 'L26-003';
  SELECT priority INTO v_prio FROM lots WHERE lot_id = 'L26-003';
  DBMS_OUTPUT.PUT_LINE('before ROLLBACK: L26-003 priority ' || v_prio);
  log_error('DEMO7', -20001, 'Pretend something went wrong with lot L26-003');
  ROLLBACK;
  SELECT priority INTO v_prio FROM lots WHERE lot_id = 'L26-003';
  DBMS_OUTPUT.PUT_LINE('after ROLLBACK:  L26-003 priority ' || v_prio);
END;
/
SELECT module, err_code, err_msg FROM error_log;

-- Without the pragma the log line would be rolled back with the rest.
CREATE OR REPLACE PROCEDURE log_error_plain (p_module VARCHAR2, p_code NUMBER, p_msg VARCHAR2) IS
BEGIN
  INSERT INTO error_log (log_id, module, err_code, err_msg)
  VALUES (error_log_seq.NEXTVAL, p_module, p_code, SUBSTR(p_msg, 1, 400));
END log_error_plain;
/
BEGIN
  log_error_plain('DEMO7-PLAIN', -20001, 'This line will vanish');
  ROLLBACK;
END;
/
SELECT module, err_code, err_msg FROM error_log;

-- === 8. Looking at the result ===
SELECT COUNT(*) AS lots_with_priority_9 FROM lots WHERE priority = 9;

-- === 9. Clean up ===
DELETE FROM error_log;
COMMIT;
DROP PROCEDURE log_error;
DROP PROCEDURE log_error_plain;
DROP PROCEDURE demo7_show_lots;
DROP TABLE my_demo_targets PURGE;
SELECT (SELECT COUNT(*) FROM error_log) AS error_log_rows,
       (SELECT COUNT(*) FROM user_tables WHERE table_name = 'MY_DEMO_TARGETS') AS demo_tables
FROM   dual;
-- Demo 7 finished.
