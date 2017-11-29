WHENEVER SQLERROR EXIT SQL.SQLCODE
SET SCAN ON
SET FEEDBACK OFF
SET VERIFY OFF

SET DEFINE ON

DEFINE install_dir=&1
DEFINE logfile_name=&2
DEFINE schema_alias=&3
DEFINE schema_name=&schema_alias._MANAGER
DEFINE schema_pwd=&4
DEFINE schema_tblsp=&5
DEFINE schema_temp_tblsp=&6

SPOOL &install_dir\&logfile_name

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------

PROMPT INSTALLING APPLICATION MANAGER PHASE 1. VERSION: 1.1

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

PROMPT Creating app manager schema

@&install_dir/create_manager_schema.sql &schema_name &schema_pwd &schema_tblsp &schema_temp_tblsp
@&install_dir/sys_Grants.sql &schema_name

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- app_owner privileges

PROMPT Creating &schema_name objects

alter session set current_schema = &schema_name;

-----------------------------
PROMPT Creating sequences....
-----------------------------


-----------------------------
PROMPT Creating static tables....
-----------------------------
@&install_dir/Tables/STATUS_CODE_T.sql
@&install_dir/Tables/SYSTEM_PARAMETERS_T.sql
@&install_dir/Tables/CONSTANTS_GENERATOR_T.sql
@&install_dir/Tables/APPLICATION_MANAGER_T.sql

--------------------------------
PROMPT Generating Constraints....
--------------------------------

--------------------------------
PROMPT Generating Indexes....
--------------------------------

--------------------------------
PROMPT Creating static table data....
--------------------------------
@&install_dir/Table_data/SYSTEM_PARAMETERS_T_fill.sql
@&install_dir/Table_data/STATUS_CODE_T_fill.sql
@&install_dir/Table_data/CONSTANTS_GENERATOR_T_fill.sql

--------------------------------
PROMPT Generating constants....
--------------------------------
@&install_dir/Procedures/P_GENERATE_CONSTANTS.prc
exec p_generate_constants;

--------------------------------
PROMPT Creating Foreign key constraints
--------------------------------

--------------------------------
PROMPT Creating synonyms
--------------------------------


--------------------------------
PROMPT Creating views....
--------------------------------

--------------------------------
PROMPT Creating types....
--------------------------------
@&install_dir/Types/VARCHAR_250_NT.tps
@&install_dir/Types/NUMBER_NT.tps

--------------------------------
PROMPT Creating contexts....
--------------------------------
@&install_dir/Contexts/pkg_util_dynsql_ctx.sql

--------------------------------
PROMPT Creating Functions....
--------------------------------

--------------------------------
PROMPT Creating package headers
--------------------------------
@&install_dir/Packages/pkg_utils.pks
@&install_dir/Packages/pkg_util_dynsql.pks

--------------------------------
PROMPT Creating package bodies
--------------------------------
@&install_dir/PackageBodies/pkg_utils.pkb
@&install_dir/PackageBodies/pkg_util_dynsql.pkb

--------------------------------
PROMPT Creating Procedures....
--------------------------------
@&install_dir/Procedures/P_EXAMPLE_SET_FILTERS_BINDS.prc
@&install_dir/Procedures/P_EXAMPLE_SET_FILTERS_CONTEXTS.prc

--------------------------------
PROMPT Creating grants
--------------------------------



-- populate table to show error_manager has been installed.
@&install_dir/Table_data/insert_into_application_manager.sql APPLICATION_MANAGER PKG_CONSTANTS EXECUTE Y
@&install_dir/Table_data/insert_into_application_manager.sql APPLICATION_MANAGER PKG_UTILS EXECUTE Y
@&install_dir/Table_data/insert_into_application_manager.sql APPLICATION_MANAGER PKG_UTIL_DYNSQL EXECUTE Y
@&install_dir/Table_data/insert_into_application_manager.sql APPLICATION_MANAGER NUMBER_NT EXECUTE Y
@&install_dir/Table_data/insert_into_application_manager.sql APPLICATION_MANAGER VARCHAR_250_NT EXECUTE Y


--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------

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
SPOOL OFF

EXIT

