-- http://www.oracle-developer.net/display.php?id=316

--identifying specific sql cursors
--
--From the DBMS_XPLAN specification, we can see that the leading parameter of DISPLAY_CURSOR is a SQL_ID. SQL_ID is a new feature of 10g and appears in many V$ views as a means to identify a specific SQL statement. SQL_ID has a one-to-one relationship with the text of a SQL statement in the shared pool but it doesn't quite have a one-to-one relationship with the execution of that SQL (i.e. the cursor). There might be multiple child cursors for a single SQL_ID (for example, the same SQL statement executed under different optimizer modes). For this reason, DISPLAY_CURSOR accepts a child number (default 0) to identify the correct cursor. Incidentally, the execution plan used for a single SQL_ID and CHILD_CURSOR might change over time and this will be represented by a new PLAN_HASH_VALUE in V$SQL_PLAN.
--
--Going back to our previous example, we saw that DISPLAY_CURSOR defaults to the last cursor if we don't provide one. New in 10g, V$SESSION displays SQL_ID/SQL_CHILD_NUMBER and PREV_SQL_ID/PREV_CHILD_NUMBER, which in the very least enables us to answer a popular forum question "how do I identify my last SQL statement?"!
--
--Of course, we are more likely to want to examine the execution plan used for a statement that is running in another session or completed some time earlier (for example, a batch job that took considerably longer than usual to run). In these circumstances, we will need to search the shared pool for the target statement to get the SQL_ID (and in some cases the CHILD_NUMBER). A simple way to do this is using V$SQL. In 10g, we have either the SQL_TEXT column (first 1,000 characters of a SQL statement) or SQL_FULLTEXT (new) which is a CLOB of the actual SQL statement in its original format. If we are searching for a statement using some token from early in the SQL (i.e in the first 1,000 characters), then SQL_TEXT will be faster. Else we have no option but to use the SQL_FULLTEXT as our search target.
--
--A useful technique is to comment every SQL statement we write. In the following example, we will search for the SQL_ID of the EMP-DEPT query we ran earlier to find its SQL_ID. We will then lookup DISPLAY_CURSOR, but this time, request ALL information available.

SELECT sql_id
    ,      child_number
    ,      sql_text
    FROM   v$sql b
 WHERE  b.sql_text LIKE
           '%PARTITION BY T.IDSBEVENT) > 1 THEN 1 ELSE 0 END AS ISGROUP%';


--We can use the SQL_ID and CHILD_NUMBER to lookup its plan as follows.
SELECT plan_table_output
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR('a2y963usb2vup',0,'RUNSTATS_LAST'));


-- if we set the stats level to all and then run the query we would also be able to see execution
-- stats

ALTER SESSION SET STATISTICS_LEVEL = ALL;
set lines 400
set pages 5000


-- NOW RUN QUERY HERE

-- you will then need to find out the sql_id and child_number to plug i below:

SELECT plan_table_output
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR('a2y963usb2vup',0,'ALL'));

--OR

 set lines 400
set pages 5000
SELECT *
FROM TABLE (DBMS_XPLAN.display_cursor (
  NULL, -- this automatically uses the sql_id of the last SQL*Plus query
  NULL, -- this automatically uses the child_number of the last SQL*Plus query
  'TYPICAL IOSTATS LAST +PEEKED_BINDS'));