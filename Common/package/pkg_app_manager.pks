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


   --=============================================================================
   --
   --      PUBLIC PROCEDURES AND FUNCTIONS
   --
   --=============================================================================
   FUNCTION get_package_name
      RETURN VARCHAR2;

   FUNCTION get_id_trace_summary
      RETURN VARCHAR2;

   --
   --    PROCEDURE set_id_trace_summary (p_id_trace_summary   IN trace_summary.id_trace_summary%TYPE);
   --
   --    FUNCTION get_trace_enabled
   --    RETURN BOOLEAN;
   --
   --    PROCEDURE set_trace_enabled (p_trace_enabled   IN BOOLEAN);
   --
   --    FUNCTION get_trace_counter
   --    RETURN PLS_INTEGER;
   --
   --    PROCEDURE set_trace_counter (p_trace_counter   IN PLS_INTEGER);
   --
   --    FUNCTION get_trace_level
   --    RETURN PLS_INTEGER;
   --
   --    PROCEDURE set_trace_level (p_trace_level   IN PLS_INTEGER);

   PROCEDURE p_configure_procedure (p_owner                 IN     trace_config.owner%TYPE,
                                    p_package_name          IN     trace_config.package_name%TYPE DEFAULT NULL,
                                    p_procedure_name        IN     trace_config.procedure_name%TYPE,
                                    p_initial_trace_level   IN     trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_disabled,
                                    po_id_trace_config         OUT trace_config.id_trace_config%TYPE);

   PROCEDURE p_switch_on_trace (p_owner            IN trace_config.owner%TYPE DEFAULT NULL,
                                p_package_name     IN trace_config.package_name%TYPE DEFAULT NULL,
                                p_procedure_name   IN trace_config.procedure_name%TYPE,
                                p_trace_level      IN trace_config.trace_level%TYPE DEFAULT NULL);

   --================================================================================
   PROCEDURE p_switch_off_trace (p_owner            IN trace_config.owner%TYPE DEFAULT NULL,
                                 p_package_name     IN trace_config.package_name%TYPE,
                                 p_procedure_name   IN trace_config.procedure_name%TYPE);

   --================================================================================
   PROCEDURE p_initialise_trace;

   --================================================================================
   PROCEDURE p_trace_start (    p_client_id            IN VARCHAR2 DEFAULT NULL,
                                p_owner                IN trace_config.owner%TYPE DEFAULT NULL,
                                p_package_name         IN trace_config.package_name%TYPE,
                                p_procedure_name       IN trace_config.procedure_name%TYPE,
                                p_force                IN BOOLEAN DEFAULT FALSE
                                );

   --================================================================================
   PROCEDURE p_trace_end;

   PROCEDURE p_trace_anon_block_start (p_trace_level IN PLS_INTEGER DEFAULT 5);

   --=============================================================================
   --................
   PROCEDURE p_trace (p_module    IN trace_log.module%TYPE DEFAULT NULL,
                      p_context   IN trace_log.context%TYPE DEFAULT pkg_app_manager_state.c_context_default,
                      p_level     IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5,
                      p_name      IN trace_log.name%TYPE DEFAULT NULL);

   --=============================================================================
   --..............
   PROCEDURE p_trace (p_module    IN trace_log.module%TYPE DEFAULT NULL,
                      p_context   IN trace_log.context%TYPE DEFAULT pkg_app_manager_state.c_context_default,
                      p_level     IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5,
                      p_name      IN trace_log.name%TYPE DEFAULT NULL,
                      p_text      IN VARCHAR2);

   --=============================================================================
   --..............
   PROCEDURE p_trace (p_module    IN trace_log.module%TYPE DEFAULT NULL,
                      p_context   IN trace_log.context%TYPE DEFAULT pkg_app_manager_state.c_context_default,
                      p_level     IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5,
                      p_name      IN trace_log.name%TYPE DEFAULT NULL,
                      p_text      IN NUMBER);

   --=============================================================================
   --..............
   PROCEDURE p_trace (p_module    IN trace_log.module%TYPE DEFAULT NULL,
                      p_context   IN trace_log.context%TYPE DEFAULT pkg_app_manager_state.c_context_default,
                      p_level     IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5,
                      p_name      IN trace_log.name%TYPE DEFAULT NULL,
                      p_text      IN DATE);

   --================================================================================
   PROCEDURE p_trace (p_module    IN trace_log.module%TYPE DEFAULT NULL,
                      p_context   IN trace_log.context%TYPE DEFAULT pkg_app_manager_state.c_context_default,
                      p_level     IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5,
                      p_name      IN trace_log.name%TYPE DEFAULT NULL,
                      p_text      IN TIMESTAMP);

   --================================================================================
   PROCEDURE p_trace (p_module    IN trace_log.module%TYPE DEFAULT NULL,
                      p_context   IN trace_log.context%TYPE DEFAULT pkg_app_manager_state.c_context_default,
                      p_level     IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5,
                      p_name      IN trace_log.name%TYPE DEFAULT NULL,
                      p_text      IN BOOLEAN);

   --================================================================================
   PROCEDURE p_trace (p_module    IN trace_log.module%TYPE DEFAULT NULL,
                      p_context   IN trace_log.context%TYPE DEFAULT pkg_app_manager_state.c_context_default,
                      p_level     IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5,
                      p_name      IN trace_log.name%TYPE DEFAULT NULL,
                      p_text      IN CLOB);

   --================================================================================
   PROCEDURE p_trace (p_module    IN trace_log.module%TYPE DEFAULT NULL,
                      p_context   IN trace_log.context%TYPE DEFAULT pkg_app_manager_state.c_context_default,
                      p_level     IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5,
                      p_name      IN trace_log.name%TYPE DEFAULT NULL,
                      p_text      IN DBMS_UTILITY.name_array);


   --================================================================================
   PROCEDURE p_trace (p_module    IN trace_log.module%TYPE DEFAULT NULL,
                      p_context   IN trace_log.context%TYPE DEFAULT pkg_app_manager_state.c_context_default,
                      p_level     IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5,
                      p_name      IN trace_log.name%TYPE DEFAULT NULL,
                      p_text      IN DBMS_UTILITY.number_array);

   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN VARCHAR2);

   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN NUMBER);

   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN DATE);
                           

   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN TIMESTAMP);
                                    
   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN BOOLEAN);


END pkg_app_manager;
/