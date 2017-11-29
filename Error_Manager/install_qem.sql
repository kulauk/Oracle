WHENEVER SQLERROR EXIT SQL.SQLCODE
SET FEEDBACK OFF
SET VERIFY OFF
SET SHOW OFF

DEFINE install_root_dir=&1
DEFINE qem_create_log=&2
DEFINE APP_OWNER_SCHEMA=&3

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************

PROMPT	Beginning installation of Error manager........

PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- owner privileges


PROMPT Creating &APP_OWNER_SCHEMA objects

alter session set current_schema = &APP_OWNER_SCHEMA;

-- install error manager
@&install_root_dir/qem$install.sql

-- the above file also spools so we can only spool from here
SPOOL &install_root_dir\&qem_create_log

-- create the errors
-- use the QEM one first
@&install_root_dir/qem$define_errors.sql
-- now define errors from status codes
@&install_root_dir/create_qem_errors_from_status_codes.sql

@&install_root_dir/pkg_error_manager.pks
@&install_root_dir/pkg_error_manager.pkb



-- populate table to show error_manager has been installed.
@&install_root_dir/../Application_manager/Table_data/insert_into_application_manager.sql ERROR_MANAGER PKG_ERROR_MANAGER EXECUTE Y
@&install_root_dir/../Application_manager/Table_data/insert_into_application_manager.sql ERROR_MANAGER Q$ERROR_MANAGER EXECUTE N

@&install_root_dir/../Application_manager/Table_data/insert_into_application_manager.sql ERROR_MANAGER Q$LOG SELECT Y
@&install_root_dir/../Application_manager/Table_data/insert_into_application_manager.sql ERROR_MANAGER Q$ERROR SELECT Y
@&install_root_dir/../Application_manager/Table_data/insert_into_application_manager.sql ERROR_MANAGER Q$ERROR_CONTEXT SELECT Y
@&install_root_dir/../Application_manager/Table_data/insert_into_application_manager.sql ERROR_MANAGER Q$ERROR_INSTANCE SELECT Y

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
PROMPT *******************************************************************************
PROMPT *******************************************************************************

PROMPT	Installation of Error manager complete.

PROMPT *******************************************************************************
PROMPT *******************************************************************************
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------

SPOOL OFF

EXIT