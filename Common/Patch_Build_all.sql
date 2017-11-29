SET PAGES 5000
SET LINES 400
SET VERIFY OFF

DEFINE deployment_dir=&1
DEFINE enter_tblsp_s=&&Enter_Tablsp_S
DEFINE enter_tblsp_m=&&Enter_Tablsp_M
DEFINE enter_indx_tblsp_s=&&Enter_Index_Tablsp_S
DEFINE enter_indx_tblsp_m=&&Enter_Index_Tablsp_M
DEFINE enter_tblsp_LOB=&&Enter_LOB_Tablsp_L


@&deployment_dir\sequence\build.sql
@&deployment_dir\table\build.sql
@&deployment_dir\type\build.sql
@&deployment_dir\package\build.sql
@&deployment_dir\packageBody\build.sql
@&deployment_dir\Scheduler\build.sql
@&deployment_dir\grants\build.sql
@&deployment_dir\Synonym\build.sql

PROMPT Hit Enter to continue..
PAUSE
EXIT
