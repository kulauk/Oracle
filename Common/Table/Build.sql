--SET TIME ON
--SET TIMING ON
SET PAGES 5000
SET LINES 400
SET VERIFY OFF


PROMPT *************************************
PROMPT *************************************
PROMPT ** Building: tables
PROMPT *************************************

@@common_errors.sql
@@common_errors_autorun.sql
@@common_error_alert.sql
@@common_error_codes.sql
@@common_error_values.sql
@@system_config.sql
@@trace_config.sql
@@trace_summary.sql
@@trace_log.sql


PROMPT *************************************
PROMPT ** Completed: tables
PROMPT *************************************

PROMPT Hit Enter to continue..
PAUSE


