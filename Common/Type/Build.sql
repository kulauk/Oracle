--SET TIME ON
--SET TIMING ON
SET PAGES 5000
SET LINES 400
SET VERIFY OFF


PROMPT *************************************
PROMPT *************************************
PROMPT ** Building: Types
PROMPT *************************************

@@obj_app_mgr_parameter.sql
@@obj_emailpayload.sql
@@tab_app_mgr_parameter.sql
@@tab_emailpayload.sql

PROMPT *************************************
PROMPT ** Completed: Types
PROMPT *************************************

PROMPT Hit Enter to continue..
PAUSE


