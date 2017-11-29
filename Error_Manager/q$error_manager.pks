CREATE OR REPLACE PACKAGE q$error_manager
/*
| This program is a part of the Quest Error Manager for Oracle.
| This product is freeware and is not supported by Quest.
|
| www.quest.com
|

© 2008 Quest Software, Inc.
ALL RIGHTS RESERVED.

Redistribution and use of the Quest Error Manager for Oracle software in source and binary forms,
with or without modification, are permitted provided that the following conditions are met:

1.    Redistributions of source code must retain (i) the following copyright notice: "©2008 Quest Software, Inc.
All rights reserved," (ii) this list of conditions, and (iii) the disclaimer below.

2.    Redistributions in binary form must reproduce (i) the following copyright notice:
"©2008 Quest Software, Inc. All rights reserved," (ii) this list of conditions, and (iii)
the disclaimer below, in the documentation and/or other materials provided with the distribution.

3.    All advertising materials mentioning features or use of the Quest Error Manager
for Oracle software must display the following acknowledgement:

This product includes software developed by Quest Software, Inc. and its contributors.

4.    Neither the name of Quest Software, Inc. nor the name its affiliates, subsidiaries
or contributors may be used to endorse or promote products derived from the Quest Error
Manager for Oracle software without specific prior written permission from Quest Software, Inc.

Disclaimer:

THIS SOFTWARE IS PROVIDED BY QUEST SOFTWARE, INC. AND ITS CONTRIBUTORS ``AS IS''
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
AND NON-INFRINGEMENT ARE DISCLAIMED. IN NO EVENT SHALL QUEST SOFTWARE OR ITS
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
QUEST ERROR MANAGER SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
/*
Modification History

Date         Who   Vrsn   What
-----------  ----- ------ -------------------------------------------------------
Dec 12 2008  SF    1.2.19 Change trigger intro'd in 1.2.17 so that you do NOT need
                          access to v$session to run QEM. It will just ignore the
                          environment info when running the trigger.
Dec 9  2008  SF    1.2.18 Avoid context strings > 500 characters. Thanks, Mike Pinker!
                          Add ability to specify multiple distinct contexts.
Nov 10 2008  SF/FS 1.2.17 Minor fixes from feedback by Filipe Silva, add trigger to
                          populate environmental info. Also, offer toggle to avoid
                          the need to mark an error as unhandled.
Jul 12 2008  SF    1.2.16 Avoid VALUE_ERROR exception for sqlcode_name.
July   2008  SF    1.2.15 register_oracle_error RAISES an error. Should not do that.
                          Thanks to Filipe de Silva for pointing this out.
                          Also add overloading to return error instance ID.
Mar 12 2008  SF    1.2.14 Minor refactorings from feedback by Volker Bartusek.
Nov 27 2007  SF    1.2.13 REMOVE DBMS_ERRLOG - only available in 10gR2.
                          Will put in separate utility that will come with QEM.
Nov 11 2007  SF    1.2.12 Allow user to show error info in message.
Oct 1  2007  SF    1.2.11 * Start tracking version.
                          * Change q$error error code for DUPVAL to -1.
                          * Add raise/register_oracle_error alternative.
                          * Obtain most recent instance ID from package global
                          g_error_instance_raised instead of parsing the
                          Oracle error message. This is set in the session
                          each time an error is registered.

Sep 27 2007  SF    SF     Add dbms_Errlog functionality
Sep 26 2007  SF    SF     Add raise_unaticipated
Sep 21 2007  SF    SF     Add overloadings with different column names
                          err_instance instead of error_instance to support
                          backward compatibility with QCGU generated code.
Sep 5 2007   SF    SF     Add "not yet implemented" program

*/
IS
   c_version               CONSTANT PLS_INTEGER := 1;
   c_release               CONSTANT PLS_INTEGER := 2;
   c_subrelease            CONSTANT PLS_INTEGER := 17;

   TYPE weak_refcursor IS REF CURSOR;

   SUBTYPE maxvarchar2_t IS VARCHAR2 (32767);

   -- public global constants
   c_varchar2_max_length   CONSTANT PLS_INTEGER := 32767;
   c_subst_char            CONSTANT VARCHAR2 (1) := '$';
   c_error_prefix          CONSTANT VARCHAR2 (4) := 'QEM';
   c_error_prefix_len      CONSTANT PLS_INTEGER := 3;
   c_error_code_len        CONSTANT PLS_INTEGER := 20;
   c_oracle_separator      CONSTANT VARCHAR2 (5) := '-ORA-';
   c_oracle_code_len       CONSTANT PLS_INTEGER := 5;

   -- public global user-defined types
   -- used to return error info back to a calling context
   TYPE error_info_rt IS RECORD (
                            error_category_name    q$error.error_category_name%TYPE   
                          , code                   q$error.code%TYPE
                          , name                   q$error.name%TYPE
                          , system_error_code      q$error_instance.system_error_code%TYPE
                          , system_error_message   q$error_instance.system_error_message%TYPE
                          , text                   q$error_instance.MESSAGE%TYPE
                          , recommendation         q$error.recommendation%TYPE
                          , error_stack            q$error_instance.error_stack%TYPE
                          , call_stack             q$error_instance.call_stack%TYPE
                          , environment_info       q$error_instance.environment_info%TYPE
                         );

   TYPE q$log_tc
   IS
      TABLE OF q$log%ROWTYPE
         INDEX BY PLS_INTEGER;

   TYPE q$error_context_tc
   IS
      TABLE OF q$error_context%ROWTYPE
         INDEX BY PLS_INTEGER;

   -- Error/warning management
   c_error                 CONSTANT CHAR (5) := 'ERROR';
   c_info_msg              CONSTANT CHAR (4) := 'INFO';
   c_warning               CONSTANT CHAR (7) := 'WARNING';
   c_status_delimiter      CONSTANT CHAR (1) := ':';
   /* Special NYI exception */
   e_not_yet_implemented exception;
   c_not_yet_implemented   PLS_INTEGER := -20999;
   PRAGMA EXCEPTION_INIT (e_not_yet_implemented, -20999);

   -- public global routines
   -- -------------------------------------
   -- Tracing and DBMS_OUTPUT encapsulation
   -- -------------------------------------
   -- switches output to the console
   -- NOTE: default is to Table
   PROCEDURE toscreen;

   -- switches output to the q$log. table
   -- NOTE: this is the default destination
   PROCEDURE totable;

   PROCEDURE totable (purge_in IN BOOLEAN);

   -- Send output to file. tofile opens the file; trace off closes the file.
   PROCEDURE tofile (dir_in       IN VARCHAR2
                   , file_in      IN VARCHAR2
                   , overwrite_in IN BOOLEAN DEFAULT TRUE
                    );

   -- simple DBMS_OUTPUT handling of 255 char limit
   -- looks for a newline, or chops to fit given length
   PROCEDURE pl (string_in IN VARCHAR2, length_in IN PLS_INTEGER := 80);

   -- converts the given boolean value to string,
   -- then writes it out as above
   PROCEDURE pl (val IN BOOLEAN);

   -- as above but concatenates str with the string value of bool
   -- e.g., 'cursor%found TRUE'
   PROCEDURE pl (str IN VARCHAR2, bool IN BOOLEAN, len IN PLS_INTEGER := 80);

   PROCEDURE pl (clob_in IN CLOB, length_in IN PLS_INTEGER := 80);

   PROCEDURE set_error_trace (onoff_in IN BOOLEAN);

   -- When error trace is turned on, all errors are also written
   -- to the log table automatically.
   PROCEDURE error_trace_on;

   PROCEDURE error_trace_off;

   FUNCTION error_trace_enabled
      RETURN BOOLEAN;

   -- Controls the trace mechanism via a private global variable
   -- and sets the trace context filter (defaults to all traces)
   -- NOTE: tracing defaults to FALSE on package initialization
   --       only one context can be in force at a time
   --       and is case-insensitive
   PROCEDURE set_trace (onoff_in             IN BOOLEAN
                      , context_like_in      IN q$log.context%TYPE:= NULL
                      , include_timestamp_in IN BOOLEAN DEFAULT FALSE
                      , delimiter_in         IN VARCHAR2 DEFAULT ','
                       );

   -- Clears out the trace contents. Currently just deletes from q$log.
   PROCEDURE clear_trace;

   PROCEDURE trace_on (context_like_in      IN q$log.context%TYPE:= NULL
                     , include_timestamp_in IN BOOLEAN DEFAULT FALSE
                     , delimiter_in         IN VARCHAR2 DEFAULT ','
                      );

   PROCEDURE trace_off (context_like_in      IN q$log.context%TYPE:= NULL
                      , include_timestamp_in IN BOOLEAN DEFAULT FALSE
                       );

   -- Has tracing been turned on globally?
   FUNCTION trace_enabled
      RETURN BOOLEAN;

   -- Has tracing been turned on globally or for a specific context?
   -- Context values are compared using UPPER case.
   FUNCTION trace_enabled (context_in IN q$log.context%TYPE)
      RETURN BOOLEAN;

   -- Writes output to the screen or q$log. table
   -- (see toscreen and totable above)
   -- If you pass TRUE for force parameter, this program will write to the log
   -- even if overall tracing is disabled.
   -- Level results in indentation to help you understand the log output.
   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , text_in        IN q$log.text%TYPE
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   );

   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , number_in      IN NUMBER
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   );

   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , date_in        IN DATE
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   );

   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , boolean_in     IN BOOLEAN
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   );

   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , clob_in        IN CLOB
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   );

   -- writes to the console the trace rows
   -- given (optionally filtered in any combination):
   --    trace id, context, text
   -- may be limited by limit_in
   -- call stack can also be displayed
   PROCEDURE show_trace (from_id_in            IN q$log.id%TYPE:= NULL
                       , context_like_in       IN VARCHAR2:= '%'
                       , text_like_in          IN VARCHAR2:= '%'
                       , limit_in              IN PLS_INTEGER:= NULL
                       , include_call_stack_in IN BOOLEAN:= TRUE
                        );

   -------------------------------------------
   -- Error handling and raising functionality
   -------------------------------------------

   -- An error needs to be raised or logged.
   -- Get a message handle for this particular error instance.
   -- The "error message" id keeps track of both the error
   -- and message information. This program also serves as
   -- "record and go" and "go". In other words, we do not
   -- raise an error, but it is noted.
   --
   PROCEDURE register_error (
      error_code_in         IN     q$error.code%TYPE
    , error_instance_id_out IN OUT q$error_instance.id%TYPE
    , text_in               IN     q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in              IN     VARCHAR2 DEFAULT NULL
    , value1_in             IN     VARCHAR2 DEFAULT NULL
    , name2_in              IN     VARCHAR2 DEFAULT NULL
    , value2_in             IN     VARCHAR2 DEFAULT NULL
    , name3_in              IN     VARCHAR2 DEFAULT NULL
    , value3_in             IN     VARCHAR2 DEFAULT NULL
    , name4_in              IN     VARCHAR2 DEFAULT NULL
    , value4_in             IN     VARCHAR2 DEFAULT NULL
    , name5_in              IN     VARCHAR2 DEFAULT NULL
    , value5_in             IN     VARCHAR2 DEFAULT NULL
    , grab_settings_in      IN     BOOLEAN DEFAULT TRUE
   );

   -- Pass in error name instead of code.
   PROCEDURE register_error (
      error_name_in         IN     q$error.name%TYPE
    , error_instance_id_out IN OUT q$error_instance.id%TYPE
    , text_in               IN     q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in              IN     VARCHAR2 DEFAULT NULL
    , value1_in             IN     VARCHAR2 DEFAULT NULL
    , name2_in              IN     VARCHAR2 DEFAULT NULL
    , value2_in             IN     VARCHAR2 DEFAULT NULL
    , name3_in              IN     VARCHAR2 DEFAULT NULL
    , value3_in             IN     VARCHAR2 DEFAULT NULL
    , name4_in              IN     VARCHAR2 DEFAULT NULL
    , value4_in             IN     VARCHAR2 DEFAULT NULL
    , name5_in              IN     VARCHAR2 DEFAULT NULL
    , value5_in             IN     VARCHAR2 DEFAULT NULL
    , grab_settings_in      IN     BOOLEAN DEFAULT TRUE
   );

   PROCEDURE register_error (
      error_code_in       IN     q$error.code%TYPE
    , err_instance_id_out IN OUT q$error_instance.id%TYPE
    , text_in             IN     q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in            IN     VARCHAR2 DEFAULT NULL
    , value1_in           IN     VARCHAR2 DEFAULT NULL
    , name2_in            IN     VARCHAR2 DEFAULT NULL
    , value2_in           IN     VARCHAR2 DEFAULT NULL
    , name3_in            IN     VARCHAR2 DEFAULT NULL
    , value3_in           IN     VARCHAR2 DEFAULT NULL
    , name4_in            IN     VARCHAR2 DEFAULT NULL
    , value4_in           IN     VARCHAR2 DEFAULT NULL
    , name5_in            IN     VARCHAR2 DEFAULT NULL
    , value5_in           IN     VARCHAR2 DEFAULT NULL
    , grab_settings_in    IN     BOOLEAN DEFAULT TRUE
   );

   -- Pass in error name instead of code.
   PROCEDURE register_error (
      error_name_in       IN     q$error.name%TYPE
    , err_instance_id_out IN OUT q$error_instance.id%TYPE
    , text_in             IN     q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in            IN     VARCHAR2 DEFAULT NULL
    , value1_in           IN     VARCHAR2 DEFAULT NULL
    , name2_in            IN     VARCHAR2 DEFAULT NULL
    , value2_in           IN     VARCHAR2 DEFAULT NULL
    , name3_in            IN     VARCHAR2 DEFAULT NULL
    , value3_in           IN     VARCHAR2 DEFAULT NULL
    , name4_in            IN     VARCHAR2 DEFAULT NULL
    , value4_in           IN     VARCHAR2 DEFAULT NULL
    , name5_in            IN     VARCHAR2 DEFAULT NULL
    , value5_in           IN     VARCHAR2 DEFAULT NULL
    , grab_settings_in    IN     BOOLEAN DEFAULT TRUE
   );

   -- Record error (using name or code), but ignore error instance.
   -- Essentially, this is "record but do not raise error."
   PROCEDURE register_error (
      error_code_in    IN q$error.code%TYPE
    , text_in          IN q$error_instance.MESSAGE%TYPE DEFAULT NULL
    , name1_in         IN VARCHAR2 DEFAULT NULL
    , value1_in        IN VARCHAR2 DEFAULT NULL
    , name2_in         IN VARCHAR2 DEFAULT NULL
    , value2_in        IN VARCHAR2 DEFAULT NULL
    , name3_in         IN VARCHAR2 DEFAULT NULL
    , value3_in        IN VARCHAR2 DEFAULT NULL
    , name4_in         IN VARCHAR2 DEFAULT NULL
    , value4_in        IN VARCHAR2 DEFAULT NULL
    , name5_in         IN VARCHAR2 DEFAULT NULL
    , value5_in        IN VARCHAR2 DEFAULT NULL
    , grab_settings_in IN BOOLEAN DEFAULT TRUE
   );

   PROCEDURE register_error (
      error_name_in    IN q$error.name%TYPE
    , text_in          IN q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in         IN VARCHAR2 DEFAULT NULL
    , value1_in        IN VARCHAR2 DEFAULT NULL
    , name2_in         IN VARCHAR2 DEFAULT NULL
    , value2_in        IN VARCHAR2 DEFAULT NULL
    , name3_in         IN VARCHAR2 DEFAULT NULL
    , value3_in        IN VARCHAR2 DEFAULT NULL
    , name4_in         IN VARCHAR2 DEFAULT NULL
    , value4_in        IN VARCHAR2 DEFAULT NULL
    , name5_in         IN VARCHAR2 DEFAULT NULL
    , value5_in        IN VARCHAR2 DEFAULT NULL
    , grab_settings_in IN BOOLEAN DEFAULT TRUE
   );

   -- Set a single context value for an error_instance row.
   -- Should overload this for a variety of datatypes.
   PROCEDURE add_context (error_instance_id_in IN q$error_instance.id%TYPE
                        , NAME_IN              IN q$error_context.name%TYPE
                        , value_in             IN q$error_context.VALUE%TYPE
                        , validate_in          IN BOOLEAN DEFAULT TRUE
                         );

   PROCEDURE add_context (err_instance_id_in IN q$error_instance.id%TYPE
                        , NAME_IN            IN q$error_context.name%TYPE
                        , value_in           IN q$error_context.VALUE%TYPE
                        , validate_in        IN BOOLEAN DEFAULT TRUE
                         );

   -- Global contexts; not tied to any specific instance.
   PROCEDURE add_gcontext (NAME_IN  IN q$error_context.name%TYPE
                         , value_in IN q$error_context.VALUE%TYPE
                          );

   -- Remove all global contexts.
   -- This is called by mark_q$error_handled as well.
   PROCEDURE clear_gcontexts;

   /*
   Raise specified error, providing minimal message
   information in a single procedure call.
   No context information is passed; if message text
   is not provided then the default with the error
   is used.
   */
   PROCEDURE raise_error (
      error_code_in    IN q$error.code%TYPE
    , text_in          IN q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in         IN VARCHAR2 DEFAULT NULL
    , value1_in        IN VARCHAR2 DEFAULT NULL
    , name2_in         IN VARCHAR2 DEFAULT NULL
    , value2_in        IN VARCHAR2 DEFAULT NULL
    , name3_in         IN VARCHAR2 DEFAULT NULL
    , value3_in        IN VARCHAR2 DEFAULT NULL
    , name4_in         IN VARCHAR2 DEFAULT NULL
    , value4_in        IN VARCHAR2 DEFAULT NULL
    , name5_in         IN VARCHAR2 DEFAULT NULL
    , value5_in        IN VARCHAR2 DEFAULT NULL
    , grab_settings_in IN BOOLEAN DEFAULT TRUE
   );

   PROCEDURE raise_error (
      error_name_in    IN q$error.name%TYPE
    , text_in          IN q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in         IN VARCHAR2 DEFAULT NULL
    , value1_in        IN VARCHAR2 DEFAULT NULL
    , name2_in         IN VARCHAR2 DEFAULT NULL
    , value2_in        IN VARCHAR2 DEFAULT NULL
    , name3_in         IN VARCHAR2 DEFAULT NULL
    , value3_in        IN VARCHAR2 DEFAULT NULL
    , name4_in         IN VARCHAR2 DEFAULT NULL
    , value4_in        IN VARCHAR2 DEFAULT NULL
    , name5_in         IN VARCHAR2 DEFAULT NULL
    , value5_in        IN VARCHAR2 DEFAULT NULL
    , grab_settings_in IN BOOLEAN DEFAULT TRUE
   );

   PROCEDURE raise_error_instance (
      err_instance_id_in IN q$error_instance.id%TYPE
   );

   /* Raise an unanticipated error. */
   PROCEDURE raise_unanticipated (
      text_in          IN q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in         IN VARCHAR2 DEFAULT NULL
    , value1_in        IN VARCHAR2 DEFAULT NULL
    , name2_in         IN VARCHAR2 DEFAULT NULL
    , value2_in        IN VARCHAR2 DEFAULT NULL
    , name3_in         IN VARCHAR2 DEFAULT NULL
    , value3_in        IN VARCHAR2 DEFAULT NULL
    , name4_in         IN VARCHAR2 DEFAULT NULL
    , value4_in        IN VARCHAR2 DEFAULT NULL
    , name5_in         IN VARCHAR2 DEFAULT NULL
    , value5_in        IN VARCHAR2 DEFAULT NULL
    , grab_settings_in IN BOOLEAN DEFAULT TRUE
   );

   /* V1.2.11 Allow user to specify that an Oracle error should be registered
              (but not re-raised) or raised (registered and re-raised).
   */
   PROCEDURE register_oracle_error (
      text_in          IN q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in         IN VARCHAR2 DEFAULT NULL
    , value1_in        IN VARCHAR2 DEFAULT NULL
    , name2_in         IN VARCHAR2 DEFAULT NULL
    , value2_in        IN VARCHAR2 DEFAULT NULL
    , name3_in         IN VARCHAR2 DEFAULT NULL
    , value3_in        IN VARCHAR2 DEFAULT NULL
    , name4_in         IN VARCHAR2 DEFAULT NULL
    , value4_in        IN VARCHAR2 DEFAULT NULL
    , name5_in         IN VARCHAR2 DEFAULT NULL
    , value5_in        IN VARCHAR2 DEFAULT NULL
    , grab_settings_in IN BOOLEAN DEFAULT TRUE
   );

   /* 1.2.15 Return error instance */
   PROCEDURE register_oracle_error (
      text_in             IN     q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in            IN     VARCHAR2 DEFAULT NULL
    , value1_in           IN     VARCHAR2 DEFAULT NULL
    , name2_in            IN     VARCHAR2 DEFAULT NULL
    , value2_in           IN     VARCHAR2 DEFAULT NULL
    , name3_in            IN     VARCHAR2 DEFAULT NULL
    , value3_in           IN     VARCHAR2 DEFAULT NULL
    , name4_in            IN     VARCHAR2 DEFAULT NULL
    , value4_in           IN     VARCHAR2 DEFAULT NULL
    , name5_in            IN     VARCHAR2 DEFAULT NULL
    , value5_in           IN     VARCHAR2 DEFAULT NULL
    , grab_settings_in    IN     BOOLEAN DEFAULT TRUE
    , err_instance_id_out    OUT q$error_instance.id%TYPE
   );

   PROCEDURE raise_oracle_error (
      text_in          IN q$error_instance.MESSAGE%TYPE:= NULL
    , name1_in         IN VARCHAR2 DEFAULT NULL
    , value1_in        IN VARCHAR2 DEFAULT NULL
    , name2_in         IN VARCHAR2 DEFAULT NULL
    , value2_in        IN VARCHAR2 DEFAULT NULL
    , name3_in         IN VARCHAR2 DEFAULT NULL
    , value3_in        IN VARCHAR2 DEFAULT NULL
    , name4_in         IN VARCHAR2 DEFAULT NULL
    , value4_in        IN VARCHAR2 DEFAULT NULL
    , name5_in         IN VARCHAR2 DEFAULT NULL
    , value5_in        IN VARCHAR2 DEFAULT NULL
    , grab_settings_in IN BOOLEAN DEFAULT TRUE
   );

   /* Get error info for latest error. */
   PROCEDURE get_error_info (
      error_instance_id_in IN     q$error_instance.id%TYPE
    , error_info_out          OUT error_info_rt
   );

   PROCEDURE get_error_info (error_info_out OUT error_info_rt);

   --Simplest format, no composite structures
   PROCEDURE get_error_info (
      code_out                 OUT q$error.code%TYPE
    , name_out                 OUT q$error.name%TYPE
    , text_out                 OUT q$error_instance.MESSAGE%TYPE
    , system_error_code_out    OUT q$error_instance.system_error_code%TYPE
    , system_error_message_out OUT q$error_instance.system_error_message%TYPE
    , recommendation_out       OUT q$error.recommendation%TYPE
    , error_stack_out          OUT q$error_instance.error_stack%TYPE
    , call_stack_out           OUT q$error_instance.call_stack%TYPE
    , environment_info_out     OUT q$error_instance.environment_info%TYPE
   );

   PROCEDURE get_error_info (
      error_instance_id_in     IN     q$error_instance.id%TYPE
    , code_out                    OUT q$error.code%TYPE
    , name_out                    OUT q$error.name%TYPE
    , text_out                    OUT q$error_instance.MESSAGE%TYPE
    , system_error_code_out       OUT q$error_instance.system_error_code%TYPE
    , system_error_message_out    OUT q$error_instance.system_error_message%TYPE
    , recommendation_out          OUT q$error.recommendation%TYPE
    , error_stack_out             OUT q$error_instance.error_stack%TYPE
    , call_stack_out              OUT q$error_instance.call_stack%TYPE
    , environment_info_out        OUT q$error_instance.environment_info%TYPE
   );

   PROCEDURE get_error_info (
      err_message_in           IN     VARCHAR2
    , code_out                    OUT q$error.code%TYPE
    , name_out                    OUT q$error.name%TYPE
    , text_out                    OUT q$error_instance.MESSAGE%TYPE
    , system_error_code_out       OUT q$error_instance.system_error_code%TYPE
    , system_error_message_out    OUT q$error_instance.system_error_message%TYPE
    , recommendation_out          OUT q$error.recommendation%TYPE
    , error_stack_out             OUT q$error_instance.error_stack%TYPE
    , call_stack_out              OUT q$error_instance.call_stack%TYPE
    , environment_info_out        OUT q$error_instance.environment_info%TYPE
   );

   PROCEDURE show_error_info (
      error_instance_id_in IN q$error_instance.id%TYPE
    , copy_to_clipboard_in IN BOOLEAN DEFAULT FALSE
   );

   PROCEDURE show_errors_after (date_in              IN DATE
                              , copy_to_clipboard_in IN BOOLEAN DEFAULT FALSE
                               );

   PROCEDURE show_errors_with_message (
      text_in              IN VARCHAR2
    , copy_to_clipboard_in IN BOOLEAN DEFAULT FALSE
   );

   PROCEDURE show_errors_with_code (
      error_code_in           IN PLS_INTEGER
    , is_system_error_code_in IN BOOLEAN DEFAULT FALSE
    , copy_to_clipboard_in    IN BOOLEAN DEFAULT FALSE
   );

   PROCEDURE show_errors_for (where_clause_in      IN VARCHAR2
                            , copy_to_clipboard_in IN BOOLEAN DEFAULT FALSE
                             );

   FUNCTION error_clipboard (clear_clipboard_in IN BOOLEAN DEFAULT TRUE)
      RETURN VARCHAR2;

   FUNCTION error_clipboard_is_full
      RETURN BOOLEAN;

   PROCEDURE clear_error_clipboard;

   PROCEDURE assert (condition_in  IN BOOLEAN
                   , text_in       IN q$error_instance.MESSAGE%TYPE
                   , error_code_in IN q$error.code%TYPE
                   , name1_in      IN VARCHAR2 DEFAULT NULL
                   , value1_in     IN VARCHAR2 DEFAULT NULL
                   , name2_in      IN VARCHAR2 DEFAULT NULL
                   , value2_in     IN VARCHAR2 DEFAULT NULL
                   , name3_in      IN VARCHAR2 DEFAULT NULL
                   , value3_in     IN VARCHAR2 DEFAULT NULL
                   , name4_in      IN VARCHAR2 DEFAULT NULL
                   , value4_in     IN VARCHAR2 DEFAULT NULL
                   , name5_in      IN VARCHAR2 DEFAULT NULL
                   , value5_in     IN VARCHAR2 DEFAULT NULL
                    );

   PROCEDURE assert (condition_in  IN BOOLEAN
                   , text_in       IN q$error_instance.MESSAGE%TYPE
                   , error_name_in IN q$error.name%TYPE
                   , name1_in      IN VARCHAR2 DEFAULT NULL
                   , value1_in     IN VARCHAR2 DEFAULT NULL
                   , name2_in      IN VARCHAR2 DEFAULT NULL
                   , value2_in     IN VARCHAR2 DEFAULT NULL
                   , name3_in      IN VARCHAR2 DEFAULT NULL
                   , value3_in     IN VARCHAR2 DEFAULT NULL
                   , name4_in      IN VARCHAR2 DEFAULT NULL
                   , value4_in     IN VARCHAR2 DEFAULT NULL
                   , name5_in      IN VARCHAR2 DEFAULT NULL
                   , value5_in     IN VARCHAR2 DEFAULT NULL
                    );

   PROCEDURE assert (condition_in IN BOOLEAN
                   , text_in      IN q$error_instance.MESSAGE%TYPE
                   , name1_in     IN VARCHAR2 DEFAULT NULL
                   , value1_in    IN VARCHAR2 DEFAULT NULL
                   , name2_in     IN VARCHAR2 DEFAULT NULL
                   , value2_in    IN VARCHAR2 DEFAULT NULL
                   , name3_in     IN VARCHAR2 DEFAULT NULL
                   , value3_in    IN VARCHAR2 DEFAULT NULL
                   , name4_in     IN VARCHAR2 DEFAULT NULL
                   , value4_in    IN VARCHAR2 DEFAULT NULL
                   , name5_in     IN VARCHAR2 DEFAULT NULL
                   , value5_in    IN VARCHAR2 DEFAULT NULL
                    );

   PROCEDURE mark_q$error_handled;

   -- Added/exposed in 1.1.1
   FUNCTION error_instance_from_string (string_in IN VARCHAR2)
      RETURN PLS_INTEGER;

   FUNCTION error_instance_from_sqlerrm
      RETURN PLS_INTEGER;

   -- 1.2 Get message text only
   FUNCTION error_message
      RETURN VARCHAR2;

   PROCEDURE start_execution (program_name_in IN VARCHAR2:= NULL
                            , information_in  IN VARCHAR2:= NULL
                             );

   /*
   Test builder validation:
     * return a status string composed of type:message
     * if no prefix, then it is an error
   */
   FUNCTION is_warning (status_in IN VARCHAR2)
      RETURN BOOLEAN;

   FUNCTION is_error (status_in IN VARCHAR2)
      RETURN BOOLEAN;

   FUNCTION is_info_msg (status_in IN VARCHAR2)
      RETURN BOOLEAN;

   PROCEDURE parse_status_string (status_in       IN     VARCHAR2
                                , status_type_out    OUT VARCHAR2
                                , message_out        OUT VARCHAR2
                                 );

   PROCEDURE make_a_warning (status_inout IN OUT VARCHAR2);

   PROCEDURE make_an_error (status_inout IN OUT VARCHAR2);

   PROCEDURE make_an_info_msg (status_inout IN OUT VARCHAR2);

   FUNCTION make_a_warning (status_in IN VARCHAR2)
      RETURN VARCHAR2;

   FUNCTION make_an_error (status_in IN VARCHAR2)
      RETURN VARCHAR2;

   FUNCTION make_an_info_msg (status_in IN VARCHAR2)
      RETURN VARCHAR2;

   FUNCTION full_log_string (context_in IN VARCHAR2
                           , text_in    IN VARCHAR2
                           , level_in   IN PLS_INTEGER
                            )
      RETURN VARCHAR2;

   FUNCTION log_entries_after (timestamp_in IN DATE)
      RETURN sys_refcursor;

   PROCEDURE not_yet_implemented (program_name_in IN VARCHAR2);

   /* 1.2.12
       Provide switch to force display of "real" error in the error message,
       rather than simply showing the error handle. You should ask for
       "raise with message" when you are not going to use the get_error_info
       program to extract error information.
   */
   PROCEDURE raise_with_message;

   /* Only show the error instance handle in the error message. This is the
      default and assumes that you will be calling get_error_info to
      extract all the info. */
   PROCEDURE raise_with_handle;

   /* 1.2.17 Specify that you do NOT want the error state cached. This means
             that you will not have to explicitly mark the error as handled,
             but this also means that if successive layers in your call stack
             handle and re-raise your exception with QEM, you will see
             multiple entries in your error instance table. */
   PROCEDURE discard_error_state;

   PROCEDURE keep_error_state;                               /* The default */

   FUNCTION error_state_discarded
      RETURN BOOLEAN;
END q$error_manager;
/