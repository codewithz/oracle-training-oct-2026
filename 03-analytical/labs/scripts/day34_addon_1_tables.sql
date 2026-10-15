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
