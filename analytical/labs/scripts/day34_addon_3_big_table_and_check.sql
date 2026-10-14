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
