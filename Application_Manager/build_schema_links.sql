WHENEVER SQLERROR EXIT SQL.SQLCODE
SET SCAN ON
SET FEEDBACK OFF
SET VERIFY OFF

SET DEFINE ON

DEFINE install_dir=&1
DEFINE app_manager_name=&2
DEFINE schema_name=&3

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------

PROMPT INSTALLING APPLICATION MANAGER LINKS

--************************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- sys privileges

PROMPT Creating SYS objects

alter session set current_schema = SYS;


--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- app manager privileges

PROMPT Creating &app_manager_name objects

alter session set current_schema = &app_manager_name;

-------------------------------------------------------------
PROMPT Creating grants FROM &app_manager_name TO &schema_name
-------------------------------------------------------------
@&install_dir/Grants/grant_all_pkgs_to_app.sql &schema_name

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- app manager privileges

PROMPT Creating &schema_name objects

alter session set current_schema = &schema_name;

-------------------------------------------------------------------------
PROMPT Creating Synonyms FROM &schema_name FOR &app_manager_name packages
-------------------------------------------------------------------------
@&install_dir/Synonyms/create_all_syns_for_app.sql &schema_name &app_manager_name



PROMPT Installation complete
PROMPT 
PROMPT PLEASE EXAMINE THE LOGFILE FOR ANY ERRORS
PROMPT 



--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------

EXIT

