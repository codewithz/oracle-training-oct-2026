
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('LOT_HISTORY','MEASUREMENTS_BIG','ERROR_LOG')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name IN ('LOT_HISTORY_SEQ','ERROR_LOG_SEQ')) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
