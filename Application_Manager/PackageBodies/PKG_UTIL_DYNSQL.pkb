CREATE OR REPLACE PACKAGE BODY pkg_util_dynsql
AS
    /******************************************************************************
      NAME:       pkg_util_dynsql
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

    c_package_context_name          CONSTANT  varchar2( 21 ) := 'PKG_UTIL_DYNSQL_CTX';

    --=============================================================================
    --
    --      PRIVATE PROCEDURES AND FUNCTIONS
    --
    --=============================================================================

    -- Note:  P_SET_FILTER_OPTIONS is a private procedure but has been placed below
    --        simply to keep it in line with the comments help

    --=============================================================================
    --
    --      PUBLIC PROCEDURES AND FUNCTIONS
    --
    --=============================================================================


    --=========================================================================
    --=========================================================================
    -- The following procedures and functions are for use when doing dynamic
    -- filtering of SQL statements.  They parse and build the SQL WHERE clauses
    -- for you.
    --=========================================================================
    --=========================================================================


    
    --=========================================================================
    -- Procedure to parse a filter string (used in dynamic sql procedures)
    -- The filter string contains name value pairs of the following types:
    --      the column_name
    --      the column value (data)
    --      data type
    --      the operator
    --      a custom filter (optional)
    --
    -- This procedure extracts the above fields from the filter string and
    -- return them in separate output paramaters.
    --........................................................................
    PROCEDURE p_parse_filter_string( p_filter_string               IN     VARCHAR2
                                   , po_column_name                   OUT VARCHAR2
                                   , po_data_string                   OUT VARCHAR2
                                   , po_data_type                     OUT VARCHAR2
                                   , po_operator                      OUT VARCHAR2
                                   , po_custom_context_name           OUT VARCHAR2
                                   , po_custom_filter                 OUT VARCHAR2 )
    IS
        i                      PLS_INTEGER := 1;
        v_delimited_data       VARCHAR2( 32000 );
        v_name                 VARCHAR2( 50 );
        v_value                VARCHAR2( 32000 );
        v_col_name_present     BOOLEAN := FALSE;
        v_data_string_present  BOOLEAN := FALSE;
        v_data_type_present    BOOLEAN := FALSE;

        --==========================================================================
        PROCEDURE p_parse_name_value_pair
        IS
        BEGIN
            IF v_name = 'COLUMN_NAME'
            THEN
                -- set column name and flag
                v_col_name_present         := TRUE;
                po_column_name             := v_value;
            ELSIF v_name = 'DATA_STRING'
            THEN
                -- set column name and flag
                v_data_string_present      := TRUE;
                po_data_string             := v_value;
            ELSIF v_name = 'DATA_TYPE'
            THEN
                -- set column name and flag
                v_data_type_present        := TRUE;
                po_data_type               := v_value;
            ELSIF v_name = 'OP'
            THEN
                -- set data type
                po_operator                := v_value;
            ELSIF v_name = 'CUSTOM_CONTEXT_NAME' 
            THEN
                -- set custom context name
                po_custom_context_name := v_value;                              
            ELSIF v_name = 'CUSTOM_FILTER'
            THEN
                -- set custom filter
                po_custom_filter           := v_value;
            ELSE
                -- raise FATAL error
                pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_validation
                                               , p_text_in                  => 'Badly formed filter: Invalid name value pair'
                                               , p_name1_in                 => 'v_name'
                                               , p_value1_in                => v_name );
            END IF;
        END p_parse_name_value_pair;
    --==========================================================================
    BEGIN
        LOOP
            v_delimited_data           := NULL;
            v_name                     := NULL;
            v_value                    := NULL;

            v_delimited_data           :=
                pkg_utils.f_get_string_between_delims( p_input_string => p_filter_string, p_occurence => i );
            -- increment the counter
            i                          := i + 1;

            -- set exit condition
            EXIT WHEN v_delimited_data IS NULL;

            -- extract the name value pair
            pkg_utils.p_get_name_value_pairs( p_input_string             => v_delimited_data
                                            , po_name                    => v_name
                                            , po_value                   => v_value );

            -- parse the resulting name value pair
            p_parse_name_value_pair;

            -- set maximum loop exit condition
            EXIT WHEN i = 100;
        END LOOP;

        pkg_error_manager.p_trace( p_context_in => 'LEVEL1', p_text_in => 'po_column_name = ' || po_column_name );
        pkg_error_manager.p_trace( p_context_in => 'LEVEL1', p_text_in => 'po_data_string = ' || po_data_string );
        pkg_error_manager.p_trace( p_context_in => 'LEVEL1', p_text_in => 'po_data_type = ' || po_data_type );
        pkg_error_manager.p_trace( p_context_in => 'LEVEL1', p_text_in => 'po_operator = ' || po_operator );
        pkg_error_manager.p_trace( p_context_in => 'LEVEL1', p_text_in => 'po_custom_context_name = ' || po_custom_context_name );                
        pkg_error_manager.p_trace( p_context_in => 'LEVEL1', p_text_in => 'po_custom_filter = ' || po_custom_filter );


        -- now check the results
        -- we MUST have a COLUMN NAME, DATA_STRING and DATA_TYPE set as a minimum
        pkg_utils.p_assert( p_condition                => v_col_name_present = TRUE
                          , p_message                  => 'Badly formed filter: Must have COLUMN_NAME name value pair in filter'
                          , p_fatal                    => TRUE );

        pkg_utils.p_assert( p_condition                => v_data_string_present = TRUE
                          , p_message                  => 'Badly formed filter: Must have DATA_STRING name value pair in filter'
                          , p_fatal                    => TRUE );

        pkg_utils.p_assert( p_condition                => v_data_type_present = TRUE
                          , p_message                  => 'Badly formed filter: Must have DATA_TYPE name value pair in filter'
                          , p_fatal                    => TRUE );

        -- now check that if the custom data type is set we must have a custom filter
        -- and if its not set then we should NOT have a custrom filter set.
        IF ( po_data_type = 'CUSTOM'
        AND po_custom_filter IS NULL )
        OR ( po_data_type <> 'CUSTOM'
        AND po_custom_filter IS NOT NULL )
        THEN
            -- raise a FATAL error
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_validation
                                           , p_text_in                  => 'Invalid Filter column set'
                                           , p_name1_in                 => 'po_column_name'
                                           , p_value1_in                => po_column_name );
        END IF;
    END p_parse_filter_string;


    --=========================================================================
    -- Procedure to build a filter string in which to use in the
    -- p_set_filter_options procedure below
    --........................................................................
    FUNCTION f_build_filter_string( p_column_name                 IN VARCHAR2
                                  , p_data_string                 IN VARCHAR2
                                  , p_data_type                   IN VARCHAR2
                                  , p_operator                    IN VARCHAR2
                                  , p_custom_context_name         IN VARCHAR2 DEFAULT NULL
                                  , p_custom_filter               IN VARCHAR2 DEFAULT NULL )
        RETURN VARCHAR2
    IS
        v_return  VARCHAR2( 32000 );
    BEGIN
        pkg_utils.p_assert( p_condition                => p_column_name IS NOT NULL
                          , p_message                  => 'Badly formed filter: Column name is mandatory'
                          , p_fatal                    => TRUE );

        pkg_utils.p_assert( p_condition                => p_data_type IS NOT NULL
                          , p_message                  => 'Badly formed filter: Data type is mandatory'
                          , p_fatal                    => TRUE );

        pkg_utils.p_assert( p_condition                => p_data_type IN
                                                                 ( 'VARCHAR2'
                                                                , 'NUMBER'
                                                                , 'DATE'
                                                                , 'ARRAY_VAR250'
                                                                , 'ARRAY_NUM'
                                                                , 'CUSTOM' )
                          , p_message                  => 'Badly formed filter: Invalid data type'
                          , p_fatal                    => TRUE );

        -- now check that if the custom data type is set we must have a custom filter
        -- and if its not set then we should NOT have a custrom filter set.
        IF ( p_data_type = 'CUSTOM'
        AND p_custom_filter IS NULL )
        OR ( p_data_type <> 'CUSTOM'
        AND p_custom_filter IS NOT NULL )
        THEN
            -- raise a FATAL error
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_validation
                                           , p_text_in                  => 'Badly formed filter: CUSTOM filter is invalid'
                                           , p_name1_in                 => 'p_data_type'
                                           , p_value1_in                => p_data_type
                                           , p_name2_in                 => 'p_custom_filter'
                                           , p_value2_in                => p_custom_filter );
        END IF;

        IF p_data_type <> 'CUSTOM'
        THEN
            v_return                   :=
                '[COLUMN_NAME='
                || p_column_name
                || '][OP='
                || p_operator
                || '][DATA_STRING='
                || p_data_string
                || '][DATA_TYPE='
                || p_data_type
                || '][CUSTOM_CONTEXT_NAME='
                || p_custom_context_name 
                || ']';                
        ELSE
            v_return                   :=
                '[COLUMN_NAME='
                || p_column_name
                || '][DATA_STRING='
                || p_data_string
                || '][DATA_TYPE=CUSTOM][CUSTOM_FILTER='
                || p_custom_filter
                || '][CUSTOM_CONTEXT_NAME='
                || p_custom_context_name 
                || ']';
        END IF;

        RETURN v_return;
    END f_build_filter_string;


    --=========================================================================
    -- Procedure to setup a filter string or strings for a dynamic WHERE clause
    -- to be used in a dynamic SQL query.
    --
    -- This procedure gives you 2 different ways of filtering
    --
    --      1. Using a fixed number of BINDS.
    --      2. Using APPLICATION CONTEXTS  ie SYS_CONTEXT    
    --
    -- Traditionally the CONTEXTS method has been used however this does not always 
    -- result in the best execution plans therefore the BINDS method which
    -- uses a fixed number of BINDS produces simpler looking SQL and the optimiser 
    -- is able to produce a better plan.  Therefore the BINDS method is the preferred 
    -- choice however CONTEXTS method has been included in case you need more flexibility.
    --
    --================================================================================================    
    -- 1. BINDS method
    -- ================
    --
    --  To use the BINDS methods then you should populate other input parameters but leave p_filter_string as NULL.
    --  You MUST set the p_column_name to be the name of the column in upper case but this can include aliases
    --  eg   'a.NURSE_ID'  -- the column name will be extracted from this by taking everything after the full stop.
    --  
    --  You MUST set the data type to be one of: VARCHAR2, NUMBER, DATE, ARRAY_VAR250, ARRAY_NUM, CUSTOM
    --  
    --  You MUST set the p_data_is_null parameter to be 'TRUE' or 'FALSE'.  This indicates whether or not the actual data that is
    --  going to be bound is null or not.
    --
    --  The rest of the parameters are optional.
    --
    --  This method is different to the CONTEXTS in that it can only setup 1 filter at a time so therfore must be 
    --  called multiple times from your calling procedure.
    --  So you can set the column name, data type, operator if you wish and you must indicate whether or not 
    --  the data you are binding exists or not.  Then the resulting filter string produced looks like :
    --
    --  IF the data is not NULL then you get 
    --                                      'AND UPPER(nurse_id) LIKE '%' || :p_nurse_id || '%'
    --
    --  however if the date IS NULL then you get
    --                                      'AND ( 1=1 OR :p_nurse_id IS NULL )
    -- 
    --  So you can see either way you will ALWAYS be binding in the nurse id therfore you know 
    --  exactly how many BINDS to use in your EXCECUTE IMMEDIATE or OPEN CURSOR expression.
    --  The 1=1 part lets the optimiser just ignore the rest of the line and so removes it from 
    --  the resulting plan...whereas with the CONTEXTS method the filter is always there and 
    --  the optimiser has to convert the data types also... with this method no conversions are needed.
    --
    --  The above example is for VARCHAR2... the number, date work in a similar way and you can use the
    --  operaator paramter if you wish to replace the = with something else.
    --  If you wish to bind in arrays then you must pass in the data in a string delimited by pipes |
    -- 
    --      eg  '20|23|3442|32'  for a number array
    --
    --  Then the resulting filter will look like
    --      'AND column_name IN (   SELECT column_value
    --                              FROM TABLE( CAST( :p_column_name AS number_nt)))'
    --
    --  So when you use this filter you must convert the string of delimited numbers to be a nested table 
    --  of type NUMBER_NT which is declared as a type in the database.
    --  Similarly for varchars you must use a VARCHAR_250_NT  nested table type.
    --
    --  For CUSTOM filters with the BIND method. If the data type is CUSTOM then the p_custom_filter
    --  parameter is added to the filter clause directly so you can use free text to code anything in here
    --  you just use it as if it were an AND statement ... note that you do not need to type ni the AND
    --          ie you get a filter that is:     'AND ' || p_custom_filter
    --
    --
    --  To use the binds method you must pass in each parameter to your calling procedure 
    --  explicitly and NOT hide them in a string of delimited parameters.
    --  You need a SEPARATE parameter for EACH filter that you wish to add to your WHERE clause
    --
    --  An example call from your calling procedure would be:
    --
    --  pkg_util_dynsql.p_set_filter_options (  p_column_name   =>  'USER_ID',
    --                                          p_data_type     =>  'NUMBER',
    --                                          p_data_is_null  =>   pkg_utils.f_is_data_null( p_user_id ),
    --                                          po_filter_clause =>  v_filter_clause                
    --                                      );
    --
    --  Note the call to pkg_utils.f_is_data_null which returns a 'TRUE' or 'FALSE' string
    --  Then in when you come to run your dyanmic sql you would do for example:
    --
    --      OPEN c_cur FOR 'SELECT .....' USING ...., p_user_id, ... ;
    --
    --  You would need to do that for each of your potential filter parameters.
    --
    --================================================================================================ 
    -- 2. APPLICATION CONTEXTS
    -- =======================
    --
    -- To use application CONTEXTS then all you need to do is call this 
    -- procedure with the p_filter_string parameter set and ensure that all of the 
    -- other input parameters are set to NULL.
    --
    -- The p_filter_string parameter must contain the filter string which is formatted 
    -- in a very specific way and the resulting string passed back is the actual 
    -- WHERE clause that will be used in the final dynamic SQL query.
    --    
    -- You can setup multiple field filters by delimiting each filter by a tilda '~'
    -- therefore you would have something that looks like this:
    --
    --  [COLUMN_NAME=user_id][OP=][DATA_STRING=100][DATA_TYPE=NUMBER][CUSTOM_CONTEXT_NAME=max_id][CUSTOM_FILTER=]~
    --  [COLUMN_NAME=nurse_id][OP=][DATA_STRING=200][DATA_TYPE=NUMBER][CUSTOM_FILTER=]~
    --  [COLUMN_NAME=org_id][OP=][DATA_STRING=300][DATA_TYPE=NUMBER][CUSTOM_FILTER=]
    --
    -- (NOTE : WITHOUT the carriage returns... these filters would be on the same line
    --         delimited by ~ its just that they are too long to show that on here)
    -- 
    -- There are 5 different data types that you are allowed to filter on:
    --  VARCHAR2, NUMBER, DATE, ARRAY_VAR250, ARRAY_NUM
    --
    -- The last 2 are strings that will be converted to arrays used for 'IN' lists.
    --
    -- This procedure sets up the filter options to use in a session context by 
    -- parsing the filter string that has been formatted correctly.
    --
    -- It accepts filter strings which contain name/value pairs which describe the filter:
    -- eg
    --  [COLUMN_NAME=user_code][OP=][DATA_STRING=user1][DATA_TYPE=VARCHAR2][CUSTOM_FILTER=]
    --
    --  the above example would produce the following filter string:   
    --  'AND UPPER(user_code) LIKE SYS_CONTEXT( 'PKG_UTIL_DYNSQL', 'P_user_code', 4000)
    --
    -- and the user code of "user1" would be placed in the session_context table. 
    --    
    -- For number data types an example is :
    --
    --  [COLUMN_NAME=user_id][OP=][DATA_STRING=100][DATA_TYPE=NUMBER][CUSTOM_FILTER=]
    --
    -- which gives the filter : 'AND user_id = pkg_utils.f_string_to_number( SYS_CONTEXT( 'PKG_UTIL_DYNSQL', 'P_user_id') )
    --
    -- If you set the OPERATOR by setting OP=<>  then this is valid for NUMBER OR DATE
    -- types and would replace the = operator that would normally exist.
    --
    -- For DATE types the resulting filter looks like:
    --
    --  AND created_dts = pkg_utils.f_string_to_date( SYS_CONTEXT( 'PKG_UTIL_DYNSQL', 'P_created_Dts') )
    --
    --  So normal filtering for number, strings and dates follow the following formats
    --
    --  numbers :       column_name = pkg_utils.f_string_to_number(SYS_CONTEXT('context_name', P_COLUMN_NAME ) )
    --  varchars:       UPPER(column_name) LIKE  '%' || SYS_CONTEXT('context_name', P_COLUMN_NAME ) || '%'
    --  dates:          TRUNC(column_name) = TRUNC( pkg_utils.f_string_to_date( SYS_CONTEXT('context_name', P_COLUMN_NAME ) ...etc
    --
    --  If you need other types of filtering you can use the CUSTOM data type
    --  eg if you needed the filter to be   column >= data   then that is a CUSTOM filter
    --
    --  So to set up a custom filter use the following as an example
    --
    --              [COLUMN_NAME=NURSE_ID][DATA_STRING=23][DATA_TYPE=CUSTOM][OP=][CUSTOM_FILTER=%COLUMN_NAME% >= %DATA_STRING%]
    --
    --  This will set up a custom filter of  'AND NURSE_ID >= SYS_CONTEXT('context_name', P_NURSE_ID )
    --  with the value of 23 inserted into the context.
    --  The %COLUMN_NAME%  and %DATA_STRING%   are substitution values used to reference the column name
    --  data string...so it is important that you use those exact strings in the filter ie %COLUMN_NAME%  and %DATA_STRING%
    --
    --  The [CUSTOM_CONTEXT_NAME=]  name /value pair is for the situation where you are using a particulare filter twice
    --  and you need to set up to filters.  For example:
    --
    --            [COLUMN_NAME=start_date][OP=<=][DATA_STRING=01/01/2009][DATA_TYPE=DATE][CUSTOM_FILTER=]
    --            [COLUMN_NAME=start_date][OP=>=][DATA_STRING=01/03/2009][DATA_TYPE=DATE][CUSTOM_FILTER=]
    --
    --  In this case you would get 2 filters that looked like this    
    --                      AND start_date <= SYS_CONTEXT( 'ctxt_name', 'p_start_date' )
    --                      AND start_date >= SYS_CONTEXT( 'ctxt_name', 'p_start_date' )
    --
    --  as you can see they are both referencing the p_start_date SESSION_CONTEXT variable, since this was
    --  built using the column name value.
    --  This would not work since we need to set up a different context name so that we can get 2 SESSION_CONTEXTS
    --  so we use the CUSTOM_CONTEXT_NAME to get round this ie :
    --
    --            [COLUMN_NAME=start_date][OP=<=][DATA_STRING=01/01/2009][DATA_TYPE=DATE][CUSTOM_CONTEXT_NAME=start_date_to][CUSTOM_FILTER=]
    --            [COLUMN_NAME=start_date][OP=>=][DATA_STRING=01/03/2009][DATA_TYPE=DATE][CUSTOM_CONTEXT_NAME=start_date_from][CUSTOM_FILTER=]
    --
    -- this would then produce filters that looked like this:
    --                      AND start_date <= SYS_CONTEXT( 'ctxt_name', 'p_start_date_to' )
    --                      AND start_date >= SYS_CONTEXT( 'ctxt_name', 'p_start_date_from' )
    --
    --  As you can see this is now what you would want.
    --
    --=================================================================================================
    --
    --  NOTE:
    --  The p_set_filter_options is now a PRIVATE procedure with 2 wrapper procedures to use either    
    -- the BINDS or CONTEXTS methods
    --
    --================================================================================================    
    --
    -- NOTE: Both methods work well and can be used in different situations however the BINDS method
    --      should be the first choice.
    --........................................................................
    PROCEDURE p_set_filter_options( p_filter_string               IN     VARCHAR2   DEFAULT NULL    
                                  , p_column_name                 IN     VARCHAR2   DEFAULT NULL
                                  , p_data_type                   IN     VARCHAR2   DEFAULT NULL                                  
                                  , p_operator                    IN     VARCHAR2   DEFAULT NULL
                                  , p_data_is_null                IN     VARCHAR2   DEFAULT NULL
                                  , p_custom_filter               IN     VARCHAR2   DEFAULT NULL
                                  , po_filter_clause              IN OUT VARCHAR2 )
    IS
        v_use_contexts          BOOLEAN;
        v_column_name           VARCHAR2( 50 );
        v_raw_column_name       VARCHAR2( 50 );
        v_data_string           VARCHAR2( 500 );
        v_operator              VARCHAR2( 10 );
        v_data_type             VARCHAR2( 50 );
        v_varchar250_array      pkg_utils.varchar250_array_type;
        v_number_array          pkg_utils.varchar250_array_type;
        v_context_name          VARCHAR2( 50);
        v_custom_context_name   VARCHAR2( 50);
        v_custom_filter         VARCHAR2( 500 );

        --======================================================================
        --======================================================================
        PROCEDURE p_set_filter_type
        IS
        BEGIN
            IF p_filter_string IS NOT NULL AND (
                    p_column_name       IS NOT NULL OR
                    p_operator          IS NOT NULL OR
                    p_data_is_null      IS NOT NULL OR
                    p_data_type         IS NOT NULL OR
                    p_custom_filter     IS NOT NULL ) THEN
                -- if we have a filter string set then we are using the context
                -- filtering method therefore no other parameters should be set
                -- if they are then raise a FATAL error                    
                pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_validation
                                               , p_text_in                  => 'Badly formed filter: More than one filter method is being used'
                                               , p_name1_in                 => 'p_filter_string'
                                               , p_value1_in                => p_filter_string);                    
            END IF;                    
            
            IF p_filter_string IS NOT NULL THEN
                pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                         , p_text_in                  => 'Setting filter type to CONTEXTS:...');
            
                -- then the filter type is using CONTEXTS
                v_use_contexts := TRUE;
                                
                -- call procedure to parse the filter string and setup the variables
                p_parse_filter_string( p_filter_string            => p_filter_string
                                     , po_column_name             => v_column_name
                                     , po_data_string             => v_data_string
                                     , po_data_type               => v_data_type
                                     , po_operator                => v_operator
                                     , po_custom_context_name     => v_custom_context_name
                                     , po_custom_filter           => v_custom_filter );                
            ELSE
                pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                         , p_text_in                  => 'Setting filter type to BINDS:...');
            
                -- we are using the BINDS method
                v_use_contexts := FALSE; 
                
                -- so now set up the variables
                v_column_name       := p_column_name;
                v_operator          := p_operator;
                v_data_type         := p_data_type;
                v_custom_filter     := p_custom_filter;        
            END IF;

        END p_set_filter_type;
        --======================================================================
        --======================================================================
        PROCEDURE p_validate_data
        IS
        BEGIN
            -- here we check for the prescence of data in the column name and data type strings
            pkg_utils.p_assert( p_condition                => v_column_name IS NOT NULL
                              , p_message                  => 'Badly formed filter: Must have column name data present in filter'
                              , p_fatal                    => TRUE );

            pkg_utils.p_assert( p_condition                => v_data_type IS NOT NULL
                              , p_message                  => 'Badly formed filter: Must have data type data present in filter'
                              , p_fatal                    => TRUE );

            -- if using the binding method we also must have p_data_is_null set
            IF v_use_contexts = FALSE THEN
                pkg_utils.p_assert( p_condition                => p_data_is_null IN ('TRUE', 'FALSE')
                                  , p_message                  => 'p_data_is_null must be TRUE OR FALSE'
                                  , p_fatal                    => TRUE );
            END IF;                                  

            -- in the case where we have used column alias' then we need to extract the actual
            -- column name eg   a.col_name   we need to get the col_name part
            -- so look for the period sign and extract the column name after it.
            IF INSTR( v_column_name, '.' ) > 0
            THEN
                v_raw_column_name          := SUBSTR( v_column_name, INSTR( v_column_name, '.' ) + 1 );
            ELSE
                v_raw_column_name          := v_column_name;
            END IF;
            
            -- set the operator if we have one
            v_operator                 := NVL( v_operator, '=' );

            -- now set the context name...use the raw column name unless we have a
            -- custom context name set
            v_context_name := NVL( v_custom_context_name, v_raw_column_name );            
        END p_validate_data;

        --======================================================================
        --======================================================================
        PROCEDURE p_set_varchar2_filter
        IS
        BEGIN
            pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                     , p_text_in                  => 'Setting VARCHAR2 filter column:...'
                                                                    || v_raw_column_name
                                                                    || '  to:...'
                                                                    || v_data_string );

            IF v_use_contexts = TRUE THEN
                -- setupt the context
                DBMS_SESSION.set_context( c_package_context_name
                                        , 'P_' || v_context_name
                                        , '%' || UPPER( v_data_string ) || '%' );
                -- set the filter clause
                po_filter_clause           :=
                    po_filter_clause
                    || CHR( 10 )
                    || 'AND UPPER( '
                    || v_column_name
                    || ' ) LIKE SYS_CONTEXT('''
                    || c_package_context_name
                    || ''',''P_'
                    || v_context_name
                    || ''', 4000) ';
            ELSE
                -- just set the filter clause to use the BINDS method 
                -- we know by getting here that the data is NOT NULL so set the filter:
                po_filter_clause           :=
                    po_filter_clause
                    || CHR( 10 )
                    || 'AND UPPER( '
                    || v_column_name
                    || ' ) LIKE ''%'' || UPPER( :p_' || v_raw_column_name || ' ) || ''%'' ';    
            END IF;
                                
        END p_set_varchar2_filter;

        --======================================================================
        --======================================================================
        PROCEDURE p_set_number_filter
        IS
        BEGIN
            pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                     , p_text_in                  => 'Setting NUMBER filter column:...'
                                                                    || v_raw_column_name
                                                                    || '  to:...'
                                                                    || v_data_string );

            IF v_use_contexts = TRUE THEN
            
                -- we are using the CONTEXTS method so set up the contexts
                DBMS_SESSION.set_context( c_package_context_name, 'P_' || v_context_name, v_data_string );
                -- set the filter clause
                po_filter_clause           :=
                    po_filter_clause
                    || CHR( 10 )
                    || 'AND '
                    || v_column_name
                    || ' '
                    || v_operator
                    || ' pkg_utils.f_string_to_number ( '''
                    || v_raw_column_name
                    || ''', SYS_CONTEXT('''
                    || c_package_context_name
                    || ''',''P_'
                    || v_context_name
                    || ''')) ';
            ELSE
                -- just set the filter clause to use the BINDS method 
                -- we know by getting here that the data is NOT NULL so set the filter:
                po_filter_clause           :=
                    po_filter_clause
                    || CHR( 10 )
                    || 'AND '
                    || v_column_name
                    || ' '
                    || v_operator                        
                    || ' :p_' || v_raw_column_name || ' ';    

            END IF;                    
        END p_set_number_filter;

        --======================================================================
        --======================================================================
        PROCEDURE p_set_date_filter
        IS
        BEGIN
            pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                     , p_text_in                  => 'Setting DATE filter column:...'
                                                                    || v_raw_column_name
                                                                    || '  to:...'
                                                                    || v_data_string );

            IF v_use_contexts = TRUE THEN
            
                DBMS_SESSION.set_context( c_package_context_name, 'P_' || v_context_name, v_data_string );
                -- set the filter clause
                po_filter_clause           :=
                    po_filter_clause
                    || CHR( 10 )
                    || 'AND TRUNC( '
                    || v_column_name
                    || ' ) '
                    || v_operator
                    || ' TRUNC( pkg_utils.f_string_to_date ( '''
                    || v_raw_column_name
                    || ''', SYS_CONTEXT('''
                    || c_package_context_name
                    || ''',''P_'
                    || v_context_name
                    || '''))) ';
            ELSE
                -- just set the filter clause to use the BINDS method 
                -- we know by getting here that the data is NOT NULL so set the filter:
                po_filter_clause           :=
                    po_filter_clause
                    || CHR( 10 )
                    || 'AND TRUNC( '
                    || v_column_name
                    || ' ) '
                    || v_operator                        
                    || ' TRUNC( :p_' || v_raw_column_name || ' ) ';    

            END IF;                    
        END p_set_date_filter;

        --======================================================================
        --======================================================================
        PROCEDURE p_set_vararray_filter
        IS
        BEGIN
            pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                     , p_text_in                  => 'Setting ARRAY_VAR250 filter column:...'
                                                                    || v_raw_column_name
                                                                    || '  to:...'
                                                                    || v_data_string );

            IF v_use_contexts = TRUE THEN
            
                v_varchar250_array         := pkg_utils.f_list_to_var250_array( v_data_string, '|' );

                FOR i IN v_varchar250_array.FIRST .. v_varchar250_array.LAST
                LOOP
                    DBMS_SESSION.set_context( c_package_context_name
                                            , 'P_' || v_context_name || '_' || i
                                            , UPPER( v_varchar250_array( i ) ) );
                END LOOP;

                -- set the filter clause
                po_filter_clause           :=
                    po_filter_clause 
                    || CHR( 10 ) 
                    || 'AND UPPER( ' || v_column_name
                    || ' ) IN ( SELECT  value
                                FROM    session_context
                                WHERE namespace = '''
                    || c_package_context_name
                    || '''
                                AND attribute LIKE ''P_'
                    || UPPER(v_context_name)
                    || '_%'') ';
            ELSE
                -- just set the filter clause to use the BINDS method 
                -- we know by getting here that the data is NOT NULL so set the filter:
                po_filter_clause           :=
                    po_filter_clause
                    || CHR( 10 )
                    || 'AND UPPER( ' || v_column_name
                    || ' ) IN ( SELECT  UPPER(column_value)
                                FROM    TABLE( CAST( :p_' || v_raw_column_name || ' AS varchar_250_nt))) ';    
            
            END IF;                    
        END p_set_vararray_filter;

        --======================================================================
        --======================================================================
        PROCEDURE p_set_numarray_filter
        IS
        BEGIN
            pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                     , p_text_in                  => 'Setting ARRAY_NUM filter column:...'
                                                                    || v_raw_column_name
                                                                    || '  to:...'
                                                                    || v_data_string );

            IF v_use_contexts = TRUE THEN
            
                -- we use a var250 array because the numbers in the array will be held in the
                -- session context table as VARCHARS so there is no point in converting them to number
                -- in the array here.
                v_number_array             := pkg_utils.f_list_to_var250_array( v_data_string, '|' );

                FOR i IN v_number_array.FIRST .. v_number_array.LAST
                LOOP
                    DBMS_SESSION.set_context( c_package_context_name
                                            , 'P_' || v_context_name || '_' || i
                                            , UPPER( v_number_array( i ) ) );
                END LOOP;

                -- set the filter clause
                po_filter_clause           :=
                    po_filter_clause
                    || CHR( 10 )
                    || 'AND '
                    || v_column_name
                    || ' IN ( SELECT  pkg_utils.f_string_to_number('''
                    || v_column_name
                    || ''', value) AS value
                              FROM    session_context
                              WHERE namespace = '''
                    || c_package_context_name
                    || '''
                              AND attribute LIKE ''P_'
                    || UPPER(v_context_name)
                    || '_%'') ';
            ELSE
                -- just set the filter clause to use the BINDS method 
                -- we know by getting here that the data is NOT NULL so set the filter:
                po_filter_clause           :=
                    po_filter_clause
                    || CHR( 10 )
                    || 'AND ' || v_column_name
                    || ' IN ( SELECT  column_value
                              FROM    TABLE( CAST( :p_' || v_raw_column_name || ' AS number_nt))) ';    
            
            END IF;                                        
        END p_set_numarray_filter;

        --======================================================================
        --======================================================================
        PROCEDURE p_set_custom_filter
        IS
        BEGIN
            IF v_use_contexts = TRUE THEN        
                v_custom_filter            := REPLACE( v_custom_filter, '%COLUMN_NAME%', v_raw_column_name );
                v_custom_filter            :=
                    REPLACE( v_custom_filter
                           , '%DATA_STRING%'
                           , 'SYS_CONTEXT('''
                             || c_package_context_name
                             || ''',''P_'
                             || v_context_name
                             || ''', 4000) ' );

                pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                         , p_text_in                  => 'Setting CUSTOM filter column:...'
                                                                        || v_raw_column_name
                                                                        || '  to:...'
                                                                        || v_custom_filter );


                DBMS_SESSION.set_context( c_package_context_name, 'P_' || v_context_name, v_data_string );
                -- set the filter clause
                po_filter_clause           := po_filter_clause || CHR( 10 ) || 'AND ' || v_custom_filter;
            ELSE
                -- just set the filter clause to use the BINDS method 
                -- we know by getting here that the data is NOT NULL so set the filter:
                po_filter_clause           := po_filter_clause || CHR( 10 ) || 'AND ' || v_custom_filter;            
            END IF;                
        END p_set_custom_filter;
    --======================================================================
    --======================================================================
    BEGIN
        -- first we check which type of filtering we are using
        p_set_filter_type;
        
        -- now validate the resulting variables
        p_validate_data;

        IF v_use_contexts = TRUE AND v_data_string IS NULL 
        THEN
            -- this is ok we just don't set any filters
            pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                     , p_text_in                  => 'Skipping filter column:...' || v_column_name );

        ELSIF v_use_contexts = FALSE AND p_data_is_null = 'TRUE' 
        THEN 
            pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                     , p_text_in                  => 'Setting filter column:...' || v_column_name );

            po_filter_clause           :=
            po_filter_clause
            || CHR( 10 )
            || 'AND ( 1=1 OR :p_' || v_raw_column_name || ' IS NULL) ';                    
        ELSIF v_data_type = 'VARCHAR2'
        THEN
            -- call procedure to setup the filter
            p_set_varchar2_filter;
        ELSIF v_data_type = 'NUMBER'
        THEN
            -- call procedure to setup the filter
            p_set_number_filter;
        ELSIF v_data_type = 'DATE'
        THEN
            -- call procedure to setup the filter
            p_set_date_filter;
        ELSIF v_data_type = 'ARRAY_VAR250'
        THEN
            -- call procedure to setup the filter
            p_set_vararray_filter;
        ELSIF v_data_type = 'ARRAY_NUM'
        THEN
            -- call procedure to setup the filter
            p_set_numarray_filter;
        ELSIF v_data_type = 'CUSTOM'
        THEN
            -- call procedure to setup the filter
            p_set_custom_filter;
        ELSE
            -- invalid data type found so raise error
            pkg_error_manager.p_raise_error( p_error_code_in            => pkg_constants.gc_ferr_validation
                                           , p_text_in                  => 'Badly formed filter: Invalid data type found'
                                           , p_name1_in                 => 'v_data_type'
                                           , p_value1_in                => v_data_type );
        END IF;
        
        pkg_error_manager.p_trace( p_context_in               => 'LEVEL1'
                                 , p_text_in                  => 'filter = ' || po_filter_clause);        
    END p_set_filter_options;

    --=========================================================================
    -- Procedure to act as wrapper around p_set_filter_options to use the BIND
    -- method. It allows you to call p_set_filter_options using the BIND method
    -- by excluding the p_filter_string parameter.
    --........................................................................
    PROCEDURE p_set_bind_filters(   p_column_name                 IN     VARCHAR2   DEFAULT NULL
                                  , p_data_type                   IN     VARCHAR2   DEFAULT NULL                                  
                                  , p_operator                    IN     VARCHAR2   DEFAULT NULL
                                  , p_data_is_null                IN     VARCHAR2   DEFAULT NULL
                                  , p_custom_filter               IN     VARCHAR2   DEFAULT NULL
                                  , po_filter_clause              IN OUT VARCHAR2 )
    IS
    BEGIN                                  
        -- call private procedure to set the filters...using the bind method
        p_set_filter_options(   p_column_name       =>  p_column_name
                              , p_data_type         =>  p_data_type                             
                              , p_operator          =>  p_operator
                              , p_data_is_null      =>  p_data_is_null
                              , p_custom_filter     =>  p_custom_filter
                              , po_filter_clause    =>  po_filter_clause);
    END p_set_bind_filters;
    
    
    --=========================================================================
    -- Procedure to act as wrapper around p_set_filter_options to use the CONTEXTS
    -- method. It allows you to call p_set_filter_options using the CONTEXTS method
    -- by including the p_filter_string parameter only and excluding the rest.
    --........................................................................
    PROCEDURE p_set_context_filters(  p_filter_string               IN     VARCHAR2
                                    , po_filter_clause              IN OUT VARCHAR2 )
    IS
    BEGIN                                  
        -- call private procedure to set the filters ...using the context method
        p_set_filter_options(   p_filter_string     =>  p_filter_string   
                              , po_filter_clause    =>  po_filter_clause);
    END p_set_context_filters;
    

    
    --=========================================================================
    -- Procedure to take a query string and a formatted filter string and a
    -- sort string and build an executable query string with the SYS contexts
    -- built in and the session context table inserted with all the filter data
    --........................................................................
    FUNCTION f_build_query( p_column_list                 IN VARCHAR2
                          , p_base_query                  IN VARCHAR2
                          , p_filter_options              IN VARCHAR2
                          , p_sort_string                 IN VARCHAR2
                          , p_initialise_context_flag     IN VARCHAR2 )
        RETURN VARCHAR2
    IS
        v_sql            VARCHAR2( 32767 );
        v_filter_clause  VARCHAR2( 32767 );
        v_filter_lines   pkg_utils.varchar250_array_type;
        v_sort_string    VARCHAR2( 500 );
        v_column_list_array pkg_utils.varchar250_array_type;

        --===============================================================================
        --===============================================================================
        PROCEDURE p_validate_parameters
        IS
        BEGIN
            -- note that a NULL column list would be replaced with * to select ALL columns
            -- from the base query.
        
            pkg_utils.p_assert( p_condition                => p_base_query IS NOT NULL
                              , p_message                  => 'Base query is mandatory'
                              , p_fatal                    => TRUE );

            pkg_utils.p_assert( p_condition                => p_initialise_context_flag IS NOT NULL
                              , p_message                  => 'Invalid flag: Must be TRUE or FALSE or BINDS'
                              , p_fatal                    => TRUE );

            pkg_utils.p_assert( p_condition                => NVL( p_initialise_context_flag, 'TRUE' ) IN
                                                                     ('TRUE', 'FALSE', 'BINDS')
                              , p_message                  => 'Invalid flag: Must be TRUE or FALSE or BINDS'
                              , p_fatal                    => TRUE );
                              
            -- check that the column list (if provided) is a valid comma delimited list..this should raise an
            -- error if the list cannot be converted to an array
            -- also check for leading or trailing commas            
            IF p_column_list IS NOT NULL THEN
                v_column_list_array := pkg_utils.f_list_to_var250_array( p_column_list, ',' );
                            
                -- now check no leading or trailing commas
                pkg_utils.p_assert( p_condition                => SUBSTR( TRIM( p_column_list ), 1, 1) <> ','
                                  , p_message                  => 'Column list is badly formed: leading comma'
                                  , p_fatal                    => TRUE );

                pkg_utils.p_assert( p_condition                => SUBSTR( TRIM( p_column_list ), -1, 1) <> ','
                                  , p_message                  => 'Column list is badly formed: trailing comma'
                                  , p_fatal                    => TRUE );                                    
            END IF;
                                                      
        END p_validate_parameters;

        --===============================================================================
        --===============================================================================
        PROCEDURE p_set_all_filter_options
        IS
            v_column_name  VARCHAR2( 50 );
            v_data_string  VARCHAR2( 100 );
            v_data_type    VARCHAR2( 8 );
        BEGIN
            pkg_error_manager.p_trace_start( p_context_in               => 'LOC'
                                           , p_text_in                  => 'f_build_query.p_set_all_filter_options' );

            -- first we check which type of filtering we are doing
            -- if the p_initialise_context_flag is set to BINDS then we are
            -- not using contexts therefore the filter string has been passed in 
            -- in its full format so we just use it...
            IF p_initialise_context_flag = 'BINDS' THEN
                -- just use the filter clause in its current format
                v_filter_clause := p_filter_options;
            ELSE
                -- if we are not using BINDS then we must be using the CONTEXTS method
                -- therefore we need to parse the delimited filter options string

                -- first choose whether or not to initialise contexts
                -- this is because your calling procedure might either be making multiple calls to 
                -- f_build_query to build multiple query strings OR it may be calling p_set_filter_options
                -- directly to build a filter string and therefore you might not always want to initialse the
                -- PKG_UTILS_DYNSQL_CTX  here since it would wipe out any other filters that your calling procedure 
                -- may have set.
                -- If DO set this flag to FALSE then you should ensure that you initialse the PKG_UTILS_DYNSQL_CTX context 
                -- in the maing wrapper procedure that calls this one.
                IF NVL( p_initialise_context_flag, 'TRUE' ) = 'TRUE'
                THEN
                    pkg_utils.p_initialise_context( c_package_context_name );
                ELSE
                    -- do not initialise
                    NULL;
                END IF;                                

                -- load the passed ~ delimited filters into an array
                v_filter_lines             := pkg_utils.f_list_to_var250_array( p_filter_options, '~' );

                IF v_filter_lines.COUNT > 0
                THEN
                    FOR i IN v_filter_lines.FIRST .. v_filter_lines.LAST
                    LOOP
                        -- call generic filter options setter
                        p_set_context_filters( p_filter_string            => v_filter_lines( i )
                                             , po_filter_clause           => v_filter_clause );
                    END LOOP;
                END IF;
                
            END IF;                

            pkg_error_manager.p_trace_end( p_context_in               => 'LOC'
                                         , p_text_in                  => 'f_build_query.p_set_all_filter_options' );
        END p_set_all_filter_options;

        --==========================================================================
        --==========================================================================
        PROCEDURE p_set_sort_column
        IS
        BEGIN
            pkg_error_manager.p_trace_start( p_context_in => 'LOC', p_text_in => 'f_build_query.p_set_sort_column' );

            pkg_error_manager.p_trace( p_context_in               => 'LOC_1'
                                     , p_text_in                  => 'Setting sort string......' || p_sort_string );

            IF p_sort_string IS NOT NULL
            THEN
                -- set the whole string
                v_sort_string              := ' ORDER BY ' || UPPER( NVL( p_sort_string, '1' ) );
            ELSE
                -- sort string null so no sorting required
                v_sort_string              := NULL;
            END IF;

            pkg_error_manager.p_trace_end( p_context_in => 'LOC', p_text_in => 'f_build_query.p_set_sort_column' );
        END p_set_sort_column;
    --==========================================================================
    --==========================================================================

    BEGIN
        -- validate inputs
        p_validate_parameters;

        -- intialise the query
        v_sql                      := 'SELECT ' || NVL(p_column_list, '*') || ' FROM (' || p_base_query || ') WHERE 1=1 ';

        -- build the filter clause
        p_set_all_filter_options;

        -- build the sort column
        p_set_sort_column;

        v_sql                      := v_sql || v_filter_clause || v_sort_string;

        pkg_error_manager.p_trace_start( p_context_in => 'LEVEL1', p_text_in => 'Sql is....' || v_sql );

        RETURN v_sql;
    END f_build_query;
--............................................................
--  Initialization section
--============================================================
BEGIN
    NULL;
END pkg_util_dynsql;
/