CREATE OR REPLACE PACKAGE common.pkg_app_manager
AS
   /******************************************************************************
      NAME:       pkg_app_manager
      PURPOSE:

      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        15/01/2013  D Lucas          Created this package.
   ******************************************************************************/
   --=============================================================================
   --
   --      Declaration section
   --
   -- (Place your package level variables and declarations here )
   --=============================================================================

   --trace_enabled        BOOLEAN;
   c_context_default    CONSTANT VARCHAR2(9)  := 'LEVEL1';
   c_context_parameter  CONSTANT VARCHAR2(9)  := 'PARAMETER';

   c_trace_disabled     CONSTANT PLS_INTEGER := 0;
   c_trace_level_1      CONSTANT PLS_INTEGER := 1;
   c_trace_level_2      CONSTANT PLS_INTEGER := 2;
   c_trace_level_3      CONSTANT PLS_INTEGER := 3;
   c_trace_level_4      CONSTANT PLS_INTEGER := 4;
   c_trace_level_5      CONSTANT PLS_INTEGER := 5;

   --=============================================================================
   --
   --      PUBLIC PROCEDURES AND FUNCTIONS
   --
   --=============================================================================


--   FUNCTION get_owner_who_called_me
--    RETURN VARCHAR2;

    PROCEDURE p_configure_procedure (   p_owner                 IN  trace_config.owner%TYPE DEFAULT NULL,
                                        p_package_name          IN  trace_config.package_name%TYPE DEFAULT NULL,
                                        p_procedure_name        IN  trace_config.procedure_name%TYPE,
                                        p_initial_trace_level   IN  trace_config.trace_level%TYPE DEFAULT c_trace_disabled,
                                        po_id_trace_config          OUT trace_config.id_trace_config%TYPE);

   PROCEDURE p_switch_on_trace (    p_owner             IN  trace_config.owner%TYPE DEFAULT NULL,
                                    p_package_name      IN  trace_config.package_name%TYPE DEFAULT NULL,
                                    p_procedure_name    IN  trace_config.procedure_name%TYPE,
                                    p_trace_level       IN  trace_config.trace_level%TYPE DEFAULT NULL);

   --================================================================================
   PROCEDURE p_switch_off_trace (   p_owner             IN  trace_config.owner%TYPE DEFAULT NULL,
                                   p_package_name      IN  trace_config.package_name%TYPE,
                                   p_procedure_name    IN  trace_config.procedure_name%TYPE
                                   );

    --=============================================================================
    --................
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL );

    --=============================================================================
    --..............
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN VARCHAR2);
    --=============================================================================
    --..............
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN NUMBER);
    --=============================================================================
    --..............
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN DATE);
   --================================================================================
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN timestamp);
   --================================================================================
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN BOOLEAN);
    --================================================================================
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN CLOB);
   --================================================================================
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN dbms_utility.name_array);


   --================================================================================
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN dbms_utility.number_array);

   --================================================================================
   PROCEDURE p_initialise_trace;

   --================================================================================
   PROCEDURE p_trace_start (    p_client_id            IN VARCHAR2 DEFAULT NULL,
                                p_owner                IN trace_config.owner%TYPE DEFAULT NULL,
                                p_package_name         IN trace_config.package_name%TYPE,
                                p_procedure_name       IN trace_config.procedure_name%TYPE
                                );

   --================================================================================
   PROCEDURE p_trace_end;

   --================================================================================
    PROCEDURE p_initialise_param_trace( p_level                 IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5,
                                        pio_tab_parameters      IN OUT   tab_app_mgr_parameter );


   --================================================================================
    PROCEDURE p_add_param_trace(    pio_tab_parameters  IN OUT   tab_app_mgr_parameter,
                                    p_level             IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5,
                                    p_parameter_name    IN  user_arguments.argument_name%TYPE,
                                    p_parameter_value   IN  VARCHAR2);

   --================================================================================
    PROCEDURE p_add_param_trace(    pio_tab_parameters  IN OUT   tab_app_mgr_parameter,
                                    p_level             IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5,
                                    p_parameter_name    IN  user_arguments.argument_name%TYPE,
                                    p_parameter_value   IN  NUMBER);

    --================================================================================
    PROCEDURE p_add_param_trace(    pio_tab_parameters  IN OUT   tab_app_mgr_parameter,
                                    p_level             IN trace_config.trace_level%TYPE DEFAULT c_trace_level_5,
                                    p_parameter_name    IN  user_arguments.argument_name%TYPE,
                                    p_parameter_value   IN  DATE);

    --================================================================================
    PROCEDURE p_trace_parameters(   p_tab_parameters    IN  tab_app_mgr_parameter );


    PROCEDURE p_trace_anon_block_start ( p_trace_level IN PLS_INTEGER DEFAULT 5);

    FUNCTION get_trace_level
    RETURN PLS_INTEGER;

END pkg_app_manager;
/
