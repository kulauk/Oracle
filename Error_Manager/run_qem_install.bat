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

IF (%1)==() (GOTO :SET_DB_PWD) ELSE GOTO :SET_VARS

	:SET_DB_PWD
	REM --------------------------------------------------------------
	REM Set up database password variables
	REM --------------------------------------------------------------

		SET root_dir=%cd%
		SET /P l_db_name="Please enter the database instance name that you wish to install into: "
		ECHO --
		ECHO -- 
		SET /P l_sys_password="Please enter the password for sys on database %l_db_name%: "
		ECHO --
		ECHO --
		GOTO :INSTALL_MAIN

	:SET_VARS
	REM --------------------------------------------------------------
	REM Set variables
	REM --------------------------------------------------------------

		GOTO :INSTALL_MAIN
	REM --------------------------------------------------------------
	REM --------------------------------------------------------------


REM -----------------------------------------------------------------------
:INSTALL_MAIN
REM -----------------------------------------------------------------------


	SET build_script_name=install_qem.sql
	SET qem_install_log_name=%db_name%_qem_install.log

	sqlplus sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\%build_script_name% %root_dir% %qem_install_log_name% %l_schema_name%

REM --------------------------------------------------------------
REM --------------------------------------------------------------
ECHO Error Manager install complete

PAUSE
IF (%1)==() EXIT
