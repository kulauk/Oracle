--SET TIME ON
--SET TIMING ON
SET PAGES 5000
SET LINES 400
SET VERIFY OFF


PROMPT *************************************
PROMPT *************************************
PROMPT ** Building: Package
PROMPT *************************************

@@common.error_utils.pks
@@email_utils.pks
--@@MD5_ENCRYPTING.pks
@@pkg_app_manager_state.pks
@@pkg_app_manager.pks
@@utils.pks
@@data_check_types.pks
@@data_check_utils.pks

PROMPT *************************************
PROMPT ** Completed: Package
PROMPT *************************************

PROMPT Hit Enter to continue..
PAUSE


