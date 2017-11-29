SET SCAN ON
SET DEFINE ON
SET FEEDBACK OFF
SET VERIFY OFF
DEFINE schema_name=&1
DEFINE schema_pwd=&2
DEFINE schema_tblspace=&3
DEFINE schema_temp_tblspace=&4

PROMPT CREATING USER: &schema_name

CREATE USER &schema_name
  IDENTIFIED BY &schema_pwd
  DEFAULT TABLESPACE &schema_tblspace
  TEMPORARY TABLESPACE &schema_temp_tblspace
  PROFILE DEFAULT
  ACCOUNT UNLOCK;
  -- 2 Roles for &schema_name 
  GRANT CONNECT TO &schema_name;
  GRANT RESOURCE TO &schema_name;
  ALTER USER &schema_name DEFAULT ROLE ALL;
  -- 2 System Privileges for &schema_name 
  GRANT UNLIMITED TABLESPACE TO &schema_name;

-- this permission would grant access to all tables
-- in the instance. This maybe required or you can just
-- grant individual schema level SELECT access.
--  GRANT SELECT ANY TABLE TO &schema_name; 

EXIT