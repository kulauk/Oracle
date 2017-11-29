CREATE OR REPLACE PACKAGE common.pkg_app_manager_state
AS
    /******************************************************************************
     NAME:        common.pkg_app_manager_state
     PURPOSE:    Provides state for common.pkg_app_manager

     REVISIONS:
     Ver        Date        Author           Description
     ---------  ----------  ---------------  ------------------------------------
     1.0       18/04/2016  Duncan Lucas     First Draft
    ******************************************************************************/
    --=============================================================================
    --
    --      Declaration section
    --
    -- (Place your private package level variables and declarations here )
    --=============================================================================

    ----------------------------------------------------------
    -- Package name constants
    g_PkgName_pkg_app_mgr        CONSTANT VARCHAR2 (30) := 'PKG_APP_MANAGER';


    --trace_enabled        BOOLEAN;
    c_context_default    CONSTANT VARCHAR2(9)  := 'LEVEL1';
    c_context_parameter  CONSTANT VARCHAR2(9)  := 'PARAMETER';

    c_trace_disabled     CONSTANT PLS_INTEGER := 0;
    c_trace_level_1      CONSTANT PLS_INTEGER := 1;
    c_trace_level_2      CONSTANT PLS_INTEGER := 2;
    c_trace_level_3      CONSTANT PLS_INTEGER := 3;
    c_trace_level_4      CONSTANT PLS_INTEGER := 4;
    c_trace_level_5      CONSTANT PLS_INTEGER := 5;
        
    c_external_client_call       CONSTANT VARCHAR2(30) := 'ANONYMOUS BLOCK';
    ----------------------------------------------------------
    g_id_trace_summary           trace_summary.id_trace_summary%TYPE;
    g_trace_enabled              BOOLEAN;
    g_trace_counter              PLS_INTEGER := 0;
    g_trace_level                PLS_INTEGER := 0;

    c_proc_name_anon_block       CONSTANT VARCHAR2(10) := 'ANON_BLOCK';
    e_procedure_not_configured   EXCEPTION;
    e_missing_trace_config       EXCEPTION;
    e_duplicate_trace_config     EXCEPTION;
    --==========================================================================
END pkg_app_manager_state;
/
