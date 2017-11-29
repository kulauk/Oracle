--SET TIME ON
--SET TIMING ON
SET PAGES 5000
SET LINES 400
SET VERIFY OFF


PROMPT *************************************
PROMPT *************************************
PROMPT ** Building: Grants
PROMPT *************************************

@@create_grants.sql

PROMPT *************************************
PROMPT ** Completed: Grants
PROMPT *************************************

PROMPT Hit Enter to continue..
PAUSE


