CREATE OR REPLACE PACKAGE BODY pkg_error_manager
AS
   /******************************************************************************
      NAME:       Pkg_error_manager
      PURPOSE:

      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        14/01/2009  D Lucas          Created this package.
   ******************************************************************************/
   --=============================================================================
   --
   --      Declaration section
   --
   -- (Place your package level variables and declarations here )
   --=============================================================================

    --l_package_context_name  CONSTANT VARCHAR2(30) := 'PKG_ERROR_MANAGER_CTX';
    l_input_parameters      VARCHAR2(4000);

   --=============================================================================
   --
   --      PRIVATE PROCEDURES AND FUNCTIONS
   --
   --=============================================================================
   --=============================================================================
   --
   --      PUBLIC PROCEDURES AND FUNCTIONS
   --
   --=============================================================================

   --==================================================================================
   --==================================================================================
   --==================================================================================
   --==================================================================================
   --
   -- EXCEPTION HANDLING ROUTINES.
   -------------------------------

   --  There are essentially 3 types of different errors that the application could raise.
   --  These are:

   --    1.  Expected errors that you wish to recover from and continue normal running.
   --
   --        An error that occurs during normal running of the application that is an
   --        expected error and the application will continue...
   --
   --        eg the application has validated some data and has failed some
   --        validation therfore an error is raised which must be reported back to the
   --        client so that the user is informed and they can make a decision and
   --        continue executing the application. for example they enter an invalid
   --        username... so the application informs the user and they enter a new one.

   --        In this case we can choose to log or not log this error.
   --
   --    2.  Expected errors that you wish to halt the execution of the application.
   --
   --        These are errors that you explicitly raise in response to eg some failed
   --        validation but the failure is such that it should never happen and you
   --        therefore you want halt the application...log the error and inform the
   --        user with a meaningful message.
   --
   --    3.  Unexpected errors that you want to halt the application log and inform
   --        the user that a fatal error has occured.
   --
   --        An error has occured that is completely unexpected and essentially a bug
   --        so you want to stop all execution of the appliation...log this error and
   --        then provide the user with a meaningful message so they know that a
   --        serious problem has occured.
   --
   --        The cases described in 2. and 3. will log the error in an ERRORS_T table
   --        and then pass the gui an error id that points to the row containing
   --        all the error information.
   --        This id can be passed to the user so that they can inform a helpdesk and
   --        that id can be passed to the appropriate DBA.

   --  To implement the above scenarios there are a number of procedures below.
   --  There are only 2 procedures that you need to call though for the 3 cases above.
   --
   --  APPLICATION ERRORS
   ----------------------
   --
   --  To explicitly raise an application error for expected errors that you wish
   --  to either continue and recover from OR you want to stop execution then you
   --  have 2 choices:

   --    1.  Use the built in ORACLE utility RAISE_APPLICATION_ERROR (   p_error_code,
   --                                                                    p_error_message )
   --        This requires that you pass in an error code in the range -20999 to -20000.
   --        The procedures have reserved -20001 as the code to use for fatal type errors
   --        that you want to stop the application from continuing with. All other codes
   --        that you use for your application type errors must fall in this range.
   --
   --          nb  The -20001 error has been set as a package constant
   --              you can set other constants for any other errors that you need
   --              however do not use either 1 or -20001.
   --
   --    2.  Use the procedure below called p_raise_app_error.
   --        This does the same job as RAISE_APPLICATION_ERROR but it allows you to
   --        pass in error codes greater than  -20001  eg  you can pass in  1 , 2 , etc
   --        All this procedure does is convert this to a negative 20000 error
   --        So error code 3 is converted to -20003
   --
   --  To implement this use the above 2 calls wherever you need to explicitly raise
   --  an error.
   --
   -- FATAL ERRORS
   ----------------
   --
   --  All fatal errors will be raised implicitly and handled appropriately by the
   --  procedure   p_raise_fatal_or_app_error  . Therefore you must call this procedure
   --  in your top level procedure as part of a WHEN OTHERS section. This maybe in an
   -- API package or not but it must be the very top level procedure that the gui
   -- uses.  Then do NOT put any other WHEN OTHERS calls into your code but let all
   -- other procedures errors propagate up to the last top level api procedure.

   --================================================================================
   --================================================================================
   --================================================================================
   --================================================================================



   --================================================================================
   --================================================================================
   --================================================================================
   --================================================================================

   -- NEW tracing routines....using QUEST ERROR MANAGER.

   --================================================================================
   --================================================================================
   --
   -- Usage:  At the top of every API procedure call:
   --
   -- pkg_error_manager.p_initialise_trace( p_trace_level => p_debug_trace );
   --
   -- where p_debug_trace is the string of contexts you wish to trace eg:
   --
   --   "ALL, LOC"  or "ALL"  or for all levels  "ALL,LEVEL%,LOC"
   --
   -- Then sprinkle your code with calls like:
   --
   --   pkg_error_manager.p_trace(p_context_in => 'ALL', p_text_in => 'Starting...p3');
   --   pkg_error_manager.p_trace(p_context_in => 'EXCEP', p_text_in => 'error in p3');
   --
   -- Then at the end of the API procedure call:
   --
   --   pkg_error_manager.p_set_trace_off;
   --
   -- to ensure that the tracing is switched off.
   --
   -- It is unnecessary to pass the p_debug_trace (which contains your context string)
   -- to all sub procedures, since it is held in a package variable. HOWEVER to make
   -- it easier to trace sub procedures on dev then it is probably worth passing the
   -- parameter down to all sub procedures otherwise you would have to make a call to
   -- p_set_trace_on before tracing these procedures in a dev environment.
   --
   -- p_initalise_trace could be amended to delete from the debug table first if
   -- required.
   --================================================================================
   PROCEDURE p_initialise_parameter_trace( p_inputs IN  VARCHAR2 )
   IS
   BEGIN
        -- store new input parameters in gtt
        l_input_parameters := SUBSTR(p_inputs, 1, 4000);           
   END p_initialise_parameter_trace;
      
   FUNCTION f_who_called_me
      RETURN VARCHAR2
   IS
      o_owner       VARCHAR2(32767);
      o_object      VARCHAR2(32767);
      o_lineno      NUMBER(10);
      l_call_stack  LONG DEFAULT DBMS_UTILITY.format_call_stack ;
      l_line        VARCHAR2(4000);
   BEGIN
      FOR i IN 1 .. 5
      LOOP
         l_call_stack := SUBSTR(l_call_stack, INSTR(l_call_stack, CHR(10)) + 1);
      END LOOP;

      l_call_stack := SUBSTR(l_call_stack, 1, INSTR(l_call_stack, CHR(10)));


      l_line       := LTRIM(SUBSTR(l_call_stack, 1, INSTR(l_call_stack, CHR(10)) - 1));

      l_line       := LTRIM(SUBSTR(l_line, INSTR(l_line, ' ')));

      o_lineno     := TO_NUMBER(SUBSTR(l_line, 1, INSTR(l_line, ' ')));
      l_line       := LTRIM(SUBSTR(l_line, INSTR(l_line, ' ')));

      l_line       := LTRIM(SUBSTR(l_line, INSTR(l_line, ' ')));

      IF l_line LIKE 'block%'
         OR l_line LIKE 'body%'
      THEN
         l_line := LTRIM(SUBSTR(l_line, INSTR(l_line, ' ')));
      END IF;

      o_owner      := LTRIM(RTRIM(SUBSTR(l_line, 1, INSTR(l_line, '.') - 1)));
      o_object     := LTRIM(RTRIM(SUBSTR(l_line, INSTR(l_line, '.') + 1)));

      IF o_owner IS NULL
      THEN
         o_owner  := USER;
         o_object := 'ANONYMOUS BLOCK';
      END IF;

      --RETURN o_owner || '.' || o_object;
      RETURN o_object;      
   END f_who_called_me;

   --================================================================================
   -- Sets tracing on: can be used in dev to explcitly turn on tracing
   --
   --================================================================================
   PROCEDURE p_set_trace_on(p_trace IN VARCHAR2 DEFAULT NULL )
   IS
   BEGIN
      q$error_manager.clear_gcontexts;
      q$error_manager.trace_on(context_like_in => p_trace);
   END p_set_trace_on;

   --================================================================================
   --================================================================================
   -- Sets tracing of: to be used at the end of every api call and also can be
   -- used in dev to explcitly turn off tracing
   --
   --================================================================================
   PROCEDURE p_set_trace_off
   IS
   BEGIN
      q$error_manager.trace_off;
      q$error_manager.clear_gcontexts;
   END p_set_trace_off;

   --================================================================================
   --================================================================================
   -- Initialises tracingby explcitly turning on tracing and clearing down the trace
   -- table .  To be called at the top of every API procedure.
   --
   --================================================================================
   PROCEDURE p_initialise_trace(p_trace_level IN VARCHAR2 DEFAULT NULL )
   IS
   BEGIN
      IF TRIM(p_trace_level) IS NOT NULL
      THEN
         -- WARNING enabling the clear trace issues a TRUNCATE on the q$log table
         -- so be aware of this
         --q$error_manager.clear_trace;
         p_set_trace_on(p_trace => p_trace_level);
      ELSE
         p_set_trace_off;
      END IF;
   END p_initialise_trace;

   --================================================================================
   --================================================================================
   -- Makes a call to the trace routine to insert your debugging info into the
   -- q%log table with the context that you give it.
   -- Make these calls all over your code to output vital tracing info.
   --
   --================================================================================
   PROCEDURE p_trace(p_context_in  IN q$log.context%TYPE
                   , p_text_in     IN VARCHAR2)
   IS
    v_trace_clob    clob;
   BEGIN
      IF q$error_manager.trace_enabled
      THEN
        -- check the length of the trace string
        -- 3900 is used because q$error manager had to be altered down to 3900
        -- otherwise some of the text went missing from the start of the string.
        IF LENGTH(p_text_in) <= 3900 THEN
            -- just use the normal trace procedure
            q$error_manager.trace(context_in => p_context_in, text_in => p_text_in);        
        ELSE
            -- since the tracing is too large we will use the clob version to trace
            dbms_lob.createtemporary( v_trace_clob, true);
            v_trace_clob := p_text_in;
            q$error_manager.trace(context_in => p_context_in, clob_in => v_trace_clob);            
        
        END IF; 
                              
      ELSE
         -- else we won't trace
         NULL;
      END IF;
   END p_trace;
      
   --================================================================================   
   PROCEDURE p_trace_start(   p_context_in  IN q$log.context%TYPE
                            , p_text_in     IN VARCHAR2)
   IS
   BEGIN
        -- call trace procedure
        p_trace(p_context_in => p_context_in, p_text_in => 'START: ' || pkg_error_manager.f_who_called_me || '.' || p_text_in );
   END p_trace_start;
   --================================================================================
   PROCEDURE p_trace_end(   p_context_in  IN q$log.context%TYPE
                          , p_text_in     IN VARCHAR2)
   IS   
   BEGIN
        -- call trace procedure
        p_trace(p_context_in => p_context_in, p_text_in => 'END: ' || pkg_error_manager.f_who_called_me || '.' || p_text_in );   
   END p_trace_end;
   --================================================================================

   --================================================================================
   --================================================================================
   --================================================================================
   --================================================================================

   --================================================================================
   --================================================================================
   --================================================================================
   --================================================================================

   -- NEW Error handling routines....using QUEST ERROR MANAGER.

   --================================================================================
   --================================================================================
   --================================================================================
   --================================================================================
    PROCEDURE p_capture_session_context (
        p_error_instance_id IN  q$error_instance.id%TYPE,
        p_user_code         IN  q$error_context.created_by%TYPE)
    IS
    PRAGMA AUTONOMOUS_TRANSACTION;    
    BEGIN
      
        -- insert into the error context all the session context values
        INSERT INTO q$error_context (
            id,
            error_instance_id,
            name,
            value,
            created_on,
            created_by )
        SELECT  q$error_context_seq.NEXTVAL,
                p_error_instance_id,
                sc.namespace || '.' || sc.attribute,
                sc.value,
                SYSDATE,
                p_user_code
        FROM    session_context sc
        WHERE namespace LIKE '%CTX%';                 
        
        -- log the input parameters.
        INSERT INTO q$error_context (
            id,
            error_instance_id,
            name,
            value,
            created_on,
            created_by )
        VALUES (q$error_context_seq.NEXTVAL,
                p_error_instance_id,
                'PKG_ERROR_MANAGER_CTX.INPUT_PARAMETERS',
                l_input_parameters,
                SYSDATE,
                p_user_code);                    
                        
        COMMIT;                   
                    
    END p_capture_session_context;
   --================================================================================
   --================================================================================
   PROCEDURE p_initialise_error_handler
   IS
   BEGIN
      q$error_manager.mark_q$error_handled;
   END p_initialise_error_handler;

   PROCEDURE p_raise_error(p_error_code_in     IN q$error.code%TYPE
                         , p_text_in           IN q$error_instance.MESSAGE%TYPE
                         , p_name1_in          IN VARCHAR2 DEFAULT NULL
                         , p_value1_in         IN VARCHAR2 DEFAULT NULL
                         , p_name2_in          IN VARCHAR2 DEFAULT NULL
                         , p_value2_in         IN VARCHAR2 DEFAULT NULL
                         , p_name3_in          IN VARCHAR2 DEFAULT NULL
                         , p_value3_in         IN VARCHAR2 DEFAULT NULL
                         , p_name4_in          IN VARCHAR2 DEFAULT NULL
                         , p_value4_in         IN VARCHAR2 DEFAULT NULL
                         , p_name5_in          IN VARCHAR2 DEFAULT NULL
                         , p_value5_in         IN VARCHAR2 DEFAULT NULL
                         , p_grab_settings_in  IN BOOLEAN DEFAULT TRUE )
   IS
   v_error_code_in  q$error.code%TYPE;
   BEGIN
   
      -- format the error number
      IF p_error_code_in <= -20000
      THEN
         v_error_code_in := p_error_code_in;
      ELSIF p_error_code_in > -20000
      THEN
         v_error_code_in := (20000 + p_error_code_in) * -1;
      END IF;   
   
      q$error_manager.raise_error(error_code_in     => v_error_code_in
                                , text_in           => p_text_in
                                , name1_in          => p_name1_in
                                , value1_in         => p_value1_in
                                , name2_in          => p_name2_in
                                , value2_in         => p_value2_in
                                , name3_in          => p_name3_in
                                , value3_in         => p_value3_in
                                , name4_in          => p_name4_in
                                , value4_in         => p_value4_in
                                , name5_in          => p_name5_in
                                , value5_in         => p_value5_in
                                , grab_settings_in  => p_grab_settings_in);
   END p_raise_error;

   PROCEDURE p_raise_when_others(p_text_in           IN q$error_instance.MESSAGE%TYPE
                               , p_name1_in          IN VARCHAR2 DEFAULT NULL
                               , p_value1_in         IN VARCHAR2 DEFAULT NULL
                               , p_name2_in          IN VARCHAR2 DEFAULT NULL
                               , p_value2_in         IN VARCHAR2 DEFAULT NULL
                               , p_name3_in          IN VARCHAR2 DEFAULT NULL
                               , p_value3_in         IN VARCHAR2 DEFAULT NULL
                               , p_name4_in          IN VARCHAR2 DEFAULT NULL
                               , p_value4_in         IN VARCHAR2 DEFAULT NULL
                               , p_name5_in          IN VARCHAR2 DEFAULT NULL
                               , p_value5_in         IN VARCHAR2 DEFAULT NULL
                               , p_grab_settings_in  IN BOOLEAN DEFAULT TRUE )
   IS
   BEGIN
      q$error_manager.raise_unanticipated(text_in           => p_text_in
                                        , name1_in          => p_name1_in
                                        , value1_in         => p_value1_in
                                        , name2_in          => p_name2_in
                                        , value2_in         => p_value2_in
                                        , name3_in          => p_name3_in
                                        , value3_in         => p_value3_in
                                        , name4_in          => p_name4_in
                                        , value4_in         => p_value4_in
                                        , name5_in          => p_name5_in
                                        , value5_in         => p_value5_in
                                        , grab_settings_in  => p_grab_settings_in);
   END p_raise_when_others;

   PROCEDURE p_raise_api_error(p_text_in           IN q$error_instance.MESSAGE%TYPE
                             , p_name1_in          IN VARCHAR2 DEFAULT NULL
                             , p_value1_in         IN VARCHAR2 DEFAULT NULL
                             , p_name2_in          IN VARCHAR2 DEFAULT NULL
                             , p_value2_in         IN VARCHAR2 DEFAULT NULL
                             , p_name3_in          IN VARCHAR2 DEFAULT NULL
                             , p_value3_in         IN VARCHAR2 DEFAULT NULL
                             , p_name4_in          IN VARCHAR2 DEFAULT NULL
                             , p_value4_in         IN VARCHAR2 DEFAULT NULL
                             , p_name5_in          IN VARCHAR2 DEFAULT NULL
                             , p_value5_in         IN VARCHAR2 DEFAULT NULL
                             , p_grab_settings_in  IN BOOLEAN DEFAULT TRUE )
   IS
      r_error_info         q$error_manager.error_info_rt;
      l_error_instance_id  q$error_instance.id%TYPE;
   BEGIN
      q$error_manager.register_oracle_error(text_in              => p_text_in
                                          , name1_in             => p_name1_in
                                          , value1_in            => p_value1_in
                                          , name2_in             => p_name2_in
                                          , value2_in            => p_value2_in
                                          , name3_in             => p_name3_in
                                          , value3_in            => p_value3_in
                                          , name4_in             => p_name4_in
                                          , value4_in            => p_value4_in
                                          , name5_in             => p_name5_in
                                          , value5_in            => p_value5_in
                                          , grab_settings_in     => p_grab_settings_in
                                          , err_instance_id_out  => l_error_instance_id);

      q$error_manager.get_error_info(r_error_info);

      DBMS_OUTPUT.put_line('ERROR_CATEGORY_NAME:  ' || r_error_info.error_category_name);
      DBMS_OUTPUT.put_line('CODE:                 ' || r_error_info.code);
      DBMS_OUTPUT.put_line('NAME:                 ' || r_error_info.name);
      DBMS_OUTPUT.put_line('SYSTEM_ERROR_CODE:    ' || r_error_info.system_error_code);
      DBMS_OUTPUT.put_line('SYSTEM_ERROR_MESSAGE: ' || r_error_info.system_error_message);
      DBMS_OUTPUT.put_line('TEXT:                 ' || r_error_info.text);
      DBMS_OUTPUT.put_line('RECOMMENDATION:       ' || r_error_info.recommendation);
      DBMS_OUTPUT.put_line('ERROR_STACK:          ' || r_error_info.error_stack);
      DBMS_OUTPUT.put_line('CALL_STACK:           ' || r_error_info.call_stack);
      DBMS_OUTPUT.put_line('ENVIRONMENT_INFO:     ' || r_error_info.environment_info);

     -- we dump out the session context values into the q$error_context table
     -- so that we can see what actually caused the error
     
     p_capture_session_context (
            p_error_instance_id => l_error_instance_id,
            p_user_code         => NULL );


      IF r_error_info.error_category_name = 'APPLICATION ERRORS'
      THEN
         -- raise error as type APPLICATION -- in this case we pass the APP keyword
         -- along with the error instance id just in case you need to find the error instance row
         -- and we also supply the recommendation text to display, if desired, to the user.
         raise_application_error(
            r_error_info.code
          ,    '[APP]:[ERROR_ID='
            || l_error_instance_id
            || ']:[ERROR_RECOMMENDATION='
            || r_error_info.text || CHR(10) || r_error_info.recommendation            
            --|| r_error_info.recommendation            
            || ']:[ERROR_MESSAGE='
            || r_error_info.text 
            || CHR(13) || CHR(10)
            || r_error_info.system_error_message
            || ']'            
         );
      ELSE
         -- for anything other then application errors we want to raise a type FATAL -- in this
         -- case we pass the FATAL keyword, with the error instance id pointing to the row in the
         -- error instance table, along with the recommendation message eg contact the helpdesk.

         -- if it is an unregistered oracle fatal error we won't have any recommendation
         -- (not until we explictily set one up) therefore use the same message as the
         -- one for APP FATAL ERRORS.
         BEGIN
               SELECT   recommendation || TO_CHAR(l_error_instance_id)
               INTO     r_error_info.recommendation
               FROM     q$error
               WHERE    error_category_name = 'APP FATAL ERRORS'
                        AND ROWNUM < 2;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               -- this should never happen....you should always have at least one type
               -- of APP FATAL ERROR message defined that gives you the correct message
               -- to display with the correct helpdesk phone number
               -- So if you haven't defined any APP FATAL ERRORS then we will just display
               -- this default FATAL error message with no specific helpdesk phone number
               r_error_info.recommendation := 'An unexpected error has occured please contact the helpdesk quoting the following id: '
                                                || TO_CHAR(l_error_instance_id);
         END;

         -- now raise the error
         raise_application_error(
            -20000
          ,    '[FATAL]:[ERROR_ID='
            || l_error_instance_id
            || ']:[ERROR_RECOMMENDATION='
            || r_error_info.recommendation
            || ']:[ERROR_MESSAGE='
            || r_error_info.text 
            || CHR(13) || CHR(10)
            || r_error_info.system_error_message
            || ']'            
         );
      END IF;
   END p_raise_api_error;
--=============================================================================

    /* AFTER ENTERING - IN and IN OUT argument tracing */
    PROCEDURE p_trace_inputs( p_trace_text_in IN VARCHAR2 )
    IS
    BEGIN
        p_trace( p_context_in => 'PARAM_I', p_text_in => p_trace_text_in );
    END p_trace_inputs;

    --==========================================================================
    --==========================================================================
    /* BEFORE LEAVING - OUT and IN OUT argument tracing */
    PROCEDURE p_trace_outputs( p_trace_text_in IN VARCHAR2 )
    IS
    BEGIN
        p_trace( p_context_in => 'PARAM_O', p_text_in => p_trace_text_in );
    END p_trace_outputs;

    --==========================================================================
    --==========================================================================
    PROCEDURE p_initialise_trace_and_errors( p_trace_text_in               IN VARCHAR2
                                           , p_debug_trace                 IN VARCHAR2 )
    IS
        v_debug_level  NUMBER( 3 );
        v_debug_trace  VARCHAR2( 500 );
        v_plsql_block  VARCHAR2( 500 );
    BEGIN    
    
        p_initialise_parameter_trace( p_inputs => p_trace_text_in );

        IF p_debug_trace IS NOT NULL
        THEN
            BEGIN
                -- set up trace parameter
                -- first check if the parameter is a number or not....
                -- if not then we assume the full debug string has been passed in
                -- OR the wildcard % either way we will use the string..
                --
                -- This way we can look up the correct debug trace string without making
                -- a database call to the table...
                v_debug_level              := TO_NUMBER( p_debug_trace );

                -- set up plsql block to run dynamically
                v_plsql_block              :=
                    'BEGIN :v_debug_trace := pkg_error_manager.gc_debug_' || TO_CHAR( v_debug_level ) || '; END;';

                -- run block to put the debug level onto the end of the constants name
                -- eg   pkg_error_manager.gc_debug_2   this would then fetch that constant into the v_debug_trace  variable
                EXECUTE IMMEDIATE v_plsql_block USING IN OUT v_debug_trace;
            EXCEPTION
                WHEN VALUE_ERROR
                THEN
                    -- if the p_debug_trace is not a number then we just use it
                    -- as a string....
                    v_debug_trace              := p_debug_trace;
            END;
        ELSE
            v_debug_trace              := p_debug_trace;
        END IF;

        -- initialise the global trace variable
        g_debug_trace := v_debug_trace;
        
        -- initialise tracing and error handler
        p_initialise_error_handler;
        p_initialise_trace( p_trace_level => v_debug_trace );

        -- trace input parameters
        p_trace_inputs( p_trace_text_in => p_trace_text_in );
    END p_initialise_trace_and_errors;

    --==========================================================================
    --==========================================================================
    PROCEDURE p_cleanup_trace_and_errors( p_trace_text_in IN VARCHAR2 )
    IS
    BEGIN
        -- trace output parameters
        p_trace_outputs( p_trace_text_in => p_trace_text_in );

        -- turn off tracing
        p_set_trace_off;
    END p_cleanup_trace_and_errors;

    --==========================================================================
    --==========================================================================



--............................................................
--  Initialization section
--============================================================


--################################################################################
END pkg_error_manager;
/