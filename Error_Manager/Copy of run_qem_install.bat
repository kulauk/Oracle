@ECHO OFF
REM -------------------------------------------------------------
REM -------------------------------------------------------------
REM -- Batch file to install Error manager onto a specified 
REM -- instance and schema
REM --
REM -- Created By : Duncan Lucas
REM -- Date	  : 14/05/2009
REM --
REM --------------------------------------------------------------
REM --------------------------------------------------------------
REM Set up the local variables:

IF (%1)==() (SET l_setup_standalone=TRUE) ELSE (SET l_setup_standalone=FALSE)
IF (l_setup_standalone)==(TRUE) GOTO :SETUP_VARS

GOTO :SETUP_SKIP


REM --------------------------------------------------------------
:SETUP_VARS

ECHO Setting up variables

SET root_dir=%cd%
SET /P l_db_name="Please enter the database instance name that you wish to install into: "
SET /P l_schema_name="Please enter the schema name that you wish to install into: "
SET /P l_sys_password="Please enter the password for sys: "

REM --------------------------------------------------------------
:SETUP_SKIP

SET build_script_name=install_qem.sql
SET qem_install_log_name=%db_name%_qem_install.log


REM --------------------------------------------------------------
REM --------------------------------------------------------------

REM Logging into sqlplus

ECHO %root_dir%
sqlplus sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\%build_script_name% %root_dir% %qem_install_log_name% %l_schema_name%

REM --------------------------------------------------------------
REM --------------------------------------------------------------
ECHO Error Manager install complete

PAUSE
IF (l_setup_standalone)==(TRUE) EXIT
