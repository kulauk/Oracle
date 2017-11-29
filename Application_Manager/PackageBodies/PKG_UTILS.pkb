CREATE OR REPLACE PACKAGE BODY pkg_utils
AS
    /******************************************************************************
      NAME:       pkg_utils
      PURPOSE:

      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        24/07/2009  D Lucas          Created this package

    ******************************************************************************/
    --=============================================================================
    --
    --      Declaration section
    --
    -- (Place your package level variables and declarations here )
    --=============================================================================
    g_loop_kill_counter         pls_integer;
    g_loop_kill_max_iterations  pls_integer;


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

    
    --=============================================================================
    -- Procedure to raise an error if the assertion fails.
    -- Uses: Best utilised to validate input parameter conditions for procedures
    --       If the fatal flag is set then we raise a fatal error else it is a
    --       normal application type error.
    --.............................................................................
    PROCEDURE p_assert( p_condition                   IN boolean
                      , p_message                     IN varchar2:= NULL
                      , p_fatal                       IN boolean )
    IS
        assertfail_fatal_c CONSTANT  pls_integer := ( 20000 + pkg_constants.gc_ferr_assertion ) * -1;
        assertfail_app_c CONSTANT    pls_integer := ( 20000 + pkg_constants.gc_err_assertion ) * -1;
        v_error_code                 pls_integer;
    BEGIN
        -- set error code
        IF p_fatal
        THEN
            -- fatal flag true so set error code as fatal type
            v_error_code               := assertfail_fatal_c;
        ELSE
            -- fatal flag false so set error code as application type
            v_error_code               := assertfail_app_c;
        END IF;

        IF NOT NVL( p_condition, FALSE )
        THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => v_error_code
                                           , p_text_in                  => 'ASSERTFAIL FATAL: '
                                                                          || SUBSTR( NVL( p_message
                                                                                        , 'No Message' )
                                                                                   , 1
                                                                                   , 200 ) );
        END IF;
    END p_assert;


    --=============================================================================
    -- Function to fetch the current system status flag from the system parameters
    -- table.
    -- No exception handling is necessary since the row should always exist and be
    -- unique.
    --.............................................................................
    FUNCTION f_get_system_status
        RETURN INTEGER
    IS
        v_return    INTEGER;
    BEGIN
        SELECT  TO_NUMBER(parameter_value)
        INTO    v_return
        FROM    system_parameters_t
        WHERE   parameter_name = 'CURRENT_SYSTEM_STATUS';
        
        RETURN v_return;
        
    END f_get_system_status;
    
    
    --=============================================================================
    -- Procedure to set the current system status flag from the system parameters
    -- table.
    --.............................................................................
    PROCEDURE p_set_system_status (
        p_system_status     IN  INTEGER )
    IS
        v_return    INTEGER;
    BEGIN
        -- check the value of the input parameter
        p_assert( p_system_status IN ( pkg_constants.gc_system_status_open, pkg_constants.gc_system_status_closed ),
                  'Invalid system status passed in',
                  TRUE );
        
        UPDATE  system_parameters_t
        SET     parameter_value = p_system_status
        WHERE   parameter_name = 'CURRENT_SYSTEM_STATUS';               
    END p_set_system_status;
    
    
    --==========================================================================
    -- Procedure to clear all old data from the named application context.
    --.............................................................................
    PROCEDURE p_initialise_context( p_context_name IN varchar2 )
    IS
    BEGIN
        FOR cur_ctx IN ( SELECT attribute
                        FROM   session_context
                        WHERE  namespace = UPPER( p_context_name ) )
        LOOP
            DBMS_SESSION.clear_context( p_context_name, DBMS_SESSION.unique_session_id, cur_ctx.attribute );
        END LOOP;
    END p_initialise_context;


    --==========================================================================
    -- This function selects the ora_rowscn column for a particular table
    -- and is selected using its primary key column and value...also passed in.
    -- Uses: Used to fetch the row scn number to test if it has changed or not
    --.............................................................................
    FUNCTION f_get_ora_row_scn( p_table_name                  IN varchar2
                              , p_primary_key_col_name        IN varchar2
                              , p_primary_key_value           IN number )
        RETURN number
    IS
        v_sql      varchar2( 500 );
        v_row_scn  number;
    BEGIN
        pkg_error_manager.p_trace_start( p_context_in => 'ALL', p_text_in => 'f_get_ora_row_scn' );

        pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                 , p_text_in                  => 'p_table_name:..............'
                                                                || p_table_name
                                                                || CHR( 13 )
                                                                || 'p_primary_key_col_name:....'
                                                                || p_primary_key_col_name
                                                                || CHR( 13 )
                                                                || 'p_primary_key_value:........'
                                                                || p_primary_key_value );
        -- fetch the row's current scn number
        v_sql                      :=
            'SELECT  ORA_ROWSCN
                    FROM    '
            || p_table_name
            || ' 
                    WHERE   '
            || p_primary_key_col_name
            || ' = :p_primary_key_value';

        pkg_error_manager.p_trace( p_context_in => 'LEVEL2', p_text_in => 'v_sql:....' || v_sql );


        EXECUTE IMMEDIATE v_sql INTO v_row_scn USING p_primary_key_value;

        pkg_error_manager.p_trace( p_context_in => 'LEVEL1', p_text_in => 'Row scn is:....' || v_row_scn );

        RETURN v_row_scn;

        pkg_error_manager.p_trace_end( p_context_in => 'ALL', p_text_in => 'f_get_ora_row_scn' );
    END f_get_ora_row_scn;

    --==========================================================================
    -- This procedure selects out the scn number of the row from the table and locks
    -- it.  This ensures that from now on the row is consistent.  This scn number
    -- is compared to the scn the the client holds for the row to ensure no other
    -- user has updated it.  If they are different a specific error is raised.
    --.............................................................................
    PROCEDURE p_lock_and_verify_rowdata( p_table_name                  IN varchar2
                                       , p_primary_key_col_name        IN varchar2
                                       , p_primary_key_data            IN number
                                       , p_existing_row_scn            IN number )
    IS
        v_sql      varchar2( 500 );
        v_row_scn  number;
    BEGIN
        pkg_error_manager.p_trace_start( p_context_in => 'ALL', p_text_in => 'p_lock_and_verify_rowdata' );

        pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                 , p_text_in                  => 'p_table_name:..............'
                                                                || p_table_name
                                                                || CHR( 13 )
                                                                || 'p_primary_key_col_name:....'
                                                                || p_primary_key_col_name
                                                                || CHR( 13 )
                                                                || 'p_primary_key_data:........'
                                                                || p_primary_key_data
                                                                || CHR( 13 )
                                                                || 'p_existing_row_scn:........'
                                                                || p_existing_row_scn );

        -- fetch the row's current scn number
        v_sql                      :=
            'SELECT  ORA_ROWSCN
                    FROM    '
            || p_table_name
            || ' 
                    WHERE   '
            || p_primary_key_col_name
            || ' = :p_primary_key
                    FOR UPDATE NOWAIT';

        EXECUTE IMMEDIATE v_sql INTO v_row_scn USING p_primary_key_data;

        pkg_error_manager.p_trace( p_context_in => 'LEVEL1', p_text_in => 'Row scn is:....' || v_row_scn );

        -- compare the current scn number of the row to the scn passed back
        -- from the client for the row that was queried initially.
        IF v_row_scn <> p_existing_row_scn
        THEN
            -- data has been modified by someone user should reselect and submit again
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_err_lock_row_modified
                                           , p_text_in                  => 'Row has been modified'
                                           , p_name1_in                 => 'New scn number: p_row_scn'
                                           , p_value1_in                => p_existing_row_scn
                                           , p_name2_in                 => 'Existing scn number: v_row_scn'
                                           , p_value2_in                => v_row_scn );
        END IF;

        pkg_error_manager.p_trace_end( p_context_in => 'ALL', p_text_in => 'p_lock_and_verify_rowdata' );
    END p_lock_and_verify_rowdata;
    --=========================================================================


    --=========================================================================
    --=========================================================================
    --=========================================================================
    --=========================================================================
    -- Functions to determine if the data passed in is null or not
    -- this is overloaded so it can be used for a range of data types
    -- They all return a string 'TRUE' or 'FALSE' 
    --........................................................................        
    FUNCTION f_is_data_null( p_data     IN  VARCHAR2)
        RETURN VARCHAR2
    IS
    BEGIN        
        RETURN (CASE WHEN p_data IS NULL THEN 'TRUE' ELSE 'FALSE' END);
    END f_is_data_null;

    FUNCTION f_is_data_null( p_data     IN  NUMBER)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN (CASE WHEN p_data IS NULL THEN 'TRUE' ELSE 'FALSE' END);
    END f_is_data_null;

    FUNCTION f_is_data_null( p_data     IN  DATE)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN (CASE WHEN p_data IS NULL THEN 'TRUE' ELSE 'FALSE' END);
    END f_is_data_null;

    FUNCTION f_is_data_null( p_data     IN  varchar_250_nt)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN (CASE WHEN p_data IS NULL THEN 'TRUE' ELSE 'FALSE' END);
    END f_is_data_null;

    FUNCTION f_is_data_null( p_data     IN  number_nt)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN (CASE WHEN p_data IS NULL THEN 'TRUE' ELSE 'FALSE' END);
    END f_is_data_null;
    --=========================================================================
    --=========================================================================
    -- This Function uses the ANYDATA type so that any data type can be passed in and 
    -- this function will return a string 'TRUE' or 'FALSE'
    -- It can be called by using the convert functions for example  
    --                  f_is_data(ANYDATA.convertVarchar2( 'A' ) )
    --                  f_is_data(ANYDATA.convertNumber( 8 ) )
    --                  f_is_data(ANYDATA.convertCollection( my_array_type ) )
    --........................................................................    
    FUNCTION f_is_data_null( p_data     IN  ANYDATA)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN (CASE WHEN p_data IS NULL THEN 'TRUE' ELSE 'FALSE' END);
    END f_is_data_null;
    --=========================================================================
    --=========================================================================
    
    --=========================================================================
    --=========================================================================    
    --=========================================================================
    --=========================================================================    




    --=============================================================================
    -- This function takes in a user supplied postcode, forces to uppercase
    -- and ensures there is a single space between the 2 portions.
    --.............................................................................
    FUNCTION f_format_postcode( p_input varchar2 )
        RETURN varchar2
    IS
        v_temp  varchar2( 20 );
    BEGIN
        IF TRIM( p_input ) IS NULL
        THEN
            -- User has left postcode field empty
            RETURN NULL;
        END IF;

        IF LENGTH( p_input ) > 20
        THEN
            -- postcode can't be more than 20 so return unformatted string
            RETURN p_input;
        END IF;

        v_temp                     := UPPER( REPLACE( p_input, ' ', '' ) );

        IF LENGTH( v_temp ) < 5
        THEN
            -- User has only typed in his post district
            RETURN p_input;
        END IF;

        -- find the last digit in the string. This is the start of the walk code
        FOR i IN REVERSE 1 .. LENGTH( v_temp )
        LOOP
            IF SUBSTR( v_temp, i, 1 ) BETWEEN '0' AND '9'
            THEN
                IF LENGTH( v_temp ) = i
                THEN
                    -- if the last character is a digit then no formatting can occur
                    -- just return the input
                    RETURN p_input;
                END IF;
                RETURN SUBSTR( v_temp, 1, i - 1 ) || ' ' || SUBSTR( v_temp, i, 4 );
            END IF;
        END LOOP;

        -- You should never get here if its a proper postcode
        -- so if you do get here just return the input as an unformatted code
        RETURN p_input;
    END f_format_postcode;


    --=========================================================================
    -- Function to take a delimited list and load it into a string associative
    -- array of type varchar250
    --........................................................................
    --    FUNCTION f_list_to_var250_array( p_input                       IN VARCHAR2
    --                                   , p_delimiter                   IN VARCHAR2 DEFAULT ',' )
    --        RETURN varchar250_array_type
    --    IS
    --        v_input       VARCHAR2( 32767 );
    --        v_delimiter   VARCHAR2( 5 );
    --        v_char        VARCHAR2( 1 );
    --        v_element     VARCHAR2( 250 );
    --        v_element_no  PLS_INTEGER := 0;
    --        v_output      varchar250_array_type;
    --
    --        data_too_large_EXCEP    EXCEPTION;
    --        PRAGMA EXCEPTION_INIT( data_too_large_EXCEP, -6502 );
    --
    --    BEGIN
    --        v_delimiter                := NVL( p_delimiter, ',' );

    --        -- if input is null then return a null output array
    --        IF p_input IS NULL
    --        THEN
    --            RETURN v_output;
    --        END IF;

    --        -- if the input does not contain a delimiter then append one to the end
    --        -- to ensure the single value is parsed eg   value1~
    --        IF INSTR( p_input, v_delimiter ) = 0
    --        THEN
    --            v_input                    := p_input || v_delimiter;
    --        ELSE
    --            v_input                    := p_input;
    --        END IF;

    --        -- now parse the string and load into array
    --        FOR c IN 1 .. LENGTH( v_input )
    --        LOOP
    --            v_char                     := SUBSTR( v_input, c, 1 );
    --            IF v_char = v_delimiter
    --            THEN
    --                v_output( v_element_no )   := v_element;
    --                v_element_no               := v_element_no + 1;
    --                v_element                  := NULL;
    --            ELSE
    --                    v_element                  := v_element || v_char;
    --            END IF;
    --        END LOOP;

    --        -- if the last element is not null then add it to the array
    --        IF v_element IS NOT NULL
    --        THEN
    --            v_output( v_element_no )   := v_element;
    --        END IF;

    --        RETURN v_output;
    --    EXCEPTION
    --    WHEN data_too_large_EXCEP THEN
    --        pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_out_of_range
    --                                       , p_text_in                  => 'Delimited data is too large'
    --                                       , p_name1_in                 => 'v_element + next characters'
    --                                       , p_value1_in                => v_element || v_char );
    --    END f_list_to_var250_array;


    --=========================================================================
    -- Function to take a delimited list and load it into a string associative
    -- array of type varchar250
    --........................................................................
    FUNCTION f_list_to_var250_array( p_input                       IN varchar2
                                   , p_delimiter                   IN varchar2 DEFAULT ',' )
        RETURN varchar250_array_type
    IS
        l_element       varchar2( 32767 );
        l_delimiter     varchar2( 5 );
        l_loc           pls_integer;
        l_startloc      pls_integer := 1;
        v_output_array  varchar250_array_type;

        data_too_large_excep exception;
        PRAGMA EXCEPTION_INIT( data_too_large_excep, -6502 );

        --========================================================================
        --========================================================================
        PROCEDURE p_add_element( p_element_in IN varchar2 )
        IS
        BEGIN
            IF ( p_element_in != l_delimiter
             OR p_element_in IS NULL )
            THEN
                v_output_array( NVL( v_output_array.LAST, 0 ) + 1 ) := p_element_in;
            END IF;
        END p_add_element;
    --========================================================================
    --========================================================================
    BEGIN
        l_delimiter                := NVL( p_delimiter, ',' );

        IF p_input IS NOT NULL
        THEN
            LOOP
                -- Find next delimiter
                l_loc                      := INSTR( p_input, l_delimiter, l_startloc );

                IF l_loc = l_startloc -- Previous element is NULL
                THEN
                    l_element                  := NULL;
                ELSIF l_loc = 0 -- Rest of string is last element
                THEN
                    l_element                  := SUBSTR( p_input, l_startloc );
                ELSE
                    l_element                  := SUBSTR( p_input, l_startloc, l_loc - l_startloc );
                END IF;

                p_add_element( l_element );

                IF l_loc = 0
                THEN
                    EXIT;
                ELSE
                    l_startloc                 := l_loc + 1;
                END IF;
            END LOOP;
        END IF;

        RETURN v_output_array;
    EXCEPTION
        WHEN data_too_large_excep
        THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_out_of_range
                                           , p_text_in                  => 'Delimiter or delimited data is too large'
                                           , p_name1_in                 => 'Next l_element'
                                           , p_value1_in                => SUBSTR( SUBSTR( p_input, l_startloc )
                                                                                 , 1
                                                                                 , 4000 )
                                           , p_name2_in                 => 'p_delimiter'
                                           , p_value2_in                => p_delimiter );
    END f_list_to_var250_array;

    --=========================================================================
    -- Function to take a delimited list and load it into a string nested table
    -- array of type varchar250
    --........................................................................
    FUNCTION f_list_to_var250_nested_tab( p_input                       IN varchar2
                                        , p_delimiter                   IN varchar2 DEFAULT ',' )
        RETURN varchar_250_nt
    IS
        l_element       varchar2( 32767 );
        l_delimiter     varchar2( 5 );
        l_loc           pls_integer;
        l_startloc      pls_integer := 1;
        v_output_array  varchar_250_nt;

        data_too_large_excep exception;
        PRAGMA EXCEPTION_INIT( data_too_large_excep, -6502 );

        --========================================================================
        --========================================================================
        PROCEDURE p_add_element( p_element_in IN varchar2 )
        IS
        BEGIN
            IF ( p_element_in != l_delimiter
             OR p_element_in IS NULL )
            THEN
                v_output_array.EXTEND;
                v_output_array( NVL( v_output_array.LAST, 0 ) ) := p_element_in;
            END IF;
        END p_add_element;
    --========================================================================
    --========================================================================
    BEGIN
        v_output_array             := varchar_250_nt( );
        l_delimiter                := NVL( p_delimiter, ',' );

        IF p_input IS NOT NULL
        THEN
            LOOP
                -- Find next delimiter
                l_loc                      := INSTR( p_input, l_delimiter, l_startloc );

                IF l_loc = l_startloc -- Previous element is NULL
                THEN
                    l_element                  := NULL;
                ELSIF l_loc = 0 -- Rest of string is last element
                THEN
                    l_element                  := SUBSTR( p_input, l_startloc );
                ELSE
                    l_element                  := SUBSTR( p_input, l_startloc, l_loc - l_startloc );
                END IF;

                p_add_element( l_element );

                IF l_loc = 0
                THEN
                    EXIT;
                ELSE
                    l_startloc                 := l_loc + 1;
                END IF;
            END LOOP;
        END IF;

        RETURN v_output_array;
    EXCEPTION
        WHEN data_too_large_excep
        THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_out_of_range
                                           , p_text_in                  => 'Delimiter or delimited data is too large'
                                           , p_name1_in                 => 'Next l_element'
                                           , p_value1_in                => SUBSTR( SUBSTR( p_input, l_startloc )
                                                                                 , 1
                                                                                 , 4000 )
                                           , p_name2_in                 => 'p_delimiter'
                                           , p_value2_in                => p_delimiter );
    END f_list_to_var250_nested_tab;


    --=========================================================================
    -- Function to take a delimited list and load it into a string associative
    -- array of type number
    --........................................................................
    FUNCTION f_list_to_num_array( p_input                       IN varchar2
                                   , p_delimiter                   IN varchar2 DEFAULT ',' )
        RETURN number_array_type
    IS
        l_element       varchar2( 32767 );
        l_delimiter     varchar2( 5 );
        l_loc           pls_integer;
        l_startloc      pls_integer := 1;
        v_output_array  number_array_type;

        data_too_large_excep exception;
        PRAGMA EXCEPTION_INIT( data_too_large_excep, -6502 );

        --========================================================================
        --========================================================================
        PROCEDURE p_add_element( p_element_in IN varchar2 )
        IS
        BEGIN
            IF ( p_element_in != l_delimiter
             OR p_element_in IS NULL )
            THEN
                v_output_array( NVL( v_output_array.LAST, 0 ) + 1 ) := TO_NUMBER(p_element_in);
            END IF;
        EXCEPTION
        WHEN value_error THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_out_of_range
                                           , p_text_in                  => 'Number conversion error: Data is not a number'
                                           , p_name1_in                 => 'p_element_in'
                                           , p_value1_in                =>  p_element_in
                                           , p_name2_in                 => 'Element Number'
                                           , p_value2_in                => (NVL( v_output_array.LAST, 0 ) + 1) );                    
        END p_add_element;
    --========================================================================
    --========================================================================
    BEGIN
        l_delimiter                := NVL( p_delimiter, ',' );

        IF p_input IS NOT NULL
        THEN
            LOOP
                -- Find next delimiter
                l_loc                      := INSTR( p_input, l_delimiter, l_startloc );

                IF l_loc = l_startloc -- Previous element is NULL
                THEN
                    l_element                  := NULL;
                ELSIF l_loc = 0 -- Rest of string is last element
                THEN
                    l_element                  := SUBSTR( p_input, l_startloc );
                ELSE
                    l_element                  := SUBSTR( p_input, l_startloc, l_loc - l_startloc );
                END IF;

                p_add_element( l_element );

                IF l_loc = 0
                THEN
                    EXIT;
                ELSE
                    l_startloc                 := l_loc + 1;
                END IF;
            END LOOP;
        END IF;

        RETURN v_output_array;
    EXCEPTION
        WHEN data_too_large_excep
        THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_out_of_range
                                           , p_text_in                  => 'Delimiter or delimited data is too large'
                                           , p_name1_in                 => 'Next l_element'
                                           , p_value1_in                => SUBSTR( SUBSTR( p_input, l_startloc )
                                                                                 , 1
                                                                                 , 4000 )
                                           , p_name2_in                 => 'p_delimiter'
                                           , p_value2_in                => p_delimiter );
    END f_list_to_num_array;

    --=========================================================================
    -- Function to take a delimited list and load it into a string nested table
    -- array of type number
    --........................................................................
    FUNCTION f_list_to_num_nested_tab( p_input                       IN varchar2
                                        , p_delimiter                   IN varchar2 DEFAULT ',' )
        RETURN number_nt
    IS
        l_element       varchar2( 32767 );
        l_delimiter     varchar2( 5 );
        l_loc           pls_integer;
        l_startloc      pls_integer := 1;
        v_output_array  number_nt;

        data_too_large_excep exception;
        PRAGMA EXCEPTION_INIT( data_too_large_excep, -6502 );

        --========================================================================
        --========================================================================
        PROCEDURE p_add_element( p_element_in IN varchar2 )
        IS
        BEGIN
            IF ( p_element_in != l_delimiter
             OR p_element_in IS NULL )
            THEN
                v_output_array.EXTEND;
                v_output_array( NVL( v_output_array.LAST, 0 ) ) := TO_NUMBER(p_element_in);
            END IF;
        EXCEPTION
        WHEN value_error THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_out_of_range
                                           , p_text_in                  => 'Number conversion error: Data is not a number'
                                           , p_name1_in                 => 'p_element_in'
                                           , p_value1_in                =>  p_element_in
                                           , p_name2_in                 => 'Element Number'
                                           , p_value2_in                => (NVL( v_output_array.LAST, 0 ) + 1) );                                
        END p_add_element;
    --========================================================================
    --========================================================================
    BEGIN
        v_output_array             := number_nt( );
        l_delimiter                := NVL( p_delimiter, ',' );

        IF p_input IS NOT NULL
        THEN
            LOOP
                -- Find next delimiter
                l_loc                      := INSTR( p_input, l_delimiter, l_startloc );

                IF l_loc = l_startloc -- Previous element is NULL
                THEN
                    l_element                  := NULL;
                ELSIF l_loc = 0 -- Rest of string is last element
                THEN
                    l_element                  := SUBSTR( p_input, l_startloc );
                ELSE
                    l_element                  := SUBSTR( p_input, l_startloc, l_loc - l_startloc );
                END IF;

                p_add_element( l_element );

                IF l_loc = 0
                THEN
                    EXIT;
                ELSE
                    l_startloc                 := l_loc + 1;
                END IF;
            END LOOP;
        END IF;

        RETURN v_output_array;
    EXCEPTION
        WHEN data_too_large_excep
        THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_out_of_range
                                           , p_text_in                  => 'Delimiter or delimited data is too large'
                                           , p_name1_in                 => 'Next l_element'
                                           , p_value1_in                => SUBSTR( SUBSTR( p_input, l_startloc )
                                                                                 , 1
                                                                                 , 4000 )
                                           , p_name2_in                 => 'p_delimiter'
                                           , p_value2_in                => p_delimiter );
    END f_list_to_num_nested_tab;


    --=========================================================================
    -- Function to take a varchar2 input field and cast it as a date and return
    -- that date.
    --........................................................................
    FUNCTION f_string_to_date( p_input_field_name            IN varchar2
                             , p_input                       IN varchar2 )
        RETURN date
    IS
        v_input  varchar2( 20 );
        v_date   date;
        e_invalid_input_length exception;
    BEGIN
        p_assert( p_condition                => p_input_field_name IS NOT NULL
                , p_message                  => 'NULL input field name'
                , p_fatal                    => TRUE );

        IF p_input IS NULL
        THEN
            RETURN NULL;
        END IF;

        v_input                    := TRIM( REPLACE( p_input, '/', '-' ) );
        v_input                    := TRIM( REPLACE( p_input, '.', '-' ) );

        -- add the leading 0 if it is missing e.g. "1-apr-2007" becomes "01-apr-2007"
        IF INSTR( v_input, '-' ) = 2
        THEN
            v_input                    := '0' || v_input;
        END IF;

        CASE LENGTH( v_input )
            WHEN 8
            THEN
                v_date                     := TO_DATE( v_input, 'DD-MM-RR' );
            WHEN 9
            THEN
                v_date                     := TO_DATE( v_input, 'DD-MON-RR' );
            WHEN 10
            THEN
                v_date                     := TO_DATE( v_input, 'DD-MM-YYYY' );
            WHEN 11
            THEN
                v_date                     := TO_DATE( v_input, 'DD-MON-YYYY' );
            ELSE
                RAISE e_invalid_input_length;
        END CASE;

        RETURN v_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_err_invalid_date
                                           , p_text_in                  => 'Passed date String is not a valid date'
                                           , p_name1_in                 => 'p_input_field_name'
                                           , p_value1_in                => p_input_field_name
                                           , p_name2_in                 => 'p_input'
                                           , p_value2_in                => p_input );
    END f_string_to_date;


    --=========================================================================
    -- Function to take a varchar2 input field and cast it as a number and return
    -- that number to the client
    --........................................................................
    FUNCTION f_string_to_number( p_input_field_name            IN varchar2
                               , p_input                       IN varchar2 )
        RETURN number
    IS
        v_number  number;
        numeric_conv_excep exception;
        PRAGMA EXCEPTION_INIT( numeric_conv_excep, -6502 );
    BEGIN
        p_assert( p_condition                => p_input_field_name IS NOT NULL
                , p_message                  => 'NULL input field name'
                , p_fatal                    => TRUE );

        IF p_input IS NULL
        THEN
            RETURN NULL;
        END IF;

        v_number                   := TO_NUMBER( p_input );
        RETURN v_number;
    EXCEPTION
        WHEN numeric_conv_excep
        THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_err_invalid_number
                                           , p_text_in                  => 'Passed date String is not a valid number'
                                           , p_name1_in                 => 'p_input_field_name'
                                           , p_value1_in                => p_input_field_name
                                           , p_name2_in                 => 'p_input'
                                           , p_value2_in                => p_input );
    END f_string_to_number;


    --=========================================================================
    -- Function to take a varchar2 input field and check to see if its null
    -- if it is raise an application error
    --........................................................................
    FUNCTION f_check_for_null( p_input_field_name            IN varchar2
                             , p_input                       IN varchar2 )
        RETURN varchar2
    IS
    BEGIN
        p_assert( p_condition                => p_input_field_name IS NOT NULL
                , p_message                  => 'NULL input field name'
                , p_fatal                    => TRUE );

        IF p_input IS NULL
        THEN
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_err_missing_data
                                           , p_text_in                  => 'Passed String ('
                                                                          || p_input
                                                                          || ') is a mandatory field.'
                                           , p_name1_in                 => 'p_input'
                                           , p_value1_in                => p_input );
        END IF;

        RETURN p_input;
    END f_check_for_null;

    --=========================================================================
    --=========================================================================
    -- The following procedures and functions are for use when doing dynamic
    -- filtering of SQL statements.  They parse and build the SQL WHERE clauses
    -- for you.
    --=========================================================================
    --=========================================================================

    --=========================================================================
    -- Function to extract the string between a pair of delimiters
    -- The occurence is eg 1st , 2nd , 3rd etc  occurece of the delimiter pair
    -- within the string
    --........................................................................
    FUNCTION f_get_string_between_delims (
        p_input_string          IN  varchar2,
        p_occurence             IN  number,
        p_start_delimiter       IN  varchar2 DEFAULT '[',
        p_end_delimiter         IN  varchar2 DEFAULT ']'
        )
        RETURN varchar2
    IS
        v_left_delim_pos    pls_integer;
        v_right_delim_pos   pls_integer;
        v_return            varchar2(32000);
    BEGIN
        p_assert( p_condition                => (p_occurence IS NOT NULL)
                , p_message                  => 'p_occurence input cannot be NULL'
                , p_fatal                    => TRUE );

        p_assert( p_condition                => (p_occurence <> 0)
                , p_message                  => 'p_occurence input cannot be zero'
                , p_fatal                    => TRUE );

        p_assert( p_condition                => p_start_delimiter IS NOT NULL
                , p_message                  => 'p_start_delimiter input cannot be NULL'
                , p_fatal                    => TRUE );

        p_assert( p_condition                => p_end_delimiter IS NOT NULL
                , p_message                  => 'p_end_delimiter input cannot be NULL'
                , p_fatal                    => TRUE );


        v_left_delim_pos         := INSTR( p_input_string, p_start_delimiter,1, p_occurence );
        v_right_delim_pos        := INSTR( p_input_string, p_end_delimiter,1, p_occurence );

        IF (v_left_delim_pos = 0 AND v_right_delim_pos = 0) THEN

            -- set the return to null
            v_return := NULL;
        ELSIF   (v_left_delim_pos = 0 AND v_right_delim_pos <> 0) OR
                (v_left_delim_pos <> 0 AND v_right_delim_pos = 0) OR
                (v_left_delim_pos > v_right_delim_pos) THEN
           -- raise error not enough occurences
           pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_validation
                                          , p_text_in                  => 'Badly formed filter: delimiters are out of position'
                                          , p_name1_in                 => 'p_input_string'
                                          , p_value1_in                => p_input_string );
        ELSE
            v_return := SUBSTR( p_input_string, v_left_delim_pos + 1, v_right_delim_pos - 1 - v_left_delim_pos );
        END IF;

        pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                 , p_text_in                  => 'Delimited Data = ' || v_return );


        RETURN v_return;
    END f_get_string_between_delims;


    --=========================================================================
    -- Procedure to parse an input string of the format  NAME=VALUE
    -- and extract the name and value into output variables
    --........................................................................
    PROCEDURE p_get_name_value_pairs (
        p_input_string          IN  varchar2,
        po_name                     OUT varchar2,
        po_value                    OUT varchar2)
    IS
        v_equals_pos         pls_integer;
    BEGIN
        IF p_input_string IS NOT NULL THEN
--            IF INSTR( p_input_string, '=', 1, 2 ) > 0 THEN
--                -- if more than 1 occurence of equals exists raise an error
--                pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_err_validation
--                                               , p_text_in                  => 'Badly formed filter: More than one equals found in name value pair'
--                                               , p_name1_in                 => 'p_input_string'
--                                               , p_value1_in                => p_input_string );
--            END IF;

            v_equals_pos := INSTR( p_input_string, '=' );

            IF v_equals_pos = 0 THEN
                -- raise error
                pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_err_validation
                                               , p_text_in                  => 'Badly formed filter: No equals found in name value pair'
                                               , p_name1_in                 => 'p_input_string'
                                               , p_value1_in                => p_input_string );
            END IF;

            po_name     := SUBSTR( p_input_string, 1, v_equals_pos - 1 );
            po_value    := SUBSTR( p_input_string, v_equals_pos + 1);
        ELSE
            po_name     := NULL;
            po_value    := NULL;
        END IF;

        pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                 , p_text_in                  => 'po_name = ' || po_name );


        pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                 , p_text_in                  => 'po_value = ' || po_value );

    END p_get_name_value_pairs;




--............................................................
--  Initialization section
--============================================================
BEGIN
    NULL;
END pkg_utils;
/
