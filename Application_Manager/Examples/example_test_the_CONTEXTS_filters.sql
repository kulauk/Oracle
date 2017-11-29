variable rc0_PO_RESULTS_CUR refcursor
set autoprint on
set serveroutput on

DECLARE
    p_filter_clause  VARCHAR2( 32767 );
    p_sort_string    VARCHAR2( 32767 );
    po_results_cur   sys_refcursor;
BEGIN
    p_sort_string              := 'plsql_constant_name asc';

    -- this is an example of building the filters
    p_filter_clause            :=
        pkg_util_dynsql.f_build_filter_string( p_column_name              => 'id'
                                             , p_data_string              => ''
                                             , p_data_type                => 'NUMBER'
                                             , p_operator                 => ''
                                             , p_custom_filter            => '' );

    p_filter_clause            :=
        p_filter_clause || '~' ||
        pkg_util_dynsql.f_build_filter_string( p_column_name              => 'id'
                                             , p_data_string              => '107|207'
                                             , p_data_type                => 'ARRAY_NUM'
                                             , p_operator                 => ''
                                             , p_custom_filter            => '' );


    p_filter_clause            :=
        p_filter_clause || '~'
        || pkg_util_dynsql.f_build_filter_string( p_column_name              => 'description'
                                                , p_data_string              => 'Invalid'
                                                , p_data_type                => 'VARCHAR2'
                                                , p_operator                 => ''
                                                , p_custom_filter            => '' );


    DBMS_OUTPUT.put_line( p_filter_clause );

    -- the difference with the BINDS method is that this string could be built by the
    -- client eg the APP server (without calling f_build_filter_string ) ... so that 
    -- the filter delimited string is already built when the app server calls 
    -- the procedure that uses f_build_query.

    dulu.p_example_set_filters_contexts( p_filter_clause, p_sort_string, po_results_cur );

    :rc0_po_results_cur        := po_results_cur;

    DBMS_OUTPUT.put_line( '' );

    COMMIT;
END;
/