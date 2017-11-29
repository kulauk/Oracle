ALTER SESSION SET STATISTICS_LEVEL = ALL;

-- or use hint : /*+ gather_plan_statistics */


-- can't find your sql id use this:

--SELECT sql_id
--    ,      child_number
--    ,      sql_text
--    FROM   v$sql b
-- WHERE  b.sql_text LIKE '%<enter sql here>%';

set lines 400
set pages 5000
set time on
set timing on


-- NOW RUN QUERY HERE
--*******************





--*******************

-- you will then need to find out the sql_id and child_number to plug i below:

SELECT plan_table_output
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR(null,null,'ALLSTATS LAST'));

--OR
--  'TYPICAL IOSTATS LAST +PEEKED_BINDS'
--
--Format keywords must be separated by either a comma or a space:
--ROWS - if relevant, shows the number of rows estimated by the optimizer
--BYTES - if relevant, shows the number of bytes estimated by the optimizer
--COST - if relevant, shows optimizer cost information
--PARTITION - if relevant, shows partition pruning information
--PARALLEL - if relevant, shows PX information (distribution method and table queue information)
--PREDICATE - if relevant, shows the predicate section
--PROJECTION -if relevant, shows the projection section
--ALIAS - if relevant, shows the "Query Block Name / Object Alias" section
--REMOTE - if relevant, shows the information for distributed query (for example, remote from serial distribution and remote SQL)
--NOTE - if relevant, shows the note section of the explain plan
--IOSTATS - assuming that basic plan statistics are collected when SQL statements are executed (either by using the gather_plan_statistics hint or by setting the parameter statistics_level to ALL), this format shows IO statistics for ALL (or only for the LAST as shown below) executions of the cursor.
--MEMSTATS - Assuming that PGA memory management is enabled (that is, pga_aggregate_target parameter is set to a non 0 value), this format allows to display memory management statistics (for example, execution mode of the operator, how much memory was used, number of bytes spilled to disk, and so on). These statistics only apply to memory intensive operations like hash-joins, sort or some bitmap operators.
--ALLSTATS - A shortcut for 'IOSTATS MEMSTATS'
--LAST - By default, plan statistics are shown for all executions of the cursor. The keyword LAST can be specified to see only the statistics for the last execution.
--The following two formats are deprecated but supported for backward compatibility:
--
--RUNSTATS_TOT - Same as IOSTATS, that is, displays IO statistics for all executions of the specified cursor.
--RUNSTATS_LAST - Same as IOSTATS LAST, that is, displays the runtime statistics for the last execution of the cursor
--Format keywords can be prefixed by the sign '-' to exclude the specified information. For example, '-PROJECTION' excludes projection information.
--
--
--Usage Notes
--
--To use the DISPLAY_CURSOR functionality, the calling user must have SELECT privilege on the fixed views V$SQL_PLAN_STATISTICS_ALL, V$SQL and V$SQL_PLAN, otherwise it shows an appropriate error message.
--
--Here are some ways you might use variations on the format parameter:
--
--Use 'ALL -PROJECTION -NOTE' to display everything except the projection and note sections.
--
--Use 'TYPICAL PROJECTION' to display using the typical format with the additional projection section (which is normally excluded under the typical format). Since typical is default, using simply 'PROJECTION' is equivalent.
--
--Use '-BYTES -COST -PREDICATE' to display using the typical format but excluding optimizer cost and byte estimates as well as the predicate section.
--
--Use 'BASIC ROWS' to display basic information with the additional number of rows estimated by the optimizer.
--
--
--
