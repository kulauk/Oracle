--SET TIME ON
--SET TIMING ON
SET PAGES 5000
SET LINES 400
SET VERIFY OFF


PROMPT *************************************
PROMPT *************************************
PROMPT ** Building: Package Body
PROMPT *************************************

@@common.error_utils.pkb
@@email_utils.pkb
--@@MD5_ENCRYPTING.pkb
@@pkg_app_manager.pkb
@@utils.pkb
@@data_check_utils.pkb

PROMPT *************************************
PROMPT ** Completed: Package Body
PROMPT *************************************

PROMPT Hit Enter to continue..
PAUSE


