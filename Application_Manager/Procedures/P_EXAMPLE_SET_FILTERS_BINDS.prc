CREATE OR REPLACE PROCEDURE p_example_set_filters_BINDS (
    p_id_equals                 IN  NUMBER,
    p_id_less_than              IN  NUMBER,
    p_id_array                  IN  VARCHAR2,
    p_description_filter        IN  VARCHAR2,
    p_plsql_constant_filter     IN  VARCHAR2,
    po_results_cur              IN OUT SYS_REFCURSOR )
IS
    v_sql               VARCHAR2(32000);
    v_filter_clause     VARCHAR2(32000);
    
    v_id_array          number_nt;

BEGIN

    -- we are using the STATUS_CODE_T table as an example since it has data in it
    -- note we MUST  include the WHERE 1=1 clause
    v_sql := 'SELECT * FROM status_code_t WHERE 1=1';
    
    -- now setup the filters
    -- we need one of these calls for EVERY filter.
    -- For each one we specify: the column name ( as in the table ) 
    --                          the data type of the column
    --                          and the function call to f_is_data_null to determine if the parameter is null or not
    pkg_util_dynsql.p_set_bind_filters (    p_column_name   =>  'ID',
                                            p_data_type     =>  'NUMBER',
                                            p_data_is_null  =>  pkg_utils.f_is_data_null ( p_id_equals ),
                                            po_filter_clause => v_filter_clause
                                      );

    -- example of using the operator clause
    pkg_util_dynsql.p_set_bind_filters (    p_column_name   =>  'ID',
                                            p_data_type     =>  'NUMBER',
                                            p_operator      =>  '<',
                                            p_data_is_null  =>  pkg_utils.f_is_data_null ( p_id_less_than ),
                                            po_filter_clause => v_filter_clause
                                      );

    -- this is an example of passing in an array
    pkg_util_dynsql.p_set_bind_filters (    p_column_name   =>  'ID',
                                            p_data_type     =>  'ARRAY_NUM',
                                            p_data_is_null  =>  pkg_utils.f_is_data_null ( p_id_array ),
                                            po_filter_clause => v_filter_clause
                                      );
    
    pkg_util_dynsql.p_set_bind_filters (    p_column_name   =>  'DESCRIPTION',
                                            p_data_type     =>  'VARCHAR2',
                                            p_data_is_null  =>  pkg_utils.f_is_data_null ( p_description_filter),
                                            po_filter_clause => v_filter_clause
                                      );
        
    pkg_util_dynsql.p_set_bind_filters (    p_column_name   =>  'PLSQL_CONSTANT_NAME',
                                            p_data_type     =>  'VARCHAR2',
                                            p_data_is_null  =>  pkg_utils.f_is_data_null ( p_plsql_constant_filter),
                                            po_filter_clause => v_filter_clause
                                      );
    
    -- since we have an array of numbers as a filter we need to set up the array
    v_id_array := pkg_utils.f_list_to_num_nested_tab( p_id_array, '|' );
    
    -- now just add this filter clause to the base sql 
    v_sql := v_sql || v_filter_clause;
    
    -- debug the v_sql
    dbms_output.put_line( v_sql );
    
    -- Now open the cursor for v_sql
    -- Here we MUST bind EVERY filter that we use above
    OPEN po_results_cur
    FOR
    v_sql USING p_id_equals, p_id_equals, v_id_array, p_description_filter, p_plsql_constant_filter;


END p_example_set_filters_BINDS;
/