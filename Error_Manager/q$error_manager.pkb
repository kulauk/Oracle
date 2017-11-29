CREATE OR REPLACE PACKAGE BODY q$error_manager
/*
| This program is a part of the Quest Error Manager for Oracle.
| This product is freeware and is not supported by Quest.
|
| www.quest.com

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
IS
   c_default_error_code      CONSTANT PLS_INTEGER := -20000;
   g_clipboard               maxvarchar2_t;
   g_clipboard_is_full       BOOLEAN DEFAULT FALSE;
   --
   c_trunc_warning VARCHAR2 (100)
         := '*** WARNING: Information truncated! ' ;
   c_warning_len             PLS_INTEGER := LENGTH (c_warning);
   --
   -- trace variables
   g_trace_enabled           BOOLEAN := FALSE;
   g_error_trace_enabled     BOOLEAN := TRUE;
   g_context_like            q$log.context%TYPE := NULL;
   g_include_timestamp       BOOLEAN := FALSE;
   g_multiple_contexts       BOOLEAN := FALSE;
   g_context_list            DBMS_SQL.varchar2s;
   /*
   Flag to indicate that the error has already been registered
   and raised within QD, so just propagate it on up the call stack.
   */
   g_error_instance_raised   q$error_instance.id%TYPE DEFAULT NULL;
   -- system settings
   g_grabbed_settings        error_info_rt;

   -- Global contexts
   TYPE gcontext_rt IS RECORD (
                          name    q$error_context.name%TYPE
                        , VALUE   q$error_context.VALUE%TYPE
                       );

   TYPE gcontext_tt
   IS
      TABLE OF gcontext_rt
         INDEX BY BINARY_INTEGER;

   g_gcontexts               gcontext_tt;

   -- current program
   TYPE runtime_rt IS RECORD (
                         package_name   all_objects.object_name%TYPE
                       , program_name   all_objects.object_name%TYPE
                      );

   /* 1.2.14 No longer used
   g_runtime                       runtime_rt;    -- "current" running program
   */

   -- collection of record
   TYPE runtime_nat IS TABLE OF runtime_rt;

   -- runtime stack implemented as a dense nested table.
   -- starts with element 1 and grows upward.
   g_runtime_nat             runtime_nat := runtime_nat ();
   -- trace target
   c_screen                  CONSTANT INTEGER := 0;
   c_table                   CONSTANT INTEGER := 1;
   c_file                    CONSTANT INTEGER := 2;
   g_target                  INTEGER := c_table;

   TYPE trace_file_info_rt IS RECORD (
                                 dir             maxvarchar2_t
                               , filename        maxvarchar2_t
                               , lines_written   PLS_INTEGER
                              );

   g_file_info               trace_file_info_rt;
   -- Every hundred lines written, close and reopen.
   c_close_threshold         CONSTANT PLS_INTEGER := 100;

   /* V1.2.11 show/hide setting */
   TYPE show_oracle_rt IS RECORD (
                             show        BOOLEAN DEFAULT FALSE
                           , revert      BOOLEAN DEFAULT FALSE
                           , revert_to   BOOLEAN
                          );

   g_show_oracle             show_oracle_rt;
   /* Option on how error is raised. */
   c_with_handle             CONSTANT PLS_INTEGER := -98;
   c_with_message            CONSTANT PLS_INTEGER := +75;
   g_raise_with              PLS_INTEGER := c_with_handle;

   g_discard_error_state     BOOLEAN := FALSE;

   /*
   1.2.12 Provide switch to force display of "real" error in the error message,
       rather than simply showing the error handle. This is needed when
       user is running tests via the API and is not retrieving errors via
       get_error_info.
   */
   PROCEDURE raise_with_message
   IS
   BEGIN
      g_raise_with := c_with_message;
   END raise_with_message;

   PROCEDURE raise_with_handle
   IS
   BEGIN
      g_raise_with := c_with_handle;
   END raise_with_handle;

   FUNCTION raising_with_message
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN g_raise_with = c_with_message;
   END raising_with_message;

   FUNCTION raising_with_handle
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN g_raise_with = c_with_handle;
   END raising_with_handle;

   /* END 1.2.12 changes */

   -- Private routines/handy utilities
   FUNCTION error_backtrace (prefix_with_error_in IN BOOLEAN DEFAULT FALSE)
      RETURN VARCHAR2
   IS
      l_errortrace   maxvarchar2_t := DBMS_UTILITY.format_error_stack;
      l_backtrace    maxvarchar2_t;
      l_return       maxvarchar2_t;
   BEGIN
      EXECUTE IMMEDIATE 'BEGIN :val := DBMS_UTILITY.format_error_backtrace; END;'
         USING OUT l_backtrace;

      l_return :=
         CASE
            WHEN prefix_with_error_in
            THEN
               l_errortrace || CHR (10) || CHR (10) || l_backtrace
            ELSE
               l_backtrace
         END;
      RETURN l_return;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN l_errortrace;
   END error_backtrace;

   FUNCTION oracle_app_error (code_in IN PLS_INTEGER)
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN code_in BETWEEN -20999 AND -20000;
   END oracle_app_error;

   PROCEDURE validate_oracle_error (code_in      IN     PLS_INTEGER
                                  , message_out     OUT VARCHAR2
                                  , is_valid_out    OUT BOOLEAN
                                   )
   IS
      l_message   maxvarchar2_t;
   BEGIN
      /* Take care of special case... */
      IF code_in IN (100, -1403)
      THEN
         is_valid_out := TRUE;
      ELSE
         l_message := SQLERRM (code_in);

         -- If SQLERRM does not find an entry, it return a string like one of these:
         -- If the number is negative...
         -- ORA-NNNNN: Message NNNN not found;  product=RDBMS; facility=ORA
         -- If the number is positive...
         --  -13000: non-ORACLE exception
         -- If the positive number is too big, we get numeric overflow.
         IF l_message LIKE 'ORA-_____: Message%not found;%'
            OR l_message LIKE '%: non-ORACLE exception%'
         THEN
            message_out := NULL;
            is_valid_out := FALSE;
         ELSE
            message_out := l_message;
            is_valid_out := TRUE;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         --numeric overflow
         IF SQLCODE = -1426
         THEN
            message_out := NULL;
            is_valid_out := FALSE;
         ELSE
            RAISE;
         END IF;
   END validate_oracle_error;

   FUNCTION is_valid_oracle_error (code_in IN PLS_INTEGER)
      RETURN BOOLEAN
   IS
      l_message   maxvarchar2_t;
      retval      BOOLEAN;
   BEGIN
      validate_oracle_error (code_in, l_message, retval);
      RETURN retval;
   END is_valid_oracle_error;

   FUNCTION sqlcode_name (error_code_in IN PLS_INTEGER)
      RETURN VARCHAR2
   IS
      l_return   maxvarchar2_t;     /* 1.2.16 all_objects.object_name%TYPE; */
   BEGIN
      l_return :=
         CASE error_code_in
            WHEN -6511
            THEN
               'CURSOR_ALREADY_OPEN'
            WHEN -0001
            THEN
               'DUP_VAL_ON_INDEX'
            WHEN -0051
            THEN
               'TIMEOUT_ON_RESOURCE'
            WHEN -1001
            THEN
               'INVALID_CURSOR'
            WHEN -1012
            THEN
               'NOT_LOGGED_ON'
            WHEN -1017
            THEN
               'LOGIN_DENIED'
            WHEN 100
            THEN
               'NO_DATA_FOUND'
            WHEN -1476
            THEN
               'ZERO_DIVIDE'
            WHEN -1722
            THEN
               'INVALID_NUMBER'
            WHEN -1422
            THEN
               'TOO_MANY_ROWS'
            WHEN -6500
            THEN
               'STORAGE_ERROR'
            WHEN -6501
            THEN
               'PROGRAM_ERROR'
            WHEN -6502
            THEN
               'VALUE_ERROR'
            WHEN -6530
            THEN
               'ACCESS_INTO_NULL'
            WHEN -6531
            THEN
               'COLLECTION_IS_NULL '
            WHEN -6532
            THEN
               'SUBSCRIPT_OUTSIDE_LIMIT'
            WHEN -6533
            THEN
               'SUBSCRIPT_BEYOND_COUNT '
            WHEN -650
            THEN
               'ROWTYPE_MISMATCH'
            WHEN -1410
            THEN
               'SYS_INVALID_ROWID'
            WHEN -30625
            THEN
               'SELF_IS_NULL'
            WHEN -6592
            THEN
               'CASE_NOT_FOUND'
            WHEN -1725
            THEN
               'USERENV_COMMITSCN_ERROR'
            WHEN -6548
            THEN
               'NO_DATA_NEEDED'
            ELSE
               UPPER(SUBSTR (SQLERRM (error_code_in)
                           , INSTR (SQLERRM (error_code_in), ':') + 2
                            ))
         END;
      RETURN l_return;
   END sqlcode_name;

   FUNCTION sqlcode_text (error_code_in IN PLS_INTEGER)
      RETURN VARCHAR2
   IS
   BEGIN
      IF error_code_in IN (100, -1403)
      THEN
         RETURN 'No data found';
      ELSE
         RETURN SQLERRM (error_code_in);
      END IF;
   END sqlcode_text;

   -- MOve from q$error_qp to remove dependency on package.
   FUNCTION q$error_qp_onerow (id_in IN q$error.id%TYPE)
      RETURN q$error%ROWTYPE
   IS
      CURSOR onerow_cur
      IS
         SELECT *
           FROM q$error
          WHERE id = id_in;

      onerow_rec   q$error%ROWTYPE;
   BEGIN
      OPEN onerow_cur;

      FETCH onerow_cur INTO onerow_rec;

      CLOSE onerow_cur;

      RETURN onerow_rec;
   END q$error_qp_onerow;

   FUNCTION q$error_instance_qp_onerow (id_in IN q$error_instance.id%TYPE)
      RETURN q$error_instance%ROWTYPE
   IS
      CURSOR onerow_cur
      IS
         SELECT *
           FROM q$error_instance
          WHERE id = id_in;

      onerow_rec   q$error_instance%ROWTYPE;
   BEGIN
      OPEN onerow_cur;

      FETCH onerow_cur INTO onerow_rec;

      CLOSE onerow_cur;

      RETURN onerow_rec;
   END q$error_instance_qp_onerow;

   PROCEDURE mark_q$error_raised (id_in IN q$error_instance.id%TYPE)
   IS
   BEGIN
      /* 1.2.17 Do not maintain state if user has requested this non-default
                behavior. That is, immediately mark it as handled. */
      IF error_state_discarded ()
      THEN
         mark_q$error_handled ();
      ELSE
         g_error_instance_raised := id_in;
      END IF;
   END mark_q$error_raised;

   -- Reset when get_error_info is called.
   PROCEDURE mark_q$error_handled
   IS
   BEGIN
      g_error_instance_raised := NULL;
      clear_gcontexts;
   END mark_q$error_handled;

   FUNCTION q$error_raised
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN g_error_instance_raised IS NOT NULL;
   END q$error_raised;

   FUNCTION q$error_instance_id_raised
      RETURN q$error_instance.id%TYPE
   IS
   BEGIN
      RETURN g_error_instance_raised;
   END q$error_instance_id_raised;

   -- returns the program name at the "top" of the runtime stack
   FUNCTION top_program_name
      RETURN all_objects.object_name%TYPE
   IS
      v_program_name   all_objects.object_name%TYPE;
   BEGIN
      IF (g_runtime_nat.COUNT > 0)
      THEN
         v_program_name := g_runtime_nat (g_runtime_nat.LAST).program_name;
      END IF;

      RETURN (v_program_name);
   END top_program_name;

   -- PBA 20040518
   FUNCTION top_package_name
      RETURN all_objects.object_name%TYPE
   IS
      v_package_name   all_objects.object_name%TYPE;
   BEGIN
      IF (g_runtime_nat.COUNT > 0)
      THEN
         v_package_name := g_runtime_nat (g_runtime_nat.LAST).program_name;
      END IF;

      RETURN (v_package_name);
   END top_package_name;

   -- PBA 20040518
   FUNCTION top_packprog_name
      RETURN VARCHAR2
   IS
   BEGIN
      RETURN top_package_name || '.' || top_program_name;
   END top_packprog_name;

   -- returns the current runtime context at the "top" of the runtime stack
   FUNCTION top_runtime
      RETURN runtime_rt
   IS
      v_runtime   runtime_rt;
   BEGIN
      IF (g_runtime_nat.COUNT > 0)
      THEN
         v_runtime := g_runtime_nat (g_runtime_nat.LAST);
      END IF;

      RETURN (v_runtime);
   END top_runtime;

   -- convert Boolean value to String
   FUNCTION strval (val IN BOOLEAN)
      RETURN VARCHAR2
   IS
   BEGIN
      IF val
      THEN
         RETURN ('TRUE');
      ELSIF NOT val
      THEN
         RETURN ('FALSE');
      ELSE
         RETURN ('NULL');
      END IF;
   END strval;

   -- public routines (exposed in the package header)
   -- -------------------------------------
   -- Tracing and DBMS_OUTPUT encapsulation
   -- -------------------------------------
   -- Tracing and DBMS_OUTPUT encapsulation
   -- switches output to the console
   -- NOTE: default is to Table
   PROCEDURE toscreen
   IS
   BEGIN
      g_target := c_screen;
   END toscreen;

   -- switches output to the q$log table
   -- NOTE: this is the default destination
   PROCEDURE totable
   IS
   BEGIN
      g_target := c_table;
   END totable;

   PROCEDURE totable (purge_in IN BOOLEAN)
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      totable ();

      IF purge_in
      THEN
         DELETE FROM q$log;

         COMMIT;
      END IF;
   END totable;

   PROCEDURE tofile (dir_in       IN VARCHAR2
                   , file_in      IN VARCHAR2
                   , overwrite_in IN BOOLEAN DEFAULT TRUE
                    )
   IS
   BEGIN
      g_file_info.dir := dir_in;
      g_file_info.filename := file_in;
      g_file_info.lines_written := 0;
      /*

      Write to file now occurs in front end when tracing is terminated

      g_file_info.file_handle :=
         utx_file.fopen (dir_in
                       , file_in
                       , CASE
                            WHEN overwrite_in
                               THEN 'W'
                            ELSE 'A'
                         END
                       , max_linesize      => 32767
                        );*/

      /*
      We still write to the table, and then dump to file later.
      */
      g_target := c_table;
   END tofile;

   -- simple DBMS_OUTPUT handling of 255 char limit
   -- looks for a newline, or chops to fit given length
   PROCEDURE pl (string_in IN VARCHAR2, length_in IN PLS_INTEGER := 80)
   IS
      v_len     PLS_INTEGER := LEAST (length_in, 255);
      v_len2    PLS_INTEGER;
      v_chr10   PLS_INTEGER;
      v_str     VARCHAR2 (2000);
   BEGIN
      IF LENGTH (string_in) > v_len
      THEN
         v_chr10 := INSTR (string_in, CHR (10));

         IF v_chr10 > 0 AND v_len >= v_chr10
         THEN
            v_len := v_chr10 - 1;
            v_len2 := v_chr10 + 1;
         ELSE
            v_len2 := v_len + 1;
         END IF;

         v_str := SUBSTR (string_in, 1, v_len);
         DBMS_OUTPUT.put_line (v_str);
         pl (string_in => SUBSTR (string_in, v_len2), length_in => length_in);
      ELSE
         DBMS_OUTPUT.put_line (string_in);
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         DBMS_OUTPUT.enable (1000000);
         DBMS_OUTPUT.put_line (v_str);
   END pl;

   -- converts the given boolean value to string,
   -- then writes it out as above
   PROCEDURE pl (val IN BOOLEAN)
   IS
   BEGIN
      pl (strval (val));
   END pl;

   -- as above but concatenates str with the string value of bool
   -- e.g., 'cursor%found TRUE'
   PROCEDURE pl (str IN VARCHAR2, bool IN BOOLEAN, len IN PLS_INTEGER := 80)
   IS
   BEGIN
      pl (string_in => str || ' ' || strval (bool), length_in => len);
   END pl;

   PROCEDURE pl (clob_in IN CLOB, length_in IN PLS_INTEGER := 80)
   IS
      buffer     VARCHAR2 (255);
      amount     BINARY_INTEGER := GREATEST (length_in, 255);
      position   INTEGER := 1;
   BEGIN
      LOOP
         DBMS_LOB.read (clob_in, amount, position, buffer);
         /* Display the buffer contents using the string overloading */
         pl (buffer);
         position := position + amount;
      END LOOP;
   EXCEPTION
      WHEN NO_DATA_FOUND OR VALUE_ERROR
      THEN
         pl ('** End of CLOB data **');
   END pl;

   PROCEDURE set_error_trace (onoff_in IN BOOLEAN)
   IS
   BEGIN
      IF onoff_in
      THEN
         error_trace_on;
      ELSE
         error_trace_off;
      END IF;
   END set_error_trace;

   PROCEDURE error_trace_on
   IS
   BEGIN
      g_error_trace_enabled := TRUE;
   END error_trace_on;

   PROCEDURE error_trace_off
   IS
   BEGIN
      g_error_trace_enabled := FALSE;
   END error_trace_off;

   FUNCTION error_trace_enabled
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN g_error_trace_enabled;
   END error_trace_enabled;

   FUNCTION string_to_list (string_in IN VARCHAR2, delim_in IN VARCHAR2)
      RETURN DBMS_SQL.varchar2s
   IS
      c_end_of_list   CONSTANT PLS_INTEGER := -99;
      l_item          maxvarchar2_t;
      l_startloc      PLS_INTEGER := 1;
      items_out       DBMS_SQL.varchar2s;

      PROCEDURE add_item (item_in IN VARCHAR2)
      IS
      BEGIN
         IF item_in = delim_in
         THEN
            /* We don't put delimiters into the collection. */
            NULL;
         ELSE
            items_out (items_out.COUNT + 1) := RTRIM (LTRIM (item_in));
         END IF;
      END;

      PROCEDURE get_next_item (string_in      IN     VARCHAR2
                             , startloc_inout IN OUT PLS_INTEGER
                             , item_out          OUT VARCHAR2
                              )
      IS
         l_loc   PLS_INTEGER;
      BEGIN
         l_loc := INSTR (string_in, delim_in, startloc_inout);

         IF l_loc = startloc_inout                    -- Previous item is NULL
         THEN
            item_out := NULL;
         ELSIF l_loc = 0                        -- Rest of string is last item
         THEN
            item_out := SUBSTR (string_in, startloc_inout);
         ELSE
            item_out :=
               SUBSTR (string_in, startloc_inout, l_loc - startloc_inout);
         END IF;

         IF l_loc = 0
         THEN
            startloc_inout := c_end_of_list;
         ELSE
            startloc_inout := l_loc + 1;
         END IF;
      END get_next_item;
   BEGIN
      IF string_in IS NOT NULL AND delim_in IS NOT NULL
      THEN
         LOOP
            get_next_item (string_in, l_startloc, l_item);
            add_item (l_item);
            EXIT WHEN l_startloc = c_end_of_list;
         END LOOP;
      END IF;

      RETURN items_out;
   END string_to_list;

   -- Clears out the trace contents. Currently just deletes from q$log.
   PROCEDURE clear_trace
   IS
   BEGIN
      EXECUTE IMMEDIATE 'truncate table q$log';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END clear_trace;

   PROCEDURE set_trace (onoff_in             IN BOOLEAN
                      , context_like_in      IN q$log.context%TYPE:= NULL
                      , include_timestamp_in IN BOOLEAN DEFAULT FALSE
                      , delimiter_in         IN VARCHAR2 DEFAULT ','
                       )
   IS
   BEGIN
      -- Special commands....
      IF onoff_in AND UPPER (context_like_in) = 'QCTO#TOTABLE'
      THEN
         totable (purge_in => TRUE);
         g_trace_enabled := onoff_in;
         g_context_like := '%';
         q$error_manager.trace (
            'set_trace to table via override with context "%"'
          , g_trace_enabled
         );
         g_include_timestamp := include_timestamp_in;
      ELSE
         g_trace_enabled := onoff_in;
         g_context_like := UPPER (NVL (context_like_in, '%'));
         q$error_manager.trace (
            'set_trace with context "' || g_context_like || '"'
          , g_trace_enabled
         );
         g_include_timestamp := include_timestamp_in;

         /*

         Write to file now occurs in front end when tracing is terminated
         IF NOT g_trace_enabled AND g_target = c_file
         THEN
            utx_file.fclose (g_file_info.file_handle);
         END IF;*/

         -- BM 1239 When turning off, set back to table, which is the default.
         IF NOT g_trace_enabled
         THEN
            totable;
         END IF;
      END IF;

      g_multiple_contexts := INSTR (context_like_in, delimiter_in) > 0;

      IF g_multiple_contexts
      THEN
         g_context_list := string_to_list (context_like_in, delimiter_in);
      END IF;
   END set_trace;

   PROCEDURE trace_on (context_like_in      IN q$log.context%TYPE:= NULL
                     , include_timestamp_in IN BOOLEAN DEFAULT FALSE
                     , delimiter_in         IN VARCHAR2 DEFAULT ','
                      )
   IS
   BEGIN
      set_trace (onoff_in               => TRUE
               , context_like_in        => context_like_in
               , include_timestamp_in   => include_timestamp_in
                );
   END trace_on;

   PROCEDURE trace_off (context_like_in      IN q$log.context%TYPE:= NULL
                      , include_timestamp_in IN BOOLEAN DEFAULT FALSE
                       )
   IS
   BEGIN
      set_trace (onoff_in               => FALSE
               , context_like_in        => context_like_in
               , include_timestamp_in   => include_timestamp_in
                );
   END trace_off;

   FUNCTION trace_enabled
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN g_trace_enabled;
   END trace_enabled;

   FUNCTION context_matches (context_in IN VARCHAR2)
      RETURN BOOLEAN
   IS
   BEGIN
      FOR indx IN 1 .. g_context_list.COUNT
      LOOP
         IF UPPER (context_in) LIKE UPPER (g_context_list (indx))
         THEN
            RETURN TRUE;
         END IF;
      END LOOP;

      RETURN FALSE;
   END context_matches;

   FUNCTION trace_enabled (context_in IN q$log.context%TYPE)
      RETURN BOOLEAN
   IS
      l_return   BOOLEAN DEFAULT FALSE;
   BEGIN
      IF g_trace_enabled
      THEN
         /* IF multiple contexts, then check for exact match. */

         IF g_multiple_contexts
         THEN
            l_return := context_matches (context_in);
         /* Use wildcarded comparision */
         ELSE
            l_return :=
               (g_context_like IS NULL
                OR UPPER (context_in) LIKE '%' || g_context_like || '%');
         END IF;
      END IF;

      RETURN l_return;
   END trace_enabled;

   FUNCTION full_log_string (context_in IN VARCHAR2
                           , text_in    IN VARCHAR2
                           , level_in   IN PLS_INTEGER
                            )
      RETURN VARCHAR2
   IS
      /*
      Cannot be longer than 4000 characters, since it is returned
      via a query.
      */
      c_timestamp CONSTANT VARCHAR2 (100)
            := TO_CHAR (SYSDATE, 'HH24:MI:SS-YYYYMMDD') ;
      l_string   maxvarchar2_t;
   BEGIN
      l_string :=
         CASE WHEN g_include_timestamp THEN c_timestamp || ' ' ELSE NULL END
         || context_in;
      l_string :=
            l_string
         || ' - '
         || SUBSTR (text_in, 1, 4000 - LENGTH (l_string) - 5);
      /* Ignore level
      || CASE
            WHEN level_in > 0
               THEN LPAD (' ', level_in)
            ELSE NULL
         END
      || context_in
      || ' - '
      || text_in;*/
      RETURN l_string;
   EXCEPTION
      WHEN VALUE_ERROR
      THEN
         RETURN SUBSTR (context_in || ' - ' || text_in, 1, 32767);
   END full_log_string;

   -- writes output to the screen or q$log table
   -- (see toscreen and totable above)
   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , text_in        IN q$log.text%TYPE
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   )
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      l_context   q$log.context%TYPE;
      l_text      q$log.text%TYPE;
   BEGIN
      IF trace_enabled (context_in) OR force_trace_in
      THEN
         -- Bypass encapsulation; problems with infinite loop.
         IF g_target = c_table
         THEN
            /* 1.2.18 Avoid context strings > 500 characters */
            l_context :=
               CASE
                  WHEN g_include_timestamp
                  THEN
                     TO_CHAR (SYSDATE, 'HH24:MI:SS-YYYYMMDD') || ' '
                  ELSE
                     NULL
               END;
            l_context := SUBSTR (l_context || context_in, 1, 500);
            l_text := SUBSTR (text_in, 1, 4000);

            INSERT INTO q$log (
                                  id
                                , context
                                , text
                                , call_stack
                                , created_on
                                , created_by
                       )
                VALUES (
                           q$log_seq.NEXTVAL
                         , l_context
                         , l_text
                         , DBMS_UTILITY.format_call_stack
                         , SYSTIMESTAMP
                         , USER
                       );
         ELSIF g_target = c_screen
         THEN
            pl (string_in => full_log_string (context_in, text_in, level_in));
         /*

         Write to file now occurs in front end when tracing is terminated

         ELSIF g_target = c_file
         THEN
            utx_file.put_line (g_file_info.file_handle
                             , full_log_string (context_in, text_in, level_in)
                              );
            -- 1.2.3: close and reopen file
            g_file_info.lines_written := g_file_info.lines_written + 1;

            IF g_file_info.lines_written >= c_close_threshold
            THEN
               utx_file.fclose (g_file_info.file_handle);
               g_file_info.file_handle :=
                  utx_file.fopen (g_file_info.dir
                                , g_file_info.filename
                                , 'A'
                                , max_linesize      => 32767
                                 );
               g_file_info.lines_written := 0;
            END IF;*/
         END IF;

         COMMIT;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         RAISE;
   END trace;

   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , boolean_in     IN BOOLEAN
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   )
   IS
   BEGIN
      IF boolean_in
      THEN
         trace (context_in
              , 'TRUE'
              , force_trace_in   => force_trace_in
              , level_in         => level_in
               );
      ELSIF NOT boolean_in
      THEN
         trace (context_in
              , 'FALSE'
              , force_trace_in   => force_trace_in
              , level_in         => level_in
               );
      ELSE
         trace (context_in
              , 'NULL BOOLEAN'
              , force_trace_in   => force_trace_in
              , level_in         => level_in
               );
      END IF;
   END trace;

   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , number_in      IN NUMBER
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   )
   IS
   BEGIN
      trace (context_in
           , TO_CHAR (number_in)
           , force_trace_in   => force_trace_in
           , level_in         => level_in
            );
   END trace;

   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , date_in        IN DATE
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   )
   IS
   BEGIN
      trace (context_in
           , TO_CHAR (date_in, 'YYYY MM DD HH24:MI:SS')
           , force_trace_in   => force_trace_in
           , level_in         => level_in
            );
   END trace;

   PROCEDURE trace (context_in     IN q$log.context%TYPE
                  , clob_in        IN CLOB
                  , force_trace_in IN BOOLEAN DEFAULT FALSE
                  , level_in       IN PLS_INTEGER DEFAULT NULL
                   )
   IS
      -- Maximum size set by column restriction
      buffer      VARCHAR2 (4000);
      --amount      BINARY_INTEGER := 4000;
      -- changed to 3900 since some chars were going missing from the start.      
      amount      BINARY_INTEGER := 3900;
      position    INTEGER := 1;
      l_notnull   BOOLEAN := FALSE;
   BEGIN
      LOOP
         DBMS_LOB.read (clob_in, amount, position, buffer);
         l_notnull := TRUE;
         trace (
            -- we always want the context so always pass it in
            --CASE WHEN position = 1 THEN context_in ELSE NULL END
            context_in
          , buffer
          , force_trace_in   => force_trace_in
          -- using this code stops the tracing from working
--          , level_in         => CASE
--                                  WHEN position = 1 THEN level_in
--                                  ELSE 0
--                               END
         );
         position := position + amount;
      END LOOP;
   EXCEPTION
      WHEN NO_DATA_FOUND OR VALUE_ERROR
      THEN
         -- Make sure that at least the trace message is written.
         IF NOT l_notnull
         THEN
            trace (context_in, '', force_trace_in, level_in);
         END IF;
   END trace;

   FUNCTION build_where_clause_show_trace (from_id_in      IN q$log.id%TYPE:= NULL
                                         , context_like_in IN VARCHAR2:= '%'
                                         , text_like_in    IN VARCHAR2:= '%'
                                          )
      RETURN VARCHAR2
   IS
      l_where   VARCHAR2 (1000);
   BEGIN
      IF from_id_in IS NULL
      THEN
         l_where := '1 = 1';
      ELSE
         l_where := 'id >= ' || from_id_in;
      END IF;

      l_where :=
            l_where
         || ' AND context LIKE ''%'
         || context_like_in
         || '%'' AND text LIKE ''%'
         || text_like_in
         || '%''';
      RETURN l_where;
   END build_where_clause_show_trace;

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
                        )
   IS
      l_where             VARCHAR2 (1000);
      l_entries           q$log_tc;
      l_index             PLS_INTEGER;
      limit_not_reached   BOOLEAN := TRUE;

      FUNCTION all_logs_by (where_clause_in IN VARCHAR2)
         RETURN q$log_tc
      IS
         TYPE weak_rc IS REF CURSOR;

         allrows_cur   weak_rc;
         l_rows        PLS_INTEGER;
         retval        q$log_tc;
      BEGIN
         OPEN allrows_cur FOR
            'SELECT
                ID,
                CONTEXT,
                TEXT,
                CALL_STACK,
                CREATED_ON,
                CREATED_BY,
                CHANGED_ON,
                CHANGED_BY
           FROM q$log WHERE '
            || where_clause_in;

         LOOP
            FETCH allrows_cur INTO retval (retval.COUNT + 1);

            EXIT WHEN allrows_cur%NOTFOUND;
         END LOOP;

         RETURN retval;
      END all_logs_by;
   BEGIN
      l_where :=
         build_where_clause_show_trace (from_id_in        => from_id_in
                                      , context_like_in   => context_like_in
                                      , text_like_in      => text_like_in
                                       );
      l_entries := all_logs_by (l_where);
      l_index := l_entries.FIRST;

      WHILE (l_index IS NOT NULL AND limit_not_reached)
      LOOP
         pl(   'ID-Context-Text = '
            || l_entries (l_index).id
            || '-'
            || l_entries (l_index).context
            || '-'
            || l_entries (l_index).text);

         IF include_call_stack_in
         THEN
            pl (l_entries (l_index).call_stack);
         END IF;

         pl ('------------------------------------------------');
         l_index := l_entries.NEXT (l_index);
         limit_not_reached := (l_index <= limit_in OR limit_in IS NULL);
      END LOOP;
   END show_trace;

   -------------------------------------------
   -- Error handling and raising functionality
   -------------------------------------------
   PROCEDURE internal_raise (code_in IN PLS_INTEGER, message_in IN VARCHAR2)
   IS
   BEGIN
      -- 4/2004: Keep this trace call in? Offer it as an option?
      -- 5/2005: Made it optional, based on the trace setting.
      IF error_trace_enabled
      THEN
         trace (
            'ERROR RAISED'
          ,    'Oracle error = '
            || code_in
            || ' - Error instance handle = '
            || message_in
          , FALSE
         );
      END IF;

      raise_application_error (code_in, message_in);
   END internal_raise;

   -- Global contexts; not tied to any specific instance.
   PROCEDURE add_gcontext (NAME_IN  IN q$error_context.name%TYPE
                         , value_in IN q$error_context.VALUE%TYPE
                          )
   IS
      l_name      q$error_context.name%TYPE := UPPER (NAME_IN);
      l_row       PLS_INTEGER := g_gcontexts.FIRST;
      l_matched   BOOLEAN := FALSE;
   BEGIN
      WHILE (l_row IS NOT NULL AND NOT l_matched)
      LOOP
         l_matched := l_name = g_gcontexts (l_row).name;

         IF NOT l_matched
         THEN
            l_row := g_gcontexts.NEXT (l_row);
         END IF;
      END LOOP;

      IF NOT l_matched
      THEN
         l_row := g_gcontexts.COUNT + 1;
      END IF;

      g_gcontexts (l_row).name := l_name;
      g_gcontexts (l_row).VALUE := value_in;
   END add_gcontext;

   -- Remove all global contexts.
   -- This is called by mark_q$error_handled as well.
   PROCEDURE clear_gcontexts
   IS
   BEGIN
      g_gcontexts.delete;
   END clear_gcontexts;

   -- Set a single context value
   PROCEDURE add_context (error_instance_id_in IN q$error_instance.id%TYPE
                        , NAME_IN              IN q$error_context.name%TYPE
                        , value_in             IN q$error_context.VALUE%TYPE
                        , validate_in          IN BOOLEAN DEFAULT TRUE
                         )
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      l_error_instance   q$error_instance%ROWTYPE;
   BEGIN
      IF NAME_IN IS NOT NULL
      THEN
         IF validate_in
         THEN
            l_error_instance :=
               q$error_instance_qp_onerow (error_instance_id_in);
         ELSE
            l_error_instance.id := error_instance_id_in;
         END IF;

         INSERT INTO q$error_context (
                                         id
                                       , error_instance_id
                                       , name
                                       , VALUE
                    )
             VALUES (
                        q$error_context_seq.NEXTVAL
                      , l_error_instance.id
                      , NAME_IN
                      , value_in
                    );

         COMMIT;
      END IF;
   EXCEPTION
      WHEN DUP_VAL_ON_INDEX
      THEN
         ROLLBACK;
      WHEN OTHERS
      THEN
         ROLLBACK;
         internal_raise (
            c_default_error_code
          ,    'Unable to insert QD context for "'
            || NAME_IN
            || '" with value "'
            || value_in
            || '" for instance ID '
            || l_error_instance.id
            || ' with Oracle error = '
            || SQLCODE
         );
   END add_context;

   PROCEDURE add_context (err_instance_id_in IN q$error_instance.id%TYPE
                        , NAME_IN            IN q$error_context.name%TYPE
                        , value_in           IN q$error_context.VALUE%TYPE
                        , validate_in        IN BOOLEAN DEFAULT TRUE
                         )
   IS
   BEGIN
      add_context (error_instance_id_in   => err_instance_id_in
                 , NAME_IN                => NAME_IN
                 , value_in               => value_in
                 , validate_in            => validate_in
                  );
   END;

   -- An error needs to be raised or logged.
   -- Get a message handle for this particular error instance.
   -- The "error message" id keeps track of both the error
   -- and message information. This program also serves as
   -- "record and go" and "go". In other words, we do not
   -- raise an error, but it is noted.
   --
   PROCEDURE register_error_instance (
      error_in              IN     q$error%ROWTYPE
    , text_in               IN     q$error_instance.MESSAGE%TYPE:= NULL
    , error_instance_id_out IN OUT q$error_instance.id%TYPE
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
   )
   IS
      l_error_instance_id   q$error_instance.id%TYPE;

      PROCEDURE add_context_values
      IS
         l_row   PLS_INTEGER;

         PROCEDURE add_one (NAME_IN IN VARCHAR2, value_in IN VARCHAR2)
         IS
         BEGIN
            IF NAME_IN IS NOT NULL
            THEN
               INSERT INTO q$error_context (
                                               id
                                             , error_instance_id
                                             , name
                                             , VALUE
                          )
                   VALUES (
                              q$error_context_seq.NEXTVAL
                            , l_error_instance_id
                            , NAME_IN
                            , value_in
                          );
            END IF;
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX
            THEN
               -- Entering another value for the same context. Mention it in the trace.
               trace (
                  'ADD CONTEXT'
                ,    'Duplicate entry for "'
                  || NAME_IN
                  || '" with value "'
                  || value_in
                  || '" for instance ID '
                  || l_error_instance_id
                , TRUE
               );
         END add_one;
      BEGIN
         add_one (name1_in, value1_in);
         add_one (name2_in, value2_in);
         add_one (name3_in, value3_in);
         add_one (name4_in, value4_in);
         add_one (name5_in, value5_in);
         --
         -- Add any global contexts
         l_row := g_gcontexts.FIRST;

         WHILE (l_row IS NOT NULL)
         LOOP
            add_one (g_gcontexts (l_row).name, g_gcontexts (l_row).VALUE);
            l_row := g_gcontexts.NEXT (l_row);
         END LOOP;
      END add_context_values;
   BEGIN
      IF q$error_raised
      THEN
         -- Just continue to propagate this error instance.
         error_instance_id_out := q$error_instance_id_raised;
      ELSE
         SELECT q$error_instance_seq.NEXTVAL
           INTO l_error_instance_id
           FROM DUAL;

         INSERT INTO q$error_instance (
                                          id
                                        , error_id
                                        , error_stack
                                        , call_stack
                                        , MESSAGE
                                        , system_error_code
                                        , system_error_message
                    )
             VALUES (
                        l_error_instance_id
                      , error_in.id
                      , g_grabbed_settings.error_stack
                      , g_grabbed_settings.call_stack
                      , text_in
                      , g_grabbed_settings.system_error_code
                      , g_grabbed_settings.system_error_message
                    );

         add_context_values;
         mark_q$error_raised (l_error_instance_id);
         error_instance_id_out := l_error_instance_id;
      END IF;
   END register_error_instance;

   PROCEDURE grab_settings
   IS
   BEGIN
      g_grabbed_settings.system_error_code := SQLCODE;
      g_grabbed_settings.system_error_message :=
         DBMS_UTILITY.format_error_stack
;
      g_grabbed_settings.error_stack := error_backtrace;
      g_grabbed_settings.call_stack := DBMS_UTILITY.format_call_stack;
   END grab_settings;

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
   )
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;

      FUNCTION error_from_repository (error_code_in IN PLS_INTEGER)
         RETURN q$error%ROWTYPE
      IS
         l_error   q$error%ROWTYPE;
      BEGIN
         /* If the error code is an Oracle error, do not create
            an "undefined" entry in the error log table.
         */
         BEGIN
            SELECT id
              INTO l_error.id
              FROM q$error
             WHERE code = error_code_in;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               l_error.id := NULL;
         END;

         IF l_error.id IS NULL             -- an unknown error; record as such
         THEN
            SELECT q$error_seq.NEXTVAL
              INTO l_error.id
              FROM DUAL;

            IF is_valid_oracle_error (error_code_in)
            THEN
               l_error.name := sqlcode_name (error_code_in);
               l_error.description := sqlcode_text (error_code_in);

               INSERT INTO q$error (
                                       id
                                     , code
                                     , name
                                     , description
                                     , error_category_name
                          )
                   VALUES (
                              l_error.id
                            , error_code_in
                            , l_error.name
                            , l_error.description
                            , 'Oracle Error'
                          );
            ELSE
               l_error.name := SQLERRM (error_code_in);

               INSERT INTO q$error (
                                       id
                                     , code
                                     , name
                                     , description
                                     , error_category_name
                          )
                   VALUES (
                              l_error.id
                            , error_code_in
                            , l_error.name
                            , 'Undefined runtime error: ' || error_code_in
                              || '. You should define this in the error repository.'
                            , 'UNDEFINED'
                          );
            END IF;

            l_error := q$error_qp_onerow (l_error.id);
         END IF;

         RETURN l_error;
      END error_from_repository;
   BEGIN
      IF q$error_raised
      THEN
         -- Just continue to propagate this error instance.
         error_instance_id_out := q$error_instance_id_raised;
      ELSE
         IF grab_settings_in
         THEN
            grab_settings;
         END IF;

         register_error_instance (
            error_from_repository (error_code_in)
          , text_in                 => text_in
          , error_instance_id_out   => error_instance_id_out
          , name1_in                => name1_in
          , value1_in               => value1_in
          , name2_in                => name2_in
          , value2_in               => value2_in
          , name3_in                => name3_in
          , value3_in               => value3_in
          , name4_in                => name4_in
          , value4_in               => value4_in
          , name5_in                => name5_in
          , value5_in               => value5_in
         );
         COMMIT;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         RAISE;
   END register_error;

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
   )
   IS
   BEGIN
      register_error (error_code_in           => error_code_in
                    , error_instance_id_out   => err_instance_id_out
                    , text_in                 => text_in
                    , name1_in                => name1_in
                    , value1_in               => value1_in
                    , name2_in                => name2_in
                    , value2_in               => value2_in
                    , name3_in                => name3_in
                    , value3_in               => value3_in
                    , name4_in                => name4_in
                    , value4_in               => value4_in
                    , name5_in                => name5_in
                    , value5_in               => value5_in
                    , grab_settings_in        => grab_settings_in
                     );
   END;

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
   )
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      l_error   q$error%ROWTYPE;
   BEGIN
      IF q$error_raised
      THEN
         -- Just continue to propagate this error instance.
         error_instance_id_out := q$error_instance_id_raised;
      ELSE
         IF grab_settings_in
         THEN
            grab_settings;
         END IF;

         BEGIN
            SELECT id
              INTO l_error.id
              FROM q$error
             WHERE name = error_name_in;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               l_error.id := NULL;         -- Create new error if not present.
         END;

         IF l_error.id IS NULL             -- an unknown error; record as such
         THEN
            SELECT q$error_seq.NEXTVAL
              INTO l_error.id
              FROM DUAL;

            INSERT INTO q$error (
                                    id
                                  , name
                                  , description
                       )
                VALUES (
                           l_error.id
                         , error_name_in
                         , 'Undefined runtime error: ' || error_name_in
                           || '. You should define this in the error repository.'
                       );

            l_error := q$error_qp_onerow (l_error.id);
         END IF;

         register_error_instance (
            l_error
          , text_in                 => text_in
          , error_instance_id_out   => error_instance_id_out
          , name1_in                => name1_in
          , value1_in               => value1_in
          , name2_in                => name2_in
          , value2_in               => value2_in
          , name3_in                => name3_in
          , value3_in               => value3_in
          , name4_in                => name4_in
          , value4_in               => value4_in
          , name5_in                => name5_in
          , value5_in               => value5_in
         );
         COMMIT;
      END IF;
   /* EXCEPTION
       WHEN OTHERS
       THEN
          ROLLBACK;
          RAISE;*/
   END register_error;

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
   )
   IS
   BEGIN
      register_error (error_name_in           => error_name_in
                    , error_instance_id_out   => err_instance_id_out
                    , text_in                 => text_in
                    , name1_in                => name1_in
                    , value1_in               => value1_in
                    , name2_in                => name2_in
                    , value2_in               => value2_in
                    , name3_in                => name3_in
                    , value3_in               => value3_in
                    , name4_in                => name4_in
                    , value4_in               => value4_in
                    , name5_in                => name5_in
                    , value5_in               => value5_in
                    , grab_settings_in        => grab_settings_in
                     );
   END;

   PROCEDURE register_error (
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
   )
   IS
      l_error_instance_id   q$error_instance.id%TYPE;
   BEGIN
      IF q$error_raised
      THEN
         -- Just continue to propagate this error instance.
         l_error_instance_id := q$error_instance_id_raised;
      ELSE
         IF grab_settings_in
         THEN
            grab_settings;
         END IF;

         register_error (error_code_in           => error_code_in
                       , error_instance_id_out   => l_error_instance_id
                       , text_in                 => text_in
                       , name1_in                => name1_in
                       , value1_in               => value1_in
                       , name2_in                => name2_in
                       , value2_in               => value2_in
                       , name3_in                => name3_in
                       , value3_in               => value3_in
                       , name4_in                => name4_in
                       , value4_in               => value4_in
                       , name5_in                => name5_in
                       , value5_in               => value5_in
                       , grab_settings_in        => FALSE
                        );
      END IF;
   END register_error;

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
   )
   IS
      l_error_instance_id   q$error_instance.id%TYPE;
   BEGIN
      IF q$error_raised
      THEN
         -- Just continue to propagate this error instance.
         l_error_instance_id := q$error_instance_id_raised;
      ELSE
         register_error (error_name_in           => error_name_in
                       , error_instance_id_out   => l_error_instance_id
                       , text_in                 => text_in
                       , name1_in                => name1_in
                       , value1_in               => value1_in
                       , name2_in                => name2_in
                       , value2_in               => value2_in
                       , name3_in                => name3_in
                       , value3_in               => value3_in
                       , name4_in                => name4_in
                       , value4_in               => value4_in
                       , name5_in                => name5_in
                       , value5_in               => value5_in
                        );
      END IF;
   END register_error;

   /* V1.2.11 Allow user to specify that Oracle errors should be passed
              directly in the Oracle error information, and not hidden
              behind the "error instance" information.

              "Hide" (don't show) is the default setting.
   */
   PROCEDURE show_oracle_error (
      show_in               IN BOOLEAN
    , revert_after_raise_in IN BOOLEAN DEFAULT FALSE
   )
   IS
   BEGIN
      g_show_oracle.show := NVL (show_in, FALSE);

      IF g_show_oracle.revert
      THEN
         g_show_oracle.revert_to := g_show_oracle.show;
      END IF;

      g_show_oracle.revert := NVL (revert_after_raise_in, FALSE);
   END show_oracle_error;

   PROCEDURE revert_oracle_error
   IS
   BEGIN
      IF g_show_oracle.revert
      THEN
         g_show_oracle.show := g_show_oracle.revert_to;
      END IF;
   END revert_oracle_error;

   -- Now raise the error that has been defined.
   PROCEDURE raise_error_instance (
      error_instance_id_in IN q$error_instance.id%TYPE
   )
   IS
      l_error_instance   q$error_instance%ROWTYPE;

      PROCEDURE issue_oracle_raise (
         error_instance_in IN q$error_instance%ROWTYPE
      )
      IS
         l_error        q$error%ROWTYPE;
         l_error_code   PLS_INTEGER;
         l_error_info   error_info_rt;
      BEGIN
         l_error := q$error_qp_onerow (id_in => error_instance_in.error_id);
         l_error_code :=
            NVL (l_error.code, error_instance_in.system_error_code)
;

         /* 1.2.12 If raising with message, load up the error message string. */
         IF raising_with_message ()
         THEN
            get_error_info (error_instance_in.id, l_error_info);
            internal_raise (
               c_default_error_code
             ,    'Error Code = '
               || l_error_info.code
               || CHR (10)
               || 'Error Message = '
               || l_error_info.text
               || CHR (10)
               || CHR (10)
               || 'Error Stack = '
               || l_error_info.error_stack
               || CHR (10)
               || 'Call Stack = '
               || l_error_info.call_stack
            );
         ELSIF oracle_app_error (l_error_code)
         THEN
            internal_raise (l_error_code, error_instance_in.MESSAGE);
         -- 1.0.5 Special case needed; cannot use EXCEPTION INIT with -1403 error.
         ELSIF l_error_code IN (100, -1403)
         THEN
            RAISE NO_DATA_FOUND;
         ELSIF l_error_code = 1
         THEN
            -- Undefined error information.
            internal_raise (
               c_default_error_code
             , NVL (error_instance_in.MESSAGE, 'User-defined error')
            );
         /* No Oracle error (0). */
         ELSIF l_error_code = 0
         THEN
            internal_raise (c_default_error_code, error_instance_in.MESSAGE);
         /* Using positive error numbers or we have an error instance
            with no error code (runtime-defined error). */
         ELSIF l_error_code > 0
               OR (l_error_code IS NULL AND error_instance_in.id IS NOT NULL)
         THEN
            internal_raise (
               c_default_error_code
             , c_error_prefix
               || LPAD (TO_CHAR (error_instance_in.id)
                      , c_error_code_len
                      , '0'
                       )
               || c_oracle_separator
               || LPAD (TO_CHAR (ABS (error_instance_in.system_error_code))
                      , c_oracle_code_len
                      , '0'
                       )
            );
         -- We have a message to pass back, at least.
         ELSIF l_error_code IS NULL AND error_instance_in.MESSAGE IS NOT NULL
         THEN
            internal_raise (c_default_error_code, error_instance_in.MESSAGE);
         ELSIF is_valid_oracle_error (l_error_code)
         THEN
            /* Negative Oracle error. */
            EXECUTE IMMEDIATE   'DECLARE '
                             || '   myexc EXCEPTION; '
                             || '   PRAGMA EXCEPTION_INIT (myexc, '
                             || TO_CHAR (l_error_code)
                             || ');'
                             || 'BEGIN '
                             || '   RAISE myexc;'
                             || 'END;';
         ELSE
            -- Undefined error information.
            internal_raise (
               c_default_error_code
             ,    'Unable to raise error instance '
               || error_instance_id_in
               || ' with error code '
               || l_error_code
            );
         END IF;
      END issue_oracle_raise;
   BEGIN
      l_error_instance := q$error_instance_qp_onerow (error_instance_id_in);
      -- Turn back on when we can check individual context values
      -- to see if they are required.
      --check_contexts (error_instance_in        => l_error_instance);
      issue_oracle_raise (l_error_instance);
   END raise_error_instance;

   PROCEDURE raise_error_instance (
      err_instance_id_in IN q$error_instance.id%TYPE
   )
   IS
   BEGIN
      raise_error_instance (error_instance_id_in => err_instance_id_in);
   END;

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
   )
   IS
      l_error_instance_id   q$error_instance.id%TYPE;
   BEGIN
      IF q$error_raised
      THEN
         -- Just continue to propagate this error instance.
         l_error_instance_id := q$error_instance_id_raised;
      ELSE
         IF grab_settings_in
         THEN
            grab_settings;
         END IF;

         register_error (error_code_in           => error_code_in
                       , error_instance_id_out   => l_error_instance_id
                       , text_in                 => text_in
                       , name1_in                => name1_in
                       , value1_in               => value1_in
                       , name2_in                => name2_in
                       , value2_in               => value2_in
                       , name3_in                => name3_in
                       , value3_in               => value3_in
                       , name4_in                => name4_in
                       , value4_in               => value4_in
                       , name5_in                => name5_in
                       , value5_in               => value5_in
                       , grab_settings_in        => FALSE
                        );
      END IF;

      raise_error_instance (error_instance_id_in => l_error_instance_id);
   END raise_error;

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
   )
   IS
      l_error_instance_id   q$error_instance.id%TYPE;
   BEGIN
      IF q$error_raised
      THEN
         -- Just continue to propagate this error instance.
         l_error_instance_id := q$error_instance_id_raised;
      ELSE
         IF grab_settings_in
         THEN
            grab_settings;
         END IF;

         register_error (error_name_in           => error_name_in
                       , error_instance_id_out   => l_error_instance_id
                       , text_in                 => text_in
                       , name1_in                => name1_in
                       , value1_in               => value1_in
                       , name2_in                => name2_in
                       , value2_in               => value2_in
                       , name3_in                => name3_in
                       , value3_in               => value3_in
                       , name4_in                => name4_in
                       , value4_in               => value4_in
                       , name5_in                => name5_in
                       , value5_in               => value5_in
                       , grab_settings_in        => FALSE
                        );
      END IF;

      raise_error_instance (error_instance_id_in => l_error_instance_id);
   END raise_error;

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
   )
   IS
   BEGIN
      raise_error (error_code_in      => SQLCODE     /*'UNANTICIPATED-ERROR'*/
                 , text_in            => text_in
                 , name1_in           => name1_in
                 , value1_in          => value1_in
                 , name2_in           => name2_in
                 , value2_in          => value2_in
                 , name3_in           => name3_in
                 , value3_in          => value3_in
                 , name4_in           => name4_in
                 , value4_in          => value4_in
                 , name5_in           => name5_in
                 , value5_in          => value5_in
                 , grab_settings_in   => grab_settings_in
                  );
   END raise_unanticipated;

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
   )
   IS
   BEGIN
      /* 1.2.15 Call register, not raise */
      register_error (error_code_in      => SQLCODE
                    , text_in            => text_in
                    , name1_in           => name1_in
                    , value1_in          => value1_in
                    , name2_in           => name2_in
                    , value2_in          => value2_in
                    , name3_in           => name3_in
                    , value3_in          => value3_in
                    , name4_in           => name4_in
                    , value4_in          => value4_in
                    , name5_in           => name5_in
                    , value5_in          => value5_in
                    , grab_settings_in   => grab_settings_in
                     );
   END register_oracle_error;

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
   )
   IS
   BEGIN
      register_error (error_code_in           => SQLCODE
                    , error_instance_id_out   => err_instance_id_out
                    , text_in                 => text_in
                    , name1_in                => name1_in
                    , value1_in               => value1_in
                    , name2_in                => name2_in
                    , value2_in               => value2_in
                    , name3_in                => name3_in
                    , value3_in               => value3_in
                    , name4_in                => name4_in
                    , value4_in               => value4_in
                    , name5_in                => name5_in
                    , value5_in               => value5_in
                    , grab_settings_in        => grab_settings_in
                     );
   END register_oracle_error;

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
   )
   IS
   BEGIN
      raise_error (error_code_in      => SQLCODE
                 , text_in            => text_in
                 , name1_in           => name1_in
                 , value1_in          => value1_in
                 , name2_in           => name2_in
                 , value2_in          => value2_in
                 , name3_in           => name3_in
                 , value3_in          => value3_in
                 , name4_in           => name4_in
                 , value4_in          => value4_in
                 , name5_in           => name5_in
                 , value5_in          => value5_in
                 , grab_settings_in   => grab_settings_in
                  );
   END raise_oracle_error;

   -- Retrieval of error information
   PROCEDURE parse_message (string_in             IN     VARCHAR2
                          , error_instance_id_out    OUT PLS_INTEGER
                          , extra_out                OUT VARCHAR2
                           )
   IS
      l_startloc   PLS_INTEGER := INSTR (string_in, ':');
      l_endloc     PLS_INTEGER;
      l_errmsg q$error.description%TYPE
            := LTRIM (SUBSTR (string_in, l_startloc + 1)) ;
   BEGIN
      /* V1.2.11 Get latest instance from global package variable.
                 If that is not available, then fall back on the
                 error message; in any case try to extract the
                 extra text.
      */
      IF /* 1.2.14 Do not directly reference variables
            g_error_instance_raised */
        q$error_instance_id_raised () IS NOT NULL
      THEN
         error_instance_id_out := q$error_instance_id_raised ();
      ELSE
         IF SUBSTR (LTRIM (l_errmsg), 1, c_error_prefix_len) = c_error_prefix
         THEN
            error_instance_id_out :=
               TO_NUMBER (
                  SUBSTR (l_errmsg, c_error_prefix_len + 1, c_error_code_len)
               );
         ELSE
            error_instance_id_out := NULL;
         END IF;
      END IF;

      extra_out :=
         SUBSTR (l_errmsg, c_error_prefix_len + c_error_code_len + 1);
   END parse_message;

   FUNCTION error_instance_from_string (string_in IN VARCHAR2)
      RETURN PLS_INTEGER
   IS
      l_errmsg   q$error.description%TYPE;
      retval     PLS_INTEGER;
   BEGIN
      parse_message (string_in, retval, l_errmsg);
      RETURN retval;
   END error_instance_from_string;

   FUNCTION error_instance_from_sqlerrm
      RETURN PLS_INTEGER
   IS
      l_loc      PLS_INTEGER;
      l_errmsg   q$error.description%TYPE;
      retval     PLS_INTEGER;
   BEGIN
      RETURN error_instance_from_string (DBMS_UTILITY.format_error_stack);
   END error_instance_from_sqlerrm;

   PROCEDURE substitute_strings (
      error_instance_in    IN     q$error_instance%ROWTYPE
    , error_message_inout  IN OUT q$error.substitute_string%TYPE
    , recommendation_inout IN OUT q$error.recommendation%TYPE
    , contexts_inout       IN OUT q$error_context_tc
   )
   IS
      l_row    PLS_INTEGER;
      retval   q$error.substitute_string%TYPE;

      PROCEDURE replace_all_occurrences (
         context_in     IN q$error_context%ROWTYPE
       , context_row_in IN PLS_INTEGER
      )
      IS
         -- Maintain format of string while doing replacements on
         -- on named strings case IN sensitively.
         c_upper_subst_name q$error_context.name%TYPE
               := c_subst_char || UPPER (context_in.name) ;
         c_len     PLS_INTEGER := LENGTH (context_in.name);
         l_loc     PLS_INTEGER;
         l_found   BOOLEAN DEFAULT FALSE;
      BEGIN
         IF error_message_inout IS NOT NULL
         THEN
            LOOP
               l_loc :=
                  INSTR (UPPER (error_message_inout), c_upper_subst_name, 1);
               EXIT WHEN l_loc = 0;
               l_found := TRUE;
               error_message_inout :=
                     SUBSTR (error_message_inout, 1, l_loc - 1)
                  || context_in.VALUE
                  || SUBSTR (error_message_inout, l_loc + c_len + 1);
            END LOOP;
         END IF;

         IF recommendation_inout IS NOT NULL
         THEN
            LOOP
               l_loc :=
                  INSTR (UPPER (recommendation_inout), c_upper_subst_name, 1);
               EXIT WHEN l_loc = 0;
               l_found := TRUE;
               recommendation_inout :=
                     SUBSTR (recommendation_inout, 1, l_loc - 1)
                  || context_in.VALUE
                  || SUBSTR (recommendation_inout, l_loc + c_len + 1);
            END LOOP;
         END IF;

         IF l_found
         THEN
            contexts_inout.delete (context_row_in);
         END IF;
      END replace_all_occurrences;
   BEGIN
      IF error_message_inout IS NOT NULL OR recommendation_inout IS NOT NULL
      THEN
         l_row := contexts_inout.FIRST;

         WHILE (l_row IS NOT NULL)
         LOOP
            replace_all_occurrences (contexts_inout (l_row), l_row);
            l_row := contexts_inout.NEXT (l_row);
         END LOOP;
      END IF;
   END substitute_strings;

   PROCEDURE get_error_info (
      error_instance_id_in IN     q$error_instance.id%TYPE
    , error_info_out          OUT error_info_rt
   )
   IS
      l_error_instance   q$error_instance%ROWTYPE;
      l_error            q$error%ROWTYPE;

      PROCEDURE subst_for_msg_help_strings
      IS
         l_contexts   q$error_context_tc;

         PROCEDURE add_to_text (
            new_string_in IN VARCHAR2
          , delimiter_in  IN VARCHAR2:= CHR (10) || CHR (10)
         )
         IS
         BEGIN
            IF new_string_in IS NOT NULL AND error_info_out.text IS NOT NULL
            THEN
               error_info_out.text :=
                  error_info_out.text || delimiter_in || new_string_in;
            ELSIF new_string_in IS NOT NULL
            THEN
               error_info_out.text := new_string_in;
            END IF;
         END add_to_text;

         PROCEDURE add_remaining_contexts
         IS
            l_row   PLS_INTEGER;
         BEGIN
            l_row := l_contexts.FIRST;

            IF l_row IS NOT NULL
            THEN
               -- Insert a blank line.
               add_to_text (' ', CHR (10));

               WHILE (l_row IS NOT NULL)
               LOOP
                  add_to_text (
                        l_contexts (l_row).name
                     || ' = '
                     || l_contexts (l_row).VALUE
                   , CHR (10)
                  );
                  l_row := l_contexts.NEXT (l_row);
               END LOOP;
            END IF;
         --1.0.4 If string gets too big then just pass back what we've got.
         EXCEPTION
            WHEN VALUE_ERROR
            THEN
               NULL;
         END add_remaining_contexts;
      BEGIN
         error_info_out.text := l_error_instance.MESSAGE;

         -- Use context values for substitution, then add any contexts
         -- that were not used at the end of the string.
         SELECT *
           BULK COLLECT
           INTO l_contexts
           FROM q$error_context
          WHERE error_instance_id = l_error_instance.id;

         substitute_strings (l_error_instance
                           , l_error.substitute_string
                           , l_error.recommendation
                           , l_contexts
                            );
         error_info_out.recommendation := l_error.recommendation;

         IF error_info_out.text IS NULL AND l_error.substitute_string IS NULL
         THEN
            -- Fall back on the generic descriptoin.
            error_info_out.text := l_error.description;
         ELSE
            add_to_text (l_error.substitute_string);
         END IF;

         --
         add_remaining_contexts;
      END subst_for_msg_help_strings;
   BEGIN
      IF error_instance_id_in IS NULL
      THEN
         -- Fall back on current error information.
         error_info_out.code := SQLCODE;
         error_info_out.name := 'Oracle Error';
         error_info_out.system_error_code := SQLCODE;
         error_info_out.system_error_message :=
            DBMS_UTILITY.format_error_stack;
         error_info_out.text := DBMS_UTILITY.format_error_stack;
      ELSE
         l_error_instance := q$error_instance_qp_onerow (error_instance_id_in);
         l_error := q$error_qp_onerow (l_error_instance.error_id);
         --
         error_info_out.error_category_name := l_error.error_category_name;         
         error_info_out.code := l_error.code;
         error_info_out.name := l_error.name;
         --
         subst_for_msg_help_strings;
         /* 1.2 Don't get grabbed settings information. Get the
                data from the error instance row.
           --
           -- Transfer grabbed settings
           error_info_out.system_error_code :=
                                        g_grabbed_settings.system_error_code;
           error_info_out.system_error_message :=
                                     g_grabbed_settings.system_error_message;
           error_info_out.error_stack := g_grabbed_settings.error_stack;
           error_info_out.call_stack := g_grabbed_settings.call_stack;
         */
         error_info_out.system_error_code :=
            l_error_instance.system_error_code;
         error_info_out.system_error_message :=
            l_error_instance.system_error_message;
         error_info_out.error_stack := l_error_instance.error_stack;
         error_info_out.call_stack := l_error_instance.call_stack;
         --
         -- All done, revert to "no error" state.
         mark_q$error_handled;
      END IF;
   END get_error_info;

   PROCEDURE get_error_info (error_info_out OUT error_info_rt)
   IS
      l_message             maxvarchar2_t := DBMS_UTILITY.format_error_stack;
      l_extra               q$error.description%TYPE;
      l_error_instance_id   q$error_instance.id%TYPE;
   BEGIN
      parse_message (l_message, l_error_instance_id, l_extra);

      IF l_error_instance_id IS NOT NULL
      THEN
         get_error_info (error_instance_id_in   => l_error_instance_id
                       , error_info_out         => error_info_out
                        );
      ELSE
         -- Of the form ORA-NNNNN: Message
         error_info_out.code :=
            SUBSTR (l_message, 4, INSTR (l_message, ':') - 4);
         error_info_out.name := 'System Error';
         error_info_out.text := l_message;
         error_info_out.system_error_code := error_info_out.code;
         error_info_out.system_error_message := error_info_out.text;
      END IF;

      --
      -- All done, revert to "no error" state.
      mark_q$error_handled;
   END get_error_info;

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
   )
   IS
      l_error   error_info_rt;
   BEGIN
      get_error_info (error_instance_id_in   => error_instance_id_in
                    , error_info_out         => l_error
                     );
      --
      -- All this logic repeated in next overloading!
      code_out := l_error.code;
      name_out := l_error.name;
      text_out := l_error.text;
      recommendation_out := l_error.recommendation;
      system_error_code_out := l_error.system_error_code;
      system_error_message_out := l_error.system_error_message;
      error_stack_out := l_error.error_stack;
      call_stack_out := l_error.call_stack;
      environment_info_out := l_error.environment_info;
   END get_error_info;

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
   )
   IS
      l_error               error_info_rt;
      l_extra               q$error.description%TYPE;
      l_error_instance_id   q$error_instance.id%TYPE;
   BEGIN
      parse_message (err_message_in, l_error_instance_id, l_extra);

      IF l_error_instance_id IS NOT NULL
      THEN
         get_error_info (error_instance_id_in   => l_error_instance_id
                       , error_info_out         => l_error
                        );
         code_out := l_error.code;
         name_out := l_error.name;
         text_out := l_error.text;
         /* 1.0.3 Do not add extra information. Avoid possible -6502 and also
          "junking up" the text with extra information.
       IF RTRIM (RTRIM (RTRIM (l_extra, ' '), CHR (10)), CHR (13)) IS NOT NULL
         THEN
            text_out :=
                  l_error.text
               || CHR (10)
               || 'Additional error information: '
               || CHR (10)
               || l_extra;
         END IF;
       */
         recommendation_out := l_error.recommendation;
         system_error_code_out := l_error.system_error_code;
         system_error_message_out := l_error.system_error_message;
         error_stack_out := l_error.error_stack;
         call_stack_out := l_error.call_stack;
      ELSE
         -- Of the form ORA-NNNNN: Message
         code_out :=
            SUBSTR (err_message_in, 4, INSTR (err_message_in, ':') - 4)
;
         name_out := 'System Error';
         text_out := err_message_in;
         system_error_code_out := code_out;
         system_error_message_out := text_out;
         environment_info_out := l_error.environment_info;
      END IF;

      --
      -- All done, revert to "no error" state.
      mark_q$error_handled;
   END get_error_info;

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
   )
   IS
   BEGIN
      get_error_info (err_message_in             => DBMS_UTILITY.format_error_stack
                    , code_out                   => code_out
                    , name_out                   => name_out
                    , text_out                   => text_out
                    , system_error_code_out      => system_error_code_out
                    , system_error_message_out   => system_error_message_out
                    , recommendation_out         => recommendation_out
                    , error_stack_out            => error_stack_out
                    , call_stack_out             => call_stack_out
                    , environment_info_out       => environment_info_out
                     );
   END get_error_info;

   -- 1.2 Get message text only
   FUNCTION error_message
      RETURN VARCHAR2
   IS
      l_extra               q$error.description%TYPE;
      l_error_instance_id   q$error_instance.id%TYPE;
      l_error               error_info_rt;
   BEGIN
      parse_message (DBMS_UTILITY.format_error_stack
                   , l_error_instance_id
                   , l_extra
                    );
      get_error_info (error_instance_id_in   => l_error_instance_id
                    , error_info_out         => l_error
                     );
      RETURN NVL (l_error.text, l_error.system_error_message);
   END error_message;

   FUNCTION error_clipboard (clear_clipboard_in IN BOOLEAN DEFAULT TRUE)
      RETURN VARCHAR2
   IS
      l_clipboard   maxvarchar2_t;
   BEGIN
      l_clipboard := g_clipboard;

      IF clear_clipboard_in
      THEN
         clear_error_clipboard;
      END IF;

      RETURN l_clipboard;
   END error_clipboard;

   FUNCTION error_clipboard_is_full
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN g_clipboard_is_full;
   /*
  IF g_clipboard IS NULL
   THEN
      RETURN FALSE;
   ELSE
      RETURN (c_warning LIKE g_clipboard || '%');
   END IF;
  */
   END error_clipboard_is_full;

   PROCEDURE clear_error_clipboard
   IS
   BEGIN
      g_clipboard := NULL;
      g_clipboard_is_full := FALSE;
   END clear_error_clipboard;

   PROCEDURE add_to_error_clipboard (str IN VARCHAR2)
   IS
   BEGIN
      IF g_clipboard IS NULL
      THEN
         g_clipboard := str;
      ELSE
         g_clipboard := g_clipboard || CHR (10) || str;
      END IF;
   END add_to_error_clipboard;

   PROCEDURE show_error_info (
      error_instance_id_in IN q$error_instance.id%TYPE
    , copy_to_clipboard_in IN BOOLEAN DEFAULT FALSE
   )
   IS
      code_out                   q$error.code%TYPE;
      name_out                   q$error.name%TYPE;
      text_out                   q$error_instance.MESSAGE%TYPE;
      system_error_code_out      q$error_instance.system_error_code%TYPE;
      system_error_message_out   q$error_instance.system_error_message%TYPE;
      recommendation_out         q$error.recommendation%TYPE;
      error_stack_out            q$error_instance.error_stack%TYPE;
      call_stack_out             q$error_instance.call_stack%TYPE;
      environment_info_out       q$error_instance.environment_info%TYPE;

      PROCEDURE pl (str IN VARCHAR2)
      IS
         already_full exception;
      BEGIN
         IF error_clipboard_is_full
         THEN
            RAISE already_full;
         END IF;

         IF copy_to_clipboard_in
         THEN
            add_to_error_clipboard (str);
         ELSE
            q$error_manager.pl (str);
         END IF;
      EXCEPTION
         WHEN already_full
         THEN
            NULL;
         WHEN VALUE_ERROR
         THEN
            g_clipboard_is_full := TRUE;

            IF LENGTH (g_clipboard) > c_varchar2_max_length - c_warning_len
            THEN
               g_clipboard :=
                  c_trunc_warning
                  || SUBSTR (g_clipboard
                           , 1
                           , c_varchar2_max_length - c_warning_len
                            );
            ELSE
               g_clipboard := c_trunc_warning || g_clipboard;
            END IF;
      END pl;

      PROCEDURE pl_header (str IN VARCHAR2)
      IS
      BEGIN
         pl ('=================================================');
         pl (str);
      END pl_header;

      PROCEDURE show_contexts
      IS
         l_context   q$error_context_tc;
         l_row       PLS_INTEGER;
      BEGIN
         SELECT *
           BULK COLLECT
           INTO l_context
           FROM q$error_context
          WHERE error_instance_id = error_instance_id_in;

         l_row := l_context.FIRST;

         IF l_row IS NOT NULL
         THEN
            pl ('   > Error context information:');

            WHILE (l_row IS NOT NULL)
            LOOP
               pl ('      Context = "' || l_context (l_row).name || '"');
               pl ('      Value = "' || l_context (l_row).VALUE || '"');
               l_row := l_context.NEXT (l_row);
            END LOOP;
         END IF;
      END show_contexts;
   BEGIN
      get_error_info (error_instance_id_in       => error_instance_id_in
                    , code_out                   => code_out
                    , name_out                   => name_out
                    , text_out                   => text_out
                    , system_error_code_out      => system_error_code_out
                    , system_error_message_out   => system_error_message_out
                    , recommendation_out         => recommendation_out
                    , error_stack_out            => error_stack_out
                    , call_stack_out             => call_stack_out
                    , environment_info_out       => environment_info_out
                     );
      pl_header ('Error report for error instance ' || error_instance_id_in);
      pl ('   > Code-Name: ' || code_out || '-' || name_out);
      pl ('   > Text: ' || text_out);
      pl ('   > System error code: ' || system_error_code_out);
      pl ('   > System error message: ' || system_error_message_out);
      pl ('   > Recommendation: ' || recommendation_out);
      pl ('   > Error stack: ' || error_stack_out);
      pl ('   > Call stack: ' || call_stack_out);

      IF environment_info_out IS NOT NULL
      THEN
         pl_header ('   > Environmental Information');
         pl ('   ' || environment_info_out);
      END IF;

      show_contexts;
   END show_error_info;

   PROCEDURE show_errors (cursor_in            IN weak_refcursor
                        , copy_to_clipboard_in IN BOOLEAN DEFAULT FALSE
                         )
   IS
      l_error_id   PLS_INTEGER;
   BEGIN
      LOOP
         FETCH cursor_in INTO l_error_id;

         EXIT WHEN cursor_in%NOTFOUND;
         show_error_info (l_error_id
                        , copy_to_clipboard_in   => copy_to_clipboard_in
                         );
         EXIT WHEN error_clipboard_is_full;
      END LOOP;
   END show_errors;

   PROCEDURE show_errors_after (date_in              IN DATE
                              , copy_to_clipboard_in IN BOOLEAN DEFAULT FALSE
                               )
   IS
      l_cursor   weak_refcursor;
   BEGIN
      OPEN l_cursor FOR
           SELECT id
             FROM q$error_instance
            WHERE created_on >= date_in
         ORDER BY id;

      show_errors (l_cursor, copy_to_clipboard_in => copy_to_clipboard_in);

      CLOSE l_cursor;
   END show_errors_after;

   PROCEDURE show_errors_with_message (
      text_in              IN VARCHAR2
    , copy_to_clipboard_in IN BOOLEAN DEFAULT FALSE
   )
   IS
      l_cursor   weak_refcursor;
   BEGIN
      OPEN l_cursor FOR
           SELECT id
             FROM q$error_instance
            WHERE INSTR (UPPER (MESSAGE), UPPER (text_in)) > 0
         ORDER BY id;

      show_errors (l_cursor, copy_to_clipboard_in => copy_to_clipboard_in);

      CLOSE l_cursor;
   END show_errors_with_message;

   PROCEDURE show_errors_with_code (
      error_code_in           IN PLS_INTEGER
    , is_system_error_code_in IN BOOLEAN DEFAULT FALSE
    , copy_to_clipboard_in    IN BOOLEAN DEFAULT FALSE
   )
   IS
      l_cursor   weak_refcursor;
   BEGIN
      IF is_system_error_code_in
      THEN
         OPEN l_cursor FOR
              SELECT id
                FROM q$error_instance
               WHERE system_error_code = error_code_in
            ORDER BY id;
      ELSE
         OPEN l_cursor FOR
              SELECT i.id
                FROM q$error_instance i, q$error e
               WHERE i.error_id = e.id AND code = error_code_in
            ORDER BY i.id;
      END IF;

      show_errors (l_cursor, copy_to_clipboard_in => copy_to_clipboard_in);

      CLOSE l_cursor;
   END show_errors_with_code;

   PROCEDURE show_errors_for (where_clause_in      IN VARCHAR2
                            , copy_to_clipboard_in IN BOOLEAN DEFAULT FALSE
                             )
   IS
      l_cursor   weak_refcursor;
   BEGIN
      OPEN l_cursor FOR
            'SELECT ID FROM q$error_instance WHERE '
         || where_clause_in
         || ' ORDER BY ID';

      show_errors (l_cursor, copy_to_clipboard_in => copy_to_clipboard_in);

      CLOSE l_cursor;
   END show_errors_for;

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
                    )
   IS
   BEGIN
      IF condition_in IS NULL OR NOT condition_in
      THEN
         trace ('ASSERTION FAILURE', text_in, FALSE);
         raise_error (error_code_in      => error_code_in
                    , text_in            => text_in
                    , name1_in           => name1_in
                    , value1_in          => value1_in
                    , name2_in           => name2_in
                    , value2_in          => value2_in
                    , name3_in           => name3_in
                    , value3_in          => value3_in
                    , name4_in           => name4_in
                    , value4_in          => value4_in
                    , name5_in           => name5_in
                    , value5_in          => value5_in
                    , grab_settings_in   => TRUE
                     );
      END IF;
   END assert;

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
                    )
   IS
   BEGIN
      IF condition_in IS NULL OR NOT condition_in
      THEN
         trace ('ASSERT', text_in, TRUE);
         raise_error (error_name_in      => error_name_in
                    , text_in            => text_in
                    , name1_in           => name1_in
                    , value1_in          => value1_in
                    , name2_in           => name2_in
                    , value2_in          => value2_in
                    , name3_in           => name3_in
                    , value3_in          => value3_in
                    , name4_in           => name4_in
                    , value4_in          => value4_in
                    , name5_in           => name5_in
                    , value5_in          => value5_in
                    , grab_settings_in   => TRUE
                     );
      END IF;
   END assert;

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
                    )
   IS
   BEGIN
      IF condition_in IS NULL OR NOT condition_in
      THEN
         trace ('ASSERT', text_in, TRUE);
         raise_error (error_name_in      => 'ASSERTION-FAILURE'
                    , text_in            => text_in
                    , name1_in           => name1_in
                    , value1_in          => value1_in
                    , name2_in           => name2_in
                    , value2_in          => value2_in
                    , name3_in           => name3_in
                    , value3_in          => value3_in
                    , name4_in           => name4_in
                    , value4_in          => value4_in
                    , name5_in           => name5_in
                    , value5_in          => value5_in
                    , grab_settings_in   => TRUE
                     );
      END IF;
   END assert;

   PROCEDURE start_execution (program_name_in IN VARCHAR2:= NULL
                            , information_in  IN VARCHAR2:= NULL
                             )
   IS
   BEGIN
      NULL;
   END;

   /*
   Test builder validation:
      * return a status string composed of type:message
     * if no prefix, then it is an error
   */
   FUNCTION is_warning (status_in IN VARCHAR2)
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN status_in LIKE c_warning || '%';
   END is_warning;

   FUNCTION is_error (status_in IN VARCHAR2)
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN status_in LIKE c_error || '%';
   END is_error;

   FUNCTION is_info_msg (status_in IN VARCHAR2)
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN status_in LIKE c_info_msg || '%';
   END is_info_msg;

   PROCEDURE parse_status_string (status_in       IN     VARCHAR2
                                , status_type_out    OUT VARCHAR2
                                , message_out        OUT VARCHAR2
                                 )
   IS
      l_loc   PLS_INTEGER := INSTR (status_in, c_status_delimiter);
   BEGIN
      IF l_loc = 0
      THEN
         status_type_out := c_error;
         message_out := status_in;
      ELSE
         status_type_out := SUBSTR (status_in, 1, l_loc - 1);
         message_out := SUBSTR (status_in, l_loc + 1);
      END IF;
   END parse_status_string;

   FUNCTION make_a_string (header_in IN VARCHAR2, status_in IN VARCHAR2)
      RETURN VARCHAR2
   IS
   BEGIN
      RETURN header_in || c_status_delimiter || status_in
             || CASE
                   WHEN trace_enabled
                   THEN
                      CHR (10) || CHR (10) || error_backtrace
                   ELSE
                      NULL
                END;
   END make_a_string;

   FUNCTION make_an_info_msg (status_in IN VARCHAR2)
      RETURN VARCHAR2
   IS
   BEGIN
      RETURN make_a_string (c_info_msg, status_in);
   END make_an_info_msg;

   FUNCTION make_a_warning (status_in IN VARCHAR2)
      RETURN VARCHAR2
   IS
   BEGIN
      RETURN make_a_string (c_warning, status_in);
   END make_a_warning;

   FUNCTION make_an_error (status_in IN VARCHAR2)
      RETURN VARCHAR2
   IS
   BEGIN
      RETURN make_a_string (c_error, status_in);
   END make_an_error;

   PROCEDURE make_a_warning (status_inout IN OUT VARCHAR2)
   IS
   BEGIN
      status_inout := make_a_warning (status_inout);
   END make_a_warning;

   PROCEDURE make_an_error (status_inout IN OUT VARCHAR2)
   IS
   BEGIN
      status_inout := make_an_error (status_inout);
   END make_an_error;

   PROCEDURE make_an_info_msg (status_inout IN OUT VARCHAR2)
   IS
   BEGIN
      status_inout := make_an_info_msg (status_inout);
   END make_an_info_msg;

   FUNCTION log_entries_after (timestamp_in IN DATE)
      RETURN sys_refcursor
   IS
      CV   sys_refcursor;
   BEGIN
      IF trace_enabled
      THEN
         trace ('log_entries_after for date', timestamp_in, TRUE);
      END IF;

      OPEN CV FOR
           SELECT full_log_string (context, text, NULL)
             FROM q$log ql
         /* WHERE BM2066 return all rows for now
              ql.created_on >= timestamp_in*/
         ORDER BY ql.id;

      RETURN CV;
   END log_entries_after;

   PROCEDURE not_yet_implemented (program_name_in IN VARCHAR2)
   IS
   BEGIN
      DBMS_OUTPUT.put_line (
         'Callstack that found its way to "' || program_name_in || '"'
      );
      DBMS_OUTPUT.put_line (DBMS_UTILITY.format_call_stack);
      raise_application_error (
         c_not_yet_implemented
       ,    'Program named "'
         || program_name_in
         || '" has not yet been implemented.'
         || ' Enable SERVEROUTPUT to see callstack for this program call.'
      );
   END not_yet_implemented;

   PROCEDURE discard_error_state
   IS
   BEGIN
      g_discard_error_state := TRUE;
   END;

   PROCEDURE keep_error_state
   IS
   BEGIN
      g_discard_error_state := FALSE;
   END;

   FUNCTION error_state_discarded
      RETURN BOOLEAN
   IS
   BEGIN
      RETURN g_discard_error_state;
   END;
END q$error_manager;
/