CREATE OR REPLACE PACKAGE pkg_utils
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
    -- Subtype for largest possible varchar2
    SUBTYPE max_varchar2_st IS VARCHAR2( 32767 );

    TYPE varchar250_array_type
    IS
        TABLE OF VARCHAR2( 250 )
            INDEX BY PLS_INTEGER;

    TYPE number_array_type
    IS
        TABLE OF NUMBER
            INDEX BY PLS_INTEGER;

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
    PROCEDURE p_assert( p_condition                   IN BOOLEAN
                      , p_message                     IN VARCHAR2:= NULL
                      , p_fatal                       IN BOOLEAN );


    --=============================================================================
    -- Function to fetch the current system status flag from the system parameters
    -- table.
    -- No exception handling is necessary since the row should always exist and be
    -- unique.
    --.............................................................................
    FUNCTION f_get_system_status
        RETURN INTEGER;
        
    --=============================================================================
    -- Procedure to set the current system status flag from the system parameters
    -- table.
    --.............................................................................
    PROCEDURE p_set_system_status (
        p_system_status     IN  INTEGER );
        
    --==========================================================================
    -- Procedure to clear all old data from the named application context.
    --.............................................................................
    PROCEDURE p_initialise_context( p_context_name IN VARCHAR2 );


    --==========================================================================
    -- This function selects the ora_rowscn column for a particular table
    -- and is selected using its primary key column and value...also passed in.
    -- Uses: Used to fetch the row scn number to test if it has changed or not
    --.............................................................................
    FUNCTION f_get_ora_row_scn( p_table_name                  IN VARCHAR2
                              , p_primary_key_col_name        IN VARCHAR2
                              , p_primary_key_value           IN NUMBER )
        RETURN NUMBER;

    --==========================================================================
    -- This procedure selects out the scn number of the row from the table and locks
    -- it.  This ensures that from now on the row is consistent.  This scn number
    -- is compared to the scn the the client holds for the row to ensure no other
    -- user has updated it.  If they are different a specific error is raised.
    --.............................................................................
    PROCEDURE p_lock_and_verify_rowdata( p_table_name                  IN VARCHAR2
                                       , p_primary_key_col_name        IN VARCHAR2
                                       , p_primary_key_data            IN NUMBER
                                       , p_existing_row_scn            IN NUMBER );



    --=========================================================================
    --=========================================================================
    --=========================================================================
    -- Functions to determine if the data passed in is null or not
    -- this is overloaded so it can be used for a range of data types
    -- They all return a string 'TRUE' or 'FALSE' 
    --........................................................................    
    FUNCTION f_is_data_null( p_data     IN  VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION f_is_data_null( p_data     IN  NUMBER)
        RETURN VARCHAR2;

    FUNCTION f_is_data_null( p_data     IN  DATE)
        RETURN VARCHAR2;

    FUNCTION f_is_data_null( p_data     IN  varchar_250_nt)
        RETURN VARCHAR2;

    FUNCTION f_is_data_null( p_data     IN  number_nt)
        RETURN VARCHAR2;
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
        RETURN VARCHAR2;
            --=========================================================================
    --=========================================================================    
    --=========================================================================




    --=============================================================================
    -- This function takes in a user supplied postcode, forces to uppercase
    -- and ensures there is a single space between the 2 portions.
    --.............................................................................
    FUNCTION f_format_postcode( p_input VARCHAR2 )
        RETURN VARCHAR2;

    --=========================================================================
    -- Function to take a delimited list and load it into a string associative
    -- array of type varchar250
    --........................................................................
    FUNCTION f_list_to_var250_array( p_input                       IN VARCHAR2
                                   , p_delimiter                   IN VARCHAR2 DEFAULT ',' )
        RETURN varchar250_array_type;


    --=========================================================================
    -- Function to take a delimited list and load it into a string nested table
    -- array of type varchar250
    --........................................................................
    FUNCTION f_list_to_var250_nested_tab( p_input                       IN VARCHAR2
                                        , p_delimiter                   IN VARCHAR2 DEFAULT ',' )
        RETURN varchar_250_nt;

    --=========================================================================
    -- Function to take a delimited list and load it into a string associative
    -- array of type number
    --........................................................................
    FUNCTION f_list_to_num_array( p_input                       IN varchar2
                                   , p_delimiter                   IN varchar2 DEFAULT ',' )
        RETURN number_array_type;

    --=========================================================================
    -- Function to take a delimited list and load it into a string nested table
    -- array of type number
    --........................................................................
    FUNCTION f_list_to_num_nested_tab( p_input                       IN varchar2
                                        , p_delimiter                   IN varchar2 DEFAULT ',' )
        RETURN number_nt;
        
    --=========================================================================
    -- Function to take a varchar2 input field and cast it as a date and return
    -- that date.
    --........................................................................
    FUNCTION f_string_to_date( p_input_field_name            IN VARCHAR2
                             , p_input                       IN VARCHAR2 )
        RETURN DATE;

    --=========================================================================
    -- Function to take a varchar2 input field and cast it as a number and return
    -- that number to the client
    --........................................................................
    FUNCTION f_string_to_number( p_input_field_name            IN VARCHAR2
                               , p_input                       IN VARCHAR2 )
        RETURN NUMBER;

    --=========================================================================
    -- Function to take a varchar2 input field and check to see if its null
    -- if it is raise an application error
    --........................................................................
    FUNCTION f_check_for_null( p_input_field_name            IN VARCHAR2
                             , p_input                       IN VARCHAR2 )
        RETURN VARCHAR2;

    --=========================================================================
    -- Function to extract the string between a pair of delimiters
    -- The occurence is eg 1st , 2nd , 3rd etc  occurece of the delimiter pair
    -- within the string
    --........................................................................
    FUNCTION f_get_string_between_delims( p_input_string                IN VARCHAR2
                                        , p_occurence                   IN NUMBER
                                        , p_start_delimiter             IN VARCHAR2 DEFAULT '['
                                        , p_end_delimiter               IN VARCHAR2 DEFAULT ']' )
        RETURN VARCHAR2;

    --=========================================================================
    -- Procedure to parse an input string of the format  NAME=VALUE
    -- and extract the name and value into output variables
    --........................................................................
    PROCEDURE p_get_name_value_pairs( p_input_string                IN     VARCHAR2
                                    , po_name                          OUT VARCHAR2
                                    , po_value                         OUT VARCHAR2 );


END pkg_utils;
/
