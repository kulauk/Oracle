set echo on
set timing on
set time on
set lines 200
set pages 5000

set serveroutput on

EXEC DBMS_SESSION.set_identifier('backoffice');

select a.spid
    from v$process a, v$session b
   where a.addr = b.paddr
     and b.audsid = userenv('sessionid')
/


show parameter timed_statistics;
alter session set timed_Statistics=true;
show parameter timed_statistics;

--alter session set sql_trace=true;
alter session set events '10046 TRACE NAME CONTEXT FOREVER, LEVEL 12';

-- now execute query

--
--then go to udump dir and look for trace file with the matching oraSPID.trc file.
--
--and run eg C:\>tkprof c:\oracle\diag\rdbms\ultdb6\raceall\trace\raceall_ora_53784.trc c:\\oracle\diag\rdbms\ultdb6\raceall\trace\tk.txt sys=no
--
--use sys=no to suppress the tracing of recursive system statements
--
--your trace file will appear in report.txt
-- 
--
--
--
--If you want to turn on sql_trace on system (instance) level, you need put 
--sql_trace = true in the init.ora file and bounce the database.
