DBMS_XPLAN.DISPLAY_CURSOR(
   sql_id        IN  VARCHAR2  DEFAULT  NULL,
   child_number  IN  NUMBER    DEFAULT  NULL, 
   format        IN  VARCHAR2  DEFAULT  'TYPICAL');
Parameters

Table 176-4 DISPLAY_CURSOR Function Parameters

Parameter    Description
sql_id
Specifies the SQL_ID of the SQL statement in the cursor cache. You can retrieve the appropriate value by querying the column SQL_ID in V$SQL or V$SQLAREA. Alternatively, you could choose the column PREV_SQL_ID for a specific session out of V$SESSION. This parameter defaults to NULL in which case the plan of the last cursor executed by the session is displayed.
child_number
Child number of the cursor to display. If not supplied, the execution plan of all cursors matching the supplied sql_id parameter are displayed. The child_number can be specified only if sql_id is specified.
format
Controls the level of details for the plan. It accepts four values:
BASIC: Displays the minimum information in the plan—the operation ID, the operation name and its option.
TYPICAL: This is the default. Displays the most relevant information in the plan (operation id, name and option, #rows, #bytes and optimizer cost). Pruning, parallel and predicate information are only displayed when applicable. Excludes only PROJECTION, ALIAS and REMOTE SQL information (see below).
SERIAL: Like TYPICAL except that the parallel information is not displayed, even if the plan executes in parallel.
ALL: Maximum user level. Includes information displayed with the TYPICAL level with additional information (PROJECTION, ALIAS and information about REMOTE SQL if the operation is distributed).
For finer control on the display output, the following keywords can be added to the above three standard format options to customize their default behavior. Each keyword either represents a logical group of plan table columns (such as PARTITION) or logical additions to the base plan table output (such as PREDICATE).

     
Format keywords must be separated by either a comma or a space:
ROWS - if relevant, shows the number of rows estimated by the optimizer
BYTES - if relevant, shows the number of bytes estimated by the optimizer
COST - if relevant, shows optimizer cost information
PARTITION - if relevant, shows partition pruning information
PARALLEL - if relevant, shows PX information (distribution method and table queue information)
PREDICATE - if relevant, shows the predicate section
PROJECTION -if relevant, shows the projection section
ALIAS - if relevant, shows the "Query Block Name / Object Alias" section
REMOTE - if relevant, shows the information for distributed query (for example, remote from serial distribution and remote SQL)
NOTE - if relevant, shows the note section of the explain plan
IOSTATS - assuming that basic plan statistics are collected when SQL statements are executed (either by using the gather_plan_statistics hint or by setting the parameter statistics_level to ALL), this format shows IO statistics for ALL (or only for the LAST as shown below) executions of the cursor.
MEMSTATS - Assuming that PGA memory management is enabled (that is, pga_aggregate_target parameter is set to a non 0 value), this format allows to display memory management statistics (for example, execution mode of the operator, how much memory was used, number of bytes spilled to disk, and so on). These statistics only apply to memory intensive operations like hash-joins, sort or some bitmap operators.
ALLSTATS - A shortcut for 'IOSTATS MEMSTATS'
LAST - By default, plan statistics are shown for all executions of the cursor. The keyword LAST can be specified to see only the statistics for the last execution.
The following two formats are deprecated but supported for backward compatibility:

RUNSTATS_TOT - Same as IOSTATS, that is, displays IO statistics for all executions of the specified cursor.
RUNSTATS_LAST - Same as IOSTATS LAST, that is, displays the runtime statistics for the last execution of the cursor
Format keywords can be prefixed by the sign '-' to exclude the specified information. For example, '-PROJECTION' excludes projection information.


Usage Notes

To use the DISPLAY_CURSOR functionality, the calling user must have SELECT privilege on the fixed views V$SQL_PLAN_STATISTICS_ALL, V$SQL and V$SQL_PLAN, otherwise it shows an appropriate error message.

Here are some ways you might use variations on the format parameter:

Use 'ALL -PROJECTION -NOTE' to display everything except the projection and note sections.

Use 'TYPICAL PROJECTION' to display using the typical format with the additional projection section (which is normally excluded under the typical format). Since typical is default, using simply 'PROJECTION' is equivalent.

Use '-BYTES -COST -PREDICATE' to display using the typical format but excluding optimizer cost and byte estimates as well as the predicate section.

Use 'BASIC ROWS' to display basic information with the additional number of rows estimated by the optimizer.

Examples

To display the execution plan of the last SQL statement executed by the current session:

SELECT * FROM table (
   DBMS_XPLAN.DISPLAY_CURSOR);
To display the execution plan of all children associated with the SQL ID 'atfwcg8anrykp':

SELECT * FROM table (
   DBMS_XPLAN.DISPLAY_CURSOR('atfwcg8anrykp'));
To display runtime statistics for the cursor included in the preceding statement:

SELECT * FROM table (
   DBMS_XPLAN.DISPLAY_CURSOR('atfwcg8anrykp', NULL, 'ALLSTATS LAST');
