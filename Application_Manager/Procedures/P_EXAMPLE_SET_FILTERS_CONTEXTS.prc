CREATE OR REPLACE PROCEDURE p_example_set_filters_CONTEXTS (
    p_filter_clause             IN  VARCHAR2,
    p_sort_string               IN  VARCHAR2,
    po_results_cur              IN OUT SYS_REFCURSOR )
IS
    v_sql               VARCHAR2(32000);
    v_filter_clause     VARCHAR2(32000);

BEGIN
    -- as you can see the code in this example calling procedure is simpler 
    -- than the BINDS version p_example_set_filters_BINDS ... but thats because the 
    -- filters are defined by the formatted filter string that f_build_filter_string return or that
    -- the app server builds.  Whereas in the BINDS method the filters are defined explicitly by having
    -- each filter as a separate parameter.

    -- we are using the STATUS_CODE_T table as an example since it has data in it
    -- note we DO NOT require the WHERE 1=1 clause
    v_sql := 'SELECT * FROM status_code_t';

    v_sql:= pkg_util_dynsql.f_build_query(    p_column_list                 =>  '*'
                                            , p_base_query                  =>  v_sql           
                                            , p_filter_options              =>  p_filter_clause
                                            , p_sort_string                 =>  p_sort_string
                                            , p_initialise_context_flag     =>  'TRUE' );
    
    -- debug the v_sql
    dbms_output.put_line( v_sql );
    
    -- Now open the cursor for v_sql
    -- Here we DO NOT BIND ANYTHING
    OPEN po_results_cur
    FOR
    v_sql;


END p_example_set_filters_CONTEXTS;
/