CREATE OR REPLACE PACKAGE pkg_util_dynsql
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

    --=============================================================================
    --
    --      PUBLIC PROCEDURES AND FUNCTIONS
    --
    --=============================================================================

                                        
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
                                   , po_custom_filter                 OUT VARCHAR2 );

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
        RETURN VARCHAR2;

    --=========================================================================
    -- Procedure to setup a filter string for a dynamic filter clause
    -- The filter string must be formatted in a very specific way and the resulting
    -- string passed back is the actual WHERE clause that will be used in the
    -- dynamic query.
    -- See below for usage instructions:
    --==========================================================================
    -- This procedure sets up the filter options for a session context
    -- It accepts filter strings of the format
    --
    --  COLUMN_NAME=data[DATA_TYPE]
    --
    --  for example   NURSE_ID=23[NUMBER]
    --
    --  the nurse id is the column name in the session context
    --  and the 23 is the data you wish to set up in the session context
    --
    --  The different data types are NUMBER, VARCHAR2, DATE and CUSTOM
    --
    --  Normal filtering for number, strings and dates follow the following formats
    --
    --  numbers :       column_name = pkg_misc.f_string_to_number(SYS_CONTEXT('context_name', P_COLUMN_NAME ) )
    --  varchars:       UPPER(column_name) LIKE  '%' || SYS_CONTEXT('context_name', P_COLUMN_NAME ) || '%'
    --  dates:          TRUNC(column_name) = TRUNC( pkg_misc.f_string_to_date( SYS_CONTEXT('context_name', P_COLUMN_NAME ) ...etc
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
    --........................................................................
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
                                  , po_filter_clause              IN OUT VARCHAR2 );
    
    
    --=========================================================================
    -- Procedure to act as wrapper around p_set_filter_options to use the CONTEXTS
    -- method. It allows you to call p_set_filter_options using the CONTEXTS method
    -- by including the p_filter_string parameter only and excluding the rest.
    --........................................................................
    PROCEDURE p_set_context_filters(  p_filter_string               IN     VARCHAR2
                                    , po_filter_clause              IN OUT VARCHAR2 );
                                    
                                    
                                    
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
        RETURN VARCHAR2;
END pkg_util_dynsql;
/
