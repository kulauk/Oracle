CREATE USER QCT_TESTER_DULU
  IDENTIFIED BY &QCT_TESTER_DULU_pwd
  DEFAULT TABLESPACE DATA_QCT
  TEMPORARY TABLESPACE TEMP_QCT
  PROFILE DEFAULT
  ACCOUNT UNLOCK;
  -- 2 Roles for QCT_TESTER_DULU 
  GRANT CONNECT TO QCT_TESTER_DULU;
  GRANT RESOURCE TO QCT_TESTER_DULU;
  ALTER USER QCT_TESTER_DULU DEFAULT ROLE ALL;
  -- 6 System Privileges for QCT_TESTER_DULU 
  GRANT UNLIMITED TABLESPACE TO QCT_TESTER_DULU;
  GRANT CREATE PROCEDURE TO QCT_TESTER_DULU;
  GRANT CREATE SEQUENCE TO QCT_TESTER_DULU;
  GRANT CREATE SESSION TO QCT_TESTER_DULU;
  GRANT CREATE SYNONYM TO QCT_TESTER_DULU;
  GRANT CREATE PUBLIC SYNONYM TO QCT_TESTER_DULU;
  GRANT DROP PUBLIC SYNONYM TO QCT_TESTER_DULU;
  GRANT CREATE TABLE TO QCT_TESTER_DULU;
  GRANT CREATE TRIGGER TO QCT_TESTER_DULU;
  GRANT CREATE VIEW TO QCT_TESTER_DULU;
  GRANT CREATE TYPE TO QCT_TESTER_DULU;