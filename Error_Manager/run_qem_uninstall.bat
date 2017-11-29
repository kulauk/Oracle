@ECHO OFF
REM -------------------------------------------------------------
REM -------------------------------------------------------------
REM -- Batch file to uninstall Error manager from a specified 
REM -- instance and schema
REM --
REM -- Created By : Duncan Lucas
REM -- Date	  : 14/05/2009
REM --
REM --------------------------------------------------------------
REM --------------------------------------------------------------
REM Set up the local variables:


SET root_dir=%cd%

SET script_name=uninstall_qem.sql

SET /P db_name="Please enter the database instance name that you wish to uninstall from: "

SET /P schema_name="Please enter the schema name that you wish to uninstall from: "

SET qem_uninstall_log_name=%db_name%_qem_uninstall.log

set /P sys_password="Please enter the password for sys: "

REM --------------------------------------------------------------
REM --------------------------------------------------------------

REM Logging into sqlplus

sqlplus sys/%sys_password%@%db_name% AS SYSDBA @%root_dir%\%script_name% %root_dir% %qem_uninstall_log_name% %schema_name%

REM --------------------------------------------------------------
REM --------------------------------------------------------------

PAUSE
EXIT
