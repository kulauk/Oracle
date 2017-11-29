CREATE OR REPLACE PACKAGE BODY common.pkg_app_manager
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
        RETURN pkg_app_manager_state.g_PkgName_pkg_app_mgr;
    END get_package_name;    
    --==========================================================================
    -- Get
    -- .......
    FUNCTION get_id_trace_summary
    RETURN VARCHAR2
    IS
    BEGIN
        RETURN pkg_app_manager_state.g_id_trace_summary;
    END get_id_trace_summary;  
    --==========================================================================
    -- Set
    -- .......
    PROCEDURE set_id_trace_summary (p_id_trace_summary   IN trace_summary.id_trace_summary%TYPE)
    IS
    BEGIN
        pkg_app_manager_state.g_id_trace_summary := p_id_trace_summary;
    END set_id_trace_summary;   
    --==========================================================================
    -- Get
    -- .......
    FUNCTION get_trace_level
    RETURN PLS_INTEGER
    IS
    BEGIN
        RETURN pkg_app_manager_state.g_trace_level;
    END get_trace_level;  
    --==========================================================================
    -- Set
    -- .......
    PROCEDURE set_trace_level (p_trace_level   IN PLS_INTEGER)
    IS
    BEGIN
        pkg_app_manager_state.g_trace_level := p_trace_level;
    END set_trace_level; 
    --==========================================================================
    -- Check if tracing is enabled based on value of id trace summary variable
    -- .......
    FUNCTION is_trace_enabled
    RETURN BOOLEAN
    IS
    BEGIN
        RETURN (CASE WHEN get_id_trace_summary() IS NOT NULL THEN TRUE ELSE FALSE END);
    END is_trace_enabled;      
    --==========================================================================
    -- Check if tracing should be done based on the level from the tracing call
    -- .......
    FUNCTION is_trace_enabled ( p_trace_level IN PLS_INTEGER )
    RETURN BOOLEAN
    IS
    BEGIN
        RETURN (CASE WHEN get_trace_level() >= p_trace_level THEN TRUE ELSE FALSE END);
    END is_trace_enabled;  
   --======================================================================
   FUNCTION is_external_call ( p_caller   IN VARCHAR2)
   RETURN BOOLEAN
   IS
      l_ext_client_call BOOLEAN;
   BEGIN        
      IF TRIM(p_caller) = pkg_app_manager_state.c_external_client_call THEN
         DBMS_OUTPUT.PUT_LINE('IS_EXTERNAL_CALL: External client call found...');
         l_ext_client_call := TRUE;
      ELSE
         DBMS_OUTPUT.PUT_LINE('IS_EXTERNAL_CALL: External client call NOT found...');
         l_ext_client_call := FALSE;
      END IF;
      
      RETURN l_ext_client_call;
   END is_external_call;            
    --==========================================================================
    -- New improved WHO_CALLED_ME:
    --
    -- Use p_stack_line_number to control which caller you need to get
    -- Eg to get the client who directly calls this procedure use:
    --    p_stack_line_number = 1
    --
    -- To get the client who called them then use    
    --    p_stack_line_number = 2   etc etc
    -- .......    
   PROCEDURE who_called_me (  p_stack_line_number  IN NUMBER,
                              po_owner                OUT VARCHAR2,
                              po_name                 OUT VARCHAR2,
                              po_lineno               OUT NUMBER,
                              po_caller_t             OUT VARCHAR2)
   AS
      call_stack    VARCHAR2 (4096) DEFAULT DBMS_UTILITY.format_call_stack;
      n             NUMBER;
      found_stack   BOOLEAN DEFAULT FALSE;
      line          VARCHAR2 (255);
      t             VARCHAR2 (255);
      cnt           NUMBER := 0;
   BEGIN
      DBMS_OUTPUT.put_line ('----------------------------');
      DBMS_OUTPUT.put_line ('----------------------------');
      DBMS_OUTPUT.put_line (call_stack);


      --
      LOOP
         n := INSTR (call_stack, CHR (10));
         EXIT WHEN (cnt = p_stack_line_number OR n IS NULL OR n = 0);
         --
         line := SUBSTR (call_stack, 1, n - 1);
         call_stack := SUBSTR (call_stack, n + 1);

         --
         --dbms_output.put_line(n);
         --dbms_output.put_line(line);
         IF (NOT found_stack)
         THEN
            IF (line LIKE '%handle%number%name%')
            THEN
               found_stack := TRUE;
            END IF;
         ELSE
            cnt := cnt + 1;
            -- cnt = 1 is ME
            -- cnt = 2 is MY Caller
            -- cnt = 3 is Their Caller
            --DBMS_OUTPUT.put_line ('cnt = ' || cnt);

            IF (cnt = p_stack_line_number)
            THEN
               -- Fix 718865
               --lineno := to_number(substr( line, 13, 6 ));
               --line   := substr( line, 21 );
               n := INSTR (line, ' ');

               IF (n > 0)
               THEN
                  t := LTRIM (SUBSTR (line, n));
                  n := INSTR (t, ' ');
               END IF;

               IF (n > 0)
               THEN
                  po_lineno := TO_NUMBER (SUBSTR (t, 1, n - 1));
                  line := LTRIM (SUBSTR (t, n));
               ELSE
                  po_lineno := 0;
               END IF;

               --DBMS_OUTPUT.put_line ('line = ' || line);

               IF (line LIKE 'pr%')
               THEN
                  n := LENGTH ('procedure ');
               ELSIF (line LIKE 'fun%')
               THEN
                  n := LENGTH ('function ');
               ELSIF (line LIKE 'package body%')
               THEN
                  n := LENGTH ('package body ');
               ELSIF (line LIKE 'pack%')
               THEN
                  n := LENGTH ('package ');
               ELSIF (line LIKE 'anon%')
               THEN
                  n := LENGTH ('anonymous block ');
               ELSE
                  n := 0;
               END IF;

               IF (n = 0)
               THEN
                  -- could be a trigger or a type body
                  po_caller_t := LTRIM (RTRIM (UPPER (SUBSTR (line, n + 1))));
               ELSE
                  po_caller_t := LTRIM (RTRIM (UPPER (SUBSTR (line, 1, n - 1))));
               END IF;

               line := SUBSTR (line, n);
               n := INSTR (line, '.');
               po_owner := UPPER(LTRIM (RTRIM (SUBSTR (line, 1, n - 1))));
               po_name := UPPER(LTRIM (RTRIM (SUBSTR (line, n + 1))));
            END IF;
         END IF;
      END LOOP;
      DBMS_OUTPUT.put_line ('----------------------------');
      DBMS_OUTPUT.put_line ('----------------------------');

      DBMS_OUTPUT.put_line ('WHO_CALLED_ME: po_owner = ' || po_owner);
      DBMS_OUTPUT.put_line ('WHO_CALLED_ME: po_caller_t = ' || po_caller_t);
      DBMS_OUTPUT.put_line ('----------------------------');
   END who_called_me;                    
    --==========================================================================
    -- 
    -- .......
   FUNCTION f_who_called_me
    RETURN VARCHAR2
   IS
      o_owner       VARCHAR2(32767);
      o_object      VARCHAR2(32767);
      o_lineno      NUMBER(10);
      caller_t      VARCHAR2(500);
   BEGIN
      -- call built in procedure to get the package name and line number from the call stack
      --owa_util.who_called_me(o_owner, o_object, o_lineno, caller_t);
      owa_util.who_called_me(o_owner, o_object, o_lineno, caller_t);

      -- return package name plus line number quoted by :: eg  pkg1:20:
      RETURN o_object || ':' || TO_CHAR(o_lineno) || ':';

   END f_who_called_me;
    --================================================================================
    PROCEDURE get_trace_config (p_owner             IN  trace_config.owner%TYPE,
                                p_package_name      IN  trace_config.package_name%TYPE DEFAULT NULL,
                                p_procedure_name    IN  trace_config.procedure_name%TYPE,
                                po_id_trace_config      OUT trace_config.id_trace_config%TYPE,
                                po_trace_level          OUT trace_config.trace_level%TYPE)                                 
    IS
        l_owner             trace_config.owner%TYPE;
        l_package_name      trace_config.package_name%TYPE;
        l_procedure_name    trace_config.procedure_name%TYPE;

        l_id_trace_config   trace_config.id_trace_config%TYPE;
        l_trace_level       trace_config.trace_level%TYPE;                
    BEGIN
        DBMS_OUTPUT.PUT_LINE('GET_TRACE_CONFIG: START');
        
        -- Ensure all variables are upper case
        l_owner             := UPPER(p_owner);         
        l_package_name      := UPPER(p_package_name);
        l_procedure_name    := UPPER(p_procedure_name);
        
        BEGIN
            SELECT  tc.id_trace_config, trace_level
            INTO    l_id_trace_config, l_trace_level
            FROM trace_config tc
            WHERE tc.owner = l_owner
            AND NVL(tc.package_name, 'X') = NVL(l_package_name, 'X')
            AND   tc.procedure_name = l_procedure_name;            
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            --DBMS_OUTPUT.PUT_LINE('GET_TRACE_CONFIG: No trace found.. raising error');
            --RAISE pkg_app_manager_state.e_missing_trace_config;
            DBMS_OUTPUT.PUT_LINE('GET_TRACE_CONFIG: No trace found...');
            l_id_trace_config := NULL;
            l_trace_level := NULL;
            
        WHEN TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE('GET_TRACE_CONFIG: No unique trace found.. raising error');
            RAISE pkg_app_manager_state.e_duplicate_trace_config;

        END;
        
        po_id_trace_config  := l_id_trace_config;
        po_trace_level      := l_trace_level;
        
        DBMS_OUTPUT.PUT_LINE('GET_TRACE_CONFIG: id_trace_config: ' || po_id_trace_config);
        DBMS_OUTPUT.PUT_LINE('GET_TRACE_CONFIG: trace_level: ' || po_trace_level);
        DBMS_OUTPUT.PUT_LINE('GET_TRACE_CONFIG: END');
    END get_trace_config;

   --================================================================================
   --....
   PROCEDURE p_trace_log( p_module      IN trace_log.module%TYPE
                        , p_context     IN trace_log.context%TYPE
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL )
   IS
    PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
            INSERT INTO trace_log (id_trace_log,
                                   id_trace_summary,
                                   module,
                                   context,
                                   name,
                                   datatype,
                                   call_stack,
                                   datetime,
                                   created_by)
            VALUES (seq_id_trace_log.NEXTVAL,
                    get_id_trace_summary(),
                    p_module,
                    p_context,
                    p_name,
                    'NULL',
                    NULL,
                    SYSTIMESTAMP,
                    USER);

            COMMIT;

   END p_trace_log;

   --================================================================================
   --....
   PROCEDURE p_trace_log( p_module      IN trace_log.module%TYPE
                        , p_context     IN trace_log.context%TYPE
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN VARCHAR2)
   IS
    PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
            INSERT INTO trace_log (id_trace_log,
                                   id_trace_summary,
                                   module,
                                   context,
                                   name,
                                   datatype,
                                   value_varchar,
                                   call_stack,
                                   datetime,
                                   created_by)
            VALUES (seq_id_trace_log.NEXTVAL,
                    get_id_trace_summary(),
                    p_module,
                    p_context,
                    p_name,
                    'VARCHAR2',
                    p_text,
                    NULL,
                    SYSTIMESTAMP,
                    USER);

            COMMIT;

   END p_trace_log;


   --================================================================================
   --....
   PROCEDURE p_trace_log( p_module      IN trace_log.module%TYPE
                        , p_context     IN trace_log.context%TYPE
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN NUMBER)
   IS
    PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
            INSERT INTO trace_log (id_trace_log,
                                   id_trace_summary,
                                   module,
                                   context,
                                   name,
                                   datatype,
                                   value_number,
                                   call_stack,
                                   datetime,
                                   created_by)
            VALUES (seq_id_trace_log.NEXTVAL,
                    get_id_trace_summary(),
                    p_module,
                    p_context,
                    p_name,
                    'NUMBER',
                    p_text,
                    NULL,
                    SYSTIMESTAMP,
                    USER);

            COMMIT;

   END p_trace_log;

   --================================================================================
   --....
   PROCEDURE p_trace_log( p_module      IN trace_log.module%TYPE
                        , p_context     IN trace_log.context%TYPE
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN DATE)
   IS
    PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
            INSERT INTO trace_log (id_trace_log,
                                   id_trace_summary,
                                   module,
                                   context,
                                   name,
                                   datatype,
                                   value_date,
                                   call_stack,
                                   datetime,
                                   created_by)
            VALUES (seq_id_trace_log.NEXTVAL,
                    get_id_trace_summary(),
                    p_module,
                    p_context,
                    p_name,
                    'DATE',
                    p_text,
                    NULL,
                    SYSTIMESTAMP,
                    USER);

            COMMIT;

   END p_trace_log;

   --================================================================================
   --....
   PROCEDURE p_trace_log( p_module      IN trace_log.module%TYPE
                        , p_context     IN trace_log.context%TYPE
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN timestamp)
   IS
    PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN


        INSERT INTO trace_log (id_trace_log,
                               id_trace_summary,
                               module,
                               context,
                               name,
                               datatype,
                               value_timestamp9,
                               call_stack,
                               datetime,
                               created_by)
        VALUES (seq_id_trace_log.NEXTVAL,
                get_id_trace_summary(),
                p_module,
                p_context,
                p_name,
                'TIMESTAMP',
                p_text,
                NULL,
                SYSTIMESTAMP,
                USER);

            COMMIT;

   END p_trace_log;
   --================================================================================
   --....
   PROCEDURE p_trace_log( p_module      IN trace_log.module%TYPE
                        , p_context     IN trace_log.context%TYPE
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN CLOB)
   IS
    PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
            INSERT INTO trace_log (id_trace_log,
                                   id_trace_summary,
                                   module,
                                   context,
                                   name,
                                   datatype,
                                   value_clob,
                                   call_stack,
                                   datetime,
                                   created_by)
            VALUES (seq_id_trace_log.NEXTVAL,
                    get_id_trace_summary(),
                    p_module,
                    p_context,
                    p_name,
                    'CLOB',
                    p_text,
                    NULL,
                    SYSTIMESTAMP,
                    USER);

            COMMIT;

   END p_trace_log;

   --================================================================================
   --....
   PROCEDURE p_trace_log( p_module      IN trace_log.module%TYPE
                        , p_context     IN trace_log.context%TYPE
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN BOOLEAN)
   IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_boolean VARCHAR2(5);
   BEGIN
        IF p_text THEN
            l_boolean := 'TRUE';
        ELSE
            l_boolean := 'FALSE';
        END IF;

        INSERT INTO trace_log (id_trace_log,
                               id_trace_summary,
                               module,
                               context,
                               name,
                               datatype,
                               value_varchar,
                               call_stack,
                               datetime,
                               created_by)
        VALUES (seq_id_trace_log.NEXTVAL,
                get_id_trace_summary(),
                p_module,
                p_context,
                p_name,
                'BOOLEAN',
                l_boolean,
                NULL,
                SYSTIMESTAMP,
                USER);

            COMMIT;

   END p_trace_log;
   --=============================================================================










   --=============================================================================
   --
   --      PUBLIC PROCEDURES AND FUNCTIONS
   --
   --=============================================================================
   -- To configure a procedure for tracing
   -- Either call manually or is called from a P_TRACE_START when not configured
   -- ....
    PROCEDURE p_configure_procedure (   p_owner                 IN  trace_config.owner%TYPE,
                                        p_package_name          IN  trace_config.package_name%TYPE DEFAULT NULL,
                                        p_procedure_name        IN  trace_config.procedure_name%TYPE,
                                        p_initial_trace_level   IN  trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_disabled,
                                        po_id_trace_config          OUT trace_config.id_trace_config%TYPE)
    IS
    BEGIN
        -- add to config table with trace level set by parameter 
        MERGE INTO trace_config t
        USING ( SELECT  UPPER(NVL(p_owner, USER)) AS owner,
                        UPPER(p_package_name) AS package_name,
                        UPPER(p_procedure_name) AS procedure_name
                FROM DUAL) d
        ON (    t.owner = d.owner
            AND NVL(t.package_name, 'X') = NVL(UPPER(d.package_name), 'X')
            AND t.procedure_name = d.procedure_name
            )
        WHEN MATCHED THEN
        UPDATE
        SET trace_level = p_initial_trace_level,
            last_updated_by = USER,
            last_updated_dts = SYSDATE
        WHEN NOT MATCHED THEN
        INSERT (    t.owner,
                    t.package_name,
                    t.procedure_name,
                    t.trace_level,
                    t.last_updated_by,
                    t.last_updated_dts)
        VALUES (    d.owner,
                    d.package_name,
                    d.procedure_name,
                    p_initial_trace_level,
                    USER,
                    SYSDATE);
                      
        -- get the id of the new/existing row to return to client          
        SELECT id_trace_config 
        INTO po_id_trace_config
        FROM trace_config
        WHERE owner = UPPER(NVL(p_owner, USER)) 
        AND NVL(package_name, 'X') = NVL(UPPER(p_package_name), 'X')
        AND procedure_name = UPPER(p_procedure_name);
             
        COMMIT;
        
    END p_configure_procedure;
    --================================================================================
   PROCEDURE p_switch_on_trace (    p_owner             IN  trace_config.owner%TYPE DEFAULT NULL,
                                    p_package_name      IN  trace_config.package_name%TYPE DEFAULT NULL,
                                    p_procedure_name    IN  trace_config.procedure_name%TYPE,
                                    p_trace_level       IN  trace_config.trace_level%TYPE DEFAULT NULL)
   IS
        l_id_trace_config   trace_config.id_trace_config%TYPE;
        l_trace_level       trace_config.trace_level%TYPE;
   BEGIN

        -- initialise tracing by setting value in table to on
        -- first locate row in trace_config table and check that this entry still maps
        get_trace_config (  p_owner             => p_owner,
                            p_package_name      => p_package_name,
                            p_procedure_name    => p_procedure_name,
                            po_id_trace_config  => l_id_trace_config,
                            po_trace_level      => l_trace_level);
                
        --If all above checks have passed then we can update trace config table to set tracing level
        UPDATE trace_config tc
        SET trace_level = NVL(p_trace_level, pkg_app_manager_state.c_trace_level_5)  -- default to level 1 which is trace enabled
        WHERE id_trace_config = l_id_trace_config;

        COMMIT;

   END p_switch_on_trace;

   --================================================================================
   PROCEDURE p_switch_off_trace (  p_owner             IN  trace_config.owner%TYPE DEFAULT NULL,
                                   p_package_name      IN  trace_config.package_name%TYPE,
                                   p_procedure_name    IN  trace_config.procedure_name%TYPE
                                   )
   IS
        l_id_trace_config   trace_config.id_trace_config%TYPE;
        l_trace_level       trace_config.trace_level%TYPE;
   BEGIN    
        -- initialise tracing by setting value in table to on
        -- first locate row in trace_config table and check that this entry still maps
        get_trace_config (  p_owner             => p_owner,
                            p_package_name      => p_package_name,
                            p_procedure_name    => p_procedure_name,
                            po_id_trace_config  => l_id_trace_config,
                            po_trace_level      => l_trace_level);

        -- initialise tracing by setting value in table to on
        UPDATE trace_config t
        SET trace_level = pkg_app_manager_state.c_trace_disabled
        WHERE id_trace_config = l_id_trace_config;

        COMMIT;

   END p_switch_off_trace;
   --================================================================================
   PROCEDURE p_initialise_trace
   IS
   BEGIN
        -- set the tracing to false
        set_trace_level(pkg_app_manager_state.c_trace_disabled);
        set_id_trace_summary(NULL);

   END p_initialise_trace;

   --================================================================================
   PROCEDURE p_trace_start (    p_client_id            IN VARCHAR2 DEFAULT NULL,
                                p_owner                IN trace_config.owner%TYPE DEFAULT NULL,
                                p_package_name         IN trace_config.package_name%TYPE,
                                p_procedure_name       IN trace_config.procedure_name%TYPE,
                                p_force                IN BOOLEAN DEFAULT FALSE
                                )
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      
      l_name              VARCHAR2(200);
      l_lineno            NUMBER;
      l_caller_t          VARCHAR2(200);
      l_dummy_caller_t    VARCHAR2(200);
      
      l_owner             trace_config.owner%TYPE;
      l_id_trace_config   trace_config.id_trace_config%TYPE;
      l_trace_level       trace_config.trace_level%TYPE;
      l_id_trace_summary  trace_summary.id_trace_summary%TYPE;
              
      l_procfunc_name     VARCHAR2(30);

      --======================================================================
      PROCEDURE get_trace_config_data
      IS
      BEGIN     
         DBMS_OUTPUT.PUT_LINE('P_TRACE_START: Trace not yet enabled..Getting trace config');
         -- get the trace config info of the calling procedure 
         get_trace_config (p_owner             => l_owner,
                           p_package_name      => p_package_name,
                           p_procedure_name    => p_procedure_name, 
                           po_id_trace_config  => l_id_trace_config,
                           po_trace_level      => l_trace_level);  
                           
      END get_trace_config_data;       
      --======================================================================
      PROCEDURE configure_trace
      IS
      BEGIN
         -- set trace level off 
         l_trace_level := pkg_app_manager_state.c_trace_disabled;
                                         
         -- configure the procedure using this trace level
         p_configure_procedure ( p_owner                 => l_owner,
                                 p_package_name          => p_package_name,
                                 p_procedure_name        => p_procedure_name,
                                 p_initial_trace_level   => l_trace_level,                                         
                                 po_id_trace_config      => l_id_trace_config );
                                            
         DBMS_OUTPUT.PUT_LINE('P_TRACE_START: ----- < Tracing config successful >--------');                                         
         DBMS_OUTPUT.PUT_LINE('P_TRACE_START: To enable trace please switch on tracing in TRACE_CONFIG table and re-run procedure call.');
      EXCEPTION
      WHEN OTHERS THEN
         RAISE pkg_app_manager_state.e_procedure_not_configured;        
      END configure_trace;
      --======================================================================
      PROCEDURE start_trace
      IS
      BEGIN   
         -- only start a trace if the trace level from the config table is not set as disabled
         -- AND the client that is calling the procedure being traced IS NOT an oracle object (procedure, function etc)
         -- ie only start a new trace if it is being called by external client or anon block not sub procedure call
         -- OR the force flag is used
         IF (l_trace_level > pkg_app_manager_state.c_trace_disabled AND is_external_call(l_caller_t))
         OR p_force 
         THEN
             DBMS_OUTPUT.PUT_LINE('P_TRACE_START: Initialising trace');
             -- we start a new trace
             INSERT INTO trace_summary (id_trace_summary,
                                        owner,
                                        package_name,
                                        procedure_name,
                                        start_time,
                                        end_time,
                                        trace_level,
                                        procedure_call,
                                        client_id)
             VALUES (seq_id_trace_summary.NEXTVAL,
                     l_owner,
                     UPPER(p_package_name),
                     UPPER(p_procedure_name),
                     SYSTIMESTAMP,
                     NULL,
                     l_trace_level,
                     NULL,                    --TODO
                     p_client_id || ':UID:' || seq_client_id.NEXTVAL || ':AUDSID:' || SYS_CONTEXT('USERENV','SESSIONID'))
             RETURNING id_trace_summary INTO l_id_trace_summary;

             -- set the global package veriable
             set_id_trace_summary(l_id_trace_summary);

             -- set the level as set by the config table
             set_trace_level(l_trace_level);

         ELSE
            -- else if trace level is set to disabled or null then
            -- do nothing
            DBMS_OUTPUT.PUT_LINE('P_TRACE_START: No tracing required');
         END IF;      
      END start_trace;   

      --======================================================================
      --======================================================================
   BEGIN
      l_procfunc_name := 'P_TRACE_START';
      DBMS_OUTPUT.PUT_LINE('P_TRACE_START: START');
      --p_initialise_trace;
      
      -- IMPORTANT
      -- who_called_me procedure call needs to parce the call stack, and the call stack would include
      -- the calls from this package ie pkg_app_manager.  Therefore in order to select the client who called your
      -- proceduer you need to take into account which line of the call stack and pass that to who_called_me.
      -- For example whoevere calls P_TRACE_START the call stack would look something like this:
      --
      -- 
      --      ----- PL/SQL Call Stack -----
      --  object      line  object
      --  handle    number  name
      --0x10d0e79f0       118  package body COMMON.PKG_APP_MANAGER
      --0x10d0e79f0       878  package body COMMON.PKG_APP_MANAGER
      --0x11a130968      2229  package body AMSADMIN.CHANNELS_API
      --0x10aa9fe70       144  anonymous block
      --
      -- So for this example P_TRACE_START was called by AMSADMIN.CHANNELS_API (ignoring the internal pkg_app_manager calls)
      -- and therefore "anonymous block" called AMSADMIN.CHANNELS_API. 
      -- So to get who called P_TRACE_START (ie the procedure using the tracing) then pass 3 (line 4 of the call stack) as p_stack_line_number to who_called_me
      -- To get who called that procedure then pass 4 (line 4 of the call stack)
      --
      -- For our purposes here we need to pass 4 to get the 4th line of the call stack to give us the external client that is calling
      -- our procedure from where p_trace_start is used.       
      who_called_me(4, l_owner, l_name, l_lineno, l_caller_t);           
      --DBMS_OUTPUT.PUT_LINE('P_TRACE_START: ' || l_caller_t);

      -- Then pass 3 to get the owner of the package that is using P_TRACE_START.
      -- use l_dummy_caller_t since we dont need that data we just need the owner.
      who_called_me(3, l_owner, l_name, l_lineno, l_dummy_caller_t);           
      DBMS_OUTPUT.PUT_LINE('P_TRACE_START: ' || l_owner || (CASE WHEN l_owner IS NOT NULL THEN '.' ELSE NULL END) || p_package_name || '.' || p_procedure_name);
      
      -- if its an anon block that is being traced then for owner just use USER
      IF p_procedure_name = pkg_app_manager_state.c_proc_name_anon_block THEN
         l_owner := USER;
      END IF;
            
      -- check for tracing info in trace_config
      get_trace_config_data;
      
      -- check result of getting the trace info            
      IF l_id_trace_config IS NULL THEN
         -- if a config does not yet exist then call procedure to configure one
         configure_trace;
      ELSE
         -- else if config does exist then start a trace (if the trace level requires it)
         start_trace;
      END IF;
            
      DBMS_OUTPUT.PUT_LINE('P_TRACE_START: g_id_trace_summary: ' || get_id_trace_summary());
      DBMS_OUTPUT.PUT_LINE('P_TRACE_START: END');
     
      COMMIT;
   EXCEPTION
   WHEN OTHERS  THEN
      ROLLBACK;
      DBMS_OUTPUT.PUT_LINE('ERROR: P_TRACE_START');
      common.error_utils.log_error_alert (   get_package_name(),
                                             l_procfunc_name,
                                             'OTHERS',
                                             SQLERRM,
                                             'Unexpected Error occured',
                                             error_utils.init_error_nvp (  p_name1 => 'p_package_name', p_value1 => p_package_name,
                                                                           p_name2 => 'p_procedure_name', p_value2 => p_procedure_name,
                                                                           p_name3 => 'p_owner', p_value3 => p_owner
                                                                           )
                                          );
   END p_trace_start;
   --================================================================================
   PROCEDURE p_trace_end
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      l_owner             trace_config.owner%TYPE;
      l_name              VARCHAR2(200);
      l_lineno            NUMBER;      
      l_caller_t          VARCHAR2(200);
   BEGIN
      DBMS_OUTPUT.PUT_LINE('P_TRACE_END: START');
      who_called_me(4, l_owner, l_name, l_lineno, l_caller_t);                 
      
      DBMS_OUTPUT.PUT_LINE('P_TRACE_END: id_trace_summary: ' || get_id_trace_summary());
      
      IF is_external_call(l_caller_t) THEN
         -- update summary to set final time
         UPDATE trace_summary
         SET end_time = SYSTIMESTAMP
         WHERE id_trace_summary = get_id_trace_summary();

         -- set the tracing flag to false to stop anymore traces
         set_trace_level(pkg_app_manager_state.c_trace_disabled);
         set_id_trace_summary(NULL);
      
      ELSE
         -- do not end tracing
         NULL;
      END IF;
      COMMIT;

   END p_trace_end;
   --================================================================================
    PROCEDURE p_trace_anon_block_start ( p_trace_level IN PLS_INTEGER DEFAULT 5)
    IS
      l_id_trace_config    NUMBER;
    BEGIN
         p_configure_procedure ( p_owner                 => USER,
                                 p_package_name          => NULL,
                                 p_procedure_name        => pkg_app_manager_state.c_proc_name_anon_block,
                                 p_initial_trace_level   => p_trace_level,                                         
                                 po_id_trace_config      => l_id_trace_config );
                                 
--        p_switch_on_trace ( p_procedure_name => pkg_app_manager_state.c_proc_name_anon_block, p_trace_level => p_trace_level);
--        p_initialise_trace;

        -- call procedure to start the trace.
        -- Pass the client id to identify exactly your instance of tracing
        -- pass the config id of the entry in the trace_config table which needs to exist in order for tracing to work
        p_trace_start (p_client_id => NULL, p_owner => USER, p_package_name => NULL, p_procedure_name => pkg_app_manager_state.c_proc_name_anon_block);


    END p_trace_anon_block_start;   
   --=============================================================================
   -- Makes a call to the trace routine to insert your debugging info into the
   -- log table with the context that you give it.
   -- Make these calls all over your code to output vital tracing info.
   --
   --================================================================================
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT pkg_app_manager_state.c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL)
    IS
    BEGIN
      IF is_trace_enabled (p_level)
      THEN
            -- just use the trace procedure for nulls
            p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                        p_context       => p_context,
                        p_name          => p_name   );
      END IF;
    END p_trace;
   --=============================================================================
   -- Makes a call to the trace routine to insert your debugging info into the
   -- log table with the context that you give it.
   -- Make these calls all over your code to output vital tracing info.
   --
   --================================================================================
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT pkg_app_manager_state.c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN VARCHAR2)
   IS
    l_trace_clob    CLOB;
   BEGIN
      IF is_trace_enabled (p_level)
      THEN
        -- check the length of the trace string
        -- 3900 is used because q$error manager had to be altered down to 3900
        -- otherwise some of the text went missing from the start of the string.
        IF p_text IS NULL THEN
            -- just use the trace procedure for nulls
            p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                        p_context       => p_context,
                        p_name          => p_name,
                        p_text          => TO_CHAR(NULL)   );

        ELSIF LENGTH(p_text) <= 4000 THEN
            -- just use the trace procedure
            p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                        p_context       => p_context,
                        p_name          => p_name,
                        p_text          => p_text);

        ELSE
            -- since the tracing is too large we will use the clob version to trace
            dbms_lob.createtemporary( l_trace_clob, TRUE);
            l_trace_clob := p_text;
            p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                        p_context       => p_context,
                        p_name          => p_name,
                        p_text          => l_trace_clob);
        END IF;

      ELSE
         -- else we won't trace
         NULL;
      END IF;
   END p_trace;
    --=============================================================================
    --..............
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT pkg_app_manager_state.c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN NUMBER)
   IS
   BEGIN
      IF is_trace_enabled (p_level)
      THEN
        -- just use the normal trace procedure
        p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                    p_context       => p_context,
                    p_name          => p_name,
                    p_text          => p_text);

      ELSE
         -- else we won't trace
         NULL;
      END IF;
   END p_trace;
    --=============================================================================
    --..............
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT pkg_app_manager_state.c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN DATE)
   IS
   BEGIN
      IF is_trace_enabled (p_level) 
      THEN
        -- just use the normal trace procedure
        p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                    p_context       => p_context,
                    p_name          => p_name,
                    p_text          => p_text);

      ELSE
         -- else we won't trace
         NULL;
      END IF;
   END p_trace;

    --=============================================================================
    --..............
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT pkg_app_manager_state.c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN timestamp)
   IS
   BEGIN
      IF is_trace_enabled (p_level)
      THEN
        -- just use the normal trace procedure
        p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                    p_context       => p_context,
                    p_name          => p_name,
                    p_text          => p_text);

      ELSE
         -- else we won't trace
         NULL;
      END IF;
   END p_trace;
    --=============================================================================
    --..............
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT pkg_app_manager_state.c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN BOOLEAN)
   IS
   BEGIN
      IF is_trace_enabled (p_level)
      THEN
        -- just use the normal trace procedure
        p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                    p_context       => p_context,
                    p_name          => p_name,
                    p_text          => p_text);

      ELSE
         -- else we won't trace
         NULL;
      END IF;
   END p_trace;

   --=============================================================================
   --
   --================================================================================
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT pkg_app_manager_state.c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN CLOB)
   IS
   BEGIN
      IF is_trace_enabled (p_level)
      THEN
        -- just use the normal trace procedure
        p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                    p_context       => p_context,
                    p_name          => p_name,
                    p_text          => p_text);

      ELSE
         -- else we won't trace
         NULL;
      END IF;
   END p_trace;
    --=============================================================================
    --..............
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT pkg_app_manager_state.c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN dbms_utility.name_array)
   IS
   BEGIN
      IF is_trace_enabled (p_level) 
      THEN
        -- just use the normal trace procedure
        FOR i IN 1 .. p_text.COUNT
        LOOP
            p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                        p_context       => p_context,
                        p_name          => p_name || '(' || i || ')',
                        p_text          => p_text(i));
        END LOOP;
      ELSE
         -- else we won't trace
         NULL;
      END IF;
   END p_trace;
    --=============================================================================
    --..............
   PROCEDURE p_trace(     p_module      IN trace_log.module%TYPE    DEFAULT NULL
                        , p_context     IN trace_log.context%TYPE   DEFAULT pkg_app_manager_state.c_context_default
                        , p_level       IN trace_config.trace_level%TYPE DEFAULT pkg_app_manager_state.c_trace_level_5
                        , p_name        IN trace_log.name%TYPE DEFAULT NULL
                        , p_text        IN dbms_utility.number_array)
   IS
   BEGIN
      IF is_trace_enabled (p_level)
      THEN
        -- just use the normal trace procedure
        FOR i IN 1 .. p_text.COUNT
        LOOP
            p_trace_log(p_module        => NVL(p_module, f_who_called_me),
                        p_context       => p_context,
                        p_name          => p_name || '(' || i || ')',
                        p_text          => p_text(i));
        END LOOP;
      ELSE
         -- else we won't trace
         NULL;
      END IF;
   END p_trace;
   --================================================================================
   -- Parameter trace just adds a context of PARAMETER to the log
   -- ..
   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN VARCHAR2)
   IS
   BEGIN
      -- just use the trace procedure
      p_trace( p_context       => pkg_app_manager_state.c_context_parameter,
               p_name          => UPPER(p_name),
               p_text          => p_text);

   END p_trace_param;
   --================================================================================
   -- Parameter trace just adds a context of PARAMETER to the log
   -- ..
   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN NUMBER)
   IS
   BEGIN
      -- just use the trace procedure
      p_trace( p_context       => pkg_app_manager_state.c_context_parameter,
               p_name          => UPPER(p_name),
               p_text          => p_text);

   END p_trace_param;
   --================================================================================
   -- Parameter trace just adds a context of PARAMETER to the log
   -- ..
   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN DATE)
   IS
   BEGIN
      -- just use the trace procedure
      p_trace( p_context       => pkg_app_manager_state.c_context_parameter,
               p_name          => UPPER(p_name),
               p_text          => p_text);

   END p_trace_param;
   --================================================================================
   -- Parameter trace just adds a context of PARAMETER to the log
   -- ..
   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN TIMESTAMP)
   IS
   BEGIN
      -- just use the trace procedure
      p_trace( p_context       => pkg_app_manager_state.c_context_parameter,
               p_name          => UPPER(p_name),
               p_text          => p_text);

   END p_trace_param;         
   --================================================================================
   -- Parameter trace just adds a context of PARAMETER to the log
   -- ..
   PROCEDURE p_trace_param(  p_module      IN trace_log.module%TYPE DEFAULT NULL
                           , p_name        IN trace_log.name%TYPE DEFAULT NULL
                           , p_text        IN BOOLEAN)
   IS
   BEGIN
      -- just use the trace procedure
      p_trace( p_context       => pkg_app_manager_state.c_context_parameter,
               p_name          => UPPER(p_name),
               p_text          => p_text);

   END p_trace_param;   
   --==================================================================================
   --==================================================================================
   --==================================================================================
   --==================================================================================


END pkg_app_manager;
/
