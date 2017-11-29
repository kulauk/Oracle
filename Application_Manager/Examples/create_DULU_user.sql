CREATE USER DULU
  IDENTIFIED BY &DULU_pwd
  DEFAULT TABLESPACE DATA_S
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;
  -- 2 Roles for DULU 
  GRANT CONNECT TO DULU;
  GRANT RESOURCE TO DULU;
  ALTER USER DULU DEFAULT ROLE ALL;
  -- 2 System Privileges for DULU 
  GRANT UNLIMITED TABLESPACE TO DULU;
  GRANT DBA TO DULU;