CREATE OR REPLACE PACKAGE COMMON.utils
AS
    /******************************************************************************
     NAME:        amsadmin.ams_api
     PURPOSE:    Provides procedures used by AMS API

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

    --=============================================================================
    --
    --      PUBLIC PROCEDURES AND FUNCTIONS
    --
    --=========================================================================
    PROCEDURE assert( p_condition                   IN BOOLEAN,
                      p_message                     IN VARCHAR2 );

    PROCEDURE set_system_config (   p_section       IN system_config.section%TYPE,
                                    p_name          IN system_config.name%TYPE,
                                    p_data          IN system_config.data%TYPE,
                                    p_description   IN system_config.description%TYPE DEFAULT NULL,
                                    p_idoperator    IN system_config.idoperatorcreated%TYPE DEFAULT NULL );

    FUNCTION get_system_config (  p_section        IN system_config.section%TYPE,
                                  p_name           IN system_config.name%TYPE,
                                  p_default_value  IN system_config.data%TYPE DEFAULT NULL )
      RETURN system_config.data%TYPE;

    FUNCTION get_system_config_num (   p_section         IN system_config.section%TYPE,
                                       p_name            IN system_config.name%TYPE,
                                       p_default_value   IN NUMBER DEFAULT NULL )
      RETURN NUMBER;

    FUNCTION is_numeric ( p_string IN VARCHAR2)
    RETURN BOOLEAN;

    FUNCTION is_Number ( p_string IN VARCHAR2)
    RETURN PLS_INTEGER;

   FUNCTION clob_replace (p_clob IN CLOB, p_what IN VARCHAR2, p_with IN CLOB)
      RETURN CLOB;

   PROCEDURE delay_till_condition_true (  p_check_condition          IN VARCHAR2,
                                          p_seconds_to_wait          IN PLS_INTEGER DEFAULT 300,
                                          p_max_number_of_iterations IN PLS_INTEGER DEFAULT 30,
                                          p_raise_error_on_expiry    IN BOOLEAN DEFAULT TRUE,
                                          p_force                    IN PLS_INTEGER DEFAULT 0);

   PROCEDURE set_dynSampling_fix_control ( p_process_name   IN VARCHAR2,
                                           p_request_on_off IN NUMBER);

   PROCEDURE configue_dynSampl_fix_control ( p_process_name          IN VARCHAR2,
                                             p_fix_control_on_off    IN NUMBER DEFAULT utils_types.c_dynSampling_fix_control_off,
                                             p_idoperator            IN VARCHAR2 DEFAULT USER );
END utils;
/