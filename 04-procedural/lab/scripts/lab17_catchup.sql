-- =====================================================================
-- Lab 17 catch-up: recreates the four Lab 16 objects.
-- Run this ONLY if you skipped Lab 16 (or lost your objects).
-- Run as FAB_LAB. Safe to run twice: CREATE OR REPLACE.
-- How to run it in DBeaver: this file is safe for Execute Script (Alt+X).
-- It holds only four CREATE OR REPLACE statements, each ending with a
-- line holding only a slash (/), and one SELECT. You can also run it
-- block by block: select each CREATE from its first line down to its
-- END; line and press Ctrl+Enter, then run the SELECT at the end.
-- The SELECT at the end should show the four objects as VALID.
-- Lines holding only "--" inside a block are spacers: a blank line there
-- could make DBeaver cut the block in two.
-- =====================================================================

-- Percent of the lot's graded wafers whose grade is PRIME, one decimal.
-- NULL when the lot has no graded wafer.
CREATE OR REPLACE FUNCTION wafer_yield(p_lot_id VARCHAR2) RETURN NUMBER IS
  v_graded NUMBER;
  v_prime  NUMBER;
BEGIN
  SELECT COUNT(grade),
         COUNT(CASE WHEN grade = 'PRIME' THEN 1 END)
  INTO   v_graded, v_prime
  FROM   wafers
  WHERE  lot_id = p_lot_id;
  --
  IF v_graded = 0 THEN
    RETURN NULL;
  END IF;
  RETURN ROUND(v_prime / v_graded * 100, 1);
END wafer_yield;
/

-- 'LOW' below 90 percent of target, 'HIGH' above 110 percent, else 'OK'.
CREATE OR REPLACE FUNCTION thickness_status(p_thickness NUMBER, p_target NUMBER)
  RETURN VARCHAR2 DETERMINISTIC IS
BEGIN
  IF p_thickness IS NULL OR p_target IS NULL THEN
    RETURN NULL;
  ELSIF p_thickness < p_target * 0.9 THEN
    RETURN 'LOW';
  ELSIF p_thickness > p_target * 1.1 THEN
    RETURN 'HIGH';
  ELSE
    RETURN 'OK';
  END IF;
END thickness_status;
/

-- Short report for one lot, printed with DBMS_OUTPUT.
CREATE OR REPLACE PROCEDURE print_lot_report(p_lot_id VARCHAR2) IS
  v_status  lots.status%TYPE;
  v_code    products.product_code%TYPE;
  v_target  products.target_thk_nm%TYPE;
  v_count   PLS_INTEGER := 0;
  CURSOR c_wafers IS
    SELECT w.wafer_id, w.grade, m.thickness_nm
    FROM   wafers w
           LEFT JOIN measurements m
                  ON m.wafer_id = w.wafer_id AND m.step = 'FINAL'
    WHERE  w.lot_id = p_lot_id
    ORDER  BY w.slot_no;
BEGIN
  SELECT l.status, p.product_code, p.target_thk_nm
  INTO   v_status, v_code, v_target
  FROM   lots l JOIN products p ON p.product_id = l.product_id
  WHERE  l.lot_id = p_lot_id;
  --
  DBMS_OUTPUT.PUT_LINE('Lot ' || p_lot_id || '  product ' || v_code
                       || '  target ' || v_target || ' nm  status ' || v_status);
  FOR w IN c_wafers LOOP
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE('- ' || RPAD(w.wafer_id, 14)
                         || RPAD(NVL(w.grade, '-'), 7)
                         || LPAD(NVL(TO_CHAR(w.thickness_nm), 'n/a'), 8) || ' nm  '
                         || NVL(thickness_status(w.thickness_nm, v_target), '-'));
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Wafers: ' || v_count || '   Yield: '
                       || NVL(TO_CHAR(wafer_yield(p_lot_id)), 'n/a') || ' %');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Lot ' || p_lot_id || ' does not exist');
END print_lot_report;
/

-- Puts a lot on hold. Errors: -20101 lot does not exist, -20102 already on hold.
CREATE OR REPLACE PROCEDURE hold_lot(p_lot_id VARCHAR2, p_reason VARCHAR2) IS
  v_status lots.status%TYPE;
BEGIN
  BEGIN
    SELECT status INTO v_status FROM lots WHERE lot_id = p_lot_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20101, 'Lot ' || p_lot_id || ' does not exist');
  END;
  --
  IF v_status = 'HOLD' THEN
    RAISE_APPLICATION_ERROR(-20102, 'Lot ' || p_lot_id || ' is already on hold');
  END IF;
  --
  UPDATE lots
  SET    status = 'HOLD',
         hold_reason = p_reason
  WHERE  lot_id = p_lot_id;
END hold_lot;
/

SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name IN ('WAFER_YIELD','THICKNESS_STATUS','PRINT_LOT_REPORT','HOLD_LOT')
ORDER  BY object_name;
-- Lab 17 catch-up done: four objects should be VALID.
