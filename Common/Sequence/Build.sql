--SET TIME ON
--SET TIMING ON
SET PAGES 5000
SET LINES 400
SET VERIFY OFF


PROMPT *************************************
PROMPT *************************************
PROMPT ** Building: Sequences
PROMPT *************************************

@@seq_id_common_errors_autorun.sql
@@id_common_errors_seq.sql
@@id_common_error_codes_seq.sql
@@seq_id_common_error_alert.sql
@@seq_client_id.sql
@@seq_id_trace_config.sql
@@seq_id_trace_log.sql
@@seq_id_trace_summary.sql


PROMPT *************************************
PROMPT ** Completed: Sequences
PROMPT *************************************

PROMPT Hit Enter to continue..
PAUSE


