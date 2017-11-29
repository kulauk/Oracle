@ECHO OFF
REM -------------------------------------------------------------
REM -------------------------------------------------------------
REM -- Batch file to create a template Application Schema
REM --
REM --
REM -- Created By : Duncan Lucas
REM -- Date	  : 01/08/2009
REM --
REM --------------------------------------------------------------
REM --------------------------------------------------------------
REM
REM --------------------------------------------------------------
REM Set up local variables
REM --------------------------------------------------------------


SET root_dir=%cd%
ECHO -------------------------------------------------------------------------------
ECHO -------------------------------------------------------------------------------
ECHO -------------------------------------------------------------------------------
ECHO APPLICATION MANAGER Installer....
ECHO -------------------------------------------------------------------------------
ECHO -------------------------------------------------------------------------------
ECHO -------------------------------------------------------------------------------
ECHO --
ECHO --
ECHO Please enter the database instance name that you wish to install into: 
ECHO --
SET /P l_db_name="ENTER DB NAME> "
ECHO --
ECHO --
ECHO Please enter the password for sys on database %l_db_name%: 
ECHO --
SET /P l_sys_password="ENTER SYS PWD> "
ECHO --
ECHO --
ECHO -------------------------------------------------------------------------------


:NEW_MANAGER_DECIDE
ECHO -------------------------------------------------------------------------------
ECHO Would you like to create a new application MANAGER schema? Enter (Y) 
ECHO or are you installing into an existing MANAGER schema? Enter (N): 
ECHO --
SET /P l_new_manager_install="ENTER (Y) or (N)> "
ECHO --

	IF (%l_new_manager_install%)==(N) GOTO :NEW_MANAGER_SKIP
	IF (%l_new_manager_install%)==(Y) (GOTO :NEW_MANAGER_INSTALL) ELSE (GOTO :NEW_MANAGER_DECIDE)

	:NEW_MANAGER_INSTALL
	ECHO -------------------------------------------------------------------------------
	ECHO This progamme will create a MANAGER schema for your application.
	ECHO It will install ERROR_MANAGER by default but all other functionality
	ECHO is optional depending on your requirements.
	ECHO -------------------------------------------------------------------------------
	ECHO --
	ECHO --
	ECHO A schema will now be created to hold the APPLICATION MANAGER objects.
	ECHO It is recommended that this schema name contains an alias of your 
	ECHO application name.
	ECHO --
	ECHO For example if your application is FNP and your main application schema
	ECHO is called FNP_OWNER then by entering the alias FNP a new schema containing
	ECHO the objects for APPLICATION MANAGER will be created as FNP_MANAGER.
	ECHO --
	ECHO Please now enter a short alias for the your application in which you wish 
	ECHO to create a manager schema. 
	ECHO (Note the password will be the same as the schema name): 
	ECHO --
	SET /P l_schema_alias="ENTER ALIAS NAME> "
	ECHO --
	SET l_schema_name=%l_schema_alias%_MANAGER
	ECHO --
	ECHO --
	SET l_schema_pwd=%l_schema_name%
	ECHO -------------------------------------------------------------------------------

	:SCHEMA_DECIDE
	ECHO --
	ECHO Would you like APPLICATION MANAGER to create your application schemas for you?
	ECHO --
	ECHO For example if you have set the alias to be FNP then application manager can
	ECHO create the 2 schemas FNP_USER AND FNP_OWNER.
	ECHO The necessary grants and synonyms for app manager's objects will 
	ECHO automatically be created.
	ECHO If you would like APPLICATION MANAGER to create these 2 schemas then enter (Y)
	ECHO If however these schemas already exist or you just want to create a standalone
	ECHO application manager then enter (N): 
	ECHO --	
	SET /P l_app_schema_install="ENTER (Y) or (N) > "
	ECHO --
	ECHO --
	ECHO -------------------------------------------------------------------------------
	IF (%l_app_schema_install%)==(N) GOTO :SCHEMA_SKIP
	IF (%l_app_schema_install%)==(Y) (GOTO :SCHEMA_INSTALL) ELSE (GOTO :SCHEMA_DECIDE)

		:SCHEMA_INSTALL
		REM --------------------------------------------------------------
		REM Install Application schemas
		REM --------------------------------------------------------------
	
		ECHO Please enter the NEW schema name that you wish to create to hold the objects
		ECHO E.g. FNP_OWNER (Note that the password will be the same as the schema name):
		ECHO --
		SET /P l_app_owner_name="ENTER SCHEMA> "
		ECHO --
		SET l_app_owner_pwd=l_app_owner_name

		ECHO Please enter the NEW schema name that you wish the client to connect to
		ECHO E.g. FNP_USER (Note that the password will be the same as the schema name):
		ECHO --
		SET /P l_app_user_name="ENTER SCHEMA> "
		ECHO --
		SET l_app_user_pwd=%l_app_user_name%

		ECHO Please enter the tablespace name you wish these new schemas to use: 
		ECHO --
		SET /P l_app_tblspc="ENTER TABLESPACE> "
		ECHO --

		ECHO Please enter the TEMP tablespace name you wish these new schemas to use: 
		ECHO --
		SET /P l_app_tmp_tblspc="ENTER TEMP TABLESPACE> "
		ECHO --
		ECHO --	
		ECHO **********************************************************************
		ECHO A READ ONLY schema will also be created. 
		ECHO Its user name and password will be %l_schema_alias%_READER
		ECHO NOTE: This reader has not been given ANY select permissions
		ECHO 	   You will need to grant permission to specific application tables.
		ECHO **********************************************************************
		ECHO --
		SET l_app_reader_pwd=%l_schema_alias%_READER
		ECHO -------------------------------------------------------------------------------
		sqlplus sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\create_owner_schema.sql %l_app_owner_name% %l_app_owner_pwd% %l_app_tblspc% %l_app_tmp_tblspc%
		sqlplus sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\create_user_schema.sql %l_app_user_name% %l_app_user_pwd% %l_app_tblspc% %l_app_tmp_tblspc%
		sqlplus sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\create_reader_schema.sql %l_schema_alias%_READER %l_app_reader_pwd% %l_app_tblspc% %l_app_tmp_tblspc%

	:SCHEMA_SKIP
	ECHO -------------------------------------------------------------------------------
	ECHO -------------------------------------------------------------------------------


	ECHO --
	ECHO --
	IF (%l_app_owner_name%)==() (GOTO :SCHEMA_INSTALL2) ELSE (GOTO :SCHEMA_SKIP2)
	:SCHEMA_INSTALL2
	REM --------------------------------------------------------------
	REM Set Application schemas
	REM --------------------------------------------------------------
	ECHO Please enter the name of the main schema that application 
	ECHO manager will be managing. 
	ECHO This is the schema that will hold your application objects (Eg FNP_OWNER): 
	ECHO --
	SET /P l_app_owner_name="ENTER SCHEMA> "
	ECHO --
	ECHO Please enter this NEW manager schema's tablespace name: 
	ECHO --
	SET /P l_app_tblspc="ENTER TABLESPACE> "
	ECHO --
	ECHO Please enter this NEW manager schema's TEMP tablespace name: 
	ECHO --
	SET /P l_app_tmp_tblspc="ENTER TEMP TABLESPACE> "
	ECHO --
	:SCHEMA_SKIP2
	SET l_build_script_name=build_schema.sql
	SET l_logfile_name=build_schema.log
	
	sqlplus sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\%l_build_script_name% %root_dir% %l_logfile_name% %l_schema_alias% %l_schema_pwd% %l_app_tblspc% %l_app_tmp_tblspc%
	IF %ERRORLEVEL%==0 (GOTO :SKIP1) ELSE (GOTO :ERROR)
	ECHO -------------------------------------------------------------------------------
	:SKIP1

	ECHO --
	ECHO --	
	REM --------------------------------------------------------------
	REM Install Error Manager:
	REM --------------------------------------------------------------
		SET root_dir=%root_dir%\..\Error_Manager
		CALL %root_dir%\run_qem_install.bat Y
		IF %ERRORLEVEL%==0 (GOTO :SKIP2) ELSE (GOTO :ERROR)
		:SKIP2
		ECHO --
		ECHO --
		SET root_dir=%cd%
	REM --------------------------------------------------------------
	REM --------------------------------------------------------------
	ECHO -------------------------------------------------------------------------------	
	
:NEW_MANAGER_SKIP
IF (%l_new_manager_install%)==(N) (GOTO :MANAGER_SETUP) ELSE (GOTO :MANAGER_SKIP)

	:MANAGER_SETUP
	ECHO --
	ECHO Please now enter the name of the manager schema that you wish to update: 
	ECHO --
	SET /P l_schema_name="ENTER MANAGER SCHEMA> "
	ECHO --
	ECHO Please now also enter the name of the application schema to be managed
	ECHO (eg for FNP_MANAGER enter FNP_OWNER): 
	ECHO --
	SET /P l_app_owner_name="ENTER APP SCHEMA> "
	ECHO --
	ECHO --

:MANAGER_SKIP
ECHO -------------------------------------------------------------------------------
REM --------------------------------------------------------------
REM Set up install options
REM --------------------------------------------------------------



REM --------------------------------------------------------------
REM --------------------------------------------------------------

sqlplus -s sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\check_app_installed.sql %l_schema_name% SESSION_MANAGER
SET l_errorlevel=%ERRORLEVEL%
IF (%l_errorlevel%)==(0) (GOTO :SESS_SKIP)
SET l_errorlevel=0

:SESS_DECIDE
SET /P l_sess_install="Would you like to install Session Manager? Enter (Y) or (N): "
ECHO --
ECHO --
	IF (%l_sess_install%)==(N) GOTO :SESS_SKIP
	IF (%l_sess_install%)==(Y) (GOTO :SESS_INSTALL) ELSE (GOTO :SESS_DECIDE)
	:SESS_INSTALL
	REM --------------------------------------------------------------
	REM Install Session Manager
	REM --------------------------------------------------------------
		ECHO Installing Session Manager
		SET l_logfile_name=session_manager_build.log
		SET root_dir=%root_dir%\..\Session_Manager

		ECHO ----------------------------------------------------------------------- 
		ECHO A session manager can be one of two types: MASTER or SLAVE
		ECHO --
		ECHO Setting it to MASTER means that it will push out the session entries
		ECHO to SLAVE session managers.. used for example with an authentication
		ECHO type schema.
		ECHO --
		ECHO Whereas SLAVE type means it is either a standalone schema
		ECHO OR it can receive session entries from the MASTER authentication schema.
		ECHO -
		ECHO ***********************************************************************
		ECHO IMPORTANT:
		ECHO If you are using session manager in the MASTER/SLAVE configuration then
		ECHO from each SLAVE schema you must 
		ECHO	GRANT EXECUTE on PKG_SESSION TO [master schema name];
		ECHO -
		ECHO and in the MASTER SCHEMA you must then, for each SLAVE :
		ECHO	CREATE SYNONYM pkg_session_[slave schema alias] 
		ECHO			FOR [master schema].pkg_session;
		ECHO -
		ECHO and in the MASTER schema,for each SLAVE, add a SYNONYM to the table:
		ECHO 		auth_slave_session_t
		ECHO -
		ECHO ***********************************************************************
		ECHO ----------------------------------------------------------------------- 
		ECHO --
		ECHO Would you like to set this instance of Session Manager as a MASTER or SLAVE? 

		:SESS_TYPE
		SET /P l_sess_type="Please enter 1 = MASTER or 2 = SLAVE: "

		IF (%l_sess_type%)==(1) (SET l_sess_type=MASTER) 
		IF (%l_sess_type%)==(MASTER) (GOTO :SESS_TYPE_SKIP)		
		IF (%l_sess_type%)==(2) (SET l_sess_type=SLAVE) ELSE (GOTO :SESS_TYPE)
		:SESS_TYPE_SKIP

		ECHO ----------------------------------------------------------------------- 
		ECHO A session manager can store passwords either as CLEAR TEXT or HASHED
		ECHO --
		ECHO Setting it the password type to CLEAR means that the passwords will be
		ECHO visible
		ECHO --
		ECHO Whereas setting to HASH means the passwords will be hashed.
		ECHO ----------------------------------------------------------------------- 
		ECHO --
		ECHO Would you like to set this instance of Session Manager 
		ECHO passwords to CLEAR or HASH?
		:SESS_PWD
		SET /P l_sess_pwd="Please enter 1 = CLEAR or 2 = HASHED: "

		IF (%l_sess_pwd%)==(1) (SET l_sess_pwd=CLEAR)
		IF (%l_sess_pwd%)==(CLEAR) (GOTO :SESS_PWD_SKIP)
		IF (%l_sess_pwd%)==(2) (SET l_sess_pwd=HASH) ELSE (GOTO :SESS_PWD)
		:SESS_PWD_SKIP
		
		sqlplus sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\install_session_manager.sql %root_dir% %l_logfile_name% %l_schema_name% %l_sess_type% %l_sess_pwd%
		IF %ERRORLEVEL%==0 (GOTO :SKIP3) ELSE (GOTO :ERROR)
		:SKIP3
		SET root_dir=%cd%
		ECHO --
		ECHO --
ECHO -------------------------------------------------------------------------------
:SESS_SKIP
REM --------------------------------------------------------------
REM --------------------------------------------------------------

sqlplus -s sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\check_app_installed.sql %l_schema_name% EMAIL_MANAGER
SET l_errorlevel=%ERRORLEVEL%
IF (%l_errorlevel%)==(0) (GOTO :EMAIL_SKIP)
SET l_errorlevel=0

REM --------------------------------------------------------------
REM --------------------------------------------------------------
:EMAIL_DECIDE
SET /P l_email_install="Would you like to install Email Manager? Enter (Y) or (N): "
ECHO --
ECHO --
	IF (%l_email_install%)==(N) GOTO :EMAIL_SKIP
	IF (%l_email_install%)==(Y) (GOTO :EMAIL_INSTALL) ELSE GOTO :EMAIL_DECIDE

	:EMAIL_INSTALL
	REM --------------------------------------------------------------
	REM Install Email Manager
	REM --------------------------------------------------------------
		ECHO Installing Email Manager
		SET root_dir=%root_dir%\..\Email_Manager
		CALL %root_dir%\run_install_javamail.bat %l_schema_name%
		IF %ERRORLEVEL%==0 (GOTO :SKIP4) ELSE (GOTO :ERROR)
		:SKIP4
		ECHO --
		ECHO --
		SET root_dir=%cd%
	REM --------------------------------------------------------------
:EMAIL_SKIP
REM --------------------------------------------------------------
REM --------------------------------------------------------------
ECHO -------------------------------------------------------------------------------


REM --------------------------------------------------------------
REM --------------------------------------------------------------

sqlplus -s sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\check_app_installed.sql %l_schema_name% DOWNLOAD_MANAGER
SET l_errorlevel=%ERRORLEVEL%
IF (%l_errorlevel%)==(0) (GOTO :DM_SKIP)
SET l_errorlevel=0


:DM_DECIDE
SET /P l_dm_install="Would you like to install Download Manager? Enter (Y) or (N): "
ECHO --
ECHO --
	IF (%l_dm_install%)==(N) GOTO :DM_SKIP
	IF (%l_dm_install%)==(Y) (GOTO :DM_INSTALL) ELSE GOTO :DM_DECIDE

	:DM_INSTALL
	REM --------------------------------------------------------------
	REM Install Download Manager
	REM --------------------------------------------------------------
		ECHO Installing Download Manager
		SET root_dir=%root_dir%\..\Download_Manager\install
		CALL %root_dir%\run_install_script.bat %l_schema_name%
		IF %ERRORLEVEL%==0 (GOTO :SKIP5) ELSE (GOTO :ERROR)
		:SKIP5
		ECHO --
		ECHO --
		SET root_dir=%cd%
	REM --------------------------------------------------------------
:DM_SKIP
REM --------------------------------------------------------------
REM --------------------------------------------------------------
ECHO -------------------------------------------------------------------------------

SET root_dir=%cd%
SET l_build_script_name=build_schema_links.sql
sqlplus sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\%l_build_script_name% %root_dir% %l_schema_name% %l_app_owner_name%
IF %ERRORLEVEL%==0 (GOTO :SKIP6) ELSE (GOTO :ERROR)
:SKIP6
REM Recompile schema

SET root_dir=%cd%
sqlplus sys/%l_sys_password%@%l_db_name% AS SYSDBA @%root_dir%\recompile_schema.sql %l_schema_name%

ECHO -------------------------------------------------------------------------------
ECHO -------------------------------------------------------------------------------

IF %ERRORLEVEL%==0 (GOTO :SKIP_ERROR) ELSE (GOTO :ERROR)
:ERROR
ECHO *******************************************************************
ECHO *******************************************************************
ECHO AN ERROR OCCURRED. PLEASE EXAMINE THE LOGFILES FOR MORE INFORMATION
ECHO *******************************************************************
ECHO *******************************************************************
GOTO :SKIP_SUCCESS
:SKIP_ERROR
ECHO *******************************************************************
ECHO *******************************************************************
ECHO INSTALLATION SUCCESSFUL
ECHO *******************************************************************
ECHO *******************************************************************
:SKIP_SUCCESS

ECHO -------------------------------------------------------------------------------
ECHO -------------------------------------------------------------------------------
ECHO -------------------------------------------------------------------------------
ECHO -------------------------------------------------------------------------------
PAUSE
EXIT
