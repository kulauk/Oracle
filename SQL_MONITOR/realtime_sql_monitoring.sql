-- Taken from this blog:
-- http://blog.yannickjaquier.com/oracle/real-time-sql-monitoring.html

-- general view of whats executing in db right now  
 SELECT *
     FROM
       (SELECT status,
         sid,
         username,
         module,
         program,
         sql_id,
         sql_exec_id,
         TO_CHAR(sql_exec_start,'dd-mon-yyyy hh24:mi:ss') AS sql_exec_start,
         substr(sql_text, 1, 38) as sql_text,
         ROUND(elapsed_time/1000000)                      AS "Elapsed (s)",
         ROUND(cpu_time    /1000000)                      AS "CPU (s)",
         buffer_gets,
         ROUND(physical_read_bytes /(1024*1024)) AS "Phys reads (MB)",
         ROUND(physical_write_bytes/(1024*1024)) AS "Phys writes (MB)"
       FROM v$sql_monitor
       where status not like 'DONE%'
       ORDER BY elapsed_time DESC
       )
     WHERE rownum<=40
     ;

-- this provides the parameters for a sid that you'll need for subsequent queries.
-- plug in these values for queries below
select sid, sql_id, sql_exec_id, sql_exec_start 
from v$sql_monitor where sid = 286;


-- Gives summary times of sql
SELECT ROUND (elapsed_time / 1000000) AS "Elapsed (s)",
	   ROUND (cpu_time / 1000000, 3) AS "CPU (s)",
	   ROUND (queuing_time / 1000000, 3) AS "Queuing (s)",
	   ROUND (application_wait_time / 1000000, 3) AS "Appli wait (s)",
	   ROUND (concurrency_wait_time / 1000000, 3) AS "Concurrency wait (s)",
	   ROUND (cluster_wait_time / 1000000, 3) AS "Cluster wait (s)",
	   ROUND (user_io_wait_time / 1000000, 3) AS "User io wait (s)",
	   ROUND (physical_read_bytes / (1024 * 1024)) AS "Phys reads (MB)",
	   ROUND (physical_write_bytes / (1024 * 1024)) AS "Phys writes (MB)",
	   buffer_gets AS "Buffer gets",
	   ROUND (plsql_exec_time / 1000000, 3) AS "Plsql exec (s)",
	   ROUND (java_exec_time / 1000000, 3) AS "Java exec (s)"
FROM   v$sql_monitor
WHERE  sql_id = '7ncz01fr2mfkz'
AND    sql_exec_id = 16777216
AND    sql_exec_start = TO_DATE ('12-feb-2015 12:16:56', 'dd-mon-yyyy hh24:mi:ss')
;


-- we can join V$SQL_MONITOR with V$ACTIVE_SESSION_HISTORY to get more accurate information:
SELECT NVL (wait_class, 'CPU') AS wait_class, NVL (event, 'CPU') AS event, COUNT (*)
FROM   v$active_session_history a
WHERE  sql_id = '7ncz01fr2mfkz'
AND    sql_exec_id = 16777216
AND    sql_exec_start = TO_DATE ('12-feb-2015 12:16:56', 'dd-mon-yyyy hh24:mi:ss')
GROUP BY wait_class, event;


-- some wait events logged in V$ACTIVE_SESSION_HISTORY do not appear in V$SQL_MONITOR. The one I have often seen is Other, but based on your database activity you may see others:
SELECT DISTINCT NVL(wait_class,'CPU') AS wait_class FROM v$active_session_history ORDER BY 1;


-- **** This is very good for showing execution plan times.. note last plan_time column  ... as it shows time for each step
col PLAN FOR a250
set lines 400
set pages 50000
SELECT	  RPAD ('(' || p.plan_line_id || ' ' || NVL (p.plan_parent_id, '0') || ')', 8)
	   || '|'
	   || RPAD (LPAD (' ', 2 * p.plan_depth) || p.plan_operation || ' ' || p.plan_options, 60, '.')
	   || NVL2 (p.plan_object_owner || p.plan_object_name, '(' || p.plan_object_owner || '.' || p.plan_object_name || ') ', '')
	   || NVL2 (p.plan_cost, 'Cost:' || p.plan_cost, '')
	   || ' '
	   || NVL2 (p.plan_bytes || p.plan_cardinality, '(' || p.plan_bytes || ' bytes, ' || p.plan_cardinality || ' rows)', '')
	   || ' '
	   || NVL2 (p.plan_partition_start || p.plan_partition_stop, ' PStart:' || p.plan_partition_start || ' PStop:' || p.plan_partition_stop, '')
	   || ' ' || NVL2 (p.plan_time, p.plan_time || '(s)', '')
		   AS plan
FROM   v$sql_plan_monitor p
WHERE  sql_id = '7ncz01fr2mfkz'
AND    sql_exec_id = 16777216
AND    sql_exec_start =TO_DATE('12-feb-2015 12:16:56','dd-mon-yyyy hh24:mi:ss')
ORDER BY p.plan_line_id, p.plan_parent_id;


-- get the waits
SELECT NVL(wait_class,'CPU') AS wait_class, NVL(event,'CPU') AS event, sql_plan_line_id, COUNT(*)
FROM v$active_session_history a
WHERE  sql_id = '7ncz01fr2mfkz'
AND    sql_exec_id = 16777216
AND    sql_exec_start =TO_DATE('12-feb-2015 12:16:56','dd-mon-yyyy hh24:mi:ss')
GROUP BY wait_class,event,sql_plan_line_id;
 
-- it starts to be complex, and fortunately Oracle is providing DBMS_SQLTUNE.REPORT_SQL_MONITOR function that do for you all those computations:
-- note uncomment html or active and save to html file to see grid control like page (very good)
SET lines 400
SET pages 10000
SET LONG 999999
SET longchunksize 400
SELECT dbms_sqltune.report_sql_monitor(sql_id=>'7ncz01fr2mfkz',sql_exec_id=>16777216,sql_exec_start=> TO_DATE('12-feb-2015 12:16:56','dd-mon-yyyy hh24:mi:ss'),report_level=>'ALL'
--, type => 'HTML'
--, type => 'ACTIVE'
) AS report FROM dual;
 

SET lines 400
SET pages 10000
SET LONG 999999
SET longchunksize 400
SPOOL C:\Users\dlucas550\Documents\1\sql_monitoring.htm
SELECT dbms_sqltune.report_sql_monitor(sql_id=>'7ncz01fr2mfkz',sql_exec_id=>16777216,sql_exec_start=> TO_DATE('12-feb-2015 12:16:56','dd-mon-yyyy hh24:mi:ss'),report_level=>'ALL'
--, type => 'HTML'
, type => 'ACTIVE'
) AS report FROM dual;
SPOOL OFF


-- this one seems to give more detail than above and only requires sql_id
SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET LINESIZE 1000
SET PAGESIZE 0
SET TRIM ON
SET TRIMSPOOL ON
SET ECHO OFF
SET FEEDBACK OFF

SPOOL C:\Users\dlucas550\Documents\1\sql_monitoring.htm
SELECT DBMS_SQLTUNE.report_sql_detail(
  sql_id       => '7ncz01fr2mfkz',
  type         => 'ACTIVE',
  report_level => 'ALL') AS report
FROM dual;
SPOOL OFF


--Remark:
--The type parameter of this function may produce an HTML report and when set to ACTIVE produce a Grid Control like page, needed resources will be downloaded from Internet.
--
--While the ACTIVE format has poor interest versus Grid Control (when you have it of course) the HTML report has a pretty good looking:
--
--sql_monitor_html1
--
--The second Real-Time SQL Monitoring function of DBMS_SQLTUNE package is pretty interesting as giving a history list of the sql_id execution over time:

SET lines 200
SET pages 1000
SET LONG 999999
SET longchunksize 400
SELECT dbms_sqltune.report_sql_monitor_list(sql_id=>'7ncz01fr2mfkz',report_level=>'ALL') AS report FROM dual;
 

