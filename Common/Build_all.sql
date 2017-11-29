--SET TIME ON
--SET TIMING ON
SET PAGES 5000
SET LINES 400
SET VERIFY OFF

DEFINE enter_tblsp_s=SBDATAS
DEFINE enter_tblsp_m=SBDATAM
DEFINE enter_indx_tblsp_s=SBINDXS
DEFINE enter_indx_tblsp_m=SBINDXM
DEFINE enter_tblsp_LOB=SBDATALOBL

--DEFINE enter_tblsp_s=&&Enter_Tablsp_S
--DEFINE enter_tblsp_m=&&Enter_Tablsp_M
--DEFINE enter_indx_tblsp_s=&&Enter_Index_Tablsp_S
--DEFINE enter_indx_tblsp_m=&&Enter_Index_Tablsp_M
--DEFINE enter_tblsp_LOB=&&Enter_LOB_Tablsp_L

--SPOOL build_log.txt

--@.\create_common_user.sql

@.\sequence\build.sql
@.\table\build.sql
@.\type\build.sql
@.\package\build.sql
@.\packageBody\build.sql
@.\Scheduler\build.sql
@.\grants\build.sql
@.\Synonym\build.sql

--@.\trigger\build.sql
--@.\constraint\build.sql




--SPOOL OFF

PROMPT Hit Enter to continue..
PAUSE
EXIT
