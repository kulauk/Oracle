--DROP USER common CASCADE;

CREATE USER common
  IDENTIFIED BY &Enter_password
  DEFAULT TABLESPACE &Enter_default_tblsp
  TEMPORARY TABLESPACE &Enter_temp_tblsp
  PROFILE DEFAULT
  ACCOUNT UNLOCK;
  -- 2 System Privileges for common 
  GRANT CREATE SESSION TO common;
  GRANT UNLIMITED TABLESPACE TO common;
  GRANT CREATE PROCEDURE TO common;
  GRANT EXECUTE ON DBMS_LOCK TO common;
  GRANT EXECUTE ON UTL_MAIL TO common;
  -- 4 Object Privileges for common 
