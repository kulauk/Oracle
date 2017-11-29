CREATE OR REPLACE PACKAGE BODY common.utils
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
    --      PRIVATE PROCEDURES AND FUNCTIONS
    --
    --=============================================================================
    --==========================================================================
    -- Function to return the package name (to avoid storing state in the package body)
    -- .......
    FUNCTION get_package_name
    RETURN VARCHAR2
    IS
    BEGIN
        RETURN 'UTILS';
    END get_package_name;

    --=============================================================================
    -- End of PRIVATE PROCEDURES AND FUNCTIONS
    --=============================================================================


    --=============================================================================
    --
    --      PUBLIC PROCEDURES AND FUNCTIONS
    --
    --=========================================================================
    --=============================================================================
    -- Procedure to raise an error if the assertion fails.
    -- Uses: Best utilised to validate input parameter conditions for procedures
    --.............................................................................
    PROCEDURE assert( p_condition                   IN BOOLEAN,
                      p_message                     IN VARCHAR2 )
    IS
    BEGIN

        IF NOT NVL( p_condition, FALSE )
        THEN
            RAISE_APPLICATION_ERROR( -20001, 'ASSERTFAIL: ' || SUBSTR( NVL( p_message, 'No Message' ), 1, 500 ) );

        END IF;
    END assert;
    --=============================================================================
    -- Procedure to set system config value
    --.............................................................................
    PROCEDURE set_system_config (   p_section       IN system_config.section%TYPE,
                                    p_name          IN system_config.name%TYPE,
                                    p_data          IN system_config.data%TYPE,
                                    p_description   IN system_config.description%TYPE DEFAULT NULL,
                                    p_idoperator    IN system_config.idoperatorcreated%TYPE DEFAULT NULL )
    IS
    BEGIN
        MERGE INTO system_config a
              USING (   SELECT   p_section AS section,
                                 p_name AS name,
                                 p_data AS data,
                                 p_description AS description,
                                 NVL(p_idoperator, USER) AS idoperatorcreated,
                                 SYSDATE AS created_date,
                                 NVL(p_idoperator, USER) AS idoperatormodified,
                                 SYSDATE AS modified_date
                          FROM DUAL) b
                  ON (a.name = b.name AND a.section = b.section)
        WHEN NOT MATCHED
        THEN
            INSERT	  ( section,
                        name,
                        data,
                        description,
                        idoperatorcreated,
                        created_date,
                        idoperatormodified,
                        modified_date)
                 VALUES (   b.section,
                            b.name,
                            b.data,
                            b.description,
                            b.idoperatorcreated,
                            b.created_date,
                            b.idoperatormodified,
                            b.modified_date)
        WHEN MATCHED
        THEN
            UPDATE SET  a.data = b.data,
                        a.description = NVL(b.description, a.description),
                        a.idoperatormodified = b.idoperatormodified,
                        a.modified_date = b.modified_date;

        COMMIT;

    END set_system_config;
    --=============================================================================
    -- Get system config variables
    --..........................
    FUNCTION get_system_config (  p_section        IN system_config.section%TYPE,
                                  p_name           IN system_config.name%TYPE,
                                  p_default_value  IN system_config.data%TYPE DEFAULT NULL )
      RETURN system_config.data%TYPE
    IS
      l_data                system_config.data%TYPE;
      g_procfunc_name       VARCHAR2 (50);
    BEGIN
        g_procfunc_name := 'GET_SYSTEM_CONFIG';

        BEGIN
            SELECT data
            INTO l_data
            FROM system_config
            WHERE section = p_section
            AND name = p_name;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- if we dont have any data then return the default value
            -- if none was provided null will be returned
            l_data := p_default_value;
        WHEN OTHERS THEN
            -- if we have duplicate rows then raise an alert dont reraise just return null
            common.error_utils.log_no_raise (
                            p_package_name     => get_package_name,
                            p_procedure_name   => g_procfunc_name,
                            p_when_error       => 'OTHERS',
                            p_error_message    => SQLERRM,
                            p_error_nvp_tbl    => common.error_utils.init_error_nvp(    p_name1    => 'p_section',
                                                                                        p_value1   => p_section,
                                                                                        p_name2    => 'p_name',
                                                                                        p_value2   => p_name,
                                                                                        p_name3    => 'p_default_value',
                                                                                        p_value3   => p_default_value
                                                                                        ),
                            p_error_level      => 5);

            -- but pass back the default value so that the calling client will get the default (if provided)
            -- and not just a null
            l_data := p_default_value;
        END;

        RETURN l_data;
    END get_system_config;
    --=============================================================================
    -- Get system config variables
    --..........................
    FUNCTION get_system_config_num (   p_section         IN system_config.section%TYPE,
                                       p_name            IN system_config.name%TYPE,
                                       p_default_value   IN NUMBER DEFAULT NULL )
      RETURN NUMBER
    IS
        l_return          NUMBER;
        g_procfunc_name   VARCHAR2 (50);
    BEGIN
        g_procfunc_name := 'GET_SYSTEM_CONFIG_NUM';

        BEGIN
            l_return := TO_NUMBER( get_system_config ( p_section => p_section, p_name => p_name, p_default_value => p_default_value));
        EXCEPTION
        WHEN OTHERS THEN
            -- if we have any error then raise an alert dont reraise just return null
            common.error_utils.log_no_raise (
                            p_package_name     => get_package_name,
                            p_procedure_name   => g_procfunc_name,
                            p_when_error       => 'OTHERS',
                            p_error_message    => SQLERRM,
                            p_error_nvp_tbl    => common.error_utils.init_error_nvp(    p_name1    => 'p_section',
                                                                                        p_value1   => p_section,
                                                                                        p_name2    => 'p_name',
                                                                                        p_value2   => p_name,
                                                                                        p_name3    => 'p_default_value',
                                                                                        p_value3   => p_default_value),
                            p_error_level      => 5);

            -- but pass back the default value so that the calling client will get the default (if provided)
            -- and not just a null
            l_return := p_default_value;
        END;

        RETURN l_return;
    END get_system_config_num;
    --=============================================================================
    -- Test for numeric value using pure PL/SQL for use in PL/SQL only
    --..........................

    FUNCTION is_numeric ( p_string IN VARCHAR2)
    RETURN BOOLEAN
    IS
        l_is_numeric    NUMBER;
    BEGIN
        l_is_numeric := TO_NUMBER(p_string);

        RETURN TRUE;
    EXCEPTION
    WHEN VALUE_ERROR THEN
        RETURN FALSE;
    END is_numeric;
    --=============================================================================
    -- Test for numeric value using pure PL/SQL for use in SQL
    --..........................

    FUNCTION is_Number ( p_string IN VARCHAR2)
    RETURN PLS_INTEGER
    IS
        l_is_numeric    NUMBER;
    BEGIN
        l_is_numeric := TO_NUMBER(p_string);

        RETURN 1;
    EXCEPTION
    WHEN VALUE_ERROR THEN
        RETURN 0;
    END is_Number;
   --==========================================================================
   -- replaces clob with text > 32K ... for data < 32K you can just use normal REPLACE
   --...........................
   FUNCTION clob_replace (p_clob IN CLOB, p_what IN VARCHAR2, p_with IN CLOB)
      RETURN CLOB
   IS
      l_ret_clob       CLOB;                                                    -- temporary CLOB to be returned
      l_next_idx       NUMBER;                                                  -- used to traverse the source CLOB, captures the next instance of the match string
      l_search_begin   NUMBER DEFAULT 1;                                        -- used to traverse the source CLOB, indicates the starting point of the next search
      l_parse_begin    NUMBER DEFAULT 1;                                        -- used to copy date from the source CLOB, indicates the beginning of the copy window
      l_parse_end      NUMBER;                                                  -- used to copy date from the source CLOB, indicates the beginning of the end window
   BEGIN
      common.pkg_app_manager.p_trace (p_level => 5, p_name => 'START:', p_text => 'clob_replace');
      common.pkg_app_manager.p_trace (p_level => 8, p_name => 'p_clob:', p_text => p_clob);
      common.pkg_app_manager.p_trace (p_level => 8, p_name => 'p_what:', p_text => p_what);
      common.pkg_app_manager.p_trace (p_level => 8, p_name => 'p_with:', p_text => p_with);

      -- Create a temporary CLOB to be returned
      DBMS_LOB.createtemporary (l_ret_clob, TRUE);

      LOOP
         l_next_idx :=
            DBMS_LOB.INSTR (p_clob,
                            p_what,
                            l_search_begin,
                            1);

         common.pkg_app_manager.p_trace (p_level => 5, p_name => 'LOOP: l_next_idx', p_text => l_next_idx);

         -- Exit once we do not find another occurance of the match string
         EXIT WHEN l_next_idx = 0;

         -- Special handling if we find a match at the first character of the source string
         IF l_next_idx = 1
         THEN
            l_parse_begin := LENGTH (p_what) + 1;

            IF LENGTH (p_with) > 0
            THEN
               DBMS_LOB.append (l_ret_clob, p_with);
            END IF;
         ELSE
            -- Copy source data up to the match
            l_parse_end := l_next_idx - 1;

            common.pkg_app_manager.p_trace (p_level => 8, p_name => 'LOOP: l_parse_end', p_text => l_parse_end);

            DBMS_LOB.COPY (l_ret_clob,
                           p_clob,
                           (l_parse_end - l_parse_begin + 1),
                           DBMS_LOB.getlength (l_ret_clob) + 1,
                           l_parse_begin);

            -- Replace the match string
            IF LENGTH (p_with) > 0
            THEN
               DBMS_LOB.append (l_ret_clob, p_with);
            END IF;

            -- Move the beginning of the next parse window past our match string
            l_parse_begin := l_parse_end + LENGTH (p_what) + 1;

            common.pkg_app_manager.p_trace (p_level => 8, p_name => 'LOOP: l_parse_begin', p_text => l_parse_begin);
         END IF;

         -- Move the beginning of the search window past our match string
         l_search_begin := l_next_idx + LENGTH (p_what);

         common.pkg_app_manager.p_trace (p_level => 8, p_name => 'LOOP: l_search_begin', p_text => l_search_begin);

         common.pkg_app_manager.p_trace (p_level => 8, p_name => 'LOOP: l_ret_clob:', p_text => l_ret_clob);
      END LOOP;


      -- Special handling for the trailing final characters of the source CLOB
      IF DBMS_LOB.getlength (p_clob) > (l_parse_end + LENGTH (p_what))
      THEN
         l_parse_begin := l_parse_end + LENGTH (p_what) + 1;
         l_parse_end := DBMS_LOB.getlength (p_clob);
         common.pkg_app_manager.p_trace (p_level => 8, p_name => 'Final l_parse_begin', p_text => l_parse_begin);
         common.pkg_app_manager.p_trace (p_level => 8, p_name => 'Final l_parse_end', p_text => l_parse_end);
         DBMS_LOB.COPY (l_ret_clob,
                        p_clob,
                        (l_parse_end - l_parse_begin + 1),
                        DBMS_LOB.getlength (l_ret_clob) + 1,
                        l_parse_begin);
      END IF;

      common.pkg_app_manager.p_trace (p_level => 8, p_name => 'Final l_ret_clob:', p_text => l_ret_clob);

      RETURN l_ret_clob;
   END clob_replace;
   --==========================================================================
   -- Sleeps until the condition is true
   --........
   PROCEDURE delay_till_condition_true (  p_check_condition          IN VARCHAR2,
                                          p_seconds_to_wait          IN PLS_INTEGER DEFAULT 300,
                                          p_max_number_of_iterations IN PLS_INTEGER DEFAULT 30,
                                          p_raise_error_on_expiry    IN BOOLEAN DEFAULT TRUE,
                                          p_force                    IN PLS_INTEGER DEFAULT 0)
   IS
      l_number_of_iterations           PLS_INTEGER := 0;
      e_max_time_exceeded              EXCEPTION;
      has_dependent_process_finished    NUMBER;
   BEGIN
   
      -- if force flag not set then check for condition true
      IF p_force = 0 THEN
         -- check if the report has missing data if so then we need to wait for copos
         -- also check we haven't reached the max number of iterations if we have raise an error
         LOOP
         
            EXECUTE IMMEDIATE 'SELECT ' || p_check_condition || ' FROM DUAL'
                      INTO has_dependent_process_finished;
                      
            EXIT WHEN has_dependent_process_finished = 1;
                      
            common.pkg_app_manager.p_trace (p_level => 5, p_name => 'Dependency condition FALSE:', p_text => '..sleeping for ' || p_seconds_to_wait || ' seconds');
            DBMS_LOCK.sleep (p_seconds_to_wait);

            -- increment counter
            l_number_of_iterations := l_number_of_iterations + 1;

            -- check max time not exceeded
            -- if raise error on expirty set to true then raise an error
            IF l_number_of_iterations >= p_max_number_of_iterations AND p_raise_error_on_expiry THEN
               RAISE e_max_time_exceeded;
            ELSIF l_number_of_iterations >= p_max_number_of_iterations AND NOT p_raise_error_on_expiry THEN
               -- if max iterations exceeded but raise error is false then just exit
               EXIT;
            ELSE
               -- else iterations not yet exceeded so continue
               NULL;
            END IF;
         END LOOP;
      ELSE
         -- if force flag set then do bother waiting just run... ie do nothing
         NULL;
      END IF;
   END delay_till_condition_true;
   --==========================================================================
   -- procedure to fix Oracle Bug: 14059307  at the session level
   --
   -- The bug occurs with 11G versions from 11.2.0.2 through to 11.2.0.4 (12c unknown)
   -- It affects large partitioned tables like TRANSACTIONS.  It imposes dynamic sampling
   -- to be used even when the stats are up to date which can cause changes to the plan resulting
   -- in poor performance.
   -- In a lot of cases dynamic sampling is useful and necessary to improve performance but in certain
   -- cases involving large partitioned tables it can cause bad cardinality estimates and bad plans leading
   -- to extremely bad performance.  Therefore this procedure can be used to control whether
   -- to use this feature or not.
   --
   -- This procedure can be called at the start of any procedure to do an ALTER SESSION command to
   -- switch off this optimizer feature that is causing the issue, based on a setting in SYSTEM_CONFIG table
   --
   -- IMPORTANT:
   -- There are 2 aspects:
   --    1. You can use the procedure SET_DYNSAMPLING_FIX_CONTROL (below) to REQUEST to alter the session and set fix control off
   --    however this will only be done if the SYSTEM_CONFIG value is set to allow this, ie dynamic sampling fix control = off
   --
   --    if however the SYSTEM_CONFIG value is NOT set to allow this, ie dynamic sampling fix control = on
   --    then requesting fix control to be off will not have any affect and in fact the session will be altered to set it ON.
   --
   --    2. You can also use the procedure SET_DYNSAMPLING_FIX_CONTROL (below) to REQUEST to alter the session and set fix control on
   --     in this case the alter session will ALWAYS be executed so that fix contrl is switched on.  This is so that if earlier in the session
   --     you have switched it off then you will always be allowed to switch it back on.
   --
   --    So your client procedure should make one call at the start of the session to set fix control OFF and then another call to set fix
   --    control back on again.

   --    NOTE: If no entry is found in SYSTEM_CONFIG then it will assume the default which is to alter the session to set the fix control ON.
   --
   --
   --........
   PROCEDURE set_dynSampling_fix_control ( p_process_name   IN VARCHAR2,
                                           p_request_on_off IN NUMBER)
   IS
      l_DynSampl_fix_control  NUMBER(1);

   BEGIN
      -- check the value of the parameter p_request_on_off.
      IF p_request_on_off = utils_types.c_dynSampling_fix_control_off THEN
         -- If this is a request to switch off need to check SYSTEM_CONFIG setting to see if we are allowed to switch off

         -- get the value of the process_name dynamic sampling fix from system config
         -- and if no entry exists then default to ON
         l_DynSampl_fix_control := get_system_config_num (  p_section         => utils_types.c_SysConfSec_DynSamp,
                                                            p_name            => p_process_name,
                                                            p_default_value   => utils_types.c_dynSampling_fix_control_on );

         -- check the value of the SYSTEM_CONFIG setting
         IF l_DynSampl_fix_control = utils_types.c_dynSampling_fix_control_off THEN

            -- if sys conf setting is OFF then set the session to fix the dynamic sampling bug (ie fix control off)
            EXECUTE IMMEDIATE 'ALTER SESSION SET "_fix_control"=''7452863:OFF''';
            common.pkg_app_manager.p_trace (p_level => 1, p_name => 'SESSION ALTERED: Dynamic sampling fix control:', p_text => '..IS SET OFF (ie bug fix is applied)');

         ELSE
            -- if sys conf fix setting is ON then dont do anything.  This means that although there was a request to switch fix control OFF
            -- the system config setting does not allow it (ie the system_config setting is set to ON)
            common.pkg_app_manager.p_trace (p_level => 1, p_name => 'SESSION NOT ALTERED: Dynamic sampling fix control:', p_text => '..IS UNCHANGED');

         END IF;
      ELSE
         -- If this is a request to switch ON then no need to check SYSTEM_CONFIG setting since we always allow the fix control back on
         -- under the assumption it was set off earlier in the process.
         -- set the fix control on
         EXECUTE IMMEDIATE 'ALTER SESSION SET "_fix_control"=''7452863:ON''';
         common.pkg_app_manager.p_trace (p_level => 1, p_name => 'SESSION ALTERED: Dynamic sampling fix control:', p_text => '..IS SET ON (ie bug fix is not applied)');

      END IF;

   END set_dynSampling_fix_control;
   --==========================================================================
   -- procedure to configure the dynamic sampling system config to fix Oracle Bug: 14059307
   -- Use 1 to switch on (ie do not use the bug fix) or 0 to switch off (the defaul ie use bug fix).
   --........
   PROCEDURE configue_dynSampl_fix_control ( p_process_name          IN VARCHAR2,
                                             p_fix_control_on_off    IN NUMBER DEFAULT utils_types.c_dynSampling_fix_control_off,
                                             p_idoperator            IN VARCHAR2 DEFAULT USER )
   IS
   BEGIN
      -- call system config procedure to add entry to system_config table
      -- This is requried in order to set the fix from your calling procedure using the same process name
      common.utils.set_system_config ( p_section      => utils_types.c_SysConfSec_DynSamp,
                                       p_name         => p_process_name,
                                       p_data         => p_fix_control_on_off,
                                       p_description  => 'Use the bug fix for dynamic sampling bug for the process described by the name (1=bug fix not used, 0=bug fix used)',
                                       p_idoperator   => p_idoperator );


   END configue_dynSampl_fix_control;
    --=====================================================
    -- END OF Public procedures
    --=====================================================

--------------------
--................
BEGIN
    NULL;
END utils;
/