SQL> @unstable_plans
SQL> break on plan_hash_value on startup_time skip 1
SQL> select * from (
  2  select sql_id, sum(execs), min(avg_etime) min_etime, max(avg_etime) max_etime, stddev_etime/min(avg_etime) norm_stddev
  3  from (
  4  select sql_id, plan_hash_value, execs, avg_etime,
  5  stddev(avg_etime) over (partition by sql_id) stddev_etime
  6  from (
  7  select sql_id, plan_hash_value,
  8  sum(nvl(executions_delta,0)) execs,
  9  (sum(elapsed_time_delta)/decode(sum(nvl(executions_delta,0)),0,1,sum(executions_delta))/1000000) avg_etime
 10  -- sum((buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta))) avg_lio
 11  from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS
 12  where ss.snap_id = S.snap_id
 13  and ss.instance_number = S.instance_number
 14  and executions_delta > 0
 15  and elapsed_time_delta > 0
 16  group by sql_id, plan_hash_value
 17  )
 18  )
 19  group by sql_id, stddev_etime
 20  )
 21  where norm_stddev > nvl(to_number('&min_stddev'),2)
 22  and max_etime > nvl(to_number('&min_etime'),.1)
 23  order by norm_stddev
 24  /
Enter value for min_stddev:
Enter value for min_etime:
 
SQL_ID        SUM(EXECS)   MIN_ETIME   MAX_ETIME   NORM_STDDEV
------------- ---------- ----------- ----------- -------------
1tn90bbpyjshq         20         .06         .24        2.2039
0qa98gcnnza7h         16       20.62      156.72        4.6669
7vgmvmy8vvb9s        170         .04         .39        6.3705
32whwm2babwpt        196         .02         .26        8.1444
5jjx6dhb68d5v         51         .03         .47        9.3888
71y370j6428cb        155         .01         .38       19.7416
66gs90fyynks7        163         .02         .55       21.1603
b0cxc52zmwaxs        197         .02         .68       23.6470
31a13pnjps7j3        196         .02        1.03       35.1301
7k6zct1sya530        197         .53       49.88       65.2909
 
10 rows selected.
 
SQL> @find_sql
SQL> select sql_id, child_number, plan_hash_value plan_hash, executions execs,
  2  (elapsed_time/1000000)/decode(nvl(executions,0),0,1,executions) avg_etime,
  3  buffer_gets/decode(nvl(executions,0),0,1,executions) avg_lio,
  4  sql_text
  5  from v$sql s
  6  where upper(sql_text) like upper(nvl('&sql_text',sql_text))
  7  and sql_text not like '%from v$sql where sql_text like nvl(%'
  8  and sql_id like nvl('&sql_id',sql_id)
  9  order by 1, 2, 3
 10  /
Enter value for sql_text:
Enter value for sql_id: 0qa98gcnnza7h
 
SQL_ID         CHILD  PLAN_HASH        EXECS     AVG_ETIME      AVG_LIO SQL_TEXT
------------- ------ ---------- ------------ ------------- ------------ ------------------------------------------------------------
0qa98gcnnza7h      0  568322376            3          9.02      173,807 select avg(pk_col) from kso.skew where col1 > 0
 
SQL> @awr_plan_stats
SQL> break on plan_hash_value on startup_time skip 1
SQL> select sql_id, plan_hash_value, sum(execs) execs, sum(etime) etime, sum(etime)/sum(execs) avg_etime, sum(lio)/sum(execs) avg_lio
  2  from (
  3  select ss.snap_id, ss.instance_number node, begin_interval_time, sql_id, plan_hash_value,
  4  nvl(executions_delta,0) execs,
  5  elapsed_time_delta/1000000 etime,
  6  (elapsed_time_delta/decode(nvl(executions_delta,0),0,1,executions_delta))/1000000 avg_etime,
  7  buffer_gets_delta lio,
  8  (buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta)) avg_lio
  9  from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS
 10  where sql_id = nvl('&sql_id','4dqs2k5tynk61')
 11  and ss.snap_id = S.snap_id
 12  and ss.instance_number = S.instance_number
 13  and executions_delta > 0
 14  )
 15  group by sql_id, plan_hash_value
 16  order by 5
 17  /
Enter value for sql_id: 0qa98gcnnza7h
 
SQL_ID        PLAN_HASH_VALUE        EXECS          ETIME    AVG_ETIME        AVG_LIO
------------- --------------- ------------ -------------- ------------ --------------
0qa98gcnnza7h       568322376           14          288.7       20.620      172,547.4
0qa98gcnnza7h      3723858078            2          313.4      156.715   28,901,466.0
 
SQL> @awr_plan_change
SQL> break on plan_hash_value on startup_time skip 1
SQL> select ss.snap_id, ss.instance_number node, begin_interval_time, sql_id, plan_hash_value,
  2  nvl(executions_delta,0) execs,
  3  (elapsed_time_delta/decode(nvl(executions_delta,0),0,1,executions_delta))/1000000 avg_etime,
  4  (buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta)) avg_lio
  5  from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS
  6  where sql_id = nvl('&sql_id','4dqs2k5tynk61')
  7  and ss.snap_id = S.snap_id
  8  and ss.instance_number = S.instance_number
  9  and executions_delta > 0
 10  order by 1, 2, 3
 11  /
Enter value for sql_id: 0qa98gcnnza7h
 
   SNAP_ID   NODE BEGIN_INTERVAL_TIME            SQL_ID        PLAN_HASH_VALUE        EXECS    AVG_ETIME        AVG_LIO
---------- ------ ------------------------------ ------------- --------------- ------------ ------------ --------------
     21857      1 20-MAR-09 04.00.08.872 PM      0qa98gcnnza7h       568322376            1       31.528      173,854.0
     22027      1 27-MAR-09 05.00.08.006 PM      0qa98gcnnza7h                            1      139.141      156,807.0
     22030      1 27-MAR-09 08.00.15.380 PM      0qa98gcnnza7h                            3       12.451      173,731.0
     22031      1 27-MAR-09 08.50.04.757 PM      0qa98gcnnza7h                            2        8.771      173,731.0
     22032      1 27-MAR-09 08.50.47.031 PM      0qa98gcnnza7h      3723858078            1      215.876   28,901,466.0
     22033      1 27-MAR-09 08.57.37.614 PM      0qa98gcnnza7h       568322376            2        9.804      173,731.0
     22034      1 27-MAR-09 08.59.12.432 PM      0qa98gcnnza7h      3723858078            1       97.554   28,901,466.0
     22034      1 27-MAR-09 08.59.12.432 PM      0qa98gcnnza7h       568322376            2        8.222      173,731.5
     22035      1 27-MAR-09 09.12.00.422 PM      0qa98gcnnza7h                            3        9.023      173,807.3
 
9 rows selected.