CREATE TABLE lot_history (
  hist_id     NUMBER(6)      CONSTRAINT lot_history_pk PRIMARY KEY,
  lot_id      VARCHAR2(12)   NOT NULL CONSTRAINT lot_hist_lot_fk REFERENCES lots,
  old_status  VARCHAR2(8)    CONSTRAINT lot_hist_old_ck CHECK (old_status IN ('ACTIVE','HOLD','SHIPPED','SCRAPPED')),
  new_status  VARCHAR2(8)    NOT NULL CONSTRAINT lot_hist_new_ck CHECK (new_status IN ('ACTIVE','HOLD','SHIPPED','SCRAPPED')),
  changed_at  DATE           NOT NULL,
  changed_by  VARCHAR2(12)   NOT NULL,
  note        VARCHAR2(200)
);
CREATE INDEX lot_history_lot_ix ON lot_history (lot_id, changed_at);
CREATE SEQUENCE lot_history_seq START WITH 1000 NOCACHE;
CREATE SEQUENCE error_log_seq   START WITH 1    NOCACHE;
DECLARE
  TYPE t_names IS VARRAY(5) OF VARCHAR2(12);
  who      t_names := t_names('RKUMAR','LTAN','SOKAFOR','PDIAZ','MAYA');
  v_hist   PLS_INTEGER := 0;
  v_i      PLS_INTEGER := 0;
  v_cycles PLS_INTEGER;
  v_t      DATE;
  v_cap    CONSTANT DATE := TO_DATE('2026-10-10 12:00','YYYY-MM-DD HH24:MI');
  v_seed   PLS_INTEGER := 0;
  v_tool   VARCHAR2(6);
  v_stop   BOOLEAN;
  FUNCTION pick_tool(p_n PLS_INTEGER) RETURN VARCHAR2 IS
    t_arr SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('MET01','MET02','MET03','ANL01','ANL02','SPL01','SPL02','CMP01','IMP01');
  BEGIN
    RETURN t_arr(MOD(p_n, 9) + 1);
  END;
  FUNCTION hold_note(p_n PLS_INTEGER, p_lot VARCHAR2) RETURN VARCHAR2 IS
    tl VARCHAR2(6) := pick_tool(p_n);
    th VARCHAR2(10) := TO_CHAR(10 + MOD(p_n * 37, 900) / 10, 'FM990.0');
  BEGIN
    IF MOD(p_n, 8) = 0 THEN RETURN 'hold - thk OOS at FINAL, ' || tl || ' read ' || th || 'nm vs target';
    ELSIF MOD(p_n, 8) = 1 THEN RETURN 'HOLD: defect cnt high after ' || tl || ' (INC-' || (20400 + MOD(p_n * 13, 600)) || ')';
    ELSIF MOD(p_n, 8) = 2 THEN RETURN 'eng req  hold  re-meas on ' || tl || ', see INC-' || (20400 + MOD(p_n * 17, 600));
    ELSIF MOD(p_n, 8) = 3 THEN RETURN 'Held by shift lead. particle count ' || (20 + MOD(p_n * 11, 80)) || ' on ' || tl;
    ELSIF MOD(p_n, 8) = 4 THEN RETURN 'wafer bow suspected - ' || p_lot || ' on hold pending ' || tl || ' check';
    ELSIF MOD(p_n, 8) = 5 THEN RETURN 'hold per FAB-OPS-' || (100 + MOD(p_n, 40)) || ', thickness ' || th || ' nm';
    ELSIF MOD(p_n, 8) = 6 THEN RETURN 'Audit hold. contact j.tan@fabops.example ' || '(ext ' || (4100 + MOD(p_n * 7, 900)) || ')';
    ELSE RETURN NULL;
    END IF;
  END;
  FUNCTION release_note(p_n PLS_INTEGER) RETURN VARCHAR2 IS
    tl VARCHAR2(6) := pick_tool(p_n + 3);
    th VARCHAR2(10) := TO_CHAR(10 + MOD(p_n * 41, 900) / 10, 'FM990.0');
  BEGIN
    IF MOD(p_n, 6) = 0 THEN RETURN 're-meas on ' || tl || ' ok, ' || th || 'nm within spec';
    ELSIF MOD(p_n, 6) = 1 THEN RETURN 'released by eng - defect cnt ' || (3 + MOD(p_n * 5, 20)) || ' within limit';
    ELSIF MOD(p_n, 6) = 2 THEN RETURN 'RELEASED. recheck ' || tl || ' pass (INC-' || (20400 + MOD(p_n * 19, 600)) || ')';
    ELSIF MOD(p_n, 6) = 3 THEN RETURN 'ok to continue   ' || tl;
    ELSIF MOD(p_n, 6) = 4 THEN RETURN NULL;
    ELSE RETURN 'hold cleared, no action';
    END IF;
  END;
  PROCEDURE add_row(p_lot VARCHAR2, p_old VARCHAR2, p_new VARCHAR2, p_at DATE, p_note VARCHAR2) IS
  BEGIN
    v_hist := v_hist + 1;
    v_seed := v_seed + 1;
    INSERT INTO lot_history (hist_id, lot_id, old_status, new_status, changed_at, changed_by, note)
    VALUES (v_hist, p_lot, p_old, p_new, p_at, who(MOD(v_seed, 5) + 1), p_note);
  END;
BEGIN
  FOR l IN (SELECT lot_id, status, start_date FROM lots ORDER BY start_date, lot_id) LOOP
    v_i := v_i + 1;
    v_cycles := 2 + MOD(v_i * 3, 5);
    v_t := l.start_date;
    add_row(l.lot_id, NULL, 'ACTIVE', v_t, CASE WHEN MOD(v_i, 4) = 0 THEN NULL ELSE 'lot started' END);
    v_stop := FALSE;
    FOR c IN 1 .. v_cycles LOOP
      EXIT WHEN v_stop;
      v_t := v_t + (6 + MOD(v_i * 7 + c * 5, 50)) / 24;
      IF v_t >= v_cap THEN EXIT; END IF;
      add_row(l.lot_id, 'ACTIVE', 'HOLD', v_t, hold_note(v_i * 10 + c, l.lot_id));
      v_t := v_t + (3 + MOD(v_i * 11 + c * 3, 40)) / 24;
      IF v_t >= v_cap THEN v_stop := TRUE; EXIT; END IF;
      IF c = v_cycles AND l.status = 'HOLD' THEN
        EXIT;
      ELSIF c = v_cycles AND l.status = 'SCRAPPED' THEN
        add_row(l.lot_id, 'HOLD', 'SCRAPPED', v_t, 'scrap - fails FINAL, ' || pick_tool(v_i) || ' read ' || TO_CHAR(900 + v_i * 17) || ' nm');
      ELSE
        add_row(l.lot_id, 'HOLD', 'ACTIVE', v_t, release_note(v_i * 10 + c));
      END IF;
    END LOOP;
    IF l.status = 'SHIPPED' THEN
      v_t := LEAST(v_t + (12 + MOD(v_i * 5, 30)) / 24, v_cap);
      add_row(l.lot_id, 'ACTIVE', 'SHIPPED', v_t, 'shipped');
    END IF;
  END LOOP;
  COMMIT;
END;
/
CREATE TABLE measurements_big (
  meas_id       NUMBER(8)     CONSTRAINT meas_big_pk PRIMARY KEY,
  wafer_id      VARCHAR2(16)  NOT NULL,
  step          VARCHAR2(8)   NOT NULL,
  tool_id       VARCHAR2(6)   NOT NULL,
  meas_time     DATE          NOT NULL,
  thickness_nm  NUMBER(8,2)   NOT NULL,
  defect_count  NUMBER(5)     NOT NULL
);
INSERT /*+ APPEND */ INTO measurements_big
SELECT g.n,
       w.wafer_id,
       CASE MOD(g.n, 3) WHEN 0 THEN 'SPLIT' WHEN 1 THEN 'ANNEAL' ELSE 'FINAL' END,
       CASE MOD(g.n, 3)
         WHEN 0 THEN CASE MOD(g.n, 2) WHEN 0 THEN 'SPL01' ELSE 'SPL02' END
         WHEN 1 THEN CASE MOD(g.n, 2) WHEN 0 THEN 'ANL01' ELSE 'ANL02' END
         ELSE CASE MOD(g.n, 7) WHEN 0 THEN 'MET03' WHEN 1 THEN 'MET02' ELSE 'MET01' END
       END,
       TO_DATE('2026-08-04 06:00','YYYY-MM-DD HH24:MI') + MOD(g.n * 7919, 67 * 1440) / 1440,
       ROUND(p.target_thk_nm
             * (CASE MOD(g.n, 3) WHEN 0 THEN 1.30 WHEN 1 THEN 1.10 ELSE 1.00 END)
             * (0.92 + MOD(g.n * 104729, 1000) / 6250), 2),
       CASE MOD(g.n, 3) WHEN 0 THEN 20 + MOD(g.n * 31, 50)
                        WHEN 1 THEN 8 + MOD(g.n * 17, 25)
                        ELSE MOD(g.n * 13, 12) END
FROM  (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 200000) g
JOIN  (SELECT wafer_id, lot_id, ROW_NUMBER() OVER (ORDER BY wafer_id) AS rn FROM wafers) w
       ON w.rn = MOD(TRUNC(g.n / 3), 66) + 1
JOIN  lots     l ON l.lot_id = w.lot_id
JOIN  products p ON p.product_id = l.product_id;
COMMIT;
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'MEASUREMENTS_BIG');
END;
/
CREATE TABLE error_log (
  log_id     NUMBER(8)       CONSTRAINT error_log_pk PRIMARY KEY,
  logged_at  TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  module     VARCHAR2(60),
  err_code   NUMBER(6),
  err_msg    VARCHAR2(400)
);
SELECT 'LOT_HISTORY' AS table_name, COUNT(*) AS row_count FROM lot_history
UNION ALL SELECT 'MEASUREMENTS_BIG', COUNT(*) FROM measurements_big
UNION ALL SELECT 'ERROR_LOG', COUNT(*) FROM error_log;