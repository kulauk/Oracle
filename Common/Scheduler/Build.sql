--SET TIME ON
--SET TIMING ON
SET PAGES 5000
SET LINES 400
SET VERIFY OFF


PROMPT *************************************
PROMPT *************************************
PROMPT ** Building: Scheduler objects
PROMPT *************************************

@@create_scheduler_objects.sql

PROMPT *************************************
PROMPT ** Completed: Scheduler objects
PROMPT *************************************

PROMPT Hit Enter to continue..
PAUSE


