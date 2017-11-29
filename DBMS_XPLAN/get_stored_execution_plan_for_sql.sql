--https://www.brentozar.com/archive/2014/07/getting-oracle-execution-plan/

--Get stored execution plan using v$sql and then DBMS_XPLAN to display it:
--Note that this will only give ALLSTATS data if the session used to run the sql was done with stats turned on ie:
--ALTER SESSION SET STATISTICS_LEVEL = ALL;
--
--Otherwise it will be basic plan data as if you had used DBMS_XPLAN.display_cursor (s.sql_id, s.child_number, 'BASIC')

SET LINES 400
SET PAGES 5000
SET TIME ON
SET TIMING ON

SELECT plan_table_output
  FROM v$sql s, TABLE (DBMS_XPLAN.display_cursor (s.sql_id, s.child_number, 'ALLSTATS LAST')) t
 WHERE s.sql_text LIKE 'INSERT INTO COPOS_TEST.SBRPTDUTIABLESTAKEB%';
 