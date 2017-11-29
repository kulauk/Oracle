CREATE OR REPLACE PACKAGE pkg_error_manager
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

    gc_debug_0                      CONSTANT VARCHAR2(500) := 'NULL' ;
    gc_debug_1                      CONSTANT VARCHAR2(500) := 'PARAM_I,PARAM_O' ;
    gc_debug_2                      CONSTANT VARCHAR2(500) := 'PARAM_I,PARAM_O,API' ;
    gc_debug_3                      CONSTANT VARCHAR2(500) := 'PARAM_I,PARAM_O,API,ALL,' ;
    gc_debug_4                      CONSTANT VARCHAR2(500) := 'PARAM_I,PARAM_O,API,ALL,LOC' ;
    gc_debug_5                      CONSTANT VARCHAR2(500) := 'PARAM_I,PARAM_O,API,ALL,LOC,LEVEL1,LOC_1' ;
    gc_debug_6                      CONSTANT VARCHAR2(500) := 'PARAM_I,PARAM_O,API,ALL,LOC,LEVEL1,LOC_1,LOOP1' ;
    gc_debug_7                      CONSTANT VARCHAR2(500) := 'PARAM_I,PARAM_O,API,ALL,LOC,LEVEL1,LEVEL2,LOC_1,LOC_2' ;
    gc_debug_8                      CONSTANT VARCHAR2(500) := 'PARAM_I,PARAM_O,API,ALL,LOC,LEVEL1,LEVEL2,LOC_1,LOC_2,LOOP1,LOOP2' ;

    g_debug_trace                   VARCHAR2( 500 );
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
   --================================================================================
   --================================================================================
   FUNCTION f_who_called_me
      RETURN VARCHAR2;   
   PROCEDURE p_set_trace_on(p_trace IN VARCHAR2 DEFAULT NULL );

   PROCEDURE p_set_trace_off;

   PROCEDURE p_initialise_trace(p_trace_level IN VARCHAR2 DEFAULT NULL );
   
   PROCEDURE p_trace(p_context_in  IN q$log.context%TYPE
                   , p_text_in     IN VARCHAR2);
   --================================================================================   
   PROCEDURE p_trace_start(   p_context_in  IN q$log.context%TYPE
                            , p_text_in     IN VARCHAR2);
   --================================================================================
   PROCEDURE p_trace_end(   p_context_in  IN q$log.context%TYPE
                          , p_text_in     IN VARCHAR2);

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
   PROCEDURE p_initialise_error_handler;

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
                         , p_grab_settings_in  IN BOOLEAN DEFAULT TRUE );

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
                               , p_grab_settings_in  IN BOOLEAN DEFAULT TRUE );

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
                             , p_grab_settings_in  IN BOOLEAN DEFAULT TRUE );
                             
                             
    /* AFTER ENTERING - IN and IN OUT argument tracing */
    PROCEDURE p_trace_inputs( p_trace_text_in IN VARCHAR2 );

    --==========================================================================
    --==========================================================================
    /* BEFORE LEAVING - OUT and IN OUT argument tracing */
    PROCEDURE p_trace_outputs( p_trace_text_in IN VARCHAR2 );

    --==========================================================================
    --==========================================================================
    PROCEDURE p_initialise_trace_and_errors( p_trace_text_in               IN VARCHAR2
                                           , p_debug_trace                 IN VARCHAR2 );

    --==========================================================================
    --==========================================================================
    PROCEDURE p_cleanup_trace_and_errors( p_trace_text_in IN VARCHAR2 );

    --==========================================================================
    --==========================================================================
                             
--=============================================================================

--............................................................
--  Initialization section
--============================================================


--################################################################################
END pkg_error_manager;
/