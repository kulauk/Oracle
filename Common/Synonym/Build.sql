--SET TIME ON
--SET TIMING ON
SET PAGES 5000
SET LINES 400
SET VERIFY OFF


PROMPT *************************************
PROMPT *************************************
PROMPT ** Building: Synonyms
PROMPT *************************************

@@create_synonyms.sql

PROMPT *************************************
PROMPT ** Completed: Synonyms
PROMPT *************************************

PROMPT Hit Enter to continue..
PAUSE


